use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub no_dates : Test {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED => undef);
    $comic->_check_date();
    ok(1);
}


sub dates_no_collision : Test {
    MockComic::make_comic($MockComic::PUBLISHED => '2016-01-01');
    MockComic::make_comic($MockComic::PUBLISHED => '2016-01-02');
    my $comic = MockComic::make_comic($MockComic::PUBLISHED => '2016-01-03');
    $comic->_check_date();
    ok(1);
}


sub dates_with_collision : Test {
    MockComic::make_comic(
        $MockComic::PUBLISHED => '2016-01-01',
        $MockComic::IN_FILE => 'one.svg');
    MockComic::make_comic($MockComic::PUBLISHED => '2016-01-02');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED => '2016-01-01',
        $MockComic::IN_FILE => 'three.svg');
    eval {
        $comic->_check_date();
    };
    like($@, qr{three\.svg: duplicated date .+ one\.svg});
}


sub dates_with_collision_ignores_whitespace : Test {
    MockComic::make_comic(
        $MockComic::PUBLISHED => '2016-01-01 ',
        $MockComic::IN_FILE => 'one.svg');
    MockComic::make_comic($MockComic::PUBLISHED => '2016-01-02');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED => ' 2016-01-01',
        $MockComic::IN_FILE => 'three.svg');
    eval {
        $comic->_check_date();
    };
    like($@, qr{three\.svg: duplicated date .+ one\.svg});
}


sub dates_no_collision_different_languages : Test {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'not funny in German',
        },
        $MockComic::PUBLISHED => '2016-01-01');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'auf Englisch nicht lustig',
        },
        $MockComic::PUBLISHED => '2016-01-01');
    $comic->_check_date();
    ok(1);
}
