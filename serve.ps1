# Serves docs/ at http://localhost:8765 so the site can be checked before it is
# pushed. The pages use root paths (/site.css, /assets/...) because that is what
# zilloris.com needs, so opening docs/index.html as a file will not show them.
#
# Usage: powershell -ExecutionPolicy Bypass -File serve.ps1   (Ctrl+C to stop)

param([int]$Port = 8765)
$docs = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'docs'
$types = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.svg'='image/svg+xml';
            '.png'='image/png'; '.ttf'='font/ttf'; '.txt'='text/plain; charset=utf-8'; '.json'='application/json' }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
"Serving $docs at http://localhost:$Port/"

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
  if ($path -eq '' -or $path.EndsWith('/')) { $path += 'index.html' }
  $file = Join-Path $docs $path
  $status = 200
  if (-not (Test-Path $file -PathType Leaf)) { $file = Join-Path $docs '404.html'; $status = 404 }
  $bytes = [System.IO.File]::ReadAllBytes($file)
  $ctx.Response.StatusCode = $status
  $ext = [System.IO.Path]::GetExtension($file).ToLower()
  $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.Close()
}
