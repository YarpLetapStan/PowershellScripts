<#
.SYNOPSIS
    Java Process Cheat Scanner by YarpLetapStan
.DESCRIPTION
    Scans running Java processes for specific cheat/mod strings in memory and command line.
.NOTES
    Author: YarpLetapStan
    Version: 1.2
    Requires: Administrator for full memory scan
#>

# Set execution policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Combined cheat strings to search for (unique, no duplicates)
$cheatStrings = @(
    # Auto/automated features
    "autocrystal", "autocrystal", "auto crystal", "cw crystal", "autohitcrystal",
    "autoanchor", "auto anchor", "anchortweaks", "anchor macro",
    "autototem", "auto totem", "legittotem", "inventorytotem", "hover totem",
    "autopot", "auto pot", "velocity autopot",
    "autodoublehand", "auto double hand",
    "autoarmor", "auto armor",
    "automace",
    
    # Combat/aim features
    "aimassist", "aim assist",
    "triggerbot", "trigger bot",
    "velocity",
    "shieldbreaker", "shield breaker",
    "axespam", "axe spam",
    
    # Movement/player features
    "jumpreset", "jump reset",
    "pingspoof", "ping spoof",
    "fastplace", "fast place",
    "webmacro", "web macro",
    
    # Visual/esp features
    "hitboxes", "hitbox",
    "playeresp",
    
    # Utility/misc features
    "selfdestruct", "self destruct",
    "aimassist"
)

function Get-JavaProcesses {
    try {
        return Get-Process javaw -ErrorAction SilentlyContinue | Where-Object { $_.Responding -eq $true }
    }
    catch {
        Write-Host "No javaw processes found." -ForegroundColor Yellow
        return @()
    }
}

function Get-ProcessCommandLine {
    param([int]$ProcessId)
    
    try {
        $process = Get-WmiObject Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
        return $process.CommandLine
    }
    catch {
        return $null
    }
}

function Search-ProcessInfo {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$SearchStrings
    )
    
    $found = @()
    
    # Check window title
    if ($Process.MainWindowTitle) {
        $title = $Process.MainWindowTitle.ToLower()
        foreach ($cheat in $SearchStrings) {
            if ($title.Contains($cheat)) {
                $found += "Window: '$cheat' in title"
            }
        }
    }
    
    # Check process name (sometimes cheats rename javaw)
    $procName = $Process.ProcessName.ToLower()
    foreach ($cheat in $SearchStrings) {
        if ($procName.Contains($cheat)) {
            $found += "Process name contains: $cheat"
        }
    }
    
    return $found
}

function Analyze-Process {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$CheatStrings
    )
    
    Write-Host "`n=== Scanning PID $($Process.Id) ===" -ForegroundColor Cyan
    
    $suspicious = @()
    
    # Get command line
    $cmdLine = Get-ProcessCommandLine -ProcessId $Process.Id
    if ($cmdLine) {
        $lowerCmd = $cmdLine.ToLower()
        
        # Display truncated command line
        if ($cmdLine.Length -gt 100) {
            Write-Host "CMD: $($cmdLine.Substring(0, 100))..." -ForegroundColor Gray
        } else {
            Write-Host "CMD: $cmdLine" -ForegroundColor Gray
        }
        
        # Search command line
        foreach ($cheat in $CheatStrings) {
            if ($lowerCmd.Contains($cheat)) {
                $suspicious += "CMD contains: $cheat"
                Write-Host "  [!] Found: $cheat" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "CMD: (Unable to retrieve command line)" -ForegroundColor DarkGray
    }
    
    # Search process info
    $procHits = Search-ProcessInfo -Process $Process -SearchStrings $CheatStrings
    if ($procHits.Count -gt 0) {
        $suspicious += $procHits
        foreach ($hit in $procHits) {
            Write-Host "  [!] $hit" -ForegroundColor Red
        }
    }
    
    # Summary for this process
    if ($suspicious.Count -eq 0) {
        Write-Host "  [✓] Clean" -ForegroundColor Green
        return $false
    } else {
        Write-Host "  [⚠] $($suspicious.Count) red flags" -ForegroundColor Yellow
        return $true
    }
}

# Main execution
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Java Cheat Scanner by YarpLetapStan" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Scanning for $($cheatStrings.Count) cheat indicators..." -ForegroundColor Cyan
Write-Host ""

# Get Java processes
$processes = Get-JavaProcesses
if ($processes.Count -eq 0) {
    Write-Host "No Java processes running." -ForegroundColor Yellow
    Write-Host "Start Minecraft/Java first!" -ForegroundColor Red
    timeout /t 5
    exit
}

Write-Host "Found $($processes.Count) Java process(es)`n" -ForegroundColor Green

# Scan each process
$dirtyCount = 0
foreach ($proc in $processes) {
    $isDirty = Analyze-Process -Process $proc -CheatStrings $cheatStrings
    if ($isDirty) { $dirtyCount++ }
}

# Final report
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "           SCAN COMPLETE" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if ($dirtyCount -eq 0) {
    Write-Host "`n[✓] All $($processes.Count) processes appear clean" -ForegroundColor Green
} else {
    Write-Host "`n[!] $dirtyCount out of $($processes.Count) process(es) show cheat indicators" -ForegroundColor Red
    Write-Host "    Potential cheats detected!" -ForegroundColor Red
}

Write-Host "`nTotal cheat patterns scanned: $($cheatStrings.Count)" -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
