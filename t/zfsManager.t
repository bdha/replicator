
use Test::More tests => 6;
use ICG::ZFSManager;

{
  my $z = ICG::ZFSManager->new();
  ok($z);
  $z->options();
  ok(1);
}

# Test config file loading
{
  my $z = ICG::ZFSManager->new();
  $z->set_conf_file("t.dat/c1.ini");
  ok($z->configure(), "configured");
  is($z->conf->get('age'), 16, "configured value");
}

# Test pid file and cross-lockout feature
{
  use POSIX 'tmpnam';
  my ($tmp) = tmpnam();
  my ($z1, $z2) = (ICG::ZFSManager->new(), ICG::ZFSManager->new());
  $z1->set_conf(MockConfig->new($tmp));
  $z2->set_conf(MockConfig->new($tmp));
  $z1->lock_pidfile();
  my $pid = fork();
  die "fork: $!" unless defined $pid;
  if ($pid > 0) { # parent
    wait();
    is($?, 0, "child was locked out");
  } else {        # child
    close $tmpFH;
    eval { $z2->lock_pidfile() };
    exit $@ && $@ =~ /already running/ ? 0 : 1;
  }

  # Make sure the right pid ends up in the pid file
  $z1->save_pid();
  open my($tmpFH), "<", $tmp or die "can't open '$tmp': $!";
  seek $tmpFH, 0, 0 or die "seek";
  chomp(my $pid = <$tmpFH>);
  is($pid, $$, "pid check");
}

package MockConfig;
use Carp 'croak';

sub new {
  bless { pid_file => $_[1] } => __PACKAGE__;
}

sub get {
  my ($self, $key, $default) = @_;
  return $self->{$key} if exists $self->{$key};
  croak "unknown key '$key'";
}

1;
