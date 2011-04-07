package ZFS::Replicator;
use strict;
use Carp 'croak';
use Fcntl qw(:flock O_RDWR O_CREAT);
use Getopt::Std;
use POSIX 'setsid';
use ZFS::Replicator::Logger;

sub new {
  my $class = shift;
  my $self = 
    bless { QM => $class->agenda_manager_factory->new(),
            SH => $class->signal_manager_factory->new(),
          } => $class;

  $self->agenda_manager->set_agenda_factory($class->agenda_factory);

  return $self;
}

sub Die {
  Fatal(@_);
  die @_;
}

sub default_config_file {
  "/etc/zfs-mgr.ini";
}

sub default_pid_file {
  "/var/run/zfs-mgr.pid";
}

sub pid_file {
  my $self = shift;
  return $self->conf->get('pid_file', $self->default_pid_file);
}

sub options {
  my $self = shift;
  local @ARGV = @_;
  local $SIG{__WARN__} = sub { Die @_ };
  my %opt = (1 => 0, 'x' => 0, g => undef,
             C => $self->default_config_file,
             v => 1, 0 => 0);
  my $ok = getopts('01xg:C:v:', \%opt)
    or return;

  $opt{v} =~ /^[012]$/ or return;

  # XXX: probably ought to use methods here
  $self->{daemon}      = ! $opt{'x'};
  $self->{onceonly}    = $opt{1};
  $self->{groups}      = $opt{g} ? [ $opt{g} ] : undef;
  $self->{conf_file}   = $opt{C};
  $self->{log_level}   = $opt{v};
  $self->{do_nothing}  = $opt{0};

  return $self;
}


sub conf_file { return $_[0]{conf_file} }
sub set_conf_file { $_[0]{conf_file} = $_[1] }

sub conf { return $_[0]{configuration} }
sub set_conf { $_[0]{configuration} = $_[1] }

sub run {
  my $self = shift;
  $self->initialize();

  if ($self->{do_nothing}) {
      Debug("do_nothing flag: exiting");
      exit 0;
  }

  $self->mainloop();
}

sub initialize {
  my $self = shift;

  $self->start_logging(daemon => $self->{daemon},
                       level => $self->{log_level}
                      );
  $self->configure();
  my $home = $self->conf->get("home", "/");
  if ($home) {
    chdir $home
      or Die "Couldn't chdir to home dir '$home': $!; aborting";
  }
  if (my $path = $self->conf->get('bin', "$home/bin")) {
    $ENV{PATH} = join ":", $path, $ENV{PATH};
  }

  $self->lock_pidfile();
  $self->daemonize() if $self->{daemon};
  $self->save_pid();

  $self->initialize_agendas();
  $self->install_signal_handlers();
}

sub configure {
  my $self = shift;
  my $conf = $self->load_conf($self->conf_file);
  $self->set_conf($conf);

  $self->conf->build_groups($self->group_factory);
  if (my @dirs = $self->conf->get_dirs('libdirs')) {
    unshift @INC, @dirs;
    $ENV{PERL5LIB} = join ":", $self->conf->get('libdirs') . $ENV{PERL5LIB};
  }

  # are the groups specified on the command line actually defined in the
  # config file?
  if ($self->{groups}) {
    for my $g (@{$self->{groups}}) {
      $self->conf->group($g)
        or Die "Group '$g' not defined in configuration file; aborting\n";
    }
  }

  # Other command-line-option vs config-file validation here

  return $self;
}

sub start_logging {
  my $self = shift;
  my %args = @_;

  my $stderr = $args{level} > 0 && ! $args{daemon};
  my $syslog = $args{level} > 0 &&   $args{daemon};

  my %opts = (ident => 'zfs-cdr',
              to_stderr => $stderr,
              $syslog ? (facility => 'daemon') : (),
              debug => $args{level} > 1,
	      prefix => $args{prefix} || 'zfs-cdr ',
             );

  my $logger =
    $self->logger_factory->set_options(\%opts);

  $logger->log(["($$) starting at %s", scalar(localtime())]);
  $logger->log_debug("In debug mode") if $opts{debug};
  return $logger;
}

sub logger_factory {
  require ZFS::Replicator::Logger;
  return "ZFS::Replicator::Logger";
}

sub mainloop {
  my $self = shift;

  while (1) {

    if ($self->signal_manager->should_stop_immediately) {
      Log("main loop: quitting because of signal");
      $self->quit;  # does not return
      exit 0;
    }

    if ($self->signal_manager->should_restart_agendas) {
      Log("main loop: restarting agendas because of signal");
      $self->agenda_manager->restart_agendas();
      $self->signal_manager->clear();
    }

    my $finish_soon = $self->{onceonly} ? "-1 flag" :
      $self->signal_manager->should_stop_after_sends ? 'a signal' : undef;
    Debug("main loop: quitting soon because of $finish_soon") if $finish_soon;
    $self->agenda_manager->manage_agendas unless $finish_soon;

    if ($finish_soon && $self->agenda_manager->is_idle) {
      Debug("main loop: agendas done; quitting") if $finish_soon;
      $self->quit;
      exit 0;
    }

    $self->abide();  # Sleep a bit and see what has happened
  }
}

sub abide {
  my $self = shift;
  select(undef, undef, undef, 1.0) unless $^P; # Zzzz.
}

sub load_conf {
  my ($self, $file) = @_;
  return
    $self->configuration_factory->new_from_file($file);
}

sub configuration_factory {
  require ZFS::Replicator::Config;
  return "ZFS::Replicator::Config";
}

sub lock_pidfile {
  my $self = shift;
  my $pidf = $self->pid_file;
  sysopen my($pidh), $pidf, O_RDWR | O_CREAT, 0666
    or Die "Couldn't open pid file $pidf: $!";
  flock $pidh, LOCK_EX | LOCK_NB
    or Die "Couldn't lock $pidf ($!); daemon already running?  Aborting";
  { my $ofh = select $pidh; $| = 1; select $ofh }
  $self->{pid_handle} = $pidh;
}

# This is separate from lock_pidfile because it must be post-daemonization
# (so it can save the correct pid.)
# locking the pidfile can't be post-daemonization because we would like
# to be able to issue an error message to STDERR if locking fails
sub save_pid {
  my $self = shift;
  my $pidh = $self->{pid_handle};
  truncate $pidh, 0;
  print $pidh "$$\n";
}

sub chdir_home { }

# TODO: Logging handle???
sub daemonize {
  my $self = shift;
  my $pid = fork();
  $self->chdir_home();
  Die "Can't fork: $!" unless defined $pid;
  exit if $pid > 0;

  POSIX::setsid();

  open STDIN, "<", "/dev/null";
  open STDOUT, ">", "/dev/null";
  open STDERR, ">", "/dev/null";

  return;
}

sub quit {
  my $self = shift;

  $self->agenda_manager->kill_all;
  Debug("stopping");

  # TODO other cleanup actions?

  exit 0;
}

sub initialize_agendas {
  my $self = shift;
  my $zfs_lister = $self->zfs_lister_factory->new();
  for my $group ($self->groups) {
    my $task_builder =
      $self->task_builder_factory->new({group => $group,
                                        zfs_lister => $zfs_lister });
    $self->agenda_manager->create_agenda($group->name, $task_builder);
  }
}
sub agenda_manager { $_[0]{QM} }

sub agenda_factory {
  require ZFS::Replicator::Agenda;
  return "ZFS::Replicator::Agenda";
}

sub agenda_manager_factory {
  require ZFS::Replicator::AgendaManager;
  return "ZFS::Replicator::AgendaManager";
}

sub task_builder_factory {
  require ZFS::Replicator::ZFSTaskBuilder;
  return "ZFS::Replicator::ZFSTaskBuilder";
}

sub groups { $_[0]->conf->groups }

sub group_factory {
  require ZFS::Replicator::Group;
  return "ZFS::Replicator::Group";
}

sub signal_manager { $_[0]{SH} }

sub signal_manager_factory {
  require ZFS::Replicator::SignalManager;
  return "ZFS::Replicator::SignalManager";
}

sub install_signal_handlers {
  my $self = shift();
  $self->signal_manager->install_signal_handlers();
}

sub zfs_lister_factory {
  require ZFS::Replicator::ZFSLister;
  return "ZFS::Replicator::ZFSLister";
}

1;

