
use Test::More tests => 9 + 6 + 7 + 7;
use ICG::ZFSManager::Config;

{
  my $c = ICG::ZFSManager::Config->new_from_file("t.dat/c1.ini");
  ok($c);
  is($c->get("foo"), "bar", "get");
  is($c->get("XXX"), undef, "get missing");
  is($c->get("XXX", "default1"), "default1", "get default");
  is_deeply($c->get("someSection"), { porn => "goat" }, "get entire subsection");
  is($c->get("someSection.porn"), "goat", "get subsection val");
  is($c->get("someSection.XXX"), undef, "get subsection val missing");
  is($c->get("someSection.XXX.blurf"), undef, "get subsection val missing");
  is($c->get("someSection.XXX", "default2"), "default2", "get subsection val default");
}

{
  use ICG::ZFSManager::Group;

  my $c = ICG::ZFSManager::Config->new_from_file("t.dat/c2.ini");
  ok($c);

  $c->build_groups('ICG::ZFSManager::Group');
  is(join(" ", sort(map $_->name, $c->groups)), "green red", "Config->groups");

  my $red = $c->group("red");
  ok($red);
  is($red->name, 'red', "group name");
  is($red->get("fruit"), "apple", "specific value");
  is($red->get("type"), "color", "general value");
}

{
  my $c = ICG::ZFSManager::Config->new_from_file("t.dat/time.ini");
  ok($c);
  is($c->get_time('time1'),      5, "no suffix");
  is($c->get_time('time2'),     10, "s suffix");
  is($c->get_time('time3'),    420, "m suffix");
  is($c->get_time('time4'),  10800, "h suffix");
  is($c->get_time('time5'), 259200, "d suffix");
  eval { $c->get_time('time6') };
  like($@, qr/unknown.*suffix/i, "unknown suffix");
}

{
  my $c = ICG::ZFSManager::Config->new_from_file("t.dat/libdir.ini");
  ok($c);
  is_deeply([$c->get_dirs('path0')], [], "no dirs");
  is_deeply([$c->get_dirs('path1')], ["foo"], "one dir");
  is_deeply([$c->get_dirs('path2')], [qw(foo bar)], "two dirs");
  is_deeply([$c->get_dirs('path3')], [qw(foo bar baz)], "three dirs");
  is_deeply([$c->get_dirs('path4')], [], "missing item");
  is_deeply([$c->get_dirs('path5', [qw(blug bloop)])], [qw(blug bloop)],
             "missing item w/ default");
}
