# One-time correction of Manuscript's documents (23 Sep 2026), approved by the
# owner with this exact wording.
#
# The documents moved from Blogger to zilloris.com on 22 Sep 2026, so the
# privacy policy's section 5 and the terms' third-party list named a service
# the app no longer contacts, and the wrong company for who sees a reader's
# network address. Only those passages change, and the effective dates move to
# 23-Sep-2026. Every copy is edited together: the published pages, the copies
# bundled in the app, and the drafting sources in the repo.
#
# Usage: perl tools/blogger-to-github-pages.pl

use strict; use warnings; use utf8;
binmode(STDOUT, ':utf8');

my $site = 'C:/my/Claude/zilloris-site/content/manuscript';
my $app  = 'C:/my/Claude/manuscript/app/src/main/assets/legal';
my $repo = 'C:/my/Claude/manuscript/store/legal';

my @files = (
    "$site/privacy.html", "$site/terms.html",
    "$app/privacy.html",  "$app/terms.html",
    "$repo/privacy-policy.html", "$repo/terms-of-use.html",
    "$repo/privacy-policy.md",   "$repo/terms-of-use.md",
);

my $dash = qr/(?:&mdash;|\x{2014})/;     # html entity or the character itself
my $apos = qr/(?:&rsquo;|\x{2019}|')/;

for my $f (@files) {
    open my $in, '<:encoding(UTF-8)', $f or die "$f: $!";
    my $t = do { local $/; <$in> }; close $in;
    my $before = $t;
    my $n = 0;

    # the section heading, in html and in markdown
    $n += $t =~ s{5\. Blogger ($dash) the text of this policy}{5. The web pages $1 the text of this policy}g;

    # where the documents live, and who serves them
    $n += $t =~ s{This policy and the terms of use are published on Blogger, a Google service,(\s+)at\s+<code>zilloris\.blogspot\.com</code>\.}
                 {This policy and the terms of use are published at <code>zilloris.com</code>,$1on GitHub Pages, a GitHub service.}g;
    $n += $t =~ s{This policy and the terms of use are published on Blogger, a Google service, at\n`zilloris\.blogspot\.com`\.}
                 {This policy and the terms of use are published at `zilloris.com`, on\nGitHub Pages, a GitHub service.}g;

    # the cross-reference later in the policy
    $n += $t =~ s{<strong>5\. Blogger</strong>}{<strong>5. The web pages</strong>}g;
    $n += $t =~ s{\*\*5\. Blogger\*\*}{**5. The web pages**}g;

    # the terms' third-party list
    $n += $t =~ s{<strong>Blogger</strong>, a Google service, publishes this document and the(\s+)privacy policy\. When you open either one inside the app, the app downloads it(\s+)from there, and Blogger$apos;?s terms apply to that request\.}
                 {<strong>GitHub Pages</strong>, a GitHub service, publishes this document and the$1privacy policy at <code>zilloris.com</code>. When you open either one inside$2the app, the app downloads it from there, and GitHub&rsquo;s terms apply to$2that request.}g;
    $n += $t =~ s{\*\*Blogger\*\*, a Google service, publishes this document and the privacy policy\.\n  When you open either one inside the app, the app downloads it from there, and\n  Blogger's terms apply to that request\.}
                 {**GitHub Pages**, a GitHub service, publishes this document and the privacy\n  policy at `zilloris.com`. When you open either one inside the app, the app\n  downloads it from there, and GitHub's terms apply to that request.}g;

    # the dates, now that the documents have changed
    $n += $t =~ s{Effective 16-Sep-2026}{Effective 23-Sep-2026}g;
    $n += $t =~ s{Effective date: 15-Sep-2026}{Effective date: 23-Sep-2026}g;
    $n += $t =~ s{(<span class="ph">)15-Sep-2026(</span>)}{${1}23-Sep-2026$2}g;
    $n += $t =~ s{(<span class="ph">)16-Sep-2026(</span>)}{${1}23-Sep-2026$2}g;

    if ($t ne $before) {
        open my $out, '>:encoding(UTF-8)', $f or die $!;
        print $out $t; close $out;
    }
    printf "%-58s %d change%s\n", (split m{/}, $f)[-2] . '/' . (split m{/}, $f)[-1], $n, ($n == 1 ? '' : 's');
}

# The published copies came back from Blogger without their <strong> and <code>
# tags, so the two passages above read as plain text there. Same words.
for my $f ("$site/privacy.html", "$site/terms.html") {
    open my $in, '<:encoding(UTF-8)', $f or die "$f: $!";
    my $t = do { local $/; <$in> }; close $in;
    my $n = 0;
    $n += $t =~ s{see 5\. Blogger above}{see 5. The web pages above}g;
    $n += $t =~ s{<li>Blogger, a Google service, publishes this document and the privacy policy\. When you open either one inside the app, the app downloads it from there, and Blogger\x{2019}s terms apply to that request\.</li>}
                 {<li>GitHub Pages, a GitHub service, publishes this document and the privacy policy at <code>zilloris.com</code>. When you open either one inside the app, the app downloads it from there, and GitHub\x{2019}s terms apply to that request.</li>}g;
    open my $out, '>:encoding(UTF-8)', $f or die $!;
    print $out $t; close $out;
    printf "%-58s %d more\n", (split m{/}, $f)[-2] . '/' . (split m{/}, $f)[-1], $n;
}
