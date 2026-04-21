param(
  [string]$Version = "v0.1.0",
  [string]$SourceSitesRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SourceSitesRoot)) {
  if (-not [string]::IsNullOrWhiteSpace($env:ICM_SITE_SOURCE_ROOT)) {
    $SourceSitesRoot = $env:ICM_SITE_SOURCE_ROOT
  } else {
    throw "请通过 -SourceSitesRoot 或环境变量 ICM_SITE_SOURCE_ROOT 提供站点来源根目录。"
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $SourceSitesRoot $Version
$targetVersionDir = Join-Path $repoRoot "site\\$Version"
$targetCurrentDir = Join-Path $repoRoot "site\\current"

if (-not (Test-Path $sourceDir)) {
  throw "源站点目录不存在：$sourceDir"
}

Remove-Item -Recurse -Force $targetVersionDir -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $targetCurrentDir -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetVersionDir) | Out-Null
Copy-Item -Recurse -Force $sourceDir $targetVersionDir
Copy-Item -Recurse -Force $sourceDir $targetCurrentDir

Write-Host "已同步站点版本：$Version"
