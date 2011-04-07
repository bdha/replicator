package ZFS::Replicator::Util;
use Sub::Exporter;
Sub::Exporter::setup_exporter({ exports => [ qw(glob_grep match_glob) ]});

sub match_glob {
  my ($pat, $target) = @_;
  my $rx = pat_to_regex($pat);
  return $target =~ /$rx/;
}

sub glob_grep {
  my ($pat, @targets) = @_;
  my $rx = pat_to_regex($pat);
  return grep /$rx/, @targets;
}

my %tr = ('\*' => '.*',
          '\?' => '.',
         );
my $tr_pat = join "|", map quotemeta($_), keys %tr;

my %cache;
sub pat_to_regex {
  my $pat = shift();
  return $cache{$pat} if exists $cache{$pat};
  my $qpat = quotemeta($pat);
  $qpat =~ s/(?!<\\)(?:\\\\)*($tr_pat)/$tr{$1}/g;
  return $cache{$pat} = qq{\\A$qpat\\z};
}

1;

