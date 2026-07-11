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
# earnings.json (실적 캘린더) — 있으면 그대로 임베드
$earningsRaw = ''
$earningsPath = Join-Path $reportsDir 'earnings.json'
if (Test-Path $earningsPath) { $earningsRaw = (Get-Content -Path $earningsPath -Raw -Encoding UTF8) -replace '</script>', '<\/script>' }
$sectorsRaw = ''
$sectorsPath = Join-Path $reportsDir 'sectors.json'
if (Test-Path $sectorsPath) { $sectorsRaw = (Get-Content -Path $sectorsPath -Raw -Encoding UTF8) -replace '</script>', '<\/script>' }
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("<script id=`"__manifest`" type=`"application/json`">$manifestJson</script>")
if ($earningsRaw) { [void]$sb.AppendLine("<script id=`"__earnings`" type=`"application/json`">$earningsRaw</script>") }
if ($sectorsRaw)  { [void]$sb.AppendLine("<script id=`"__sectors`" type=`"application/json`">$sectorsRaw</script>") }

# 섹터 뷰 날짜별 히스토리: 스냅샷 임베드 + sectors-index.json 생성
$histDir = Join-Path $reportsDir 'sectors-history'
$histDates = @()
if (Test-Path $histDir) {
  foreach ($hf in (Get-ChildItem -Path $histDir -Filter 'sectors_*.json' | Sort-Object Name)) {
    if ($hf.BaseName -match 'sectors_(\d{8})$') {
      $d = $Matches[1]
      $dateFmt = "$($d.Substring(0,4))-$($d.Substring(4,2))-$($d.Substring(6,2))"
      $histDates += $dateFmt
      $hraw = (Get-Content -Path $hf.FullName -Raw -Encoding UTF8) -replace '</script>', '<\/script>'
      [void]$sb.AppendLine("<script type=`"application/json`" class=`"__sectorhist`" data-date=`"$dateFmt`">$hraw</script>")
    }
  }
}
$histSorted = @($histDates | Sort-Object -Descending)
$idxJson = ([pscustomobject]@{ dates = $histSorted } | ConvertTo-Json -Compress)
[System.IO.File]::WriteAllText((Join-Path $reportsDir 'sectors-index.json'), $idxJson, (New-Object System.Text.UTF8Encoding($false)))
[void]$sb.AppendLine("<script id=`"__sectorsindex`" type=`"application/json`">$idxJson</script>")
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
[void]$sb.AppendLine('var __e=document.getElementById("__earnings"); if(__e){ try{ window.EMBEDDED.earnings=JSON.parse(__e.textContent); }catch(e){} }')
[void]$sb.AppendLine('var __s=document.getElementById("__sectors"); if(__s){ try{ window.EMBEDDED.sectors=JSON.parse(__s.textContent); }catch(e){} }')
[void]$sb.AppendLine('var __si=document.getElementById("__sectorsindex"); if(__si){ try{ window.EMBEDDED.sectorsIndex=JSON.parse(__si.textContent); }catch(e){} }')
[void]$sb.AppendLine('window.EMBEDDED.sectorsHistory={}; document.querySelectorAll("script.__sectorhist").forEach(function(h){ try{ window.EMBEDDED.sectorsHistory[h.dataset.date]=JSON.parse(h.textContent); }catch(e){} });')
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
