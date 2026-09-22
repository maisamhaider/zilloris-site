# One-time repair of content/manuscript/*.html (22 Sep 2026).
#
# Blogger's editor dropped the class attributes our documents were written
# with, so the imported copies lost the section numbers ("1accepting these
# terms") and the tones the app sets in its own type: the effective line, the
# intro, the short version, the warning, the legalese.
#
# Manuscript downloads the published page and parses it (domain/Legal.kt), so
# these classes are not decoration - they are what the app reads. The words
# are never touched: every paragraph is matched to the same paragraph in the
# copy bundled with the app (app/src/main/assets/legal/), and only its class
# is copied across. A paragraph that does not match exactly is left alone.
#
# Usage: perl tools/restore-manuscript-classes.pl

use strict; use warnings; use utf8;
binmode(STDOUT, ':utf8');

my $bundled = 'C:/my/Claude/manuscript/app/src/main/assets/legal';

sub plain {                      # visible words, for matching only
    my $s = shift;
    $s =~ s/<[^>]+>//g;
    $s =~ s/&nbsp;/ /g; $s =~ s/&amp;/&/g; $s =~ s/&#8217;|&rsquo;/\x{2019}/g;
    $s =~ s/&#8220;|&ldquo;/\x{201c}/g; $s =~ s/&#8221;|&rdquo;/\x{201d}/g;
    $s =~ s/&#8212;|&mdash;/\x{2014}/g;
    $s =~ s/[\x{2018}\x{2019}]/'/g; $s =~ s/[\x{201c}\x{201d}]/"/g;
    $s =~ s/\s+/ /g;
    return lc trim($s);
}
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; $s }

for my $kind (qw(privacy terms)) {
    my $ours = "content/manuscript/$kind.html";
    open my $fh, '<:encoding(UTF-8)', "$bundled/$kind.html" or die "no bundled $kind: $!";
    my $src = do { local $/; <$fh> };

    # what the original said, paragraph by paragraph and heading by heading
    my (%class_of, %number_of);
    # The tones are written as a div around the paragraph (<div class="short">).
    # Blogger dropped the div, so the class goes onto the paragraph itself -
    # which the app reads the same way (Legal.kt inheritedTone).
    while ($src =~ /<div class="(short|warning|legalese|intro)">(.*?)<\/div>/gs) {
        my ($class, $inside) = ($1, $2);
        $class_of{plain($1)} = $class while $inside =~ /<p\b[^>]*>(.*?)<\/p>/gs;
    }
    while ($src =~ /<p\b([^>]*)>(.*?)<\/p>/gs) {
        my ($attrs, $inner) = ($1, $2);
        my $class = $attrs =~ /class\s*=\s*"([^"]*)"/ ? $1 : '';
        $class_of{plain($inner)} = $class if $class;
    }
    while ($src =~ /<h2\b[^>]*>\s*<span class="num">([^<]*)<\/span>(.*?)<\/h2>/gs) {
        $number_of{plain($2)} = $1;
    }

    open my $in, '<:encoding(UTF-8)', $ours or die "no $ours: $!";
    my $doc = do { local $/; <$in> };
    my ($paras, $heads) = (0, 0);

    $doc =~ s{<p>(.*?)</p>}{
        my $inner = $1;
        my $class = $class_of{plain($inner)};
        if ($class) { $paras++; qq{<p class="$class">$inner</p>} } else { "<p>$inner</p>" }
    }gse;

    $doc =~ s{<h2>(.*?)</h2>}{
        my $inner = $1;
        my $done = "<h2>$inner</h2>";
        for my $words (keys %number_of) {
            my $n = $number_of{$words};
            if (plain($inner) eq "$n$words") {          # "1accepting these terms"
                my $rest = $inner; $rest =~ s/^\Q$n\E//;
                $heads++; $done = qq{<h2><span class="num">$n</span>$rest</h2>};
                last;
            }
        }
        $done;
    }gse;

    open my $out, '>:encoding(UTF-8)', $ours or die $!;
    print $out $doc; close $out;
    print "$kind: $paras paragraph classes, $heads section numbers restored\n";
}
