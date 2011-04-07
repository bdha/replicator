
use Test::More tests => 2;
use ICG::ZFSManager::ZFSTaskBuilder;

my $tm = ICG::ZFSManager::ZFSTaskBuilder->new({ group => Gp->new(),
                                                zfs_lister => ZL->new() });
ok($tm);
my @tasks = $tm->make_tasks();

# Five tasks:
# 1. snapshot
# 2. replicate
# 3. local cleanup
# 4. remote cleanup
# 5. wait until next iteration
is(scalar(@tasks), 5);

package ZL;
sub new { bless {} => __PACKAGE__ }

package Gp;
BEGIN { %d = (source => "source", name => "group name",
              snapshot_name => 'mjd-%i',
              frequency_time => 600,
             ) }

sub new { bless {} => __PACKAGE__ }
sub get {
  my ($self, $key, $default) = @_;
  die "Gp '$key' not defined" unless exists $d{$key};
  return $d{$key};
}
sub get_time { $_[0]->get("$_[1]_time") }
sub name { $_[0]->get('name') }
