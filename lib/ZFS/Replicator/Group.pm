
package ZFS::Replicator::Group;
use base 'ZFS::Replicator::Config';
use Carp qw(croak);
use ZFS::Replicator::Logger;
use strict;
use warnings;

sub new_group {
  my ($class, $name, $hash, $parent) = @_;
  my $self = $class->SUPER::new();
  $self->_set_hash($hash);
  $self->_set_parent($parent);
  $self->hash->{name} = $name;
  return $self;
}

sub name { $_[0]->get("name") }
sub _set_name { $_[0]->hash->{name} = $_[1] }


sub snap_pat {
  my ($self, $fs) = @_;
  croak "missing argument in snap_pat" unless defined $fs;
  my $format = $self->get('snapshot_name');
  $format =~ s/%\w/*/g; # TODO: %Y should turn into ????, not into *.
  $format =~ tr/*/*/s;
  return join '@', $fs, $format;
}

# We will destroy all the snapshots that are too old
# and then any others that are in excess of max_count
# but if that would destroy all of them, then we will keep the most recent.
sub destructible_snapshots {
  my ($self, $snapshots) = @_;
  my @to_destroy;

  return if $snapshots->count == 0;

  $snapshots->by_date();
  my $last_snapshot = $snapshots->latest();

  my $n_to_keep = $self->get("max_count", $snapshots->count);
  $n_to_keep = 1 if $n_to_keep < 1;
  my $n_to_destroy = $snapshots->count - $n_to_keep;
  @to_destroy = $snapshots->splice_some($n_to_destroy)
    if $n_to_destroy > 0 && $n_to_keep < $snapshots->count;

  Debug(["to destroy A: [%s]", \@to_destroy]);

  # Now add the old snapshots to the list
  my $retire_after = $self->get_time("retire_after", 2**32-1);
  push @to_destroy, $snapshots->older_than($retire_after - 1);
  Debug(["to destroy B: [%s]", \@to_destroy]);

  return grep $_ != $last_snapshot, @to_destroy;
}

# For testing only!
sub _force_time { $_[0]{TIME} = $_[1]; $_[0] }
sub time { defined($_[0]{TIME}) ? $_[0]{TIME} : time() }


1;
