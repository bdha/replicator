package ZFS::Replicator::Config;
use Config::Any;
use strict;
use Carp 'croak';
use Scalar::Util 'reftype';

sub new {
  my $class = shift;
  bless {} => $class;
}

sub new_from_file {
  my ($class, $file) = @_;

  my $cfg = Config::Any->load_files({ files => [ $file ],
                                      use_ext => 1 });
  my $hash = eval { $cfg->[0]{$file} };
  return unless $hash;

  my $self = $class->new();
  $self->_set_hash($hash);
  $self->_set_filename($file);
  return $self;
}

sub new_from_hash {
  my ($base, $name, $hash) = @_;
  my $class = ref($base) || $base;
  my $self = $class->new();
  $self->_set_hash($hash);
  $self->_set_name($name);
  return $self;
}

sub get {
  my ($self, $key, $default) = @_;
  return $self->getpath($self->split($key), $default);
}

my %time_suffix = ('' => 1,
		   's' => 1,
		   'm' => 60,
		   'h' => 3600,
		   'd' => 86400,
		  );

sub get_time {
  my ($self, $key, $default) = @_;
  my $time = $self->get($key, $default);
  my ($n, $suf) = $time =~ /^(\d+)\s*(\w?)$/
    or die "Unparseable duration in config line '$key = $time'; aborting\n";
  my $m = $time_suffix{lc $suf}
    or die "Unknown time unit suffix '$suf' in config line '$key = $time'; aborting\n";
  return $n * $m;
}

sub getpath {
  my ($self, $path, $default) = @_;
  my @path = @$path;
  my $hash = $self->hash;
  while (my $component = shift @path) {
    unless (ref($hash) && reftype($hash) eq "HASH") {
      croak "Bad config path [@$path]";
    }

    if (defined $hash->{$component}) {
      $hash = $hash->{$component};
    } elsif ($self->parent) {
      return $self->parent->getpath($path, $default);
    } else {
      return $default;   # or die if we aren't at the *end* of the path?
    }
  }
  return $hash;
}

sub get_dirs {
  my ($self, $key, $default) = @_;
  $default ||= [];
  my $dirstring = $self->get($key);
  return defined($dirstring) ? ( split /:/, $dirstring ) : @$default;
}

sub split {
  my ($self, $key) = @_;
  return [ split /\./, $key ];
}

sub hash { $_[0]{H} }
sub _set_hash { $_[0]{H} = $_[1] }
sub filename { $_[0]{F} }
sub _set_filename { $_[0]{F} = $_[1] }
sub parent { $_[0]{P} }
sub _set_parent { $_[0]{P} = $_[1] }

# pull out group configurations and build groups
sub build_groups {
  my ($self, $group_factory) = @_;
  my $h = $self->hash;
  for my $k (keys %$h) {
    next unless $k =~ /^group:(.*)$/;
    my $group_conf = delete $h->{$k};

    $h->{group}{$1} = $group_factory->new_group($1, $group_conf, $self);
  }
}

sub groups { values %{$_[0]->hash->{group}} }
sub group {
  my ($self, $groupname) = @_;
  return $self->getpath(['group', $groupname]);
}

1;

