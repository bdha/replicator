
package ZFS::Replicator::Logger;
use base 'Log::Dispatchouli';
use Carp 'croak';
use POSIX 'strftime';
use strict;

our $LOG;

if ($^P) {
  $LOG = __PACKAGE__->new({to_stderr => 1, debug => 1, ident => "zfscdr"});
  $LOG->log_debug("Logging enabled");
}

sub set_options {
  my ($self, $opts) = @_;
  return $LOG = $self->new($opts);
}

sub import {
  my $class = shift;
  croak "$class can't selectively export; aborting" if @_;
  my $caller = caller();
  no strict 'refs';
  *{"$caller\::Log"}   = sub { $LOG && $LOG->log(where(), @_) };
  *{"$caller\::Debug"} = sub { $LOG && $LOG->log_debug(where(), @_) };
  *{"$caller\::Fatal"} = sub { $LOG && $LOG->log_fatal(where(), @_) };
}

sub where {
  my $n = 2;
  my ($pack, $file, $line, $sub) = caller($n);
  $line = (caller($n-1))[2];
  $sub =~ s/^ZFS:://;
  $sub =~ s/^Replicator(::)?//;
  $sub =~ s/__ANON__/?/;
  my $when = strftime("%T", localtime());
  return "$when $sub($line)";
}


1;

