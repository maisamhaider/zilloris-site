# Builds zilloris.com into docs/ - the folder GitHub Pages serves.
#
#   apps.json         which apps appear, and what each card says
#   src/index.html    the page, with <!--APPS--> and friends filled in here
#   src/site.css      the studio look (shared with the Shelf and the covers)
#
# Icons come straight from each app's own repo, resized to 192px so the page
# stays light; the fonts come from One Page's res/font. Nothing is fetched from
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

# GitHub Pages: the custom domain, and no Jekyll (it would hide .well-known/).
Write-Text (Join-Path $docs 'CNAME') "zilloris.com`n"
Write-Text (Join-Path $docs '.nojekyll') ''
Write-Text (Join-Path $docs 'robots.txt') "User-agent: *`nAllow: /`n"

# ---- fonts ------------------------------------------------------------------
$fontSrc = Join-Path $root 'one-page\app\src\main\res\font'
$fonts = @{
  'bricolage_grotesque_800.ttf' = 'bricolage-grotesque-800.ttf'
  'instrument_sans_400.ttf'     = 'instrument-sans-400.ttf'
  'geist_mono_400.ttf'          = 'geist-mono-400.ttf'
}
foreach ($f in $fonts.Keys) {
  Copy-Item (Join-Path $fontSrc $f) (Join-Path $docs "assets\fonts\$($fonts[$f])")
}

# ---- icons ------------------------------------------------------------------
$ffmpeg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue |
          Select-Object -First 1 -ExpandProperty FullName
$data = Get-Content (Join-Path $here 'apps.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$warnings = @()

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
  $links = ''
  if ($a.links -and @($a.links).Count) {
    $links = '<span class="links">' + ((@($a.links) | ForEach-Object {
      "<a href=""$(Esc $_.url)"">$(Esc $_.label)</a>" }) -join '') + '</span>'
  }
@"
        <li class="app" style="--accent:$(Esc $a.accent)">
          $icon
          <div>
            <h3>$(Esc $a.name)</h3>
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

# ---- report -----------------------------------------------------------------
$kb = [math]::Round(((Get-ChildItem $docs -Recurse -File | Measure-Object Length -Sum).Sum) / 1KB)
"Built docs/: $n apps, $kb KB in total."
$warnings | ForEach-Object { "  note: $_" }
