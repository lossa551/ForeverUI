param(
    [string]$WowAddonsPath = ""
)

$ErrorActionPreference = "Stop"
$SourceDir = Join-Path $PSScriptRoot "ForeverUI"

if (-not $WowAddonsPath) {
    $Candidates = @(
        "E:\Games\wow\World of Warcraft\_forever_\Interface\AddOns",
        "E:\Games\wow\_forever_\Interface\AddOns",
        "E:\Games\wow\_classic_era_\Interface\AddOns",
        "E:\Games\wow\_retail_\Interface\AddOns",
        "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns",
        "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns"
    )
    foreach ($Candidate in $Candidates) {
        if (Test-Path $Candidate) {
            $WowAddonsPath = $Candidate
            break
        }
    }
}

if (-not $WowAddonsPath) {
    Write-Host "Usage: .\Deploy-ForeverUI.ps1 -WowAddonsPath '<path-to-WoW>\Interface\AddOns'" -ForegroundColor Yellow
    exit 0
}

$TargetDir = Join-Path $WowAddonsPath "ForeverUI"
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$TargetItem = Get-Item $TargetDir
if ($TargetItem.LinkType -eq "Junction" -or $TargetItem.LinkType -eq "SymbolicLink") {
    Write-Host "ForeverUI is already linked via $($TargetItem.LinkType) to: $($TargetItem.Target)" -ForegroundColor Green
} else {
    Copy-Item -Path (Join-Path $SourceDir "*") -Destination $TargetDir -Recurse -Force
    Write-Host "Deployed ForeverUI to: $TargetDir" -ForegroundColor Green
}
Write-Host "Type /reload in World of Warcraft: Forever, then run /fui showcase or /fui kill!" -ForegroundColor Cyan
