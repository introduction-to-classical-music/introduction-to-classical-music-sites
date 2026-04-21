param(
  [string]$Version = "v0.1.0",
  [string]$SourceSitesRoot = "F:\personal\Sunhaoran\OneDrive\music\buquanshu\sites"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $SourceSitesRoot $Version
$targetVersionDir = Join-Path $repoRoot "site\$Version"
$targetCurrentDir = Join-Path $repoRoot "site\current"

if (-not (Test-Path $sourceDir)) {
  throw "源站点目录不存在：$sourceDir"
}

Remove-Item -Recurse -Force $targetVersionDir -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $targetCurrentDir -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetVersionDir) | Out-Null
Copy-Item -Recurse -Force $sourceDir $targetVersionDir
Copy-Item -Recurse -Force $sourceDir $targetCurrentDir

Write-Host "已同步站点版本：$Version"
