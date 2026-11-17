param(
  [string]$Version = "v0.1.0",
  [string]$BaseUrl = "",
  [string]$SiteDir = "",
  [switch]$AllowTestDomain
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "site-release-common.ps1")

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required. Pass -BaseUrl https://<public-domain> (placeholder domains such as example.com are rejected)."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$siteRoot = if ([string]::IsNullOrWhiteSpace($SiteDir)) {
  Join-Path $repoRoot "site\$Version"
} else {
  [System.IO.Path]::GetFullPath($SiteDir)
}
$siteRoot = $siteRoot.TrimEnd('\', '/')

if (-not (Test-Path -LiteralPath $siteRoot -PathType Container)) {
  throw "Site directory not found: $siteRoot"
}

$baseUrlInfo = ConvertTo-BaseUrlInfo $BaseUrl
if (-not $baseUrlInfo.Ok) {
  throw "Invalid -BaseUrl: $($baseUrlInfo.Message)"
}

if (Test-PlaceholderHost $baseUrlInfo.Host) {
  if (-not $AllowTestDomain) {
    throw "BaseUrl uses a placeholder domain '$($baseUrlInfo.Host)'. Pass the real public domain. Use -AllowTestDomain only for temporary local fixtures."
  }
  # Placeholder domains are only for temporary fixtures. Never write them into
  # the repository site/ directory.
  $repoSiteRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "site")).TrimEnd('\', '/')
  $separator = [System.IO.Path]::DirectorySeparatorChar
  $isInsideRepoSite = ($siteRoot -eq $repoSiteRoot) -or $siteRoot.StartsWith($repoSiteRoot + $separator, [System.StringComparison]::OrdinalIgnoreCase)
  if ($isInsideRepoSite) {
    throw "Refusing to write placeholder-domain metadata into the repository site/ directory: $siteRoot"
  }
  Write-Host "WARNING: placeholder test domain in use: $($baseUrlInfo.Host) (fixture-only switch -AllowTestDomain)"
}

$pageFiles = @(Get-SiteHtmlPageFiles $siteRoot)
if ($pageFiles.Count -eq 0) {
  throw "No HTML pages found under: $siteRoot"
}

$sitemapParts = New-Object System.Collections.Generic.List[string]
$sitemapParts.Add('<?xml version="1.0" encoding="UTF-8"?>')
$sitemapParts.Add('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($file in $pageFiles) {
  $url = Get-SitePageUrl -SiteRoot $siteRoot -BaseWithSlash $baseUrlInfo.BaseWithSlash -File $file
  $escapedUrl = [System.Security.SecurityElement]::Escape($url)
  $sitemapParts.Add("  <url><loc>$escapedUrl</loc></url>")
}
$sitemapParts.Add('</urlset>')
$sitemapText = ($sitemapParts.ToArray() -join "`r`n") + "`r`n"

$sitemapUrl = $baseUrlInfo.BaseWithSlash + "sitemap.xml"
$robotsText = @(
  "User-agent: *",
  "Allow: /",
  "Sitemap: $sitemapUrl"
) -join "`r`n"
$robotsText = $robotsText + "`r`n"

$notFound = @'
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Page Not Found | BuQuanShu</title>
    <style>
      body { font-family: "Noto Serif SC", serif; margin: 0; padding: 48px; background: #f5efe2; color: #2e2418; }
      main { max-width: 680px; margin: 0 auto; }
      a { color: inherit; }
    </style>
  </head>
  <body>
    <main>
      <h1>Page Not Found</h1>
      <p>The requested page does not exist in this release. Please return to the homepage.</p>
      <p><a href="/">Back to Home</a></p>
    </main>
  </body>
</html>
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $siteRoot "robots.txt"), $robotsText, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $siteRoot "sitemap.xml"), $sitemapText, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $siteRoot "404.html"), ($notFound + "`r`n"), $utf8NoBom)

# Post-generation assertions: the generated XML must stay valid and must list
# exactly the indexable HTML pages (404.html is an error page, not a content page).
$sitemapPath = Join-Path $siteRoot "sitemap.xml"
$sitemapDocument = New-Object System.Xml.XmlDocument
try {
  $sitemapDocument.LoadXml([System.IO.File]::ReadAllText($sitemapPath))
} catch {
  throw "Generated sitemap.xml is not valid XML: $($_.Exception.Message)"
}
$locNodes = @($sitemapDocument.SelectNodes("//*[local-name()='loc']"))
if ($locNodes.Count -ne $pageFiles.Count) {
  throw "Generated sitemap.xml has $($locNodes.Count) <loc> entries but the site has $($pageFiles.Count) HTML pages (404.html excluded)."
}
foreach ($locNode in $locNodes) {
  $locText = [string]$locNode.InnerText
  if (-not $locText.StartsWith($baseUrlInfo.BaseWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Generated sitemap.xml contains a URL outside the base URL: $locText"
  }
}
$sitemapRaw = [System.IO.File]::ReadAllText($sitemapPath)
if ($sitemapRaw.Contains("System.Object[]")) {
  throw "Generated sitemap.xml still contains System.Object[]"
}
$robotsPath = Join-Path $siteRoot "robots.txt"
$robotsRaw = [System.IO.File]::ReadAllText($robotsPath)
if (-not $robotsRaw.Contains("Sitemap: $sitemapUrl")) {
  throw "Generated robots.txt does not reference $sitemapUrl"
}

Write-Host "Static metadata generated for: $Version"
Write-Host "Site directory: $siteRoot"
Write-Host "HTML pages indexed: $($pageFiles.Count) (404.html excluded)"
Write-Host "Robots sitemap URL: $sitemapUrl"
