
use Test::More tests => 21;
use ICG::ZFSManager::Agenda;

my $q = ICG::ZFSManager::Agenda->new();
ok($q);

my($A, $B, $C) = map MockEvent->new($_), qw(A B C);
$q->add_events($A, $B, $C);
ok($q->is_idle, "not started = idle");
is($q->current_event->name, "A", "Agenda ordered");
$q->pop_current_event();
ok($q->is_idle, "not started = idle");
is($q->current_event->name, "B", "Agenda ordered");
ok(! $q->is_finished, "not started = not finished");
$q->start_next_event();
ok($B->is_running, "B started");
ok(! $q->is_idle, "started = not idle");
ok(! $q->is_finished, "not finished = not ready");
$B->stop;
ok($q->is_idle, "killed = idle");
ok(! $q->is_finished, "unfinished event = not finished");
$q->start_next_event();
is($q->current_event->name, "C", "Finished event discarded");
ok(! $q->is_idle, "started = not idle");
ok(! $q->is_finished, "started = not finished");
ok($C->is_running, "C started");
$q->kill;
ok($q->is_idle, "killed = idle");
ok($C->is_finished, "C killed");
ok($q->is_finished, "killed = ready");
$q->start_next_event();
ok($q->is_empty(), "no more events");
ok($q->is_finished, "empty = ready");
ok($q->is_idle, "empty = idle");


# Mock event class
package MockEvent;

sub new {
  my ($class, $name, $est) = @_;
  bless { A => $name, F => 0, R => 0 } => $class;
}

sub is_finished { $_[0]{F} }
sub is_running { $_[0]{R} }
sub start { $_[0]{R} = 1 }
sub stop { $_[0]{R} = 0; $_[0]{F} = 1 }
sub name { $_[0]{A} }
sub result {}

1;
