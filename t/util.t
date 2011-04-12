
use Test::More 'no_plan';
use ZFS::Replicator::Util '-all';
use strict;
use warnings;

while (<DATA>) {
  next unless /\S/;
  chomp;
  my ($in, $exp) = split /\s+/, $_, 2;
  is(ZFS::Replicator::Util::pat_to_regex($in), "\\A$exp\\z");
}

__DATA__
foo	foo
*	.*
?	.
foo*	foo.*
^	\^
foo*/bar*   foo.*\/bar.*
x@y/*	x\@y\/.*
t*	t.*
