
use ZFS::Replicator::Config;
use ZFS::Replicator::Group;
use ZFS::Replicator::SnapshotListing;
use Test::More tests => 5 + 12 + 0;
use Test::Deep;
use strict;
use warnings;

sub sn {
  return ZFS::Replicator::SnapshotListing->new(
    [ "fs", "mjd-c", 3000 ],
    [ "fs", "mjd-a", 100 ],
    [ "fs", "mjd-b", 200 ],
    [ "fs", "mjd-b", 700 ],
  );
}

sub by_date { $a->[2] <=> $b->[2] }

my @sn = sort by_date sn()->snapshots; # newest first

note "** max_count tests";
{
  my %conf;
  my $c = ZFS::Replicator::Group->new_from_hash('test', \%conf);

  for my $i (4, 3, 2, 1) {
    $conf{max_count} = $i;
    cmp_bag([$c->destructible_snapshots(sn)], [@sn[0 .. 4-$i-1]]);
  }

  # Even with a max count of 0, the freshest one will never be destroyed
  $conf{max_count} = 0;
  cmp_bag([$c->destructible_snapshots(sn)], [ @sn[0 .. 2] ]);
}

note "** old age tests";
{
  my %conf;
  my $c = ZFS::Replicator::Group->new_from_hash('test', \%conf);
  my $now = 10000; # Pretend that the time is 10000
  $c->_force_time($now);

  for my $i (
    # this:
    [9900, 1], # means if retire_after is LESS THAN OR EQUAL TO 9900, then
    # we expect to expire 1, and otherwise 0

    [9800, 2],
    [9300, 3],
    [5000, 4],
            ) {
    my ($retire_after_base, $x) = @$i;
    for my $retire_after (reverse $retire_after_base - 1
                            .. $retire_after_base + 1) {
      $conf{retire_after} = $retire_after;
      my $x_num_destroyed = $x -
        ($retire_after <= $retire_after_base ? 0 : 1);

      # Never destroy the last one
      $x_num_destroyed = @sn-1 if $x_num_destroyed > @sn-1;
      note "retire_after = $retire_after; expect to destroy $x_num_destroyed";

      cmp_bag([$c->destructible_snapshots(sn()->_force_time($now))],
              [@sn[0 .. $x_num_destroyed - 1]]);
    }
  }
}


# conjunction tests

