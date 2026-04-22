param(
  [string]$Version = "v0.1.0",
  [string]$Bucket,
  [string]$Endpoint
)

$ErrorActionPreference = "Stop"

if (-not $Bucket) {
  throw "请提供 OSS Bucket，例如：-Bucket oss://your-bucket-name"
}

if (-not $Endpoint) {
  throw "请提供 OSS Endpoint，例如：-Endpoint oss-cn-your-region.aliyuncs.com"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$siteRoot = Join-Path $repoRoot "site\$Version"

if (-not (Test-Path $siteRoot)) {
  throw "Site directory not found: $siteRoot"
}

$ossutil = Get-Command ossutil -ErrorAction SilentlyContinue
if (-not $ossutil) {
  throw "未找到 ossutil，请先安装并完成阿里云凭证配置。"
}

$target = "$Bucket/"
Write-Host "Uploading $siteRoot to $target via $Endpoint"

& $ossutil.Source cp "$siteRoot" $target -r --update --endpoint $Endpoint

if ($LASTEXITCODE -ne 0) {
  throw "OSS upload failed."
}

Write-Host "OSS upload completed: $Version"
