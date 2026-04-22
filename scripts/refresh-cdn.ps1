[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Domain,

  [Parameter(Mandatory = $true)]
  [string[]]$Paths
)

$ErrorActionPreference = "Stop"

function Get-AliyunCli {
  $candidate = Get-Command aliyun -ErrorAction SilentlyContinue
  if (-not $candidate) {
    throw "未找到 aliyun CLI（命令行工具）。请先安装并完成阿里云凭据配置。"
  }
  return $candidate.Source
}

$aliyun = Get-AliyunCli

foreach ($path in $Paths) {
  if ([string]::IsNullOrWhiteSpace($path)) {
    continue
  }

  Write-Host "Refreshing CDN path: $path"
  & $aliyun cdn RefreshObjectCaches --ObjectPath $path --ObjectType File | Out-Null
}

Write-Host "CDN refresh completed for domain: $Domain"
