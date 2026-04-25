# =======================
# TOOLS COLLECTOR (CUSTOM)
# =======================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

cls
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "        TOOLS COLLECTOR (MIN)        " -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Restarting as administrator..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList `
        "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
    exit 0
}

$root = "C:\"
$name = "SS"
$i = 1
while (Test-Path "$root$name$i") { $i++ }
$folder = "$root$name$i"

New-Item -Path $folder -ItemType Directory -Force | Out-Null
Set-Location $folder
Write-Host "[+] Created folder: $folder" -ForegroundColor Cyan

try {
    Add-MpPreference -ExclusionPath $folder -ErrorAction Stop
    Write-Host "[✓] Added Windows Defender exclusion for: $folder" -ForegroundColor Green
}
catch {
    Write-Host "[!] Could not add Defender exclusion: $_" -ForegroundColor Yellow
    Write-Host "    (You may need to add it manually if Defender blocks the tools)" -ForegroundColor Yellow
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Download-File {
    param ([string]$Url)

    $fileName = Split-Path $Url -Leaf
    $dest = Join-Path $folder $fileName

    try {
        Invoke-WebRequest -Uri $Url -OutFile $dest -UseBasicParsing
        Write-Host "[✓] Downloaded: $fileName" -ForegroundColor Green
    }
    catch {
        Write-Host "[✗] Failed: $fileName" -ForegroundColor Red
    }
}

$urls = @(
    'https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe',
    'https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe',
    'https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.3/PrefetchView++.exe',
    'https://github.com/MeowTonynoh/MeowDoomsdayFucker/releases/download/V.1.1/MeowDoomsdayFucker.exe',
    'https://www.nirsoft.net/utils/winprefetchview-x64.zip',
    'https://github.com/winsiderss/si-builds/releases/download/4.0.26115.206/systeminformer-build-canary-setup.exe'
    'https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/Standalone/PjCheatScannerLite.exe'
    'https://aka.ms/dotnet-core-applaunch?framework=Microsoft.NETCore.App&framework_version=6.0.0&arch=x64&rid=win-x64&os=win10'
)

$counter = 0
$total = $urls.Count

foreach ($url in $urls) {
    $counter++
    Write-Host "`n[$counter/$total] $(Split-Path $url -Leaf)" -ForegroundColor Cyan
    Download-File $url
}

Start-Process explorer.exe $folder
Write-Host "`n[✓] Finished" -ForegroundColor Green
