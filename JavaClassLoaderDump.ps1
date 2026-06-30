# ===============================================================
#  Yarp's SS Tool - Classloader Dump (auto-JDK)
#  1) Finds jcmd (bundled -> installed -> auto-installs Temurin 25)
#  2) Finds javaw PID(s)
#  3) Runs jcmd diagnostics
#  4) Saves a report to Downloads
# ===============================================================

$ErrorActionPreference = "Stop"

# Official Adoptium Temurin 25 (JDK, x64, Windows) - jcmd lives in its bin folder
$MsiUrl  = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk_x64_windows_hotspot_25.0.3_9.msi"
$MsiName = "OpenJDK25U-jdk_x64_windows_hotspot_25.0.3_9.msi"

# ---- banner ----
Write-Host ""
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host "        YARP'S SS - CLASSLOADER DUMP"     -ForegroundColor Cyan
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host ""

# ---- output file ----
$downloads = Join-Path $env:USERPROFILE "Downloads"
if (-not (Test-Path $downloads)) { $downloads = [Environment]::GetFolderPath("Desktop") }
$stamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outFile = Join-Path $downloads "SS-ClassloaderDump_$stamp.txt"
function Write-Report($text) { Add-Content -Path $outFile -Value $text -Encoding UTF8 }

Write-Report "Yarp's SS - Classloader Dump"
Write-Report "Generated: $(Get-Date)"
Write-Report "Machine:   $env:COMPUTERNAME   User: $env:USERNAME"
Write-Report ("=" * 60)

# ---------------------------------------------------------------
# Locate jcmd:  bundled (next to script) -> javaw bin -> JAVA_HOME
#               -> PATH -> known JDK dirs
# ---------------------------------------------------------------
function Find-Jcmd($proc) {
    # 0) bundled alongside the script (portable, no install)
    if ($PSScriptRoot) {
        $c = Join-Path $PSScriptRoot "jcmd.exe"
        if (Test-Path $c) { return $c }
    }
    # 1) same bin as the running javaw (only works if it's a JDK)
    try {
        if ($proc -and $proc.Path) {
            $c = Join-Path (Split-Path $proc.Path) "jcmd.exe"
            if (Test-Path $c) { return $c }
        }
    } catch {}
    # 2) JAVA_HOME
    if ($env:JAVA_HOME) {
        $c = Join-Path $env:JAVA_HOME "bin\jcmd.exe"
        if (Test-Path $c) { return $c }
    }
    # 3) PATH
    $onPath = Get-Command jcmd.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    # 4) known JDK install roots
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

# ---------------------------------------------------------------
# Self-elevate (needed only for the silent MSI install)
# ---------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------
# Install Temurin 25 if jcmd is nowhere to be found
# ---------------------------------------------------------------
function Install-Temurin {
    if (-not (Test-Admin)) {
        Write-Host "  Need admin to install the JDK - relaunching with elevation..." -ForegroundColor Yellow
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            "-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`""
        )
        exit
    }

    $msiPath = Join-Path $env:TEMP $MsiName
    Write-Host "  Downloading Temurin 25 JDK (~180 MB)... this can take a minute." -ForegroundColor Yellow
    Write-Report "`n[*] Downloading JDK from: $MsiUrl"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $MsiUrl -OutFile $msiPath -UseBasicParsing
    } catch {
        Write-Host "  Download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Report "[!] JDK download failed: $($_.Exception.Message)"
        return $null
    }

    Write-Host "  Installing silently..." -ForegroundColor Yellow
    Write-Report "[*] Installing $MsiName silently"
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Write-Report "[!] msiexec returned exit code $($p.ExitCode)"
    }
    Remove-Item $msiPath -ErrorAction SilentlyContinue

    return (Find-Jcmd $null)
}

# ---------------------------------------------------------------
# 1) find java processes
# ---------------------------------------------------------------
$javaProcs = Get-Process -Name javaw, java -ErrorAction SilentlyContinue
if (-not $javaProcs) {
    Write-Host "  No javaw/java process found. Is Minecraft open?" -ForegroundColor Red
    Write-Report "`nNO JAVA PROCESS FOUND - Minecraft was not running."
    Write-Host "`n  Report saved to: $outFile" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"; exit
}
Write-Host ("  Found {0} java process(es)." -f $javaProcs.Count) -ForegroundColor Green

# ---------------------------------------------------------------
# 2) resolve jcmd (install if necessary)
# ---------------------------------------------------------------
$jcmd = Find-Jcmd $javaProcs[0]
if (-not $jcmd) {
    Write-Host "  jcmd not found on this machine." -ForegroundColor Yellow
    $jcmd = Install-Temurin
}
if (-not $jcmd) {
    Write-Host "  Could not obtain jcmd. Aborting." -ForegroundColor Red
    Write-Report "`n[!] jcmd unavailable - no diagnostics collected."
    Read-Host "Press Enter to exit"; exit
}
Write-Host "  Using jcmd: $jcmd" -ForegroundColor Green
Write-Report "`nUsing jcmd: $jcmd"

# ---------------------------------------------------------------
# 3) run diagnostics per process
# ---------------------------------------------------------------
$commands = @(
    "VM.classloaders show-classes",
    "VM.classloader_stats",
    "GC.class_histogram",
    "VM.command_line",
    "VM.system_properties"
)

foreach ($proc in $javaProcs) {
    $pidNum   = $proc.Id
    $procPath = if ($proc.Path) { $proc.Path } else { "(path unavailable)" }

    Write-Host ("  -> {0}  PID {1}" -f $proc.ProcessName, $pidNum) -ForegroundColor White
    Write-Report "`n`n##############################################"
    Write-Report "## PROCESS: $($proc.ProcessName)  PID: $pidNum"
    Write-Report "## EXE: $procPath"
    Write-Report ("## Started: {0}" -f $(try { $proc.StartTime } catch { "unknown" }))
    Write-Report "##############################################"

    foreach ($cmd in $commands) {
        Write-Report "`n----- jcmd $pidNum $cmd -----"
        try {
            $output = & $jcmd $pidNum $cmd.Split(" ") 2>&1
            if ($output) { Write-Report ($output -join "`n") } else { Write-Report "(no output)" }
        } catch {
            Write-Report "[!] ATTACH FAILED: $($_.Exception.Message)"
            Write-Report "    (A cheat that blocks the Attach API can cause this - worth a closer look.)"
        }
    }
}

Write-Report "`n`n$('=' * 60)`nEnd of report."
Write-Host ""
Write-Host "  Done. Report saved to:" -ForegroundColor Green
Write-Host "  $outFile" -ForegroundColor Yellow
Write-Host "`n  Send that .txt file to the staff member running your SS." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
