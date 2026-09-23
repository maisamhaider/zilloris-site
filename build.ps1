# Builds zilloris.com into docs/ - the folder GitHub Pages serves.
#
#   apps.json         which apps appear, and what each card says
#   src/index.html    the page, with <!--APPS--> and friends filled in here
#   src/site.css      the studio look (shared with the Shelf and the covers)
#   content/<id>/     each app's About, Privacy and Terms (src/app-page.html + src/themes/)
#
# Icons come straight from each app's own repo, resized to 192px so the page
# stays light; the fonts from the apps' own res/font. Nothing is fetched from
# the internet, and nothing here costs money to host.
#
# docs/ is rebuilt from scratch every run: edit src/ and apps.json, never docs/.
#
# Usage: powershell -ExecutionPolicy Bypass -File build.ps1

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here                 # C:\my\Claude
$docs = Join-Path $here 'docs'
$utf8 = New-Object System.Text.UTF8Encoding $false
function Write-Text($path, $text) { [System.IO.File]::WriteAllText($path, $text, $utf8) }
function Esc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }

# ---- fresh output ---------------------------------------------------------
if (Test-Path $docs) { Remove-Item -Recurse -Force $docs }
foreach ($d in 'docs', 'docs\assets\fonts', 'docs\assets\icons') {
  New-Item -ItemType Directory -Force (Join-Path $here $d) | Out-Null
}

Copy-Item (Join-Path $here 'src\site.css')    $docs
Copy-Item (Join-Path $here 'src\404.html')    $docs
Copy-Item (Join-Path $here 'src\favicon.svg') $docs
Copy-Item (Join-Path $here 'src\app-base.css') (Join-Path $docs 'assets\app-base.css')
New-Item -ItemType Directory -Force (Join-Path $docs 'assets\themes') | Out-Null
Copy-Item (Join-Path $here 'src\themes\*.css') (Join-Path $docs 'assets\themes')

# GitHub Pages: the custom domain, and no Jekyll (it would hide .well-known/).
Write-Text (Join-Path $docs 'CNAME') "zilloris.com`n"
Write-Text (Join-Path $docs '.nojekyll') ''
Write-Text (Join-Path $docs 'robots.txt') "User-agent: *`nAllow: /`n"

# ---- fonts ------------------------------------------------------------------
# Each app's pages use that app's own fonts, copied from its repo.
$fonts = @{
  'one-page\app\src\main\res\font\bricolage_grotesque_800.ttf'    = 'bricolage-grotesque-800.ttf'
  'one-page\app\src\main\res\font\instrument_sans_400.ttf'        = 'instrument-sans-400.ttf'
  'one-page\app\src\main\res\font\instrument_sans_600.ttf'        = 'instrument-sans-600.ttf'
  'one-page\app\src\main\res\font\geist_mono_400.ttf'             = 'geist-mono-400.ttf'
  'note-taking\app\src\main\res\font\dmserifdisplay_regular.ttf'  = 'dm-serif-display-400.ttf'
}
foreach ($f in $fonts.Keys) {
  Copy-Item (Join-Path $root $f) (Join-Path $docs "assets\fonts\$($fonts[$f])")
}
# The Open Font License lets these be shared freely, on condition its text
# travels with them. Add a font above and its copyright line goes in this file.
Copy-Item (Join-Path $here 'src\fonts-OFL.txt') (Join-Path $docs 'assets\fonts\OFL.txt')

# ---- icons ------------------------------------------------------------------
$ffmpeg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue |
          Select-Object -First 1 -ExpandProperty FullName
$data = Get-Content (Join-Path $here 'apps.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$warnings = @()

# Only apps with a build on Google Play appear on the site (owner's rule, 22 Sep 2026).
$hidden = @($data.apps | Where-Object { -not $_.onPlay } | ForEach-Object { $_.name })
$data.apps = @($data.apps | Where-Object { $_.onPlay })
if ($hidden.Count) { $warnings += "Not on Play yet, so hidden: $($hidden -join ', ')" }

foreach ($a in $data.apps) {
  if (-not $a.icon) { $warnings += "$($a.name): no icon file yet - shown as a letter"; continue }
  $src = Join-Path $root $a.icon
  if (-not (Test-Path $src)) { throw "Icon for $($a.name) not found: $src" }
  $dst = Join-Path $docs "assets\icons\$($a.id).png"
  if ($ffmpeg) { & $ffmpeg -y -loglevel error -i $src -vf 'scale=192:192:flags=lanczos' $dst }
  else         { Copy-Item $src $dst; $warnings += "ffmpeg not found - $($a.name)'s icon copied at full size" }
}

# ---- studio covers, if they have been rendered ----------------------------
$covers = Join-Path $root 'shelf\marketing\covers\images'
$ogTag = ''; $touchTag = ''
if (Test-Path (Join-Path $covers 'og-image.png')) {
  Copy-Item (Join-Path $covers 'og-image.png') (Join-Path $docs 'assets\og.png')
  $ogTag = '<meta property="og:image" content="https://zilloris.com/assets/og.png">' + "`n" +
           '<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">'
} else { $warnings += 'No studio og-image rendered: link previews will have no picture' }
if (Test-Path (Join-Path $covers 'avatar-small.png')) {
  Copy-Item (Join-Path $covers 'avatar-small.png') (Join-Path $docs 'apple-touch-icon.png')
  $touchTag = '<link rel="apple-touch-icon" href="/apple-touch-icon.png">'
}

# ---- the app cards ----------------------------------------------------------
$cards = foreach ($a in $data.apps) {
  if ($a.icon) {
    $icon = "<img class=""icon"" src=""/assets/icons/$($a.id).png"" alt="""" width=""72"" height=""72"" loading=""lazy"">"
  } else {
    $ground = if ($a.ground) { "--mark-ground:$(Esc $a.ground);" } else { '' }
    $icon = "<span class=""icon mark"" style=""$ground"" aria-hidden=""true"">$(Esc $a.name.Substring(0,1))</span>"
  }
  $links = ''; $nameHtml = Esc $a.name
  if ($a.pages) {
    $nameHtml = "<a href=""/$($a.id)/"">$(Esc $a.name)</a>"
    $links = "<span class=""links""><a href=""/$($a.id)/"">About</a><a href=""/$($a.id)/privacy/"">Privacy</a><a href=""/$($a.id)/terms/"">Terms</a></span>"
  }
@"
        <li class="app" style="--accent:$(Esc $a.accent)">
          $icon
          <div>
            <h3>$nameHtml</h3>
            <p class="line">$(Esc $a.line)</p>
            <div class="meta">
              <span class="status $(Esc $a.status)">$(Esc $a.statusText)</span>
              $links
            </div>
          </div>
        </li>
"@
}

$n = @($data.apps).Count
$page = [System.IO.File]::ReadAllText((Join-Path $here 'src\index.html'), $utf8)
$page = $page.Replace('<!--APPS-->', ($cards -join "`n")).
              Replace('<!--COUNT-->', "$n apps").
              Replace('<!--YEAR-->', (Get-Date).Year.ToString()).
              Replace('<!--OG_IMAGE-->', $ogTag).
              Replace('<!--TOUCH_ICON-->', $touchTag)
Write-Text (Join-Path $docs 'index.html') $page

# ---- each app's own pages: About, Privacy, Terms ---------------------------
# content/<id>/*.html is the source (the policies were imported word for word
# from Blogger; see tools/import-blogger.ps1). This only dresses it.
$dash = [char]0x2014
$tpl  = [System.IO.File]::ReadAllText((Join-Path $here 'src\app-page.html'), $utf8)
$docsList = @(
  @{ doc = 'about';   file = 'about.html';   path = '';         label = 'About' },
  @{ doc = 'privacy'; file = 'privacy.html'; path = 'privacy/'; label = 'Privacy' },
  @{ doc = 'terms';   file = 'terms.html';   path = 'terms/';   label = 'Terms' }
)
function PlainText([string]$s) { ([System.Net.WebUtility]::HtmlDecode(($s -replace '<[^>]+>', '')) -replace '\s+', ' ').Trim().ToLower() }
$pageCount = 0
foreach ($a in @($data.apps | Where-Object { $_.pages })) {
  foreach ($d in $docsList) {
    $src = Join-Path $here "content\$($a.id)\$($d.file)"
    if (-not (Test-Path $src)) { throw "Missing $src - every app with pages=true needs about, privacy and terms" }
    $raw   = [System.IO.File]::ReadAllText($src, $utf8)
    $title = if ($raw -match '<!-- title: (.*?) -->') { $Matches[1].Trim() } else { $a.name }
    $body  = ([regex]::Replace($raw, '(?s)<!--.*?-->', '')).Trim()

    if ($d.doc -eq 'about') {
      $h1 = $a.name
      $pageTitle = "$($a.name) $dash $($a.line.TrimEnd('.'))"
      $status = "  <p class=""status"">$(Esc $a.statusText)</p>"
    } else {
      # "One Page - Privacy Policy" -> heading "Privacy Policy"; the app name is in the header already
      $h1 = ($title -split '\s+[\u2014\u2013-]\s+', 2)[-1]
      $pageTitle = "$h1 $dash $($a.name)"
      $status = ''
      # Drop leading lines that only repeat the title ("Manuscript", "Privacy Policy",
      # "Manuscript, by Zilloris"): the page heading and header already say them.
      $repeat = @($title, "$($a.name) $([char]0x00B7) by Zilloris") + ($title -split '\s+[\u2014\u2013-]\s+') | ForEach-Object { PlainText $_ }
      while ($body -match '^\s*<(p|h2|h3)\b[^>]*>(.*?)</\1>\s*') {
        if ($repeat -contains (PlainText $Matches[2])) { $body = $body.Substring($Matches[0].Length) } else { break }
      }
    }

    $nav = ($docsList | ForEach-Object {
      $cur = if ($_.doc -eq $d.doc) { ' aria-current="page"' } else { '' }
      "<a href=""/$($a.id)/$($_.path)""$cur>$($_.label)</a>"
    }) -join ''

    $html = $tpl.Replace('{{PAGE_TITLE}}', (Esc $pageTitle)).
                 Replace('{{DESCRIPTION}}', (Esc "$h1 for $($a.name), an Android app by Zilloris.")).
                 Replace('{{CANONICAL}}', "https://zilloris.com/$($a.id)/$($d.path)").
                 Replace('{{ID}}', $a.id).Replace('{{DOC}}', $d.doc).
                 Replace('{{NAME}}', (Esc $a.name)).Replace('{{NAV}}', $nav).
                 Replace('{{H1}}', (Esc $h1)).Replace('{{STATUS}}', $status).
                 Replace('{{CONTENT}}', $body)
    $dir = Join-Path $docs "$($a.id)\$($d.path)"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Write-Text (Join-Path $dir 'index.html') $html
    $pageCount++

  }
}


# ---- report -----------------------------------------------------------------
$kb = [math]::Round(((Get-ChildItem $docs -Recurse -File | Measure-Object Length -Sum).Sum) / 1KB)
"Built docs/: $n apps on the home page, $pageCount app pages, $kb KB in total."
$warnings | ForEach-Object { "  note: $_" }
