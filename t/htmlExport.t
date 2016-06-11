use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use DateTime;
use Comic;

__PACKAGE__->runtests() unless caller;


my $today;
my @exported;


sub set_up : Test(setup) {
    Comic::reset_statics();
    @exported = ();
    $today = DateTime->now;
}


sub make_comic {
    my ($language, $title, $published, $contributor) = @_;

    my $contrib = $contributor || "";
    local *Comic::_slurp = sub {
        return <<XML;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{
&quot;title&quot;: {
    &quot;$language&quot;: &quot;$title&quot;
},
&quot;tags&quot;: {
    &quot;$language&quot;: [ &quot;JSON, tags&quot; ]
},
&quot;published&quot;: {
    &quot;when&quot;: &quot;$published&quot;
}
$contrib
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    *File::Path::make_path = sub {
        return 1;
    };
    *Comic::_export_language_html = sub {
        my ($self, $to, $language) = @_;
        push @exported, "$to:" . ($self->{meta_data}->{title}->{$language} || '');
        return;
    };

    *Comic::_write_sitemap_xml_fragment = sub {
        return;
    };
    *Comic::_now = sub {
        return $today;
    };
    return new Comic('whatever');
}


sub export_only_if_meta_title_for_language : Test {
    local *Comic::_make_comics_path = sub { die("should not make a path"); };
    my $comic = make_comic('English', 'title', '2016-04-19');
    $comic->_export_language_html('web/comics', 'Deutsch', ("Deutsch" => "de"));
    ok(1); # Would have failed above
}


sub navigation_links_first : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    Comic::export_all_html("English" => "en");

    is($jan->{'first'}{'English'}, 0, "Jan first");
    is($jan->{'prev'}{'English'}, 0, "Jan prev");
    is($jan->{'next'}{'English'}, "feb.html", "Jan next");
    is($jan->{'last'}{'English'}, "mar.html", "Jan last");
}


sub navigation_links_middle : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    Comic::export_all_html("English" => "en");

    is($feb->{'first'}{'English'}, "jan.html", "Feb first");
    is($feb->{'prev'}{'English'}, "jan.html", "Feb prev");
    is($feb->{'next'}{'English'}, "mar.html", "Feb next");
    is($feb->{'last'}{'English'}, "mar.html", "Feb last");
}


sub navigation_links_last : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    Comic::export_all_html("English" => "en");

    is($mar->{'first'}{'English'}, "jan.html", "Mar first");
    is($mar->{'prev'}{'English'}, "feb.html", "Mar prev");
    is($mar->{'next'}{'English'}, 0, "Mar next");
    is($mar->{'last'}{'English'}, 0, "Mar last");
}


sub ignores_unknown_language : Test {
    my $comic = make_comic('English', 'Jan', '2016-01-01'),
    Comic::export_all_html("Deutsch" => "de");
    is($comic->{pref}, undef);
}


sub skips_comic_without_that_language : Tests {
    my $jan = make_comic('English', 'jan', '2016-01-01');
    my $feb = make_comic('Deutsch', 'feb', '2016-02-01');
    my $mar = make_comic('English', 'mar', '2016-03-01');

    Comic::export_all_html("English" => "en", "Deutsch" => "de");

    is($jan->{'first'}{'English'}, 0, "Jan first");
    is($jan->{'prev'}{'English'}, 0, "Jan first");
    is($jan->{'next'}{'English'}, 'mar.html', "Jan next");
    is($jan->{'last'}{'English'}, 'mar.html', "Jan last");

    is($mar->{'first'}{'English'}, 'jan.html', "Mar first");
    is($mar->{'prev'}{'English'}, 'jan.html', "Mar first");
    is($mar->{'next'}{'English'}, 0, "Mar next");
    is($mar->{'last'}{'English'}, 0, "Mar last");

    is($feb->{'first'}{'Deutsch'}, 0, "Feb first");
    is($feb->{'prev'}{'Deutsch'}, 0, "Feb prev");
    is($feb->{'next'}{'Deutsch'}, 0, "Feb next");
    is($feb->{'last'}{'Deutsch'}, 0, "Feb last");
}


sub skips_comic_without_published_date : Test {
    my $not_yet = make_comic('English', 'not yet', '');
    Comic::export_all_html('English' => 'en');
    is_deeply(['tmp/backlog:not yet'], \@exported);
}


sub skips_comic_in_far_future : Tests {
    my $not_yet = make_comic('English', 'not yet', '2200-01-01');
    Comic::export_all_html('English' => 'en');
    is_deeply(['tmp/backlog:not yet'], \@exported);
}


sub includes_comic_for_next_friday : Tests {
    #       May 2016
    #  Su Mo Tu We Th Fr Sa
    #   1  2  3  4  5  6  7
    #   8  9 10 11 12 13 14
    #  15 16 17 18 19 20 21
    #  22 23 24 25 26 27 28
    #  29 30 31
    $today = DateTime->new(year => 2016, month => 5, day => 1);
    my $not_yet = make_comic('English', 'next Friday', '2016-05-01');
    Comic::export_all_html('English' => 'en');
    is_deeply(['web/comics:next Friday'], \@exported);
}


sub separate_navs_for_archive_and_backlog : Tests {
    my $a1 = make_comic('Deutsch', 'arch1', '2016-01-01');
    my $a2 = make_comic('Deutsch', 'arch2', '2016-01-02');
    my $b1 = make_comic('Deutsch', 'back1', '2222-01-01');
    my $b2 = make_comic('Deutsch', 'back2', '2222-01-02');
    Comic::export_all_html('Deutsch' => 'de');

    is($a1->{'prev'}{'Deutsch'}, 0, "arch1 should have no prev");
    is($a1->{'next'}{'Deutsch'}, "arch2.html", "arch1 next should be arch2");
    is($a1->{'first'}{'Deutsch'}, 0, "arch1 should have no first");
    is($a1->{'last'}{'Deutsch'}, "arch2.html", "arch1 last should be arch2");

    is($a2->{'prev'}{'Deutsch'}, "arch1.html", "arch2 prev should be arch1");
    is($a2->{'next'}{'Deutsch'}, 0, "arch2 should not have a next");
    is($a2->{'first'}{'Deutsch'}, "arch1.html", "arch2 first should be arch1");
    is($a2->{'last'}{'Deutsch'}, 0, "arch2 should not have a last");

    is($b1->{'prev'}{'Deutsch'}, 0, "back1 should not have a prev");
    is($b1->{'next'}{'Deutsch'}, "back2.html", "back1 next should be back2");
    is($b1->{'first'}{'Deutsch'}, 0, "back1 should not have a first");
    is($b1->{'last'}{'Deutsch'}, "back2.html", "back1 last should be back2");

    is($b2->{'next'}{'Deutsch'}, 0, "back2 should not have a next");
    is($b2->{'prev'}{'Deutsch'}, "back1.html", "back2 prev should be back1");
    is($b2->{'first'}{'Deutsch'}, "back1.html", "back2 first should be back1");
    is($b2->{'last'}{'Deutsch'}, 0, "back2 should not have a last");
}


sub write_templ_en {
    my ($comic) = @_;
    local *Comic::_slurp = sub {
        return <<TEMPL;
[% IF contrib %]
    <p style="contributors">With help from
        [% FOREACH c IN contrib %]
            [% c != contrib.first && c == contrib.last ? ' and ' : '' %]
            [% c %][% contrib.defined(2) ? ', ' : '' %]
        [% END %]
    </p>
[% END %]
TEMPL
    };
    return $comic->_do_export_html('Deutsch');
}


sub contributor_credit_en_none : Tests {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01');
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_en_empty : Tests {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib:&quot;: []');
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_en_one : Tests {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib&quot;: [ &quot;Mark Dilger&quot; ]');
    like(write_templ_en($comic), qr{With\s+help\s+from\s+Mark\s+Dilger}xim);
}


sub contributor_credit_en_two : Tests {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib&quot;: [ &quot;Mark Dilger&quot;, &quot;Mike Karr&quot;]');
    like(write_templ_en($comic),
        qr{With\s+help\s+from\s+Mark\s+Dilger\s+and\s+Mike\s+Karr}xim);
}


sub contributor_credit_en_many_en : Tests {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib&quot;: [ &quot;Mark Dilger&quot;, &quot;Mike Karr&quot;, &quot;My Self&quot;]');
    like(write_templ_en($comic),
        qr{With\s+help\s+from\s+Mark\s+Dilger,\s+Mike\s+Karr,\s+and\s+My\s+Self}xim);
}


sub write_templ_de {
    my ($comic) = @_;
    local *Comic::_slurp = sub {
        return <<TEMPL;
[% IF contrib %]
    <p style="contributors">Mit Ideen von
[% FOREACH c IN contrib %][% c != contrib.first && c == contrib.last ? ' und ' : '' %][% c != contrib.first && c != contrib.last ? ', ' : '' %][% c %][% END %]
    </p>
[% END %]
TEMPL
    };
    return $comic->_do_export_html('Deutsch');
}


sub contributor_credit_de_none : Test {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01');
    like(write_templ_de($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_de_empty : Tests {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib:&quot;: []');
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_de_one : Test {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib&quot;: [ &quot;Mark Dilger&quot; ]');
    like(write_templ_de($comic), qr{Mit\s+Ideen\s+von\s+Mark\s+Dilger}xim);
}


sub contributor_credit_de_two : Test {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib&quot;: [ &quot;Mark Dilger&quot;, &quot;Mike Karr&quot;]');
    like(write_templ_de($comic),
        qr{Mit\s+Ideen\s+von\s+Mark\s+Dilger\s+und\s+Mike\s+Karr}xim);
}


sub contributor_credit_de_many : Test {
    my $comic = make_comic('Deutsch', 'Beer flavored', '2016-01-01',
        ', &quot;contrib&quot;: [ &quot;Mark Dilger&quot;, &quot;Mike Karr&quot;, &quot;My Self&quot;]');
    like(write_templ_de($comic),
        qr{Mit\s+Ideen\s+von\s+Mark\s+Dilger,\s+Mike\s+Karr\s+und\s+My\s+Self}xim);
}
