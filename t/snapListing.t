
use Test::More tests => 4;
use ICG::ZFSManager::SnapshotListing;

my @words = qw(the quick brown fox thumps over a lazy trog);
my @snaps = map [$_, 's1', fake_date($_)], @words;
my @names = map "$_\@s1", @words;

my $q = ICG::ZFSManager::SnapshotListing->new(@snaps);
ok($q);
is_deeply(scalar($q->names), \@names, "->names");
is_deeply(scalar($q->snap_names), [("s1") x @words], "->names");

my $g = $q->glob('t*@s1');
is_deeply(scalar($g->names), [grep /^t/, @names], "->glob");

sub fake_date {
  my $str = shift;
  join "", map ord() - 64, split //, uc $str;
}

1;
