<#
  build_manifest.ps1 - scan reports/*.md and (re)build reports/manifest.json
  The dashboard (index.html) reads this manifest to list & search reports.
  Run once after adding/updating any report.

  Usage:  powershell -File build_manifest.ps1   (Windows PowerShell 5.1)
          pwsh -File build_manifest.ps1         (PowerShell 7)

  NOTE: source is kept ASCII-only on purpose so PowerShell 5.1 parses it
  regardless of BOM. Korean only flows through as DATA (read from .md files).
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$reportsDir = Join-Path $root 'reports'
$outFile    = Join-Path $reportsDir 'manifest.json'

if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir | Out-Null }

$items = @()
foreach ($f in (Get-ChildItem -Path $reportsDir -Filter '*.md' | Sort-Object Name)) {
  $lines = Get-Content -Path $f.FullName -Encoding UTF8
  $h1    = ($lines | Where-Object { $_ -match '^#\s+' }   | Select-Object -First 1)
  $h3    = ($lines | Where-Object { $_ -match '^###\s+' } | Select-Object -First 1)

  $company = ''; $ticker = ''; $headline = ''
  if ($h1 -match '^#\s+(.+?)\(([^)]+)\)\s*\|\s*(.+)$') {
    $company = $Matches[1].Trim(); $ticker = $Matches[2].Trim(); $headline = $Matches[3].Trim()
  } elseif ($h1 -match '^#\s+(.+?)\s*\|\s*(.+)$') {
    $company = $Matches[1].Trim(); $headline = $Matches[2].Trim()
  } elseif ($h1) {
    $company = ($h1 -replace '^#\s+','').Trim()
  }

  $period = if ($h3) { ($h3 -replace '^###\s+','').Trim() } else { '' }

  # filename patterns:  TICKER_YYYYMMDD.md   or   CODE_NAME_YYYYMMDD.md
  $base = $f.BaseName
  $date = ''
  if ($base -match '(\d{8})$') { $date = $Matches[1] }
  if (-not $ticker) { $ticker = ($base -split '_')[0] }

  $market  = if ($ticker -match '^\d{6}$') { 'KR' } else { 'US' }
  $dateFmt = if ($date.Length -eq 8) { "$($date.Substring(0,4))-$($date.Substring(4,2))-$($date.Substring(6,2))" } else { '' }

  $type = 'earnings'
  if ($base -match '_preview_') { $type = 'preview' }
  elseif ($base -match '_review_') { $type = 'review' }

  $items += [pscustomobject]@{
    file     = $f.Name
    ticker   = $ticker
    company  = $company
    headline = $headline
    period   = $period
    market   = $market
    date     = $dateFmt
    type     = $type
  }
}

$items = @($items | Sort-Object -Property date -Descending)

$manifest = [pscustomobject]@{
  count   = $items.Count
  reports = $items
}
$json = $manifest | ConvertTo-Json -Depth 5

# write WITHOUT BOM so the browser's fetch().json() parses cleanly
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outFile, $json, $utf8NoBom)

Write-Host ("manifest.json built - {0} report(s)" -f $items.Count)
