
package ZFS::Async::ShellCommand::Simple;
use base 'ZFS::Async::ShellCommand';
use strict;
use Carp 'croak';

sub new {
    my ($class, $command, @args) = @_;
#    warn "## pre command($command) args(@args)";
    if (@args == 0 && $command =~ /\W/) {
      @args = ('-c', join " ", $command, @args);
      $command = 'sh';
    }
#    warn "## pos command($command) args(@args)";
    return $class->SUPER::new({command => $command,
                               args => \@args,
                               name => "command '$command @args'",
                               die_on_failure => 1,
                              });
}

1;
