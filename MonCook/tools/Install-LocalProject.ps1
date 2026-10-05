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
        $item = Get-Item -LiteralPath $currentPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $item) {
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

function Get-BundledEntries {
    param([string]$Root)
    $excludedDirectories = @('.git', 'build', 'builds', 'dist', 'out', 'artifacts', 'bin', 'obj', '__pycache__', '.pytest_cache')
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        $directoryPath = $stack.Pop()
        foreach ($entry in @(Get-ChildItem -LiteralPath $directoryPath -Force)) {
            if ($entry.PSIsContainer -and
                (($excludedDirectories -contains $entry.Name) -or ($entry.Name -like '.MonCook-*'))) {
                continue
            }
            if (-not $entry.PSIsContainer -and $entry.Extension -ieq '.zip') {
                continue
            }
            if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Linked files or directories are not supported in the bundle: $($entry.FullName)"
            }
            Write-Output $entry
            if ($entry.PSIsContainer) {
                $stack.Push($entry.FullName)
            }
        }
    }
}

$sourceProject = Get-NormalizedPath (Split-Path -Path $PSScriptRoot -Parent)
Assert-SafeDirectory $sourceProject
$projectMarker = Join-Path $sourceProject 'default.project.json'
$docsMarker = Join-Path (Join-Path (Join-Path $sourceProject 'docs') 'LastRecipe_Codex_Design') 'CODEX_START_HERE.md'
if (-not (Test-Path -LiteralPath $projectMarker -PathType Leaf) -or
    -not (Test-Path -LiteralPath $docsMarker -PathType Leaf)) {
    throw 'The MonCook project bundle is incomplete. Extract the whole source ZIP before running this script.'
}

$targets = @(
    (Get-NormalizedPath $SourceProjectPath),
    (Get-NormalizedPath (Join-Path $PersonalRepositoryPath 'MonCook'))
)
foreach ($target in $targets) {
    if (Test-PathOverlap $sourceProject $target) {
        throw "The extracted bundle and destination must be separate directories: $target"
    }
    Assert-SafeDirectory $target
}
if (Test-PathOverlap $targets[0] $targets[1]) {
    throw 'The source-project and personal-repository destinations must be separate directories.'
}

# Collect the source once and prune excluded directories before traversal.
$entries = @(Get-BundledEntries $sourceProject)
$sourcePrefix = $sourceProject + [System.IO.Path]::DirectorySeparatorChar
$directories = @($entries | Where-Object { $_.PSIsContainer })
$files = @($entries | Where-Object { -not $_.PSIsContainer })
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$plans = @()

# Validate both destination trees before writing to either one.
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
        $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
        $exists = $null -ne $existing
        if ($exists) {
            if ($existing.PSIsContainer -or
                (($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw "A file destination is occupied by a directory or link: $destination"
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
    $backupRoot = Join-Path (Join-Path $target '.MonCook-project-backups') $runId
    Assert-SafeDirectory $backupRoot
    $plans += [pscustomobject]@{
        Target = $target
        Pending = $pending
        Unchanged = $unchanged
        BackupRoot = $backupRoot
    }
}

foreach ($plan in $plans) {
    Write-Host ("Destination: {0}; files to copy: {1}; identical files skipped: {2}" -f $plan.Target, $plan.Pending.Count, $plan.Unchanged)
    if (-not $PSCmdlet.ShouldProcess($plan.Target, 'Create project folders, back up changed existing files, and copy the bundled MonCook project')) {
        continue
    }
    New-Item -ItemType Directory -Path $plan.Target -Force | Out-Null
    foreach ($directory in $directories) {
        $relativePath = $directory.FullName.Substring($sourcePrefix.Length)
        New-Item -ItemType Directory -Path (Join-Path $plan.Target $relativePath) -Force | Out-Null
    }
    $backedUp = 0
    foreach ($item in $plan.Pending) {
        if ($item.Exists) {
            $backupPath = Join-Path $plan.BackupRoot $item.RelativePath
            New-Item -ItemType Directory -Path (Split-Path -Path $backupPath -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $item.Destination -Destination $backupPath -Force
            $backedUp++
        }
        New-Item -ItemType Directory -Path (Split-Path -Path $item.Destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Force
    }
    Write-Host ("Saved {0} project files; backed up {1} previous files." -f $plan.Pending.Count, $backedUp)
    if ($backedUp -gt 0) {
        Write-Host ("Backup directory: {0}" -f $plan.BackupRoot)
    }
}
