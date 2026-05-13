[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
cls

Write-Host ""
Write-Host "#########################################" -ForegroundColor Magenta
Write-Host "#     Yarp's SS Tool Downloader         #" -ForegroundColor White
Write-Host "#########################################" -ForegroundColor Magenta
Write-Host ""

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[~] Elevating privileges, please wait..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList `
        "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
    exit 0
}

$baseDir   = "C:\"
$prefix    = "SS"
$idx       = 1
while (Test-Path "$baseDir$prefix$idx") { $idx++ }
$workDir   = "$baseDir$prefix$idx"

New-Item -Path $workDir -ItemType Directory -Force | Out-Null
Set-Location $workDir
Write-Host "[+] Working directory: $workDir" -ForegroundColor Cyan

try {
    Add-MpPreference -ExclusionPath $workDir -ErrorAction Stop
    Write-Host "[OK] Defender exclusion set for: $workDir" -ForegroundColor Green
}
catch {
    Write-Host "[!!] Defender exclusion failed: $_" -ForegroundColor Yellow
    Write-Host "     Add the exclusion manually if tools get blocked." -ForegroundColor Yellow
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Fetch-File {
    param ([string]$Link)
    $file = Split-Path $Link -Leaf
    $out  = Join-Path $workDir $file
    try {
        Invoke-WebRequest -Uri $Link -OutFile $out -UseBasicParsing
        Write-Host "  [OK] $file" -ForegroundColor Green
    }
    catch {
        Write-Host "  [FAIL] $file" -ForegroundColor Red
    }
}

$downloadList = @(
    'https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe',
    'https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe',
    'https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.3/PrefetchView++.exe',
    'https://github.com/MeowTonynoh/MeowDoomsdayFucker/releases/download/V.1.1/MeowDoomsdayFucker.exe',
    'https://www.nirsoft.net/utils/winprefetchview-x64.zip',
    'https://github.com/winsiderss/si-builds/releases/download/4.0.26115.206/systeminformer-build-canary-setup.exe',
    'https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/Scanner/PjCheatScannerLite.exe',
    'https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/Scanner/cheat_strings.txt',
    'https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/Scanner/RunPjCheatScanner.bat',
    'https://github.com/spokwn/Tool/releases/download/v1.1.3/espouken.exe',
    'https://dl.echo.ac/tool/usb',
    'https://www.voidtools.com/Everything-1.4.1.1029.x64-Setup.exe',
    'https://github.com/Orbdiff/JARParser/releases/download/v1.2/JARParser.exe',
    'https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe',
    'https://dl.echo.ac/tool/journal',
    'https://dl.echo.ac/tool/userassist',
    'https://dl.echo.ac/tool/strings',
    'https://github.com/txvch/Screenshare-Collector/releases/download/tech/Technical.Utilities.exe',
    'https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe',
    'https://www.nirsoft.net/utils/usbdeview-x64.zip'
)

$n   = 0
$tot = $downloadList.Count

foreach ($link in $downloadList) {
    $n++
    Write-Host "`n  --> [$n/$tot] $(Split-Path $link -Leaf)" -ForegroundColor Cyan
    Fetch-File $link
}

Start-Process explorer.exe $workDir
Write-Host "`n[DONE] All tasks complete." -ForegroundColor Green
