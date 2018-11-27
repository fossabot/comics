use strict;
use warnings;
use Test::More;

eval "use Test::MinimumVersion";
plan skip_all => "Test::MinimumVersion required to test minimum Perl version" if $@;
all_minimum_version_ok('5.10', { skip => ['t/MockComic.pm'] });