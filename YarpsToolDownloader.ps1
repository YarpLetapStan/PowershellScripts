[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
cls
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host @"
██╗   ██╗ █████╗ ██████╗ ██████╗ ███████╗    ███████╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     
╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗██╔════╝    ██╔════╝██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     
 ╚████╔╝ ███████║██████╔╝██████╔╝███████╗    ███████╗███████╗       ██║   ██║   ██║██║   ██║██║     
  ╚██╔╝  ██╔══██║██╔══██╗██╔═══╝ ╚════██║    ╚════██║╚════██║       ██║   ██║   ██║██║   ██║██║     
   ██║   ██║  ██║██║  ██║██║     ███████║    ███████║███████║       ██║   ╚██████╔╝╚██████╔╝███████╗
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝    ╚══════╝╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝

██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗ 
██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝
██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗
██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║
╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
"@ -ForegroundColor Blue

$lineWidth = 100
Write-Host "Yarp's SS Tool Downloader".PadLeft(($lineWidth + 24) / 2) -ForegroundColor Cyan
Write-Host ("━" * $lineWidth) -ForegroundColor Cyan
Write-Host ""

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!!] Please run this script as Administrator." -ForegroundColor Red
    Write-Host "     Right-click PowerShell and select 'Run as administrator'." -ForegroundColor Yellow
    Write-Host ""
    pause
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
    param ([string]$Link, [string]$Name = "")
    $file = if ($Name) { $Name } else { Split-Path $Link -Leaf }
    $out  = Join-Path $workDir $file
    try {
        Invoke-WebRequest -Uri $Link -OutFile $out -UseBasicParsing `
            -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        Write-Host "  [Downloaded] $file" -ForegroundColor Green
    }
    catch {
        Write-Host "  [Failed] $file - $_" -ForegroundColor Red
    }
}

$downloadList = @(
    # Priority tools first
    @{ Link = 'https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe' },
    @{ Link = 'https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.3/PrefetchView++.exe' },
    @{ Link = 'https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/1.1/PjCheatScannerLite.exe' },
    @{ Link = 'https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/1.1/cheat_strings.txt' },
    @{ Link = 'https://github.com/winsiderss/si-builds/releases/download/4.0.26133.456/systeminformer-build-canary-setup.exe' },
    @{ Link = 'https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe' },
    @{ Link = 'https://github.com/MeowTonynoh/MeowDoomsdayFucker/releases/download/V.1.1/MeowDoomsdayFucker.exe' },
    @{ Link = 'https://www.nirsoft.net/utils/winprefetchview-x64.zip' },
    @{ Link = 'https://github.com/spokwn/Tool/releases/download/v1.1.3/espouken.exe' },
    @{ Link = 'https://dl.echo.ac/tool/usb';        Name = 'echo-usb.exe' },
    @{ Link = 'https://www.voidtools.com/Everything-1.4.1.1029.x64-Setup.exe' },
    @{ Link = 'https://github.com/Orbdiff/JARParser/releases/download/v1.2/JARParser.exe' },
    @{ Link = 'https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe' },
    @{ Link = 'https://dl.echo.ac/tool/journal';    Name = 'echo-journal.exe' },
    @{ Link = 'https://dl.echo.ac/tool/userassist'; Name = 'echo-userassist.exe' },
    @{ Link = 'https://dl.echo.ac/tool/strings';    Name = 'echo-strings.exe' },
    @{ Link = 'https://github.com/txvch/Screenshare-Collector/releases/download/tech/Technical.Utilities.exe' },
    @{ Link = 'https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe' },
    @{ Link = 'https://www.nirsoft.net/utils/usbdeview-x64.zip' }
)

$n   = 0
$tot = $downloadList.Count
foreach ($item in $downloadList) {
    $n++
    $displayName = if ($item.Name) { $item.Name } else { Split-Path $item.Link -Leaf }
    Write-Host "`n  --> [$n/$tot] $displayName" -ForegroundColor Cyan
    Fetch-File -Link $item.Link -Name $item.Name
}

Start-Process explorer.exe $workDir
Write-Host "`n[DONE] All tasks complete." -ForegroundColor Green
