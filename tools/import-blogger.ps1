# One-time import: copies each app's Privacy Policy and Terms from the live
# Blogger posts into content/<app>/, as clean HTML, word for word.
#
# Why a script and not a copy-paste: this is legal text. It is lifted by a
# parser, stripped of Blogger's styling only (tags kept: headings, paragraphs,
# lists, tables, links, bold, italics), and then checked - the visible text of
# the new file must equal the visible text of the Blogger post, character for
# character after collapsing whitespace. A file that fails is not written.
#
# After this runs once, content/ is the source. Edit the files there; do not
# re-import, or edits made here are overwritten by Blogger's copy.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\import-blogger.ps1

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$utf8 = New-Object System.Text.UTF8Encoding $false

$posts = @(
  @{ app = 'one-page';   doc = 'privacy'; url = 'https://zilloris.blogspot.com/2026/09/one-page-privacy-policy.html' },
  @{ app = 'one-page';   doc = 'terms';   url = 'https://zilloris.blogspot.com/2026/09/one-page-terms-of-use.html' },
  @{ app = 'manuscript'; doc = 'privacy'; url = 'https://zilloris.blogspot.com/2026/09/manuscript-privacy-policy.html' },
  @{ app = 'manuscript'; doc = 'terms';   url = 'https://zilloris.blogspot.com/2026/09/manuscript-terms-of-use.html' },
  @{ app = 'note-bolt';  doc = 'privacy'; url = 'https://zilloris.blogspot.com/2026/09/note-taking-privacy-policy.html' },
  @{ app = 'note-bolt';  doc = 'terms';   url = 'https://zilloris.blogspot.com/2026/09/note-taking-terms-and-conditions.html' }
)

# tag -> output tag; anything not listed is unwrapped (its children kept, the tag dropped)
$keep = @{ H1='h2'; H2='h2'; H3='h3'; H4='h4'; H5='h4'; H6='h4'; P='p'; UL='ul'; OL='ol'; LI='li';
           STRONG='strong'; B='strong'; EM='em'; I='em'; A='a'; BLOCKQUOTE='blockquote'; CODE='code';
           TABLE='table'; THEAD='thead'; TBODY='tbody'; TR='tr'; TH='th'; TD='td'; BR='br'; HR='hr' }
$blockTags = 'P','UL','OL','TABLE','H1','H2','H3','H4','H5','H6','BLOCKQUOTE','DIV','HR','SECTION'

function Enc([string]$s) { $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function Norm([string]$s) { ($s -replace '[\s ]+', ' ').Trim() }

function Walk($n) {
  if ($n.nodeType -eq 3) { return (Enc ($n.nodeValue -replace ' ', ' ')) }
  if ($n.nodeType -ne 1) { return '' }
  $tag = $n.nodeName.ToUpper()
  if ($tag -in 'SCRIPT','STYLE') { return '' }
  $inner = -join (@($n.childNodes) | ForEach-Object { Walk $_ })
  if ($tag -eq 'DIV' -or $tag -eq 'SECTION') {
    # a div holding only inline content was a paragraph in Blogger's editor
    $hasBlock = @($n.childNodes) | Where-Object { $_.nodeType -eq 1 -and $blockTags -contains $_.nodeName.ToUpper() }
    if ($hasBlock -or -not $inner.Trim()) { return $inner } else { return "<p>$($inner.Trim())</p>`n" }
  }
  if (-not $keep.ContainsKey($tag)) { return $inner }
  $t = $keep[$tag]
  if ($t -in 'br','hr') { return "<$t>" }
  if ($t -eq 'a') {
    $href = [string]$n.getAttribute('href')
    if ($href -match '^(https?:|mailto:)') { return "<a href=""$(Enc $href)"">$inner</a>" } else { return $inner }
  }
  $nl = if ($t -in 'p','h2','h3','h4','ul','ol','li','table','tr','blockquote') { "`n" } else { '' }
  if ($t -in 'p','li','h2','h3','h4','td','th' -and -not $inner.Trim()) { return '' }
  return "<$t>$inner</$t>$nl"
}

function Parse([string]$html) {
  $d = New-Object -ComObject 'HTMLFile'
  $d.write([ref]$html)   # [ref] is how this COM parser accepts a string here
  return $d
}

$failed = 0
foreach ($p in $posts) {
  $bytes = (Invoke-WebRequest $p.url -UseBasicParsing).RawContentStream.ToArray()
  $html  = [System.Text.Encoding]::UTF8.GetString($bytes) -replace '(?s)<script.*?</script>', ''
  $doc   = Parse $html
  $body  = @($doc.getElementsByTagName('div')) | Where-Object { "$($_.className)" -like 'post-body*' } | Select-Object -First 1
  $title = @($doc.getElementsByTagName('h3')) | Where-Object { "$($_.className)" -like 'post-title*' } | Select-Object -First 1
  if (-not $body) { "FAIL  $($p.app)/$($p.doc): no post body found"; $failed++; continue }

  $clean = (-join (@($body.childNodes) | ForEach-Object { Walk $_ })) -replace "(`n){3,}", "`n`n"
  $clean = $clean.Trim()

  # Fidelity: the new file's visible text must equal the Blogger post's visible text.
  $check = Parse "<html><body>$clean</body></html>"
  $want  = Norm $body.innerText
  $got   = Norm $check.body.innerText
  if ($want -ne $got) {
    $i = 0; while ($i -lt [Math]::Min($want.Length, $got.Length) -and $want[$i] -eq $got[$i]) { $i++ }
    "FAIL  $($p.app)/$($p.doc): text differs at character $i"
    "      blogger: ...$($want.Substring([Math]::Max(0,$i-30), [Math]::Min(80, $want.Length-[Math]::Max(0,$i-30))))..."
    "      ours:    ...$($got.Substring([Math]::Max(0,$i-30), [Math]::Min(80, $got.Length-[Math]::Max(0,$i-30))))..."
    $failed++; continue
  }

  $dir = Join-Path $here "content\$($p.app)"
  New-Item -ItemType Directory -Force $dir | Out-Null
  $stamp = Get-Date -Format 'yyyy-MM-dd'
  $head  = "<!-- title: $((Norm $title.innerText)) -->`n" +
           "<!-- imported $stamp from $($p.url), word for word; this file is now the source -->`n"
  [System.IO.File]::WriteAllText((Join-Path $dir "$($p.doc).html"), $head + $clean + "`n", $utf8)
  "OK    $($p.app)/$($p.doc).html  $($want.Length) characters, identical to Blogger  ($((Norm $title.innerText)))"
}
if ($failed) { "$failed document(s) not written."; exit 1 }
