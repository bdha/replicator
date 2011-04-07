
package ZFS::Replicator::AgendaManager;
use ZFS::Replicator::Logger;
use POSIX ();
use strict;

sub new {
  my ($class, $queue_factory) = @_;
  bless { AF => $queue_factory,
          AGENDA => {},
          STOPPED => {},
        } => $class;
}

# clean up finished tasks, start new tasks
sub manage_agendas {
  my $self = shift;
  for my $agenda ($self->agendas) {
    my $result = $self->manage_agenda($agenda);
    _show_result($agenda, $result) if defined $result;
  }
}

sub manage_agenda {
  my ($self, $agenda) = @_;
  my $result;

  Debug(["Managing agenda '%s'", $agenda->name]);
  if ($self->agenda_stopped($agenda)) {
    Debug("It's stopped.");
    return;
  }

  if ($agenda->is_idle) {
    Debug(["It's idle; advancing it"]);
    my $prev_task = $agenda->start_next_event();
    if ($prev_task) {
      if ($prev_task->successful) {
        $result = $prev_task->result();
      } else {
        Log(["Agenda '%s' task '%s' failed: %s; stopping agenda",
             $agenda->name, $prev_task->name,
             $prev_task->safe_result]);
        $self->stop_agenda($agenda);
        return;
      }
    }
  }

  if ($agenda->is_empty) {
    Debug(["It's empty; filling it"]);
    $self->fill_agenda($agenda->name);
  }
  return $result;
}

sub _show_result {
  my ($agenda, $result) = @_;
  Debug(["Agenda '%s' produced output <<%s>>",
       $agenda->name, $result]);
}

sub create_agenda {
  my ($self, $name, $taskBuilder) = @_;
  $self->{AGENDA}{$name} = $self->agenda_factory->new(name => $name);
  $self->{TB}{$name} = $taskBuilder;
  $self->{STOPPED}{$name} = 0;
  $self->fill_agenda($name);
}

# given the name of group, generate a list of all the work that
# needs to be done for that group
sub fill_agenda {
  my ($self, $agenda_name) = @_;

  my @tasks = $self->task_builder($agenda_name)->make_tasks();
  $self->agenda($agenda_name)->add_events(@tasks);
}

sub agenda { $_[0]{AGENDA}{$_[1]} }
sub agendas { return values %{$_[0]{AGENDA}} }

sub agenda_factory { $_[0]{AF} }
sub set_agenda_factory { $_[0]{AF} = $_[1] }

sub task_builder {
  my ($self, $agenda_name) = @_;
  return $self->{TB}{$agenda_name};
}

sub set_task_builder {
  my ($self, $agenda_name, $task_builder) = @_;
  $self->{TB}{$agenda_name} = $task_builder;
}

sub kill_all {
  my $self = shift;
  for my $agenda ($self->agendas) {
    $agenda->kill();
  }
}

# All agendas are idle?
sub is_idle {
  my $self = shift;
  for my $agenda ($self->agendas) {
    return unless $self->agenda_stopped($agenda) || $agenda->is_idle;
    Debug(["Agenda '%s' is idle"]);
  }
  Debug("All agendas are idle");
  return 1;
}

sub stop_agenda {
  my ($self, $agenda) = @_;
  $self->{STOPPED}{$agenda->name()} = 1;
}

sub start_agenda {
  my ($self, $agenda) = @_;
  $self->{STOPPED}{$agenda->name()} = 0;
}

sub agenda_stopped {
  my ($self, $agenda) = @_;
  return $self->{STOPPED}{$agenda->name};
}

sub restart_agendas {
  my $self = shift;
  for my $k (keys %{$self->{STOPPED}}) {
    my $ag = $self->agenda($k);
    if ($self->agenda_stopped($ag)) {
      Log(["Restarting agenda '%s'", $k]);
      $self->start_agenda($ag);
    }
  }
}

1;


