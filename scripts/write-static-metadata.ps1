param(
  [string]$Version = "v0.1.0",
  [string]$BaseUrl
)

$ErrorActionPreference = "Stop"

if (-not $BaseUrl) {
  throw "Please provide a base URL, for example: -BaseUrl https://your-domain.example"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$siteRoot = Join-Path $repoRoot "site\$Version"

if (-not (Test-Path $siteRoot)) {
  throw "Site directory not found: $siteRoot"
}

$normalizedBaseUrl = $BaseUrl.TrimEnd("/")
$htmlFiles = Get-ChildItem -Path $siteRoot -Recurse -Filter *.html | Where-Object { -not $_.PSIsContainer }
$urls = foreach ($file in $htmlFiles) {
  $relative = $file.FullName.Substring($siteRoot.Length).TrimStart('\') -replace '\\', '/'
  if ($relative -eq 'index.html') {
    "$normalizedBaseUrl/"
  } elseif ($relative.EndsWith('/index.html')) {
    "$normalizedBaseUrl/" + $relative.Substring(0, $relative.Length - 'index.html'.Length)
  } else {
    "$normalizedBaseUrl/$relative"
  }
}

$robots = @(
  "User-agent: *",
  "Allow: /",
  "Sitemap: $normalizedBaseUrl/sitemap.xml"
) -join "`r`n"

$sitemapItems = $urls | ForEach-Object { "  <url><loc>$_</loc></url>" }
$sitemap = @(
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  $sitemapItems,
  '</urlset>'
) -join "`r`n"

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

Set-Content -Path (Join-Path $siteRoot "robots.txt") -Value $robots -Encoding utf8
Set-Content -Path (Join-Path $siteRoot "sitemap.xml") -Value $sitemap -Encoding utf8
Set-Content -Path (Join-Path $siteRoot "404.html") -Value $notFound -Encoding utf8

Write-Host "Static metadata generated for: $Version"
