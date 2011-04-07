
package ZFS::Replicator::Agenda;
use ZFS::Replicator::Logger;
use Carp 'croak';
use strict;

# An agenda is a sequence of objects that support is_finished, start, and stop
# methods.  The agenda will run them in sequence

sub new {
  my $class = shift;
  my %args = @_;
  my $self = bless { Q => []  } => $class;
  $self->{NAME} = delete $args{name} if exists $args{name};
  croak "Unknown arguments to new: ", join(", ", keys(%args))
    if %args;
  return $self;
}

sub name { $_[0]{NAME} }
sub _q { $_[0]{Q} }
sub events { @{$_[0]{Q}} }

sub is_empty { @{$_[0]->_q} == 0 }

sub current_event {
  my $self = shift;
  return $self->_q->[0];
}

sub pop_current_event {
  my $self = shift;
  $self->current_event->stop;
  shift @{$self->_q};
}

sub add_event {
  my ($self, $event) = @_;
  push @{$self->_q}, $event;
}

sub add_events {
  my ($self, @events) = @_;
  $self->add_event($_) for @events;
}

# An agenda is "finished" if every task in it is finished.
sub is_finished {
  my $self = shift;
  for my $ev (@{$self->_q}) {
    return if ! $ev->is_finished;
  }
  return 1;  # All tasks are finished, so the agenda is idle
}

# An agenda is "idle" if it is empty, or if its head task is not running
sub is_idle {
  my $self = shift;
  return $self->is_empty || ! $self->current_event->is_running;
}

sub start_next_event {
  my $self = shift;
  Debug(["Agenda %s starting next event", $self->name]);
  return if $self->is_empty;
  my $fin_ev;
  $fin_ev = $self->pop_current_event if $self->current_event->is_finished;
  unless ($self->is_empty) {
    $self->current_event->start;
    Log(["Agenda '%s' started task '%s'", $self->name, $self->current_event->name]);
  }
  return $fin_ev;
}

sub kill {
  my $self = shift;
  return if $self->is_empty;
  return if $self->current_event->is_finished;
  $self->current_event->stop;
}

1;
