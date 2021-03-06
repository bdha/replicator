
use Test::More tests => 4;
use ZFS::Async::Storable;
my $ft = ZFS::Async::Storable->new();
ok($ft);

my $fruit = { apple  => [ 'red', 'green' ],
              cherry => [ 'red', 'black' ],
              banana => [ 'green', 'yellow' ],
              orange => [ 'orange' ] };

my $s = $ft->freeze($fruit);
ok($s);

my $d = $ft->thaw($s);
ok($d);
is_deeply($d, $fruit, "round trip");

