
use Test::More tests => 1 + 3 + 6;
use ZFS::Replicator::AgendaManager;

my $am = ZFS::Replicator::AgendaManager->new("FakeAgenda");
ok($am);

$am->create_agenda("foo", FakeTaskBuilder->new());
{
  my @ag = $am->agendas;
  is(@ag, 1);
  my $a = $ag[0];
  is($a->name, "foo");
  ok(! $am->agenda_stopped($a));
}

$am->create_agenda("bar", FakeTaskBuilder->new());
{
  my ($foo, $bar) = ($am->agenda("foo"), $am->agenda("bar"));

  ok(! $am->agenda_stopped($foo));
  ok(! $am->agenda_stopped($bar));
  $am->stop_agenda($bar);
  ok(! $am->agenda_stopped($foo));
  ok(  $am->agenda_stopped($bar));
  $am->restart_agendas();
  ok(! $am->agenda_stopped($foo));
  ok(! $am->agenda_stopped($bar));
}

package FakeAgenda;

sub new {
  my $class = shift;
  my %args = @_;
  return bless \%args => FakeAgenda;
}

sub name { $_[0]{name} }
sub stop { }

sub add_events {
  my $self = shift;
  push @{$self->{EV}}, @_;
}

package FakeTaskBuilder;  # Fake TaskBuilder

sub new { bless {} => __PACKAGE__ }
sub make_tasks { return () }

1;
