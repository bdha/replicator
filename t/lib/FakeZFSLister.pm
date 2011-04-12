
package t::lib::FakeZFSLister;
use base 'ZFS::Replicator::ZFSLister';
use Carp qw(croak);

#
# Doesn't yet simulate remote systems
#

sub set_fake_snapshots {
  my ($self, @snaps) = @_;
  $self->{SNAPS} = \@snaps;
  return $self;
}

sub fake_snapshots {
  my ($self) = @_;
  @{$self->{SNAPS}};
}

sub snapshots {
  my ($self) = @_;
  return $self->listing_factory->new($self->fake_snapshots);
}

sub filesystems {
  my ($self) = @_;
  my %fs = map { $_->[0] => 1 } $self->fake_snapshots;
  return keys %fs;
}

sub fake_command_output {
  my ($self, @output_sets) = @_;
  push @{$self->{OUTPUT}}, @output_sets;
  return $self;
}

sub run_command {
  my ($self, $cmd) = @_;
  my $lines = shift @{$self->{OUTPUT}};
  croak "No fake output set up for command '$cmd'" unless $lines;
  return @$lines;
}

1;
