param(
  [string]$SourceSiteDir = "",
  [string]$Version = "v0.1.0",
  [switch]$Publish
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SourceSiteDir)) {
  throw "Pass -SourceSiteDir with a built Pages site directory."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDir = [System.IO.Path]::GetFullPath($SourceSiteDir)
$manifestPath = Join-Path $sourceDir "site-release-manifest.json"
$expectedBase = "/introduction-to-classical-music-sites/"

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
  throw "Source site directory does not exist: $sourceDir"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceDir "index.html") -PathType Leaf)) {
  throw "Source site is missing index.html: $sourceDir"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Source site is missing site-release-manifest.json: $sourceDir"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ([string]$manifest.siteBase -ne $expectedBase) {
  throw "Invalid Pages site base. Expected $expectedBase, got $($manifest.siteBase)"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "icm-pages-$([guid]::NewGuid().ToString('N'))"
$worktreeAdded = $false

try {
  git -C $repoRoot worktree add --detach $tempRoot origin/pages
  if ($LASTEXITCODE -ne 0) { throw "Could not create temporary pages worktree" }
  $worktreeAdded = $true

  Get-ChildItem -LiteralPath $tempRoot -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
  }
  Get-ChildItem -LiteralPath $sourceDir -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $tempRoot $_.Name) -Recurse -Force
  }
  New-Item -ItemType File -Force -Path (Join-Path $tempRoot ".nojekyll") | Out-Null

  & (Join-Path $PSScriptRoot "audit-site.ps1") -SiteDir $tempRoot -Version $Version
  if (-not $?) { throw "Pages site audit failed" }

  git -C $tempRoot add -A
  $diffSummary = git -C $tempRoot diff --cached --stat
  if ($diffSummary) { Write-Host $diffSummary }
  if (-not $Publish) {
    Write-Host "Preview only: nothing was committed or pushed. Pass -Publish to update pages."
    return
  }

  git -C $tempRoot commit -m "deploy: publish $Version"
  if ($LASTEXITCODE -ne 0) { throw "Pages commit failed" }
  git -C $tempRoot push origin HEAD:pages
  if ($LASTEXITCODE -ne 0) { throw "Pages push failed" }
} finally {
  if ($worktreeAdded) {
    git -C $repoRoot worktree remove --force $tempRoot 2>$null
  }
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
