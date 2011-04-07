
package ZFS::Replicator::ZFSLister;
use ZFS::Replicator::Logger;
use Date::Parse 'str2time';
use ZFS::Replicator::Util qw(glob_grep match_glob);
use strict;

sub new {
  my $class = shift;
  bless {} => $class;
}

sub zfs_command {
  my ($self, $remote) = @_;
  my $zfs = $_[0]{ZFS} || "zfs";
  return $zfs;
}

sub run_command {
  my ($self, $cmd) = @_;
  return qx{$cmd};
}

# Qualify a command for remote execution
sub remote_command {
  my ($self, $remote, $command) = @_;

  return $command unless $remote;
  my @ssh = qw(zfs-ssh -o ConnectionAttempts=2 -o ConnectTimeout=10 -o BatchMode=yes);
  if (ref $command) {
    return [@ssh, $remote, @$command];
  } else {
    return join " ", @ssh, $remote, $command;
  }
}

sub filesystems {
  my ($self, $remote) = @_;
  my $ZFS = $self->zfs_command;
  my $cmd = $self->remote_command($remote, "$ZFS list -H -t filesystem");
  chomp(my @lines = $self->run_command($cmd));
  my @fs = map ((split /\t/)[0], @lines);
  return @fs;
}

sub filesystems_matching {
  my ($self, $glob, $remote) = @_;
  return glob_grep $glob, $self->filesystems($remote);
}

# This matches the full name, including filesystem and snapshot name
sub snapshots_matching {
  my ($self, $glob, $remote) = @_;
  Debug(["looking for snapshots matching %s on remote host <%s>",
         $glob, $remote]);
  return $self->snapshots($remote)->glob($glob);
}

sub snapshots {
  my ($self, $remote) = @_;
  my $ZFS = $self->zfs_command();
  my $cmd = $self->remote_command($remote, "$ZFS list -oname,creation -H -t snapshot");
  my @result;
  Debug("snapshots command: <$cmd>");
  chomp(my @lines = $self->run_command($cmd));

  if ($?) {
    my $st = $? >> 8;
    die "Command <$cmd> failed; exit status $st\n";
  }

  for my $line (@lines) {
    my ($name, $creation) = split /\t/, $line;
    push @result, [split(/\@/, $name, 2), str2time($creation)];
  }
  return $self->listing_factory->new(@result);
}

sub find_previous_snapshot {
  my ($self, $source, $snap_name, $group) = @_;
  Debug(["source %s\@%s", $source, $snap_name]);
  my $prev_snaps =
    $self->snapshots->glob($group->snap_pat($source))->by_date;
  my @snaps = $prev_snaps->snapshots;
  Debug(["Snaps: [%s]", \@snaps]);
  # discard snapshots until we find the one named by $snap_name
  # then discard that too and use the previous one, if there is one
  while (@snaps) {
    my $last = pop @snaps;
    # XXX encapsulation violation
    Debug(["popped %s\@%s", $last->[0], $last->[1]]);
    last if $last->[1] eq $snap_name;
  }
  # XXX encapsulation violation
  my $result = @snaps ? $snaps[-1][1] : undef;
  Debug(["result %s", $result]);
  return $result;
}

sub destroy {
  my ($self, $arg) = @_;
  my $not_really = $arg->{not_really};
  my $ZFS = $self->zfs_command();
  for my $what (@{$arg->{snaps}}) {
    my $cmd = qq{$ZFS destroy $what};
    if ($not_really) {
      Debug(["ZFSLister->destroy: Not actually executing < %s >", $cmd]);
    } else {
      Debug(["ZFSLister->destroy: Executing < %s >", $cmd]);
      $self->run_command($cmd);
    }
  }
}

# Snapshots available on local system but not on remote system
# TODO: Instead of depending on the names, we should set a user property, say
# com.icgroup:replication_id, at the time the snapshots are made.  Then we could
# depend on the ID numbers instead of hoping that the names are accurate.
sub missing_snapshots {
  my ($self, $group) = @_;
  my ($source, $target, $remhost) =
    ($group->get('source'), $group->get('target'), $group->get('remote_host'));
  Debug(["Looking for snapshots under %s missing from %s on host %s",
         $source, $target, $remhost]);

  my $local = $self->snapshots_matching($group->snap_pat($source));
  my $remote = $self->snapshots_matching(
    $group->snap_pat(_compose($source, $target)),
    $remhost
  );

  # Maybe have a ->grep method on SnapshotListings instead of this?
  my @d = grep ! $remote->contains($self->remote_snap_name($target, $_)), $local->snapshots;
  return $local->new(@d);
}

# Compose ZFS filesystem names
sub _compose {
  my ($source, $target) = @_;
  my ($pool, $source_fs) = split m{/}, $source, 2;
  return "$target/$source_fs";
}

# XXX encapsulation violation
sub remote_snap_name {
  my ($self, $target, $snap) = @_;
  my ($fs, $snapname, $moddate) = @$snap;
  return [ _compose($fs, $target), $snapname, $moddate ];
}

sub listing_factory {
  require ZFS::Replicator::SnapshotListing;
  return 'ZFS::Replicator::SnapshotListing';
}

1;
