
use Test::More tests => 9;
use ICG::ZFSManager::SignalManager;

my $sm = ICG::ZFSManager::SignalManager->new();
ok($sm);

ok(! $sm->should_stop_immediately(), "no flag set initially 1");
ok(! $sm->should_stop_after_sends(), "no flag set initially 2");

my %signo;
{
  use Config;
  my @signames = split(' ', $Config{sig_name});
  for (0 .. $#signames) {
    $signo{$signames[$_]} = $_;
  }
}

$sm->install_signal_handlers();
kill $signo{TERM} => $$;
ok(  $sm->should_stop_immediately(), "stop immediately 1");
ok(! $sm->should_stop_after_sends(), "stop immediately 2");

$sm->clear;
ok(! $sm->should_stop_immediately(), "no flag set after clear 1");
ok(! $sm->should_stop_after_sends(), "no flag set after clear 2");

kill $signo{USR1} => $$;
ok(! $sm->should_stop_immediately(), "stop after sends 1");
ok(  $sm->should_stop_after_sends(), "stop after sends 2");

1;
