# Shared helpers for the site release scripts.
#
# Keep this file ASCII-only and compatible with Windows PowerShell 5.1 and
# PowerShell 7+: BOM-less script files are decoded as ANSI by Windows
# PowerShell 5.1, so non-ASCII text in scripts is not safe.

function Test-PlaceholderHost {
  param(
    [string]$HostName
  )

  if ([string]::IsNullOrWhiteSpace($HostName)) {
    return $true
  }

  $hostText = $HostName.Trim().TrimEnd('.').ToLowerInvariant()
  $exactHosts = @(
    'localhost',
    'example',
    'example.com',
    'example.org',
    'example.net',
    'your-domain.example',
    'your-domain.com',
    '127.0.0.1',
    '0.0.0.0',
    '::1'
  )
  if ($exactHosts -contains $hostText) {
    return $true
  }

  $reservedSuffixes = @(
    '.example.com',
    '.example.org',
    '.example.net',
    '.your-domain.example',
    '.your-domain.com',
    '.example',
    '.test',
    '.invalid',
    '.localhost'
  )
  foreach ($suffix in $reservedSuffixes) {
    if ($hostText.EndsWith($suffix)) {
      return $true
    }
  }

  if ($hostText -match '^127\.') {
    return $true
  }
  return $false
}

function ConvertTo-SiteBasePath {
  param(
    [string]$Value
  )

  $text = ''
  if ($null -ne $Value) {
    $text = ([string]$Value).Trim()
  }
  if (-not $text) {
    return '/'
  }
  if ($text -match '^[A-Za-z][A-Za-z0-9+.\-]*://') {
    try {
      $parsed = New-Object System.Uri($text, [System.UriKind]::Absolute)
      $text = $parsed.AbsolutePath
    } catch {
      return '/'
    }
  }
  if (-not $text.StartsWith('/')) {
    $text = '/' + $text
  }
  if (-not $text.EndsWith('/')) {
    $text = $text + '/'
  }
  return ($text -replace '/{2,}', '/')
}

function ConvertTo-BaseUrlInfo {
  param(
    [string]$BaseUrl
  )

  $info = [ordered]@{
    Ok = $false
    Message = ''
    BaseUrl = ''
    BaseWithSlash = ''
    BasePath = '/'
    Authority = ''
    Host = ''
    Scheme = ''
  }

  $text = ''
  if ($null -ne $BaseUrl) {
    $text = ([string]$BaseUrl).Trim()
  }
  if (-not $text) {
    $info.Message = 'BaseUrl is required'
    return $info
  }
  if ($text -match '[?#]') {
    $info.Message = 'BaseUrl must not contain a query string or fragment'
    return $info
  }

  $uri = $null
  try {
    $uri = New-Object System.Uri($text, [System.UriKind]::Absolute)
  } catch {
    $info.Message = "BaseUrl is not an absolute URL: $text"
    return $info
  }
  $scheme = $uri.Scheme.ToLowerInvariant()
  if ($scheme -ne 'http' -and $scheme -ne 'https') {
    $info.Message = "BaseUrl must use http or https: $text"
    return $info
  }
  if ([string]::IsNullOrWhiteSpace($uri.Host)) {
    $info.Message = "BaseUrl is missing a host: $text"
    return $info
  }

  $basePath = ConvertTo-SiteBasePath $uri.AbsolutePath
  $authority = $uri.GetLeftPart([System.UriPartial]::Authority)
  $info.Ok = $true
  $info.BasePath = $basePath
  $info.Authority = $authority
  $info.Host = $uri.Host
  $info.Scheme = $scheme
  $info.BaseWithSlash = $authority + $basePath
  $info.BaseUrl = $info.BaseWithSlash.TrimEnd('/')
  return $info
}

function Get-SiteHtmlPageFiles {
  param(
    [string]$SiteRoot
  )

  $root = $SiteRoot.TrimEnd('\', '/')
  $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.html' -ErrorAction Stop)
  $pages = @($files | Where-Object { $_.Name -ne '404.html' } | Sort-Object FullName)
  return $pages
}

function Get-SiteHtmlPageCount {
  param(
    [string]$SiteRoot
  )

  $pages = @(Get-SiteHtmlPageFiles $SiteRoot)
  return $pages.Count
}

function Get-SitePageUrl {
  param(
    [string]$SiteRoot,
    [string]$BaseWithSlash,
    [System.IO.FileInfo]$File
  )

  $root = $SiteRoot.TrimEnd('\', '/')
  $relative = $File.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/'
  if ($relative -eq 'index.html') {
    return $BaseWithSlash
  }
  if ($relative.EndsWith('/index.html')) {
    return $BaseWithSlash + $relative.Substring(0, $relative.Length - 'index.html'.Length)
  }
  return $BaseWithSlash + $relative
}
