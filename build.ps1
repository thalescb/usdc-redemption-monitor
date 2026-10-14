# Rebuilds data/*.csv and index.html from the public Ethereum dataset.
# Usage: ./build.ps1 -Project <your-gcp-project> [-RecentDays 90] [-SkipQuery]
# Requires the bq CLI (Google Cloud SDK). Scans ~5 GB for the SVB window and ~70 GB for 90 days.
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [int]$RecentDays = 90,
  [switch]$SkipQuery
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $SkipQuery) {
  # bq rejects a query string that starts with a comment, so strip comments and collapse whitespace
  $sql = ((Get-Content -Raw "$root/sql/redemption_pressure.sql") -replace '--[^\r\n]*', '' -replace '\s+', ' ').Trim()
  $end = (Get-Date).ToUniversalTime().Date
  $runs = @(
    @{ file = 'svb_hourly.csv';   start = '2023-03-06 00:00:00'; end = '2023-03-20 00:00:00'; hourly = 'true' },
    @{ file = 'recent_daily.csv'; start = $end.AddDays(-$RecentDays).ToString('yyyy-MM-dd 00:00:00'); end = $end.ToString('yyyy-MM-dd 00:00:00'); hourly = 'false' }
  )
  foreach ($r in $runs) {
    bq --project_id=$Project query --use_legacy_sql=false --format=csv --max_rows=1000 `
      --parameter="start:TIMESTAMP:$($r.start)" --parameter="end:TIMESTAMP:$($r.end)" --parameter="hourly:BOOL:$($r.hourly)" $sql 2>$null |
      Where-Object { $_ -notmatch '^WITH|^DECLARE|-- at' } |
      Out-File -Encoding ascii "$root/data/$($r.file)"
  }
}

$svb = Import-Csv "$root/data/svb_hourly.csv" | ConvertTo-Json -Compress
$now = Import-Csv "$root/data/recent_daily.csv" | ConvertTo-Json -Compress
$page = [IO.File]::ReadAllText("$root/template.html").Replace('/*SVB_DATA*/', $svb).Replace('/*NOW_DATA*/', $now)
[IO.File]::WriteAllText("$root/index.html", $page, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Built index.html"
