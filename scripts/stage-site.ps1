param(
  [string]$Version = "v0.1.0",
  [string]$SourceSitesRoot = "",
  [string]$SourceSiteDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SourceSiteDir) -and [string]::IsNullOrWhiteSpace($SourceSitesRoot)) {
  if (-not [string]::IsNullOrWhiteSpace($env:ICM_SITE_SOURCE_ROOT)) {
    $SourceSitesRoot = $env:ICM_SITE_SOURCE_ROOT
  } else {
    throw "请通过 -SourceSitesRoot 或环境变量 ICM_SITE_SOURCE_ROOT 提供站点来源根目录。"
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDir = if (-not [string]::IsNullOrWhiteSpace($SourceSiteDir)) {
  [System.IO.Path]::GetFullPath($SourceSiteDir)
} else {
  Join-Path $SourceSitesRoot $Version
}
$targetVersionDir = Join-Path $repoRoot "site\\$Version"
$targetCurrentDir = Join-Path $repoRoot "site\\current"
$stagingRoot = Join-Path $repoRoot "site\\.staging\\$Version-$([guid]::NewGuid().ToString('N'))"

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
  throw "源站点目录不存在：$sourceDir"
}

if (-not (Test-Path -LiteralPath (Join-Path $sourceDir "index.html") -PathType Leaf)) {
  throw "源站点缺少 index.html：$sourceDir"
}

try {
  New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
  Get-ChildItem -LiteralPath $sourceDir -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stagingRoot $_.Name) -Recurse -Force
  }

  $manifestPath = Join-Path $stagingRoot "site-release-manifest.json"
  if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  } else {
    $manifest = [ordered]@{
      appVersion = ""
      builtAt = ""
      siteBase = "/"
      sourceDigest = ""
      siteDigest = ""
    }
  }
  $manifest | Add-Member -NotePropertyName archivedVersion -NotePropertyValue $Version -Force
  $manifest | Add-Member -NotePropertyName stagedAt -NotePropertyValue ([DateTime]::UtcNow.ToString("o")) -Force
  $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetVersionDir) | Out-Null
  Remove-Item -Recurse -Force $targetVersionDir -ErrorAction SilentlyContinue
  Move-Item -LiteralPath $stagingRoot -Destination $targetVersionDir
  Remove-Item -Recurse -Force $targetCurrentDir -ErrorAction SilentlyContinue
  Copy-Item -LiteralPath $targetVersionDir -Destination $targetCurrentDir -Recurse -Force
} finally {
  if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "已同步站点版本：$Version"
