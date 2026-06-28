<#
  build_html.ps1 - build a SELF-CONTAINED dashboard.html that opens by
  double-click (file://), no server needed.

  It embeds every report's markdown + the manifest directly into the HTML,
  and inlines the markdown libraries (marked + DOMPurify) so the file also
  works fully offline. Falls back to CDN tags if libraries can't be fetched.

  Usage:  powershell -File build_html.ps1

  NOTE: ASCII-only source (PowerShell 5.1 safe). Korean only flows as DATA.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # PS 5.1: avoid Invoke-WebRequest hang/slowness
$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$reportsDir = Join-Path $root 'reports'
$vendorDir  = Join-Path $root 'vendor'
$indexFile  = Join-Path $root 'index.html'
$outFile    = Join-Path $root 'dashboard.html'

# 1) make sure manifest.json is fresh
& (Join-Path $root 'build_manifest.ps1')

# 2) load manifest + every report's markdown
$manifest = Get-Content -Path (Join-Path $reportsDir 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$content  = [ordered]@{}
foreach ($r in $manifest.reports) {
  $p = Join-Path $reportsDir $r.file
  if (Test-Path $p) { $content[$r.file] = (Get-Content -Path $p -Raw -Encoding UTF8) }
}

# Build embed block WITHOUT ConvertTo-Json on the big markdown
# (PS 5.1 ConvertTo-Json is pathologically slow on long Korean strings).
# - manifest: small -> ConvertTo-Json is fine
# - each report: embed RAW markdown inside a <script type="text/markdown"> block
#   (script content is raw text; only "</script>" must be neutralized)
$manifestJson = $manifest | ConvertTo-Json -Depth 6 -Compress
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("<script id=`"__manifest`" type=`"application/json`">$manifestJson</script>")
foreach ($r in $manifest.reports) {
  $md = $content[$r.file]
  if ($null -eq $md) { continue }
  $md = $md -replace '</script>', '<\/script>'
  [void]$sb.AppendLine("<script type=`"text/markdown`" data-file=`"$($r.file)`">")
  [void]$sb.Append($md)
  [void]$sb.AppendLine("`n</script>")
}
[void]$sb.AppendLine('<script>')
[void]$sb.AppendLine('window.EMBEDDED={manifest:JSON.parse(document.getElementById("__manifest").textContent),content:{}};')
[void]$sb.AppendLine('document.querySelectorAll(''script[type="text/markdown"]'').forEach(function(s){window.EMBEDDED.content[s.dataset.file]=s.textContent.replace(/^\n/,"").replace(/\n$/,"");});')
[void]$sb.AppendLine('</script>')
$embedTag = $sb.ToString()

# 3) get the libraries (cache in vendor/, download if missing)
if (-not (Test-Path $vendorDir)) { New-Item -ItemType Directory -Path $vendorDir | Out-Null }
function Get-Lib($name, $url) {
  $local = Join-Path $vendorDir $name
  if (-not (Test-Path $local)) {
    try {
      Invoke-WebRequest -Uri $url -OutFile $local -UseBasicParsing -TimeoutSec 60
      Write-Host "downloaded $name"
    } catch {
      Write-Warning "could not download $name ($($_.Exception.Message)) - will keep CDN tag"
      return $null
    }
  }
  $js = Get-Content -Path $local -Raw -Encoding UTF8
  return ($js -replace '</script>', '<\/script>')   # safety
}
$marked = Get-Lib 'marked.min.js' 'https://cdn.jsdelivr.net/npm/marked/marked.min.js'
$purify = Get-Lib 'purify.min.js' 'https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.min.js'

# 4) assemble dashboard.html from index.html
$html = Get-Content -Path $indexFile -Raw -Encoding UTF8
$html = $html.Replace('<!--EMBEDDED-->', $embedTag)   # inject embedded data

# inline libraries (or leave CDN tag if unavailable)
$markedTag = '<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>'
$purifyTag = '<script src="https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.min.js"></script>'
if ($marked) { $html = $html.Replace($markedTag, "<script>$marked</script>") }
if ($purify) { $html = $html.Replace($purifyTag, "<script>$purify</script>") }

# 5) write (UTF-8 with BOM so double-clicked file renders Korean correctly)
$utf8bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($outFile, $html, $utf8bom)

$kb = [math]::Round((Get-Item $outFile).Length / 1KB)
Write-Host ("dashboard.html built - {0} report(s), {1} KB (open by double-click)" -f $manifest.count, $kb)
