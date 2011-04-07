
package ZFS::Replicator::SignalManager;
use ZFS::Replicator::Logger;
use strict;

sub new {
  my ($class) = @_;
  my $self = bless { SIGNALS => { }  } => $class;
}

sub signal_handler_table {
  return
    ([TERM => 'stop_immediately'],
     [USR1 => 'stop_after_sends'],
     [USR2 => 'restart_agendas'],
    );
}

sub install_signal_handlers {
  my $self = shift;
  for my $kvp ($self->signal_handler_table()) {
    $self->install_signal_handler(@$kvp);
  }
}

sub install_signal_handler {
  my ($self, $signal, $record_name) = @_;
  $SIG{$signal} = sub { 
    Log("Received signal $signal ($record_name)");
    $self->{SIGNALS}{$record_name} = 1;
  };
}

sub signal_record { $_[0]{SIGNALS} }

sub should_stop_immediately { $_[0]->signal_record->{stop_immediately} }
sub should_stop_after_sends { $_[0]->signal_record->{stop_after_sends} }
sub should_restart_agendas  { $_[0]->signal_record->{restart_agendas} }

sub clear {
  my $self = shift;
  %{$self->signal_record} = ();
}

1;
