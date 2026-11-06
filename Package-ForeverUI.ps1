param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "dist"),
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

$AddonName = "ForeverUI"
$SourceDir = Join-Path $PSScriptRoot $AddonName
$TocPath = Join-Path $SourceDir "$AddonName.toc"

if (-not (Test-Path $TocPath)) {
    throw "Could not find $TocPath"
}

if (-not $SkipVerify) {
    $VerifyScript = Join-Path $PSScriptRoot "tests\verify_addon.py"
    if (Test-Path $VerifyScript) {
        Write-Host "Running addon verification suite..." -ForegroundColor Cyan
        & python $VerifyScript
        if ($LASTEXITCODE -ne 0) {
            throw "Addon verification failed. Aborting package build."
        }
    }
}

# Parse version from .toc
$Version = "1.0.0"
$TocLines = Get-Content $TocPath
foreach ($Line in $TocLines) {
    if ($Line -match "^##\s*Version:\s*(.+)$") {
        $Version = $Matches[1].Trim()
        break
    }
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$ZipFileName = "$AddonName-v$Version.zip"
$ZipFilePath = Join-Path $OutputDir $ZipFileName

if (Test-Path $ZipFilePath) {
    Remove-Item $ZipFilePath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipArchive = [System.IO.Compression.ZipFile]::Open($ZipFilePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $Files = Get-ChildItem -Path $SourceDir -Recurse -File
    foreach ($File in $Files) {
        $RelPath = $File.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        # Use forward slashes inside the zip archive for cross-platform & addon manager compatibility
        $EntryName = ($AddonName + "/" + ($RelPath -replace '\\', '/'))
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $ZipArchive,
            $File.FullName,
            $EntryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $ZipArchive.Dispose()
}

$ZipInfo = Get-Item $ZipFilePath
Write-Host "Packaged $AddonName v$Version -> $($ZipInfo.FullName) ($($ZipInfo.Length) bytes)" -ForegroundColor Green
