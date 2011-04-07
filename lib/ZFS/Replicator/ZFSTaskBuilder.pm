
package ZFS::Replicator::ZFSTaskBuilder;
use ZFS::Replicator::Logger;
use ZFS::Replicator::Util qw(match_glob);
use strict;

sub new {
  my ($class, $args) = @_;
  my $self = bless {} => $class;
  $self->set_group($args->{group})           if exists $args->{group};
  $self->set_zfs_lister($args->{zfs_lister}) if exists $args->{zfs_lister};
  return $self;
}

sub group { $_[0]{group} }
sub set_group { $_[0]{group} = $_[1] }

sub zfs_lister { $_[0]{zfs_lister} }
sub set_zfs_lister { $_[0]{zfs_lister} = $_[1] }

sub make_tasks {
  my $self = shift;
  my $group = $self->group();
  my $source = $group->get('source');
  Debug(["Making tasks for '%s' (source=%s)", $group->name, $source]);

  my @tasks =
    ($self->zfs_snapshot_action($group, $source),
     $self->zfs_replicate_action($group, $source),
     $self->local_cleanup_action($group, $source),
     $self->remote_cleanup_action($group, $source));

  {
      my $end_time = $self->calculate_end_time($group);
      push @tasks, $self->abide_action($end_time);
  }

  return @tasks;
}

# zfs snapshot -r $SRC@repl-$STAMP
sub zfs_snapshot_action {
  my ($self, $group, $source) = @_;
  my @recursive = ();

  if ($source =~ s{/\*$}{}) {
    @recursive = ('-r');
  }

  my $snapshot_name = $self->snapshot_name($group);

  my $action;
  if ($source =~ m{\*}) {
    die "Sorry, * is implemented only at the end of a source name.  Aborting";
  } else {
    $action = $self->command_factory
      ->new("zfs",
            'snapshot', @recursive, _snap($source, $snapshot_name));
  }
#  $action->set_name("snapshot action");

  return $action;
}


# initial
#   zfs send              $NEWSNAP | $SSH $TARGET_HOST zfs recv -vdF $DST
# incremental
#   zfs send -i $LASTSNAP $NEWSNAP | $SSH $TARGET_HOST zfs recv -vdF $DST
sub zfs_replicate_action {
  my ($self, $group, $source) = @_;

  my $action = $self->action_factory->new(
    sub {
      my $remote = $group->get('remote_host');
      my $target = $group->get('target');
      Debug(["Replicating %s to %s on host %s", $source, $target, $remote]);

      my $missing_snapshots = $self->zfs_lister->missing_snapshots($group);

      Debug(["Remote side is missing snapshots: [%s]",
             scalar $missing_snapshots->names]);

      for my $name ($missing_snapshots->snapshots) {
        my ($snap_source, $snap_name) = @$name;
        next unless match_glob($source, $snap_source);
        my $cmd = $self->send_snapshot($snap_source, $snap_name, $group);
	Debug(["Sending snapshot %s\@%s to %s",
               $snap_source, $snap_name, $remote]);
        $cmd->start;
        $cmd->await;  # Run to completion before replicating the next one
      }
    });
  $action->set_name("replicate action");
  return $action;
}

sub send_snapshot {
  my ($self, $source, $snapshot, $group) = @_;

  my @incremental = ();
  {
    my $previous_snapshot =
      $self->zfs_lister->find_previous_snapshot($source, $snapshot, $group);

    if ($previous_snapshot) {
      Debug(["Found snapshot previous to %s: %s",
             $snapshot, $previous_snapshot]);
      @incremental = ('-i', _snap($source, $previous_snapshot));
    }
  }

  my $remote = $group->get('remote_host');
  my $target = $group->get('target');

  Log(["Sending %s\@%s to %s on %s (%s)",
       $source, $snapshot, $target, $remote,
      @incremental ? "incremental" : "base",
      ]);

  return $self->command_factory
    ->new(join " ",
          "zfs", "send", @incremental,
          _snap($source, $snapshot),
          '|',
          $self->zfs_lister
            ->remote_command($remote, "zfs recv -vdF $target"));
}

# zfs list -t snapshot -o name | grep repl | grep $SRC
sub local_cleanup_action {
  my ($self, $group)= @_;

  return $self->action_factory
    ->new(sub {
	    Debug(["Starting local cleanup for group %s", $group->name]);
            my $snapshots =
              $self->zfs_lister->snapshots_matching(
                $group->snap_pat($group->get('source')));
            my $n_snaps = $snapshots->count;

            my @to_destroy = $group->destructible_snapshots($snapshots);
            if (@to_destroy >= $n_snaps) {
              Fatal(["Bug: group '%s' wants to destroy *all* the snapshots",
                     $group->name]);
              return;
            }

            $self->zfs_lister->destroy(
              { snaps => [map _snap(@$_), @to_destroy],
                not_really => $group->get('test_mode'),
              });
            Debug(["finished calling destroyer"]);
            return @to_destroy;
          }, "local cleanup");
}

# $SSH $TARGET_HOST zfs list -t snapshot -o name | grep repl | grep $SRC
sub remote_cleanup_action {
  # TODO
  my $self = shift;
  return $self->action_factory->new(sub { 1 },
                                    "fake remote cleanup action");
}

# Sleep until it's time to start the next batch of tasks
sub abide_action {
  my ($self, $wakeup_time) = @_;
  return $self->action_factory
    ->new(sub {
	    my $wait_time = $wakeup_time - time();
	    sleep $wait_time;
            Debug("awake");
	  }, "sleeping until " . localtime($wakeup_time) );
}

# If $freq is 300, a later action will sleep until the (epoch) time is divisible
# by 300.  So it will sleep until the end of the current 5-minute period.
sub calculate_end_time {
  my ($self, $group) = @_;
  my $freq = $group->get_time('frequency');
  return $freq * POSIX::ceil(time()/$freq);
}

sub snapshot_name {
  my ($self, $group) = @_;
  my $snapshot_pat = $group->get('snapshot_name');
  return $self->strftime(defined($snapshot_pat) ? $snapshot_pat : "%i");
}

sub strftime {
  my ($self, $format) = @_;
  $format =~ s/%i/%Y%m%d%H%M%S/g;
  return POSIX::strftime($format, localtime());
}

sub _snap {
  my ($source, $snapshot_name) = @_;
  return join '@', $source, $snapshot_name;
}

sub command_factory {
  require ZFS::Async::ShellCommand::Simple;
  return "ZFS::Async::ShellCommand::Simple";
}

sub action_factory {
  require ZFS::Async;
  return "ZFS::Async";
}

1;
