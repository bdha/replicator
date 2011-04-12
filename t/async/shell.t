
use Test::More tests => 2 + 4 + 7 + 1;
#use Test::More tests => 1;
use ZFS::Async::ShellCommand;
use ZFS::Async::ShellCommand::Simple;
use Time::HiRes;


# Trying to check ->finished on a non-started task ought not to fail utterly
{
  my $t = ZFS::Async::ShellCommand::Simple->new("true");
  ok(! $t->is_started(), "non-started task is_started");
  ok(! $t->is_finished(), "non started task is_finished");
  $t->start;
  ok(  $t->is_started(), "started task is_started");
  sleep 1;
  ok(  $t->is_finished(), "started task is_finished");
}

{
  my $task = ZFS::Async::ShellCommand::Simple->new('true');
  ok($task);
  $task->start();
  is_deeply($task->await, { stdout => "", stderr => "", exit_status => 0 });
}

{
  note "sh -c 'exit 1'";
  my $task = ZFS::Async::ShellCommand::Simple->new(q{sh -c 'exit 1'});
  $task->start();
  my $res = eval { $task->await };
  is_deeply($@, { stdout => "", stderr => "", exit_status => 256 });
}

{
  note "echo potato";
  my $task = ZFS::Async::ShellCommand::Simple->new('echo', 'potato');
  $task->start();
  is_deeply($task->await, { stdout => "potato\n", stderr => "", exit_status => 0 });
}

{
  note "echo potato 1>&2";
  my $task = ZFS::Async::ShellCommand::Simple->new('echo potato 1>&2');
  $task->start();
  is_deeply($task->await, { stdout => "", stderr => "potato\n", exit_status => 0 });
}

{
  note "perl -e";
  my $task = ZFS::Async::ShellCommand::Simple->new('perl -e "print qq{foo\nbar}; die"');
  $task->start();
  my $res = eval { $task->await };
  is_deeply($@, { stdout => "foo\nbar",
                  stderr => "Died at -e line 1.\n",
                  exit_status =>  255 * 256
                });
}

{
  note "input from string";
  my $task = ZFS::Async::ShellCommand
    ->new({command => 'tr',
           args => [qw([a-z] [A-Z])],
           input => "With\nyour\nmouth!\n"
          },
         );

  $task->start();
  is_deeply($task->await, { stdout => "WITH\nYOUR\nMOUTH!\n",
			    stderr => "",
			    exit_status =>  0 * 256
			  });
}

# This test catches a bug at f85098f5b7a183f29cb2c893513e8d8c58c2b545
# Where if the task finished before the ->await call, the ->await
# would erroneously die because it was not running; it was only supposed
# to die if the task had never been started
{
  note "regression f85098";
  my $task = ZFS::Async::ShellCommand::Simple->new('true');
  ok($task);
  $task->start();
  sleep 1;
  is_deeply($task->await, { stdout => "", stderr => "", exit_status => 0 });
}

# New ->stdin feature means that shell command should use the specified
# filehandle as its stdin, instead of force-feeding it from $input
{
  note "input from stdin";
  my $data = "with.your.mouth";
  (my $DATA = $data) =~ tr/a-z./A-Z\n/;
  my $task = do
    { open my($rd), "echo '$data' | tr . '\\n' |" or die $!;
    #  warn "Pipe from " . fileno($wr) . " to " . fileno($rd) . "\n";
      ZFS::Async::ShellCommand->new({
        command => 'tr',
        args => [qw([a-z] [A-Z])],
        stdin => $rd,
      }) or die;
    };
  $task->start;
  is_deeply($task->await,
            { stdout => uc($DATA) . "\n", stderr => "", exit_status => 0 },
            "ShellCommand->new(stdin => ...)",
           );
}

