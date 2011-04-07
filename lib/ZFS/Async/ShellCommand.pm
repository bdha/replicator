package ZFS::Async::ShellCommand;
use base 'ZFS::Async';
use Carp 'croak';
use ZFS::Replicator::Logger;
use IO::Handle;
use IPC::Run;
use Symbol;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $code = $class->make_shell_command_action($args);
    my $self = $class->SUPER::new($code);
    my $name = $args->{name}
      || qq{shell command "$args->{command} @{$args->{args}}"};
    $self->set_name($name);
    return $self;
}

sub make_shell_command_action {
  my ($self, $args) = @_;
  $args ||= {};
  $args->{debug} ||= 0;

  return sub {
    my ($stdin, $stdout, $stderr) = ("", "", "");
#    $_ = IO::Handle->new() for my ($stdin, $stdout, $stderr);
    Debug(["Running shell command [%s]", [$args->{command}, @{$args->{args}}]]);
    my @STDIN;
    if (exists $args->{stdin}) {
      @STDIN = $stdin = $args->{stdin};
    } elsif (exists $args->{input}) {
      $stdin = $args->{input};
      @STDIN = (\$stdin);
    } else {
      $stdin = "";
      @STDIN = (\$stdin);
    }

    my $h = IPC::Run::start(
      [$args->{command}, @{$args->{args}}],
      @STDIN, \$stdout, \$stderr,
      debug => $args->{debug},
    );
    $h->finish;

    my ($res) = $h->full_results;
    my $result = { exit_status => $res,
                   stdout => $stdout,
                   stderr => $stderr,
                 };

    if ($res != 0 && $args->{die_on_failure}) {
      die $result;
    } else {
      return $result;
    }
  }
}

sub _contains {
  my ($set, $fh) = @_;
  return vec($set, fileno($fh), 1);
}

1;
