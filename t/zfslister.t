
use Test::More tests => 4 + 1;
use ZFS::Replicator::ZFSLister;
use t::lib::FakeZFSLister;
use strict;
use warnings;

{
  my $zl = ZFS::Replicator::ZFSLister->new();
  ok($zl);
  my $snap = [ 'rpool/zones/depot/tank/home', 'mjd-20100505', 0 ];
  my $target = 'rpool/zones/recon/tank';
  my $remote = $zl->remote_snap_name($target, $snap);
  is ($remote->[0], "rpool/zones/recon/tank/zones/depot/tank/home");
  is ($remote->[1], $snap->[1]);
  is ($remote->[2], $snap->[2]);
}

# BUG in filesystems_matching mjd 2010-11-11
{
  my $ls = t::lib::FakeZFSLister->new()->
    set_fake_snapshots(
      [ 'rpool/zones/depot/tank/home', 'mjd-20100505', 0 ],
      [ 'rpool/zones/depot/fred/home', 'mjd-20101111', 0 ],
      [ 'rpool/zones/depot/ned/home', 'mjd-20101111', 0 ],
    );
  my @match = $ls->filesystems_matching("rpool/zones/depot/*ed/home");
  is(@match, 2, "exactly two filesystems matching '../*ed/home'");
}


1;
