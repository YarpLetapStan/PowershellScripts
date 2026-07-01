
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
Clear-Host

Write-Host "Made by YarpLetapStan`nDm YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan
Write-Host @"
██╗   ██╗ █████╗ ██████╗ ██████╗ ██╗     ███████╗████████╗ █████╗ ██████╗ ███████╗████████╗ █████╗ ███╗   ██╗ ╗███████╗
╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗██║     ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔══██╗████╗  ██║╔╝██╔════╝
 ╚████╔╝ ███████║██████╔╝██████╔╝██║     █████╗     ██║   ███████║██████╔╝███████╗   ██║   ███████║██╔██╗ ██║  ███████╗
  ╚██╔╝  ██╔══██║██╔══██╗██╔═══╝ ██║     ██╔══╝     ██║   ██╔══██║██╔═══╝ ╚════██║   ██║   ██╔══██║██║╚██╗██║  ╚════██║
   ██║   ██║  ██║██║  ██║██║     ███████╗███████╗   ██║   ██║  ██║██║     ███████║   ██║   ██║  ██║██║ ╚████║  ███████║
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝
"@ -ForegroundColor Blue

Write-Host @"
 ██████╗██╗      █████╗ ███████╗███████╗██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗
██╔════╝██║     ██╔══██╗██╔════╝██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
██║     ██║     ███████║███████╗███████╗██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝
██║     ██║     ██╔══██║╚════██║╚════██║██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗
╚██████╗███████╗██║  ██║███████║███████║███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║
 ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
"@ -ForegroundColor Blue

Write-Host @"
██████╗ ██╗   ██╗███╗   ███╗██████╗
██╔══██╗██║   ██║████╗ ████║██╔══██╗
██║  ██║██║   ██║██╔████╔██║██████╔╝
██║  ██║██║   ██║██║╚██╔╝██║██╔═══╝
██████╔╝╚██████╔╝██║ ╚═╝ ██║██║
╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝
"@ -ForegroundColor Blue

$lineWidth = 100
Write-Host "YarpLetapStan's Classloader Dump v1.0".PadLeft(($lineWidth + 37) / 2) -ForegroundColor Cyan
Write-Host ("━" * $lineWidth) -ForegroundColor Cyan
Write-Host ""

$MsiUrl  = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk_x64_windows_hotspot_25.0.3_9.msi"
$MsiName = "OpenJDK25U-jdk_x64_windows_hotspot_25.0.3_9.msi"

$jobs = @(
    @{ Cmd = "VM.classloaders show-classes"; Short = "Classloaders-Full"; Title = "VM.classloaders show-classes" },
    @{ Cmd = "VM.classloaders";              Short = "Classloaders-Tree"; Title = "VM.classloaders" }
)

$downloads = Join-Path $env:USERPROFILE "Downloads"
if (-not (Test-Path $downloads)) { $downloads = [Environment]::GetFolderPath("Desktop") }
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

foreach ($j in $jobs) {
    $j.File = Join-Path $downloads ("{0}_{1}.txt" -f $j.Short, $stamp)
    @(
        "YarpLetapStan's Classloader Dump"
        "Command : jcmd <pid> $($j.Title)"
        "Date    : $(Get-Date)"
        "Machine : $env:COMPUTERNAME   User: $env:USERNAME"
        ("━" * 60)
    ) -join "`r`n" | Set-Content -Path $j.File -Encoding UTF8
}

function Find-Jcmd($proc) {
    if ($PSScriptRoot) {
        $c = Join-Path $PSScriptRoot "jcmd.exe"
        if (Test-Path $c) { return $c }
    }
    try {
        if ($proc -and $proc.Path) {
            $c = Join-Path (Split-Path $proc.Path) "jcmd.exe"
            if (Test-Path $c) { return $c }
        }
    } catch {}
    if ($env:JAVA_HOME) {
        $c = Join-Path $env:JAVA_HOME "bin\jcmd.exe"
        if (Test-Path $c) { return $c }
    }
    $onPath = Get-Command jcmd.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $roots = @(
        "C:\Program Files\Eclipse Adoptium",
        "C:\Program Files\Java",
        "C:\Program Files\Microsoft",
        "C:\Program Files\Zulu",
        "C:\Program Files\Amazon Corretto",
        "$env:LOCALAPPDATA\Programs\Java"
    )
    foreach ($r in $roots) {
        $hit = Get-ChildItem -Path $r -Filter jcmd.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Temurin {
    if (-not (Test-Admin)) {
        Write-Host "  [i] Need admin to install the JDK - relaunching elevated..." -ForegroundColor Yellow
        Start-Process powershell.exe -Verb RunAs -ArgumentList @("-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
        exit
    }
    $msiPath = Join-Path $env:TEMP $MsiName
    Write-Host "  [i] Downloading Temurin 25 JDK (~180 MB)..." -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $MsiUrl -OutFile $msiPath -UseBasicParsing
    } catch {
        Write-Host "  [!] Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    Write-Host "  [i] Installing silently..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait | Out-Null
    Remove-Item $msiPath -ErrorAction SilentlyContinue
    return (Find-Jcmd $null)
}

$sep = "━" * 111
Write-Host $sep -ForegroundColor Yellow
Write-Host "MINECRAFT PROCESS SCANNER" -ForegroundColor Yellow
Write-Host $sep -ForegroundColor Yellow
Write-Host ""

$javaProcs = Get-Process -Name javaw, java -ErrorAction SilentlyContinue
if (-not $javaProcs) {
    Write-Host "  [!] No javaw/java process found" -ForegroundColor Red
    Write-Host "  [i] Make sure Minecraft is running`n" -ForegroundColor Yellow
    foreach ($j in $jobs) { Add-Content $j.File "`r`nNO JAVA PROCESS FOUND - Minecraft was not running." }
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); exit
}

Write-Host "  [i] Found $($javaProcs.Count) Java process(es)" -ForegroundColor White
foreach ($p in $javaProcs) {
    try {
        $up = (Get-Date) - $p.StartTime
        Write-Host "  ┌─ $($p.Name) PID $($p.Id)" -ForegroundColor Green
        Write-Host "  └─ Uptime: $($up.Hours)h $($up.Minutes)m $($up.Seconds)s" -ForegroundColor DarkGreen
    } catch {}
}
Write-Host ""

$jcmd = Find-Jcmd $javaProcs[0]
if (-not $jcmd) { Write-Host "  [i] jcmd not found locally" -ForegroundColor Yellow; $jcmd = Install-Temurin }
if (-not $jcmd) {
    Write-Host "  [!] Could not obtain jcmd. Aborting." -ForegroundColor Red
    foreach ($j in $jobs) { Add-Content $j.File "`r`n[!] jcmd unavailable - no diagnostics collected." }
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); exit
}
Write-Host "  [✓] Using jcmd: $jcmd`n" -ForegroundColor Green

Write-Host $sep -ForegroundColor Cyan
Write-Host "RUNNING CLASSLOADER DUMPS" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
Write-Host ""

foreach ($j in $jobs) {
    Add-Content $j.File "`r`nUsing jcmd: $jcmd"
    Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  ║ " -NoNewline -ForegroundColor Cyan; Write-Host "$($j.Title)" -ForegroundColor White
    Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor Cyan

    foreach ($proc in $javaProcs) {
        $pidNum   = $proc.Id
        $procPath = if ($proc.Path) { $proc.Path } else { "(path unavailable)" }

        Add-Content $j.File "`r`n$('━' * 60)"
        Add-Content $j.File "PROCESS : $($proc.ProcessName)  PID: $pidNum"
        Add-Content $j.File "EXE     : $procPath"
        Add-Content $j.File "COMMAND : jcmd $pidNum $($j.Cmd)"
        Add-Content $j.File ("━" * 60)
        try {
            $output = & $jcmd $pidNum $j.Cmd.Split(" ") 2>&1
            if ($output) { Add-Content $j.File ($output -join "`r`n") } else { Add-Content $j.File "(no output)" }
            Write-Host "  ║ " -NoNewline -ForegroundColor Cyan; Write-Host "[✓] PID $pidNum dumped" -ForegroundColor Green
        } catch {
            Add-Content $j.File "[!] ATTACH FAILED: $($_.Exception.Message)"
            Add-Content $j.File "    (A cheat that blocks the Attach API can cause this - worth a closer look.)"
            Write-Host "  ║ " -NoNewline -ForegroundColor Cyan; Write-Host "[!] PID $pidNum attach failed" -ForegroundColor Red
        }
    }
    Add-Content $j.File "`r`n$('━' * 60)`r`nEnd of report."
    Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host "  DUMP COMPLETE" -ForegroundColor Cyan
Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host ""
foreach ($j in $jobs) {
    Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Saved  " -NoNewline -ForegroundColor White; Write-Host "$($j.Short).txt" -ForegroundColor Green
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Path   " -NoNewline -ForegroundColor White; Write-Host "$($j.File)" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}
Write-Host "  [i] Send BOTH .txt files to the staff member running your SS.`n" -ForegroundColor Cyan

Write-Host "Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
