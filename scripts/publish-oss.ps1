param(
  [string]$Version = "v0.1.0",
  [string]$Bucket,
  [string]$Endpoint,
  [string]$BaseUrl = "",
  [string]$SiteDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Bucket)) {
  throw "Bucket is required, for example: -Bucket oss://your-bucket-name"
}

if ([string]::IsNullOrWhiteSpace($Endpoint)) {
  throw "Endpoint is required, for example: -Endpoint oss-cn-your-region.aliyuncs.com"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$siteRoot = if ([string]::IsNullOrWhiteSpace($SiteDir)) {
  Join-Path $repoRoot "site\$Version"
} else {
  [System.IO.Path]::GetFullPath($SiteDir)
}

if (-not (Test-Path -LiteralPath $siteRoot -PathType Container)) {
  throw "Site directory not found: $siteRoot"
}

# Blocking gate: never upload a site that has not passed audit-site.ps1.
# The audit checks sitemap/robots/manifest, forbidden content and local paths.
$auditScript = Join-Path $PSScriptRoot "audit-site.ps1"
$auditParameters = @{
  Version = $Version
  SiteDir = $siteRoot
}
if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
  $auditParameters["BaseUrl"] = $BaseUrl
}
Write-Host "Running mandatory site audit before upload: $siteRoot"
& $auditScript @auditParameters
if (-not $?) {
  throw "Site audit failed; OSS upload aborted."
}

$ossutil = Get-Command ossutil -ErrorAction SilentlyContinue
if (-not $ossutil) {
  throw "ossutil was not found. Install ossutil and configure the Aliyun credentials first."
}

$target = "$Bucket/"
Write-Host "Uploading $siteRoot to $target via $Endpoint"

& $ossutil.Source cp "$siteRoot" $target -r --update --endpoint $Endpoint

if ($LASTEXITCODE -ne 0) {
  throw "OSS upload failed."
}

Write-Host "OSS upload completed: $Version"
