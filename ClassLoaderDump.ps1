# ===============================================================
#  Yarp's SS Tool - Classloader Dump (two-file)
#  1) Finds jcmd (bundled -> installed -> auto-installs Temurin 25)
#  2) Finds javaw PID(s)
#  3) Runs two jcmd commands, each into its own .txt in Downloads
# ===============================================================

$ErrorActionPreference = "Stop"

# Official Adoptium Temurin 25 (JDK, x64, Windows) - jcmd lives in its bin folder
$MsiUrl  = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk_x64_windows_hotspot_25.0.3_9.msi"
$MsiName = "OpenJDK25U-jdk_x64_windows_hotspot_25.0.3_9.msi"

# ---- the two commands, each with the filename suffix it writes to ----
# Note: the flag is "show-classes" (a boolean switch), NOT "show-classes=true".
$jobs = @(
    @{ Cmd = "VM.classloaders show-classes"; Suffix = "classloaders-show-classes" },
    @{ Cmd = "VM.classloaders";              Suffix = "classloaders-folded"       }
)

# ---- banner ----
Write-Host ""
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host "        YARP'S SS - CLASSLOADER DUMP"     -ForegroundColor Cyan
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host ""

# ---- output folder + per-file paths ----
$downloads = Join-Path $env:USERPROFILE "Downloads"
if (-not (Test-Path $downloads)) { $downloads = [Environment]::GetFolderPath("Desktop") }
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

foreach ($j in $jobs) {
    $j.File = Join-Path $downloads ("SS-{0}_{1}.txt" -f $j.Suffix, $stamp)
    "Yarp's SS - $($j.Cmd)`r`nGenerated: $(Get-Date)`r`nMachine: $env:COMPUTERNAME   User: $env:USERNAME`r`n$('=' * 60)" |
        Set-Content -Path $j.File -Encoding UTF8
}

# ---------------------------------------------------------------
# Locate jcmd:  bundled -> javaw bin -> JAVA_HOME -> PATH -> JDK dirs
# ---------------------------------------------------------------
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
        Write-Host "  Need admin to install the JDK - relaunching with elevation..." -ForegroundColor Yellow
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            "-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`""
        )
        exit
    }
    $msiPath = Join-Path $env:TEMP $MsiName
    Write-Host "  Downloading Temurin 25 JDK (~180 MB)..." -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $MsiUrl -OutFile $msiPath -UseBasicParsing
    } catch {
        Write-Host "  Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    Write-Host "  Installing silently..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait | Out-Null
    Remove-Item $msiPath -ErrorAction SilentlyContinue
    return (Find-Jcmd $null)
}

# ---- 1) find java processes ----
$javaProcs = Get-Process -Name javaw, java -ErrorAction SilentlyContinue
if (-not $javaProcs) {
    Write-Host "  No javaw/java process found. Is Minecraft open?" -ForegroundColor Red
    foreach ($j in $jobs) { Add-Content $j.File "`r`nNO JAVA PROCESS FOUND - Minecraft was not running." }
    Read-Host "Press Enter to exit"; exit
}
Write-Host ("  Found {0} java process(es)." -f $javaProcs.Count) -ForegroundColor Green

# ---- 2) resolve jcmd ----
$jcmd = Find-Jcmd $javaProcs[0]
if (-not $jcmd) { Write-Host "  jcmd not found." -ForegroundColor Yellow; $jcmd = Install-Temurin }
if (-not $jcmd) {
    Write-Host "  Could not obtain jcmd. Aborting." -ForegroundColor Red
    foreach ($j in $jobs) { Add-Content $j.File "`r`n[!] jcmd unavailable - no diagnostics collected." }
    Read-Host "Press Enter to exit"; exit
}
Write-Host "  Using jcmd: $jcmd" -ForegroundColor Green

# ---- 3) run each command into its own file, for every process ----
foreach ($j in $jobs) {
    Add-Content $j.File "`r`nUsing jcmd: $jcmd"
    foreach ($proc in $javaProcs) {
        $pidNum = $proc.Id
        $procPath = if ($proc.Path) { $proc.Path } else { "(path unavailable)" }
        Write-Host ("  -> [{0}]  {1} PID {2}" -f $j.Suffix, $proc.ProcessName, $pidNum) -ForegroundColor White

        Add-Content $j.File "`r`n`r`n##############################################"
        Add-Content $j.File "## PROCESS: $($proc.ProcessName)  PID: $pidNum"
        Add-Content $j.File "## EXE: $procPath"
        Add-Content $j.File "## COMMAND: jcmd $pidNum $($j.Cmd)"
        Add-Content $j.File "##############################################"
        try {
            $output = & $jcmd $pidNum $j.Cmd.Split(" ") 2>&1
            if ($output) { Add-Content $j.File ($output -join "`r`n") } else { Add-Content $j.File "(no output)" }
        } catch {
            Add-Content $j.File "[!] ATTACH FAILED: $($_.Exception.Message)"
            Add-Content $j.File "    (A cheat that blocks the Attach API can cause this - worth a closer look.)"
        }
    }
    Add-Content $j.File "`r`n$('=' * 60)`r`nEnd of report."
}

Write-Host ""
Write-Host "  Done. Two reports saved to Downloads:" -ForegroundColor Green
foreach ($j in $jobs) { Write-Host ("   - {0}" -f $j.File) -ForegroundColor Yellow }
Write-Host "`r`n  Send BOTH .txt files to the staff member running your SS." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
