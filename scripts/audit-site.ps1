param(
  [string]$Version = "v0.1.0",
  [string]$SiteDir = "",
  [string]$BaseUrl = "",
  [string]$ExpectedSiteBase = "",
  [string]$LogDir = "",
  [switch]$SkipStaticMetadata
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "site-release-common.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$siteRoot = if ([string]::IsNullOrWhiteSpace($SiteDir)) {
  Join-Path $repoRoot "site\$Version"
} else {
  [System.IO.Path]::GetFullPath($SiteDir)
}
$siteRoot = $siteRoot.TrimEnd('\', '/')

$effectiveLogDir = if (-not [string]::IsNullOrWhiteSpace($LogDir)) {
  $LogDir
} elseif (-not [string]::IsNullOrWhiteSpace($env:ICM_AUDIT_LOG_DIR)) {
  $env:ICM_AUDIT_LOG_DIR
} else {
  Join-Path $repoRoot "logs"
}

$script:AuditFailures = New-Object System.Collections.Generic.List[string]
$script:AuditDetails = New-Object System.Collections.Generic.List[string]

function Add-AuditFailure {
  param([string]$Message)
  $script:AuditFailures.Add($Message) | Out-Null
  Write-Host "[audit] FAIL: $Message"
}

function Add-AuditDetail {
  param([string]$Message)
  $script:AuditDetails.Add($Message) | Out-Null
}

function Write-AuditLog {
  if ($script:AuditFailures.Count -eq 0) {
    return ""
  }
  if (-not (Test-Path -LiteralPath $effectiveLogDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $effectiveLogDir | Out-Null
  }
  $logPath = Join-Path $effectiveLogDir "audit-site-$Version.log"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("Site audit log")
  $lines.Add("Generated: " + (Get-Date).ToString("o"))
  $lines.Add("Site directory: $siteRoot")
  if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
    $lines.Add("Expected base URL: $BaseUrl")
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedSiteBase)) {
    $lines.Add("Expected site base path: $ExpectedSiteBase")
  }
  $lines.Add("Failures: $($script:AuditFailures.Count)")
  $lines.Add("")
  foreach ($failure in $script:AuditFailures) {
    $lines.Add("[FAIL] $failure")
  }
  if ($script:AuditDetails.Count -gt 0) {
    $lines.Add("")
    $lines.Add("Details:")
    foreach ($detail in $script:AuditDetails) {
      $lines.Add($detail)
    }
  }
  $lines | Set-Content -LiteralPath $logPath -Encoding utf8
  return $logPath
}

function Stop-AuditWithFailures {
  $logPath = Write-AuditLog
  $message = "Site audit failed with $($script:AuditFailures.Count) error(s)."
  if ($logPath) {
    $message = $message + " Log: $logPath"
  }
  throw $message
}

function Test-ParseAbsoluteHttpUrl {
  param(
    [string]$Value,
    [string]$Label
  )

  $uri = $null
  try {
    $uri = New-Object System.Uri($Value, [System.UriKind]::Absolute)
  } catch {
    Add-AuditFailure "$Label is not an absolute URL: $Value"
    return $null
  }
  if ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https") {
    Add-AuditFailure "$Label must use http or https: $Value"
    return $null
  }
  if (Test-PlaceholderHost $uri.Host) {
    Add-AuditFailure "$Label uses a placeholder domain '$($uri.Host)': $Value"
  }
  return $uri
}

# The audit depends on ripgrep for the forbidden-pattern scan. Fail loudly when
# it is missing instead of silently skipping the scan.
$rgCommand = Get-Command rg -ErrorAction SilentlyContinue
if (-not $rgCommand) {
  Add-AuditFailure "ripgrep (rg) was not found on PATH. Install ripgrep and put it on PATH before auditing the site."
  Stop-AuditWithFailures
}

if (-not (Test-Path -LiteralPath $siteRoot -PathType Container)) {
  Add-AuditFailure "Site directory not found: $siteRoot"
  Stop-AuditWithFailures
}
if (-not (Test-Path -LiteralPath (Join-Path $siteRoot "index.html") -PathType Leaf)) {
  Add-AuditFailure "Site is missing index.html: $siteRoot"
}

$expectedBasePath = ""
$baseUrlInfo = $null

if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
  $baseUrlInfo = ConvertTo-BaseUrlInfo $BaseUrl
  if (-not $baseUrlInfo.Ok) {
    Add-AuditFailure "Invalid -BaseUrl: $($baseUrlInfo.Message)"
    Stop-AuditWithFailures
  }
  if (Test-PlaceholderHost $baseUrlInfo.Host) {
    Add-AuditFailure "Expected BaseUrl uses a placeholder domain '$($baseUrlInfo.Host)'; pass the real public domain."
    Stop-AuditWithFailures
  }
  $expectedBasePath = $baseUrlInfo.BasePath
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedSiteBase)) {
  $explicitBasePath = ConvertTo-SiteBasePath $ExpectedSiteBase
  if ($expectedBasePath -and $explicitBasePath -ne $expectedBasePath) {
    Add-AuditFailure "-ExpectedSiteBase '$explicitBasePath' does not match the base path in -BaseUrl '$expectedBasePath'."
    Stop-AuditWithFailures
  }
  $expectedBasePath = $explicitBasePath
}

# Release manifest: required for every audited release site.
$manifestPath = Join-Path $siteRoot "site-release-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  Add-AuditFailure "site-release-manifest.json is missing: $manifestPath"
} else {
  $manifest = $null
  $manifestParsed = $false
  try {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $manifestParsed = $true
  } catch {
    Add-AuditFailure "site-release-manifest.json is not valid JSON: $($_.Exception.Message)"
  }
  if ($manifestParsed) {
    $siteBaseProperty = $manifest.PSObject.Properties["siteBase"]
    $manifestSiteBase = if ($null -ne $siteBaseProperty) { [string]$siteBaseProperty.Value } else { "" }
    if ([string]::IsNullOrWhiteSpace($manifestSiteBase)) {
      Add-AuditFailure "site-release-manifest.json is missing a non-empty siteBase."
    } else {
      $manifestBasePath = ConvertTo-SiteBasePath $manifestSiteBase
      if ([string]::IsNullOrWhiteSpace($expectedBasePath)) {
        $expectedBasePath = $manifestBasePath
      } elseif ($manifestBasePath -ne $expectedBasePath) {
        Add-AuditFailure "site-release-manifest.json siteBase '$manifestSiteBase' does not match the expected base path '$expectedBasePath'."
      }
    }
  }
}

$htmlPages = @(Get-SiteHtmlPageFiles $siteRoot)
$htmlCount = $htmlPages.Count
if ($htmlCount -eq 0) {
  Add-AuditFailure "No HTML pages found under: $siteRoot"
}

# Forbidden content patterns (regression guard for the F12/F14 defect classes).
$scanPatterns = @(
  "localhost",
  "127\.0\.0\.1",
  "__local-resource",
  "testtesttest",
  "guide-test-3",
  "columns/test",
  "columns/testtesttest",
  "example\.com",
  "your-domain\.example",
  "System\.Object\[\]",
  "(^|[^A-Za-z0-9])[A-Za-z]:[\\/]"
)
foreach ($pattern in $scanPatterns) {
  $scanOutput = @(& $rgCommand.Source -n --no-heading --color never --glob "*" -e $pattern $siteRoot 2>&1)
  $scanExitCode = $LASTEXITCODE
  if ($scanExitCode -eq 0) {
    foreach ($line in $scanOutput) {
      $lineText = [string]$line
      if (-not [string]::IsNullOrWhiteSpace($lineText)) {
        Add-AuditFailure "Forbidden pattern '$pattern' found in site: $lineText"
      }
    }
  } elseif ($scanExitCode -gt 1) {
    Add-AuditFailure "ripgrep failed while scanning pattern '$pattern' (exit code $scanExitCode)."
    foreach ($line in $scanOutput) {
      Add-AuditDetail ([string]$line)
    }
  }
}

if (-not $SkipStaticMetadata) {
  $sitemapPath = Join-Path $siteRoot "sitemap.xml"
  if (-not (Test-Path -LiteralPath $sitemapPath -PathType Leaf)) {
    Add-AuditFailure "sitemap.xml is missing: $sitemapPath"
  } else {
    $sitemapText = Get-Content -Raw -LiteralPath $sitemapPath
    if ($sitemapText.Contains("System.Object[]")) {
      Add-AuditFailure "sitemap.xml contains System.Object[] (array join bug)."
    }
    $sitemapDocument = $null
    $sitemapParsed = $false
    try {
      $sitemapDocument = New-Object System.Xml.XmlDocument
      $sitemapDocument.LoadXml($sitemapText)
      $sitemapParsed = $true
    } catch {
      Add-AuditFailure "sitemap.xml is not valid XML: $($_.Exception.Message)"
    }
    if ($sitemapParsed) {
      if ($null -eq $sitemapDocument.DocumentElement -or $sitemapDocument.DocumentElement.LocalName -ne "urlset") {
        Add-AuditFailure "sitemap.xml root element must be <urlset>."
      }
      $locNodes = @($sitemapDocument.SelectNodes("//*[local-name()='loc']"))
      if ($locNodes.Count -ne $htmlCount) {
        Add-AuditFailure "sitemap.xml has $($locNodes.Count) <loc> entries but the site has $htmlCount HTML pages (404.html excluded)."
      }
      foreach ($locNode in $locNodes) {
        $locText = [string]$locNode.InnerText
        $locUri = Test-ParseAbsoluteHttpUrl -Value $locText -Label "sitemap.xml <loc>"
        if ($null -ne $locUri) {
          if ($baseUrlInfo) {
            if (-not $locText.StartsWith($baseUrlInfo.BaseWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
              Add-AuditFailure "sitemap.xml URL is outside the expected base URL '$($baseUrlInfo.BaseWithSlash)': $locText"
            }
          } elseif (-not ($locUri.AbsolutePath.StartsWith($expectedBasePath, [System.StringComparison]::OrdinalIgnoreCase))) {
            Add-AuditFailure "sitemap.xml URL is outside the expected base path '$expectedBasePath': $locText"
          }
        }
      }
    }
  }

  $robotsPath = Join-Path $siteRoot "robots.txt"
  if (-not (Test-Path -LiteralPath $robotsPath -PathType Leaf)) {
    Add-AuditFailure "robots.txt is missing: $robotsPath"
  } else {
    $robotsText = Get-Content -Raw -LiteralPath $robotsPath
    $sitemapUrls = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($robotsText -split "`r?`n")) {
      if ($line -match '^\s*Sitemap\s*:\s*(\S+)\s*$') {
        $sitemapUrls.Add($Matches[1])
      }
    }
    if ($sitemapUrls.Count -eq 0) {
      Add-AuditFailure "robots.txt is missing a Sitemap line."
    }
    $expectedSitemapPath = $expectedBasePath.TrimEnd('/') + "/sitemap.xml"
    foreach ($sitemapUrl in $sitemapUrls) {
      $sitemapUri = Test-ParseAbsoluteHttpUrl -Value $sitemapUrl -Label "robots.txt Sitemap URL"
      if ($null -eq $sitemapUri) {
        continue
      }
      if ($baseUrlInfo) {
        $sitemapAuthority = $sitemapUri.GetLeftPart([System.UriPartial]::Authority)
        if ($sitemapAuthority -ne $baseUrlInfo.Authority) {
          Add-AuditFailure "robots.txt Sitemap domain '$sitemapAuthority' does not match the expected base '$($baseUrlInfo.Authority)'."
        }
      }
      if ($sitemapUri.AbsolutePath -ne $expectedSitemapPath) {
        Add-AuditFailure "robots.txt Sitemap path '$($sitemapUri.AbsolutePath)' does not match the expected path '$expectedSitemapPath'."
      }
    }
  }
}

if ($script:AuditFailures.Count -gt 0) {
  Stop-AuditWithFailures
}

Write-Host "Site audit passed: $Version"
Write-Host "Site directory: $siteRoot"
Write-Host "HTML pages: $htmlCount (404.html excluded)"
if ($baseUrlInfo) {
  Write-Host "Expected base URL: $($baseUrlInfo.BaseWithSlash)"
} else {
  Write-Host "Expected site base path: $expectedBasePath (domain checks skipped: no -BaseUrl)"
}
