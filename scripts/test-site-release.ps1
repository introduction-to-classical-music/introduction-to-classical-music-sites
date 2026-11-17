[CmdletBinding()]
param(
  [string]$TestRoot = "",
  [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

$scriptsDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptsDir
$writeMetadataScript = Join-Path $scriptsDir "write-static-metadata.ps1"
$auditScript = Join-Path $scriptsDir "audit-site.ps1"
$publishOssScript = Join-Path $scriptsDir "publish-oss.ps1"

$pagesBaseUrl = "https://introduction-to-classical-music.github.io/introduction-to-classical-music-sites"
$pagesBasePath = "/introduction-to-classical-music-sites/"

$script:PassCount = 0
$script:Failures = New-Object System.Collections.Generic.List[string]

$createdTempRoot = $false
if ([string]::IsNullOrWhiteSpace($TestRoot)) {
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("icm-site-release-tests-" + [guid]::NewGuid().ToString("N"))
  $createdTempRoot = $true
} else {
  $tempRoot = [System.IO.Path]::GetFullPath($TestRoot)
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
$logRoot = Join-Path $tempRoot "audit-logs"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

function Write-CheckPass {
  param([string]$Name)
  $script:PassCount = $script:PassCount + 1
  Write-Host "[PASS] $Name"
}

function Write-CheckFailure {
  param([string]$Name)
  $script:Failures.Add($Name) | Out-Null
  Write-Host "[FAIL] $Name"
}

function Assert-Test {
  param(
    [bool]$Condition,
    [string]$Name
  )
  if ($Condition) {
    Write-CheckPass $Name
  } else {
    Write-CheckFailure $Name
  }
}

function Assert-Contains {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Name
  )
  $matched = $false
  if ($null -ne $Text) {
    $matched = [bool]($Text -match $Pattern)
  }
  Assert-Test $matched $Name
}

function Assert-NotContains {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Name
  )
  $matched = $true
  if ($null -ne $Text) {
    $matched = [bool]($Text -match $Pattern)
  }
  Assert-Test (-not $matched) $Name
}

function Get-PowerShellHostPath {
  $processPath = ""
  try {
    $processPath = (Get-Process -Id $PID).Path
  } catch {
    $processPath = ""
  }
  if (-not [string]::IsNullOrWhiteSpace($processPath)) {
    return $processPath
  }
  $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($pwshCommand) {
    return $pwshCommand.Source
  }
  $powershellCommand = Get-Command powershell -ErrorAction SilentlyContinue
  if ($powershellCommand) {
    return $powershellCommand.Source
  }
  throw "Cannot locate a PowerShell host executable."
}

function Invoke-SiteScript {
  param(
    [string]$ScriptPath,
    [string[]]$Arguments = @(),
    [hashtable]$Environment = @{}
  )

  $hostPath = Get-PowerShellHostPath
  $argumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $Arguments
  $savedEnvironment = @{}
  foreach ($name in $Environment.Keys) {
    $savedEnvironment[$name] = [System.Environment]::GetEnvironmentVariable($name, [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable($name, [string]$Environment[$name], [System.EnvironmentVariableTarget]::Process)
  }
  try {
    # Windows PowerShell 5.1 turns redirected native stderr into terminating
    # errors while $ErrorActionPreference is 'Stop'; keep it non-terminating for
    # the duration of the child invocation and read the exit code instead.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $output = & $hostPath @argumentList 2>&1
      $exitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }
  } finally {
    foreach ($name in $savedEnvironment.Keys) {
      [System.Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], [System.EnvironmentVariableTarget]::Process)
    }
  }
  $text = (@($output) | ForEach-Object { [string]$_ }) -join "`n"
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = $text
  }
}

function Invoke-GitCommand {
  param(
    [string]$RepoPath,
    [string[]]$Arguments = @()
  )

  # Native git stderr must not become a terminating error while
  # $ErrorActionPreference is "Stop"; capture it and surface it on failure.
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & git -C $RepoPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $text = (@($output) | ForEach-Object { [string]$_ }) -join "`n"
  if ($exitCode -ne 0) {
    throw "git -C $RepoPath $($Arguments -join ' ') failed (exit $exitCode): $text"
  }
  return $text
}

function New-FixtureSite {
  param(
    [string]$Name,
    [string[]]$Pages = @("index.html", "about/index.html", "composers/index.html")
  )

  $sitePath = Join-Path $tempRoot $Name
  foreach ($page in $Pages) {
    $file = Join-Path $sitePath ($page -replace '/', '\')
    $parent = Split-Path -Parent $file
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $html = '<!doctype html><html><head><title>' + $Name + '</title></head><body><h1>' + $Name + '</h1></body></html>'
    Set-Content -LiteralPath $file -Value $html -Encoding ascii
  }
  return $sitePath
}

function Write-TestManifest {
  param(
    [string]$SitePath,
    [string]$SiteBase,
    [string]$AppVersion = "0.1.1",
    [string]$LibraryName = "Test Library"
  )

  $manifestPath = Join-Path $SitePath "site-release-manifest.json"
  # Build the JSON by hand so the non-ASCII libraryName is stored as raw UTF-8
  # bytes (Node.js JSON.stringify behavior). ConvertTo-Json would escape it to
  # \uXXXX, which would hide the Windows PowerShell 5.1 ANSI decoding bug.
  $digest = ("0" * 64)
  $safeLibraryName = $LibraryName.Replace('\', '\\').Replace('"', '\"')
  $json = '{"libraryId":"test-library","libraryName":"' + $safeLibraryName + '","appVersion":"' + $AppVersion + '","builtAt":"2026-01-01T00:00:00.000Z","siteBase":"' + $SiteBase + '","sourceDigest":"' + $digest + '","siteDigest":"' + $digest + '"}'
  # Export manifests are UTF-8 without BOM (written by Node.js); reproduce that
  # shape so Windows PowerShell 5.1 encoding regressions are covered.
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($manifestPath, ($json + "`n"), $utf8NoBom)
}

function Invoke-WriteStaticMetadata {
  param(
    [string]$SitePath,
    [string]$BaseUrl = $pagesBaseUrl,
    [string[]]$ExtraArguments = @()
  )

  $arguments = @("-Version", "vtest", "-SiteDir", $SitePath)
  if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
    $arguments += @("-BaseUrl", $BaseUrl)
  }
  $arguments += $ExtraArguments
  return Invoke-SiteScript -ScriptPath $writeMetadataScript -Arguments $arguments -Environment @{ ICM_AUDIT_LOG_DIR = $logRoot }
}

function Invoke-SiteAudit {
  param(
    [string]$SitePath,
    [string]$BaseUrl = $pagesBaseUrl,
    [string[]]$ExtraArguments = @()
  )

  $arguments = @("-Version", "vtest", "-SiteDir", $SitePath)
  if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
    $arguments += @("-BaseUrl", $BaseUrl)
  }
  $arguments += $ExtraArguments
  return Invoke-SiteScript -ScriptPath $auditScript -Arguments $arguments -Environment @{ ICM_AUDIT_LOG_DIR = $logRoot }
}

function New-PreparedSite {
  param(
    [string]$Name,
    [bool]$WithManifest = $true
  )

  $sitePath = New-FixtureSite -Name $Name
  $generation = Invoke-WriteStaticMetadata -SitePath $sitePath
  if ($generation.ExitCode -ne 0) {
    throw "Could not prepare fixture '$Name': $($generation.Output)"
  }
  if ($WithManifest) {
    Write-TestManifest -SitePath $sitePath -SiteBase $pagesBasePath
  }
  return $sitePath
}

function Get-HtmlPageCount {
  param([string]$SitePath)
  $files = @(Get-ChildItem -LiteralPath $SitePath -Recurse -File -Filter "*.html" | Where-Object { $_.Name -ne "404.html" })
  return $files.Count
}

function Get-LocTexts {
  param([string]$SitemapPath)
  $document = New-Object System.Xml.XmlDocument
  $document.LoadXml([System.IO.File]::ReadAllText($SitemapPath))
  $texts = New-Object System.Collections.Generic.List[string]
  foreach ($node in @($document.SelectNodes("//*[local-name()='loc']"))) {
    $texts.Add([string]$node.InnerText)
  }
  return $texts.ToArray()
}

function Get-FileSha256 {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ""
  }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$exitCode = 1
try {
  Write-Host "Site release regression tests"
  Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
  Write-Host "Repository: $repoRoot"
  Write-Host "Temp root: $tempRoot"
  Write-Host ""

  $repoSitemapPath = Join-Path $repoRoot "site\current\sitemap.xml"
  $repoSitemapHashBefore = Get-FileSha256 $repoSitemapPath

  # -------------------------------------------------------------------------
  # 1. write-static-metadata generates valid sitemap metadata
  # -------------------------------------------------------------------------
  Write-Host "Section 1: write-static-metadata generation"
  $positiveSite = New-FixtureSite -Name "positive-site"
  $generationResult = Invoke-WriteStaticMetadata -SitePath $positiveSite
  Assert-Test ($generationResult.ExitCode -eq 0) "write-static-metadata succeeds on a fixture site"

  $sitemapPath = Join-Path $positiveSite "sitemap.xml"
  $robotsPath = Join-Path $positiveSite "robots.txt"
  Assert-Test (Test-Path -LiteralPath $sitemapPath -PathType Leaf) "write-static-metadata writes sitemap.xml"
  Assert-Test (Test-Path -LiteralPath $robotsPath -PathType Leaf) "write-static-metadata writes robots.txt"
  Assert-Test (Test-Path -LiteralPath (Join-Path $positiveSite "404.html") -PathType Leaf) "write-static-metadata writes 404.html"

  $pageCount = Get-HtmlPageCount -SitePath $positiveSite
  $sitemapParsed = $false
  $locTexts = @()
  if (Test-Path -LiteralPath $sitemapPath -PathType Leaf) {
    try {
      $locTexts = @(Get-LocTexts -SitemapPath $sitemapPath)
      $sitemapParsed = $true
    } catch {
      $sitemapParsed = $false
    }
  }
  Assert-Test $sitemapParsed "generated sitemap.xml is valid XML"
  Assert-Test ($sitemapParsed -and $locTexts.Count -eq $pageCount) "generated sitemap <loc> count equals HTML page count ($($locTexts.Count) vs $pageCount)"
  $sitemapRaw = ""
  if (Test-Path -LiteralPath $sitemapPath -PathType Leaf) {
    $sitemapRaw = [System.IO.File]::ReadAllText($sitemapPath)
  }
  Assert-NotContains -Text $sitemapRaw -Pattern "System\.Object\[\]" -Name "generated sitemap.xml does not contain System.Object[]"
  $allLocsMatchBase = $true
  foreach ($locText in $locTexts) {
    if (-not $locText.StartsWith($pagesBaseUrl + "/", [System.StringComparison]::OrdinalIgnoreCase)) {
      $allLocsMatchBase = $false
    }
  }
  Assert-Test ($sitemapParsed -and $allLocsMatchBase) "generated sitemap URLs use the configured base URL"
  $robotsRaw = ""
  if (Test-Path -LiteralPath $robotsPath -PathType Leaf) {
    $robotsRaw = [System.IO.File]::ReadAllText($robotsPath)
  }
  Assert-Test ($robotsRaw.Contains("Sitemap: $pagesBaseUrl/sitemap.xml")) "generated robots.txt points at the configured base domain"

  $secondRun = Invoke-WriteStaticMetadata -SitePath $positiveSite
  $secondLocTexts = @(Get-LocTexts -SitemapPath $sitemapPath)
  Assert-Test ($secondRun.ExitCode -eq 0 -and $secondLocTexts.Count -eq $pageCount) "re-running write-static-metadata is idempotent (404.html excluded from sitemap)"

  # -------------------------------------------------------------------------
  # 2. write-static-metadata rejects missing/placeholder base URLs
  # -------------------------------------------------------------------------
  Write-Host ""
  Write-Host "Section 2: write-static-metadata guard rails"
  $guardSite = New-FixtureSite -Name "guard-site"
  $missingBase = Invoke-SiteScript -ScriptPath $writeMetadataScript -Arguments @("-Version", "vtest", "-SiteDir", $guardSite)
  Assert-Test ($missingBase.ExitCode -ne 0) "write-static-metadata fails when -BaseUrl is omitted"
  Assert-Contains -Text $missingBase.Output -Pattern "BaseUrl" -Name "missing -BaseUrl failure mentions BaseUrl"

  $placeholderBase = Invoke-WriteStaticMetadata -SitePath $guardSite -BaseUrl "https://example.com"
  Assert-Test ($placeholderBase.ExitCode -ne 0) "write-static-metadata rejects placeholder domain example.com"
  Assert-Contains -Text $placeholderBase.Output -Pattern "placeholder" -Name "placeholder-domain failure mentions placeholder domain"

  $placeholderBase2 = Invoke-WriteStaticMetadata -SitePath $guardSite -BaseUrl "https://your-domain.example"
  Assert-Test ($placeholderBase2.ExitCode -ne 0) "write-static-metadata rejects placeholder domain your-domain.example"

  $invalidBase = Invoke-WriteStaticMetadata -SitePath $guardSite -BaseUrl "not a url"
  Assert-Test ($invalidBase.ExitCode -ne 0) "write-static-metadata rejects a non-absolute base URL"

  $allowTestDomain = Invoke-WriteStaticMetadata -SitePath $guardSite -BaseUrl "https://example.com" -ExtraArguments @("-AllowTestDomain")
  Assert-Test ($allowTestDomain.ExitCode -eq 0) "-AllowTestDomain permits a placeholder domain for a temporary fixture"

  $repoSiteDir = Join-Path $repoRoot "site\current"
  if (Test-Path -LiteralPath $repoSiteDir -PathType Container) {
    $repoGuard = Invoke-WriteStaticMetadata -SitePath $repoSiteDir -BaseUrl "https://example.com" -ExtraArguments @("-AllowTestDomain")
    Assert-Test ($repoGuard.ExitCode -ne 0) "-AllowTestDomain refuses to write placeholder metadata into repository site/"
    Assert-Contains -Text $repoGuard.Output -Pattern "Refusing" -Name "repository site/ guard explains the refusal"
  } else {
    Write-Host "[SKIP] repository site/current missing; repository guard check skipped"
  }

  # -------------------------------------------------------------------------
  # 3. audit-site passes a valid release site
  # -------------------------------------------------------------------------
  Write-Host ""
  Write-Host "Section 3: audit-site positive cases"
  $validSite = New-PreparedSite -Name "valid-site"
  $auditPass = Invoke-SiteAudit -SitePath $validSite
  Assert-Test ($auditPass.ExitCode -eq 0) "audit-site passes for a valid fixture site with -BaseUrl"
  Assert-Contains -Text $auditPass.Output -Pattern "Site audit passed" -Name "audit-site success message is printed"
  $auditPassManifest = Invoke-SiteAudit -SitePath $validSite -BaseUrl ""
  Assert-Test ($auditPassManifest.ExitCode -eq 0) "audit-site passes using manifest siteBase when -BaseUrl is omitted"
  $successLogs = @(Get-ChildItem -LiteralPath $logRoot -File -ErrorAction SilentlyContinue)
  Assert-Test ($successLogs.Count -eq 0) "audit-site does not write a failure log for a passing site"

  # -------------------------------------------------------------------------
  # 4. audit-site blocks legacy and broken artifacts
  # -------------------------------------------------------------------------
  Write-Host ""
  Write-Host "Section 4: audit-site negative cases"

  $legacySite = New-FixtureSite -Name "legacy-site"
  $legacyRobots = @(
    "User-agent: *",
    "Allow: /",
    "Sitemap: https://example.com/sitemap.xml"
  ) -join "`r`n"
  Set-Content -LiteralPath (Join-Path $legacySite "robots.txt") -Value $legacyRobots -Encoding ascii
  $legacySitemap = @(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    'System.Object[]',
    '</urlset>'
  ) -join "`r`n"
  Set-Content -LiteralPath (Join-Path $legacySite "sitemap.xml") -Value $legacySitemap -Encoding ascii
  $legacyAudit = Invoke-SiteAudit -SitePath $legacySite
  Assert-Test ($legacyAudit.ExitCode -ne 0) "audit-site fails for legacy artifacts (example.com + System.Object[] + no manifest)"
  Assert-Contains -Text $legacyAudit.Output -Pattern "site-release-manifest\.json is missing" -Name "legacy audit failure reports the missing manifest"
  Assert-Contains -Text $legacyAudit.Output -Pattern "sitemap\.xml" -Name "legacy audit failure reports the broken sitemap"
  Assert-Test (Test-Path -LiteralPath (Join-Path $logRoot "audit-site-vtest.log") -PathType Leaf) "audit-site writes a failure log under the log directory"

  $exampleSite = New-PreparedSite -Name "example-robots-site"
  $exampleRobots = @(
    "User-agent: *",
    "Allow: /",
    "Sitemap: https://example.com/sitemap.xml"
  ) -join "`r`n"
  Set-Content -LiteralPath (Join-Path $exampleSite "robots.txt") -Value $exampleRobots -Encoding ascii
  $exampleAudit = Invoke-SiteAudit -SitePath $exampleSite
  Assert-Test ($exampleAudit.ExitCode -ne 0) "audit-site fails when robots.txt points at example.com"
  Assert-Contains -Text $exampleAudit.Output -Pattern "example\.com" -Name "example.com audit failure names the offending content"

  $objectArraySite = New-PreparedSite -Name "object-array-site"
  $brokenSitemap = @(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    'System.Object[]',
    '</urlset>'
  ) -join "`r`n"
  Set-Content -LiteralPath (Join-Path $objectArraySite "sitemap.xml") -Value $brokenSitemap -Encoding ascii
  $objectArrayAudit = Invoke-SiteAudit -SitePath $objectArraySite
  Assert-Test ($objectArrayAudit.ExitCode -ne 0) "audit-site fails for a System.Object[] sitemap"
  Assert-Contains -Text $objectArrayAudit.Output -Pattern "System\.Object\[\]" -Name "sitemap audit failure names System.Object[]"

  $missingManifestSite = New-PreparedSite -Name "missing-manifest-site"
  Remove-Item -LiteralPath (Join-Path $missingManifestSite "site-release-manifest.json") -Force
  $missingManifestAudit = Invoke-SiteAudit -SitePath $missingManifestSite
  Assert-Test ($missingManifestAudit.ExitCode -ne 0) "audit-site fails when site-release-manifest.json is missing"
  Assert-Contains -Text $missingManifestAudit.Output -Pattern "manifest" -Name "missing manifest audit failure mentions the manifest"

  $baseMismatchSite = New-PreparedSite -Name "base-mismatch-site"
  Write-TestManifest -SitePath $baseMismatchSite -SiteBase "/"
  $baseMismatchAudit = Invoke-SiteAudit -SitePath $baseMismatchSite
  Assert-Test ($baseMismatchAudit.ExitCode -ne 0) "audit-site fails when manifest siteBase does not match the expected base"
  Assert-Contains -Text $baseMismatchAudit.Output -Pattern "siteBase" -Name "base mismatch audit failure mentions siteBase"

  $countMismatchSite = New-PreparedSite -Name "count-mismatch-site"
  $countMismatchSitemapPath = Join-Path $countMismatchSite "sitemap.xml"
  $countMismatchText = [System.IO.File]::ReadAllText($countMismatchSitemapPath)
  $extraLoc = "  <url><loc>$pagesBaseUrl/extra.html</loc></url>`r`n</urlset>"
  $countMismatchText = $countMismatchText.Replace("</urlset>", $extraLoc)
  [System.IO.File]::WriteAllText($countMismatchSitemapPath, $countMismatchText, (New-Object System.Text.UTF8Encoding($false)))
  $countMismatchAudit = Invoke-SiteAudit -SitePath $countMismatchSite
  Assert-Test ($countMismatchAudit.ExitCode -ne 0) "audit-site fails when sitemap loc count differs from the HTML page count"
  Assert-Contains -Text $countMismatchAudit.Output -Pattern "loc" -Name "loc count audit failure mentions the loc mismatch"

  $robotsPathMismatchSite = New-PreparedSite -Name "robots-path-mismatch-site"
  $wrongRobots = @(
    "User-agent: *",
    "Allow: /",
    "Sitemap: https://introduction-to-classical-music.github.io/wrong-base/sitemap.xml"
  ) -join "`r`n"
  Set-Content -LiteralPath (Join-Path $robotsPathMismatchSite "robots.txt") -Value $wrongRobots -Encoding ascii
  $robotsPathMismatchAudit = Invoke-SiteAudit -SitePath $robotsPathMismatchSite
  Assert-Test ($robotsPathMismatchAudit.ExitCode -ne 0) "audit-site fails when robots.txt sitemap path does not match the base"
  Assert-Contains -Text $robotsPathMismatchAudit.Output -Pattern "Sitemap path" -Name "robots path mismatch audit failure mentions the sitemap path"

  $missingMetadataSite = New-PreparedSite -Name "missing-metadata-site"
  Remove-Item -LiteralPath (Join-Path $missingMetadataSite "sitemap.xml") -Force
  Remove-Item -LiteralPath (Join-Path $missingMetadataSite "robots.txt") -Force
  $missingMetadataAudit = Invoke-SiteAudit -SitePath $missingMetadataSite
  Assert-Test ($missingMetadataAudit.ExitCode -ne 0) "audit-site fails when sitemap.xml and robots.txt are missing"
  Assert-Contains -Text $missingMetadataAudit.Output -Pattern "sitemap\.xml is missing" -Name "missing sitemap audit failure names sitemap.xml"
  Assert-Contains -Text $missingMetadataAudit.Output -Pattern "robots\.txt is missing" -Name "missing robots audit failure names robots.txt"

  # -------------------------------------------------------------------------
  # 5. audit-site fails when ripgrep is unavailable
  # -------------------------------------------------------------------------
  Write-Host ""
  Write-Host "Section 5: missing ripgrep"
  $emptyBinDir = Join-Path $tempRoot "empty-path-bin"
  New-Item -ItemType Directory -Force -Path $emptyBinDir | Out-Null
  $savedPath = $env:PATH
  $missingRgResult = Invoke-SiteScript -ScriptPath $auditScript -Arguments @("-Version", "vtest", "-SiteDir", $validSite, "-BaseUrl", $pagesBaseUrl) -Environment @{ ICM_AUDIT_LOG_DIR = $logRoot; PATH = $emptyBinDir }
  $env:PATH = $savedPath
  Assert-Test ($missingRgResult.ExitCode -ne 0) "audit-site fails when ripgrep is missing from PATH"
  Assert-Contains -Text $missingRgResult.Output -Pattern "ripgrep" -Name "missing ripgrep failure mentions ripgrep"
  $rgLogPath = Join-Path $logRoot "audit-site-vtest.log"
  $rgLogText = ""
  if (Test-Path -LiteralPath $rgLogPath -PathType Leaf) {
    $rgLogText = [System.IO.File]::ReadAllText($rgLogPath)
  }
  Assert-Contains -Text $rgLogText -Pattern "ripgrep" -Name "missing ripgrep failure is written to the audit log"

  # -------------------------------------------------------------------------
  # 6. publish-oss refuses to upload an unaudited site
  # -------------------------------------------------------------------------
  Write-Host ""
  Write-Host "Section 6: publish-oss audit gate"
  $unauditedSite = New-PreparedSite -Name "unaudited-site" -WithManifest $false
  $publishRejected = Invoke-SiteScript -ScriptPath $publishOssScript -Arguments @(
    "-Version", "vtest",
    "-SiteDir", $unauditedSite,
    "-Bucket", "oss://test-bucket",
    "-Endpoint", "oss-cn-test.aliyuncs.com",
    "-BaseUrl", $pagesBaseUrl
  ) -Environment @{ ICM_AUDIT_LOG_DIR = $logRoot }
  Assert-Test ($publishRejected.ExitCode -ne 0) "publish-oss aborts when the site has not passed audit-site"
  Assert-Contains -Text $publishRejected.Output -Pattern "audit" -Name "publish-oss abort output mentions the audit"
  Assert-NotContains -Text $publishRejected.Output -Pattern "Uploading" -Name "publish-oss does not start uploading after an audit failure"

  $fakeBinDir = Join-Path $tempRoot "fake-bin"
  New-Item -ItemType Directory -Force -Path $fakeBinDir | Out-Null
  $fakeOssutilLog = Join-Path $tempRoot "fake-ossutil-calls.log"
  $fakeOssutilPath = Join-Path $fakeBinDir "ossutil.cmd"
  $fakeOssutilContent = @(
    "@echo off",
    'echo %*>>"%ICM_FAKE_OSSUTIL_LOG%"',
    "exit /b 0"
  ) -join "`r`n"
  Set-Content -LiteralPath $fakeOssutilPath -Value $fakeOssutilContent -Encoding ascii
  $publishAccepted = Invoke-SiteScript -ScriptPath $publishOssScript -Arguments @(
    "-Version", "vtest",
    "-SiteDir", $validSite,
    "-Bucket", "oss://test-bucket",
    "-Endpoint", "oss-cn-test.aliyuncs.com",
    "-BaseUrl", $pagesBaseUrl
  ) -Environment @{ ICM_AUDIT_LOG_DIR = $logRoot; ICM_FAKE_OSSUTIL_LOG = $fakeOssutilLog; PATH = ($fakeBinDir + ";" + $env:PATH) }
  Assert-Test ($publishAccepted.ExitCode -eq 0) "publish-oss uploads after a passing audit"
  Assert-Contains -Text $publishAccepted.Output -Pattern "OSS upload completed" -Name "publish-oss reports a completed upload"
  $fakeCalls = ""
  if (Test-Path -LiteralPath $fakeOssutilLog -PathType Leaf) {
    $fakeCalls = [System.IO.File]::ReadAllText($fakeOssutilLog)
  }
  Assert-Contains -Text $fakeCalls -Pattern "cp" -Name "publish-oss invoked ossutil cp through the audit gate"

  # -------------------------------------------------------------------------
  # 7. UTF-8 without BOM manifests with non-ASCII content (PowerShell 5.1)
  # -------------------------------------------------------------------------
  Write-Host ""
  Write-Host "Section 7: UTF-8 without BOM manifest (PowerShell 5.1 encoding regression)"
  $utf8Site = New-PreparedSite -Name "utf8-manifest-site"
  # "Salon Library " + five CJK characters ("official library") encoded as UTF-8
  # bytes; keeping the script itself ASCII-only so Windows PowerShell 5.1 parses
  # it correctly.
  $utf8LibraryName = "Salon Library " + [System.Text.Encoding]::UTF8.GetString([byte[]](0xE5, 0xAE, 0x98, 0xE6, 0x96, 0xB9, 0xE8, 0xB5, 0x84, 0xE6, 0x96, 0x99, 0xE5, 0xBA, 0x93))
  Write-TestManifest -SitePath $utf8Site -SiteBase $pagesBasePath -LibraryName $utf8LibraryName
  $utf8ManifestPath = Join-Path $utf8Site "site-release-manifest.json"
  $manifestBytes = [System.IO.File]::ReadAllBytes($utf8ManifestPath)
  $hasBom = ($manifestBytes.Length -ge 3) -and ($manifestBytes[0] -eq 0xEF) -and ($manifestBytes[1] -eq 0xBB) -and ($manifestBytes[2] -eq 0xBF)
  Assert-Test (-not $hasBom) "regression manifest is UTF-8 without BOM"
  $manifestHasMultiByteBytes = @($manifestBytes | Where-Object { $_ -gt 0x7F }).Count -gt 0
  Assert-Test $manifestHasMultiByteBytes "regression manifest stores the non-ASCII libraryName as raw UTF-8 bytes"
  $utf8ManifestText = [System.IO.File]::ReadAllText($utf8ManifestPath, [System.Text.Encoding]::UTF8)
  Assert-Test ($utf8ManifestText.Contains($utf8LibraryName)) "regression manifest text preserves the non-ASCII libraryName"

  $utf8Audit = Invoke-SiteAudit -SitePath $utf8Site
  Assert-Test ($utf8Audit.ExitCode -eq 0) "audit-site parses a UTF-8 without BOM manifest (Windows PowerShell 5.1)"
  Assert-Contains -Text $utf8Audit.Output -Pattern "Site audit passed" -Name "UTF-8 manifest audit reports success"
  $utf8AuditNoBase = Invoke-SiteAudit -SitePath $utf8Site -BaseUrl ""
  Assert-Test ($utf8AuditNoBase.ExitCode -eq 0) "audit-site compares UTF-8 manifest siteBase when -BaseUrl is omitted"

  # publish-pages/publish preview must not fail on the same manifest. Run it
  # against an isolated throwaway git repository so the real site-deploy repo
  # (and its origin/pages worktree) is never touched by the test.
  $publishRepo = Join-Path $tempRoot "publish-preview-repo"
  New-Item -ItemType Directory -Force -Path $publishRepo | Out-Null
  Invoke-GitCommand -RepoPath $publishRepo -Arguments @("init", "--quiet") | Out-Null
  Invoke-GitCommand -RepoPath $publishRepo -Arguments @("config", "user.name", "Site Release Test") | Out-Null
  Invoke-GitCommand -RepoPath $publishRepo -Arguments @("config", "user.email", "site-release-test@example.invalid") | Out-Null
  Set-Content -LiteralPath (Join-Path $publishRepo "index.html") -Value "<!doctype html><html><body>seed pages</body></html>" -Encoding ascii
  Invoke-GitCommand -RepoPath $publishRepo -Arguments @("add", "-A") | Out-Null
  Invoke-GitCommand -RepoPath $publishRepo -Arguments @("commit", "--quiet", "-m", "seed pages") | Out-Null
  Invoke-GitCommand -RepoPath $publishRepo -Arguments @("update-ref", "refs/remotes/origin/pages", "HEAD") | Out-Null
  $seedHead = (Invoke-GitCommand -RepoPath $publishRepo -Arguments @("rev-parse", "HEAD")).Trim()

  $publishReposcripts = Join-Path $publishRepo "scripts"
  New-Item -ItemType Directory -Force -Path $publishReposcripts | Out-Null
  foreach ($scriptName in @("publish-pages.ps1", "audit-site.ps1", "stage-site.ps1", "site-release-common.ps1")) {
    Copy-Item -LiteralPath (Join-Path $scriptsDir $scriptName) -Destination (Join-Path $publishReposcripts $scriptName) -Force
  }
  $childTempRoot = Join-Path $tempRoot "child-temp"
  New-Item -ItemType Directory -Force -Path $childTempRoot | Out-Null
  $utf8Environment = @{ ICM_AUDIT_LOG_DIR = $logRoot; TEMP = $childTempRoot; TMP = $childTempRoot }

  $previewResult = Invoke-SiteScript -ScriptPath (Join-Path $publishReposcripts "publish-pages.ps1") -Arguments @("-Version", "vtest", "-SourceSiteDir", $utf8Site) -Environment $utf8Environment
  Assert-Test ($previewResult.ExitCode -eq 0) "publish-pages preview accepts a UTF-8 without BOM manifest"
  Assert-Contains -Text $previewResult.Output -Pattern "Preview only" -Name "publish-pages preview stops before committing and pushing"
  $headAfterPreview = (Invoke-GitCommand -RepoPath $publishRepo -Arguments @("rev-parse", "HEAD")).Trim()
  Assert-Test ($headAfterPreview -eq $seedHead) "publish-pages preview does not create a commit"
  $worktreeLines = @((Invoke-GitCommand -RepoPath $publishRepo -Arguments @("worktree", "list")) -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  Assert-Test ($worktreeLines.Count -eq 1) "publish-pages preview removes its temporary worktree"

  $stageResult = Invoke-SiteScript -ScriptPath (Join-Path $publishReposcripts "stage-site.ps1") -Arguments @("-Version", "vtest", "-SourceSiteDir", $utf8Site) -Environment $utf8Environment
  Assert-Test ($stageResult.ExitCode -eq 0) "stage-site accepts a UTF-8 without BOM manifest"
  $stagedManifestPath = Join-Path $publishRepo "site\vtest\site-release-manifest.json"
  Assert-Test (Test-Path -LiteralPath $stagedManifestPath -PathType Leaf) "stage-site writes the archived manifest"
  $stagedManifest = $null
  $stagedParsed = $false
  try {
    $stagedManifest = [System.IO.File]::ReadAllText($stagedManifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $stagedParsed = $true
  } catch {
    $stagedParsed = $false
  }
  Assert-Test $stagedParsed "stage-site archived manifest is valid JSON"
  Assert-Test ($stagedParsed -and ([string]$stagedManifest.libraryName -eq $utf8LibraryName)) "stage-site preserves the non-ASCII libraryName"
  Assert-Test ($stagedParsed -and ([string]$stagedManifest.archivedVersion -eq "vtest")) "stage-site records the archived version"

  # -------------------------------------------------------------------------
  # 8. repository site artifacts are untouched by the tests
  # -------------------------------------------------------------------------
  Write-Host ""
  Write-Host "Section 8: repository safety"
  $repoSitemapHashAfter = Get-FileSha256 $repoSitemapPath
  Assert-Test ($repoSitemapHashBefore -eq $repoSitemapHashAfter) "tests do not modify repository site/ artifacts"

  Write-Host ""
  if ($script:Failures.Count -gt 0) {
    Write-Host ("TESTS FAILED: " + $script:Failures.Count + " check(s) failed, " + $script:PassCount + " passed.")
    foreach ($failure in $script:Failures) {
      Write-Host ("  - " + $failure)
    }
    $exitCode = 1
  } else {
    Write-Host ("ALL CHECKS PASSED: " + $script:PassCount + " checks.")
    $exitCode = 0
  }
} finally {
  if ($createdTempRoot -and -not $KeepArtifacts -and (Test-Path -LiteralPath $tempRoot)) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $tempRoot) {
      Write-Host "[WARN] temporary test directory was not removed: $tempRoot"
    } else {
      Write-Host "[cleanup] removed temporary test directory: $tempRoot"
    }
  } elseif ($KeepArtifacts) {
    Write-Host "[cleanup] kept temporary test directory: $tempRoot"
  }
}

exit $exitCode
