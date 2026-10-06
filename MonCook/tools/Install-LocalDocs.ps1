[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$SourceProjectPath = 'C:\smallsize\wak\MonCook',

    [ValidateNotNullOrEmpty()]
    [string]$PersonalRepositoryPath = 'C:\smallsize\wak\MonCook_LocalRepository'
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')
}

function Test-PathOverlap {
    param([string]$First, [string]$Second)
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $separator = [System.IO.Path]::DirectorySeparatorChar
    return $First.Equals($Second, $comparison) -or
        $First.StartsWith($Second + $separator, $comparison) -or
        $Second.StartsWith($First + $separator, $comparison)
}

function Assert-SafeDirectory {
    param([string]$Path)
    $currentPath = $Path
    while (-not [string]::IsNullOrEmpty($currentPath)) {
        if (Test-Path -LiteralPath $currentPath) {
            $item = Get-Item -LiteralPath $currentPath -Force
            if (-not $item.PSIsContainer) {
                throw "A directory path is occupied by a file: $currentPath"
            }
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Linked directories are not supported: $currentPath"
            }
        }
        $currentPath = Split-Path -Path $currentPath -Parent
    }
}

$sourceDocs = Get-NormalizedPath (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'docs')
if (-not (Test-Path -LiteralPath $sourceDocs -PathType Container)) {
    throw "Bundled docs directory was not found: $sourceDocs. Extract the whole ZIP before running this script."
}
Assert-SafeDirectory $sourceDocs

$targets = @(
    (Get-NormalizedPath (Join-Path $SourceProjectPath 'docs')),
    (Get-NormalizedPath (Join-Path (Join-Path $PersonalRepositoryPath 'MonCook') 'docs'))
)
foreach ($target in $targets) {
    if (Test-PathOverlap $sourceDocs $target) {
        throw "The bundled docs and destination must be separate directories: $target"
    }
    Assert-SafeDirectory $target
}
if (Test-PathOverlap $targets[0] $targets[1]) {
    throw 'The source-project docs and personal-repository docs destinations must be separate directories.'
}

# Snapshot the bundle before creating anything; never enumerate a destination.
$entries = @(Get-ChildItem -LiteralPath $sourceDocs -Recurse -Force)
foreach ($entry in $entries) {
    if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Linked files or directories are not supported in the bundle: $($entry.FullName)"
    }
}
$sourcePrefix = $sourceDocs + [System.IO.Path]::DirectorySeparatorChar
$directories = @($entries | Where-Object { $_.PSIsContainer })
$files = @($entries | Where-Object { -not $_.PSIsContainer })
if ($files.Count -eq 0) {
    throw "The bundled docs directory is empty: $sourceDocs"
}

$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
foreach ($target in $targets) {
    $pending = @()
    $unchanged = 0
    foreach ($directory in $directories) {
        $relativePath = $directory.FullName.Substring($sourcePrefix.Length)
        Assert-SafeDirectory (Join-Path $target $relativePath)
    }
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($sourcePrefix.Length)
        $destination = Join-Path $target $relativePath
        $exists = Test-Path -LiteralPath $destination
        if ($exists) {
            $existing = Get-Item -LiteralPath $destination -Force
            if ($existing.PSIsContainer -or
                (($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw "A document destination is occupied by a directory or link: $destination"
            }
            if ($existing.Length -eq $file.Length) {
                $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
                if ($sourceHash -eq $destinationHash) {
                    $unchanged++
                    continue
                }
            }
        }
        $pending += [pscustomobject]@{
            Source = $file.FullName
            Destination = $destination
            RelativePath = $relativePath
            Exists = $exists
        }
    }

    $backupRoot = Join-Path (Split-Path -Path $target -Parent) ('.MonCook-docs-backups\' + $runId)
    Assert-SafeDirectory $backupRoot
    Write-Host ("Destination: {0}; documents to copy: {1}; identical documents skipped: {2}" -f $target, $pending.Count, $unchanged)
    if (-not $PSCmdlet.ShouldProcess($target, 'Create docs folders, back up changed existing documents, and copy bundled documents')) {
        continue
    }

    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($directory in $directories) {
        $relativePath = $directory.FullName.Substring($sourcePrefix.Length)
        New-Item -ItemType Directory -Path (Join-Path $target $relativePath) -Force | Out-Null
    }
    $backedUp = 0
    foreach ($item in $pending) {
        if ($item.Exists) {
            $backupPath = Join-Path $backupRoot $item.RelativePath
            New-Item -ItemType Directory -Path (Split-Path -Path $backupPath -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $item.Destination -Destination $backupPath -Force
            $backedUp++
        }
        New-Item -ItemType Directory -Path (Split-Path -Path $item.Destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Force
    }
    Write-Host ("Saved {0} documents; backed up {1} previous documents." -f $pending.Count, $backedUp)
    if ($backedUp -gt 0) {
        Write-Host ("Backup directory: {0}" -f $backupRoot)
    }
}
