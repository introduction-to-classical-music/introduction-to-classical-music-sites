<#
.SYNOPSIS
  Windows long-path budget guard for the site-deploy repository (W9b / C-F21).

.DESCRIPTION
  Reads the real tracked paths from `git ls-tree -z` (NUL-delimited raw UTF-8,
  never Git's C-quoted display form), computes the absolute Windows path length
  of each tracked file, and reports:
    - tracked file count
    - longest absolute path length
    - number of paths at/above the warning threshold (default 240)
    - number of paths at/above the MAX_PATH limit (default 260)

  Accepted baseline for this repository (recorded by the audit-closure review):
    over_limit_260 = 6, max_absolute_length = 284
  The six accepted long paths are the legacy `site/current` / `site/v0.1.0`
  person images listed below. Renaming them is deferred to a content window
  (D7-C); this guard is read-only and never renames or rewrites anything.

  The guard fails when the path budget grows:
    - any path at/above the limit (260) that is not in the accepted baseline
    - max absolute length above the accepted baseline (284)
    - over-limit count above the accepted baseline (6)

  It passes on a shorter checkout root (e.g. GitHub Actions) because the
  absolute lengths only shrink there; the accepted baseline is the upper bound.

.PARAMETER RepoRoot
  Repository to scan. Default: the repository containing this script.

.PARAMETER Threshold
  Warning threshold in characters (default 240).

.PARAMETER Limit
  Failure limit in characters (default 260).

.PARAMETER AcceptedOverLimit
  Accepted baseline count of tracked paths at/above Limit (default 6).

.PARAMETER AcceptedMax
  Accepted baseline maximum absolute path length (default 284).

.PARAMETER Json
  Emit machine-readable JSON instead of the text report.

.EXAMPLE
  ./scripts/check-long-paths.ps1

.EXAMPLE
  ./scripts/check-long-paths.ps1 -RepoRoot F:\some\site-deploy -Threshold 240 -Limit 260
#>
param(
  [string]$RepoRoot = "",
  [int]$Threshold = 240,
  [int]$Limit = 260,
  [int]$AcceptedOverLimit = 6,
  [int]$AcceptedMax = 284,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

# Accepted baseline: tracked paths already at/above 260 in the canonical clone.
# Keep this list in sync with docs/windows-long-paths.md; all entries are ASCII.
$AcceptedLongPaths = @(
  "site/current/library-assets/managed/people/person-symphonieorchester-des-bayerischen-rundfunks/person-symphonieorchester-des-bayerischen-rundfunks-1ffa04dd94.jpg",
  "site/v0.1.0/library-assets/managed/people/person-symphonieorchester-des-bayerischen-rundfunks/person-symphonieorchester-des-bayerischen-rundfunks-1ffa04dd94.jpg",
  "site/current/library-assets/managed/people/person-bremen-philharmonisches-staatsorchester/person-bremen-philharmonisches-staatsorchester-d9fc83a229.jpg",
  "site/v0.1.0/library-assets/managed/people/person-bremen-philharmonisches-staatsorchester/person-bremen-philharmonisches-staatsorchester-d9fc83a229.jpg",
  "site/current/library-assets/managed/people/person-rundfunk-sinfonieorchester-berlin/person-rundfunk-sinfonieorchester-berlin-08db4f529c.jpg",
  "site/v0.1.0/library-assets/managed/people/person-rundfunk-sinfonieorchester-berlin/person-rundfunk-sinfonieorchester-berlin-08db4f529c.jpg"
)

function Get-GitExecutable {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) { throw "git executable not found in PATH" }
  return $git.Source
}

function Get-RepoRoot {
  param([string]$Requested)
  if (-not [string]::IsNullOrWhiteSpace($Requested)) {
    return ([System.IO.Path]::GetFullPath($Requested)).TrimEnd('\', '/')
  }
  $git = Get-GitExecutable
  try {
    $raw = (& $git -C $PSScriptRoot rev-parse --show-toplevel 2>$null | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      return ([System.IO.Path]::GetFullPath($raw)).TrimEnd('\', '/')
    }
  } catch {
    # fall through to the scripts/ parent
  }
  return ([System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))).TrimEnd('\', '/')
}

function Quote-ProcessArgument {
  param([string]$Value)
  if ($Value -eq "") { return '""' }
  if ($Value -match '[\s"]') { return ('"' + $Value.Replace('"', '\"') + '"') }
  return $Value
}

function Get-TrackedPathsRaw {
  param([string]$Repository)
  # Read git's NUL-delimited raw stdout as UTF-8 bytes: paths stay real, no C-quote escaping.
  $git = Get-GitExecutable
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $git
  $psi.Arguments = (@(
    "-C", (Quote-ProcessArgument $Repository),
    "ls-tree", "-r", "-z", "--name-only", "HEAD"
  ) -join " ")
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($psi)
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $memory = New-Object System.IO.MemoryStream
  $bytes = $null
  try {
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $process.WaitForExit()
    $bytes = $memory.ToArray()
  } finally {
    $memory.Dispose()
  }
  $stderr = $stderrTask.Result
  if ($process.ExitCode -ne 0) {
    throw ("git ls-tree failed (exit " + $process.ExitCode + "): " + $stderr.Trim())
  }
  $text = [System.Text.Encoding]::UTF8.GetString($bytes)
  return @($text.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries))
}

function Get-CoreLongpaths {
  param([string]$Repository)
  $git = Get-GitExecutable
  try {
    $value = (& $git -C $Repository config --local --get core.longpaths 2>$null | Out-String).Trim()
    return ($value -eq "true")
  } catch {
    return $false
  }
}

$repo = Get-RepoRoot $RepoRoot
$paths = Get-TrackedPathsRaw $repo
if ($paths.Count -eq 0) {
  throw ("No tracked paths found in repository: " + $repo)
}

$entries = New-Object System.Collections.Generic.List[object]
foreach ($relativePath in $paths) {
  $windowsRelative = $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
  $absolutePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repo, $windowsRelative))
  $entries.Add([pscustomobject]@{
    Path = $relativePath
    RelativeLength = $relativePath.Length
    AbsoluteLength = $absolutePath.Length
  }) | Out-Null
}

$sorted = @($entries | Sort-Object -Property @{Expression = "AbsoluteLength"; Descending = $true }, @{Expression = "RelativeLength"; Descending = $true }, Path)
$maxAbsolute = [int]$sorted[0].AbsoluteLength
$maxRelative = [int]$sorted[0].RelativeLength
$overThreshold = @($entries | Where-Object { $_.AbsoluteLength -ge $Threshold })
$overLimit = @($entries | Where-Object { $_.AbsoluteLength -ge $Limit })
$newOverLimit = @($overLimit | Where-Object { $AcceptedLongPaths -notcontains $_.Path })
$acceptedMatched = @($overLimit | Where-Object { $AcceptedLongPaths -contains $_.Path })
$coreLongpaths = Get-CoreLongpaths $repo

$failures = New-Object System.Collections.Generic.List[string]
if ($overLimit.Count -gt $AcceptedOverLimit) {
  $failures.Add(("over-limit count " + $overLimit.Count + " exceeds accepted baseline " + $AcceptedOverLimit)) | Out-Null
}
if ($maxAbsolute -gt $AcceptedMax) {
  $failures.Add(("max absolute length " + $maxAbsolute + " exceeds accepted baseline " + $AcceptedMax)) | Out-Null
}
if ($newOverLimit.Count -gt 0) {
  $failures.Add(("new tracked path(s) at/above " + $Limit + ": " + (($newOverLimit | ForEach-Object { $_.Path }) -join "; "))) | Out-Null
}
if ($entries.Count -eq 0) {
  $failures.Add("tracked path list is empty") | Out-Null
}
$ok = ($failures.Count -eq 0)

$longest = @($sorted | Select-Object -First 10)
$result = [ordered]@{
  schemaVersion = "site-long-path-check-v1"
  ok = $ok
  repo = $repo
  tracked = $entries.Count
  maxAbsoluteLength = $maxAbsolute
  maxRelativeLength = $maxRelative
  threshold = $Threshold
  limit = $Limit
  overThreshold = $overThreshold.Count
  overLimit = $overLimit.Count
  acceptedOverLimit = $AcceptedOverLimit
  acceptedMaxAbsoluteLength = $AcceptedMax
  acceptedLongPathCount = $AcceptedLongPaths.Count
  acceptedLongPathMatched = $acceptedMatched.Count
  newOverLimitCount = $newOverLimit.Count
  newOverLimitPaths = @($newOverLimit | ForEach-Object { $_.Path })
  coreLongpaths = $coreLongpaths
  longest = @($longest | ForEach-Object { [ordered]@{ absoluteLength = $_.AbsoluteLength; relativeLength = $_.RelativeLength; path = $_.Path } })
  failures = @($failures)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  Write-Host "Windows long-path guard (site-deploy)"
  Write-Host ("repo=" + $repo)
  Write-Host ("tracked=" + $entries.Count + " max=" + $maxAbsolute + " overThreshold(" + $Threshold + ")=" + $overThreshold.Count + " overLimit(" + $Limit + ")=" + $overLimit.Count + " core.longpaths=" + $(if ($coreLongpaths) { "true" } else { "(unset/false)" }))
  Write-Host ("acceptedBaseline: overLimit=" + $AcceptedOverLimit + " max=" + $AcceptedMax + " longPaths=" + $AcceptedLongPaths.Count + " matched=" + $acceptedMatched.Count + " newOverLimit=" + $newOverLimit.Count)
  Write-Host "longest tracked paths (absolute char length):"
  foreach ($entry in $longest) {
    Write-Host ("  " + ([string]$entry.AbsoluteLength).PadLeft(3) + " " + $entry.Path)
  }
  if ($acceptedMatched.Count -gt 0) {
    Write-Host "accepted baseline paths observed at/above limit:"
    foreach ($entry in $acceptedMatched) {
      Write-Host ("  " + ([string]$entry.AbsoluteLength).PadLeft(3) + " " + $entry.Path)
    }
  }
  if ($newOverLimit.Count -gt 0) {
    Write-Host "NEW long paths (budget violation):"
    foreach ($entry in $newOverLimit) {
      Write-Host ("  " + ([string]$entry.AbsoluteLength).PadLeft(3) + " " + $entry.Path)
    }
  }
  if ($ok) {
    Write-Host "RESULT: PASS (accepted baseline not exceeded; no new >= $Limit paths)"
  } else {
    Write-Host "RESULT: FAIL"
    foreach ($failure in $failures) { Write-Host ("  - " + $failure) }
  }
}

if (-not $ok) { exit 1 }
exit 0
