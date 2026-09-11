param(
  [string]$Version = "v0.1.0",
  [string]$SiteDir = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$siteRoot = if ([string]::IsNullOrWhiteSpace($SiteDir)) {
  Join-Path $repoRoot "site\$Version"
} else {
  [System.IO.Path]::GetFullPath($SiteDir)
}
$logDir = Join-Path $repoRoot "logs"

if (-not (Test-Path -LiteralPath $siteRoot -PathType Container)) {
  throw "Site directory not found: $siteRoot"
}

$patterns = @(
  "localhost",
  "127.0.0.1",
  "__local-resource",
  "testtesttest",
  "guide-test-3",
  "columns/test",
  "columns/testtesttest",
  "[A-Z]:\\"
)

$allMatches = @()
foreach ($pattern in $patterns) {
  $matches = rg -n --glob "*" $pattern $siteRoot 2>$null
  if ($LASTEXITCODE -eq 0 -and $matches) {
    $allMatches += $matches
  }
}

if ($allMatches.Count -gt 0) {
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  $allMatches | Set-Content -Path (Join-Path $logDir "audit-site-$Version.log")
  throw "Site audit failed. Review logs\\audit-site-$Version.log for details."
}

Write-Host "Site audit passed: $Version"
