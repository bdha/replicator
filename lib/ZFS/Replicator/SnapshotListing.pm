package ZFS::Replicator::SnapshotListing;
use ZFS::Replicator::Logger;
use ZFS::Replicator::Util qw(match_glob);
use strict;

# Format: snapdata is an array whose elements are 
# [ filesystem name, snapshot name, creation-date ] triples
sub new {
  my $base = shift;
  my $class = ref($base) || $base;
  my @snapdata = @_;
  bless { SNAPS => \@snapdata, SORTED => undef } => $class;
}

sub snapshots {
  my $self = shift;
  return @{$self->{SNAPS}};
}

sub names {
  my $self = shift;
  my @names = map _snapname($_), @{$self->{SNAPS}};
  return wantarray ? @names : \@names;
}

sub _snapname { join '@', $_[0][0], $_[0][1] }

sub snap_names {
  my $self = shift;
  my @names = map $_->[1], @{$self->{SNAPS}};
  return wantarray ? @names : \@names;
}

# return only snapshots whose filesystem matches the supplied pattern
sub glob {
  my ($self, $pat) = @_;
  my @in = $self->snapshots();
  my @matches = grep match_glob($pat, _snapname($_)), $self->snapshots();
  Debug(["Snaps filtered with '%s': before %d after %d",
         $pat, scalar @in,  scalar @matches]);
  return $self->new(@matches);
}

# return only snapshots whose filesystem matches the supplied pattern
# -- unimplemented --

# return only snapshots whose snapshot name matches the supplied pattern
sub snap_filter {
  my ($self, $pat) = @_;
  my @in = $self->snapshots();
  my @matches = grep match_glob($pat, $_->[1]), @in;
  Debug(["Snaps filtered with '%s': before %d after %d",
         $pat, scalar @in,  scalar @matches]);
  return $self->new(@matches);
}

sub sorted_by {
  my ($self, $what) = @_;
  return defined($self->{SORTED}) && $self->{SORTED} eq "by $what";
}

# Sort snapshots by name, in place
sub sort {
  my $self = shift;
  return $self if $self->sorted_by('name');
  @{$self->{SNAPS}} = sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
    @{$self->{SNAPS}};
  $self->{SORTED} = 'by name';
  return $self;
}

sub by_date {
  my $self = shift;
  return $self if $self->sorted_by('date');
  @{$self->{SNAPS}} = sort { $a->[2] <=> $b->[2] } @{$self->{SNAPS}};
  $self->{SORTED} = 'by date';
  return $self;
}

sub latest { $_[0]->by_date->{SNAPS}[-1] }

sub count {
  my $self = shift;
  return scalar(@{$self->{SNAPS}});
}

sub splice_some {
  my ($self, $n) = @_;
  return splice @{$self->{SNAPS}}, 0, $n;
}

sub older_than {
  my ($self, $age) = @_;
  my $now = $self->time();
  return grep $now - $_->[2] > $age, @{$self->{SNAPS}};
}

sub contains {
  my ($self, $snap) = @_;
  for my $e ($self->snapshots) {
    return 1 if $e->[0] eq $snap->[0] && $e->[1] eq $snap->[1];
  }
  return;
}

sub as_string {
  my ($self, $term) = @_;
  $term ||= "\n";

  return join "", map "$_->[0]\@$_->[1]$term", $self->snapshots;
}

# For testing only!
sub _force_time { $_[0]{TIME} = $_[1]; return $_[0] }
sub time { defined($_[0]{TIME}) ? $_[0]{TIME} : time() }

1;
