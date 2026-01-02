<#
.SYNOPSIS
    Process String Scanner by YarpLetapStan
.DESCRIPTION
    Simple memory string scanner for Java processes
.NOTES
    Author: YarpLetapStan
    Version: 1.1
#>

# Set execution policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] Run as Administrator for best results" -ForegroundColor Yellow
}

# Cheat strings to search for (not shown to user)
$cheatStrings = @(
    "autocrystal", "auto crystal", "cw crystal", "autohitcrystal",
    "autoanchor", "auto anchor", "anchortweaks", "anchor macro",
    "autototem", "auto totem", "legittotem", "inventorytotem", "hover totem",
    "autopot", "auto pot", "velocity",
    "autodoublehand", "auto double hand",
    "autoarmor", "auto armor",
    "automace",
    "aimassist", "aim assist",
    "triggerbot", "trigger bot",
    "shieldbreaker", "shield breaker",
    "axespam", "axe spam",
    "jumpreset", "jump reset",
    "pingspoof", "ping spoof",
    "fastplace", "fast place",
    "webmacro", "web macro",
    "selfdestruct", "self destruct"
)

# Simple banner
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Process Scanner" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# Get Java processes
Write-Host "[*] Finding Java processes..." -ForegroundColor Cyan
$processes = Get-Process javaw, java -ErrorAction SilentlyContinue | Where-Object { $_.Responding -eq $true }

if ($processes.Count -eq 0) {
    Write-Host "[X] No Java processes found" -ForegroundColor Red
    timeout /t 3
    exit
}

Write-Host "[✓] Found $($processes.Count) process(es)" -ForegroundColor Green
Write-Host ""

$foundCheats = @()
$processCount = 0

foreach ($proc in $processes) {
    $processCount++
    Write-Host "--- Scanning Process $processCount ---" -ForegroundColor Cyan
    Write-Host "PID: $($proc.Id)" -ForegroundColor Gray
    Write-Host "Name: $($proc.ProcessName)" -ForegroundColor Gray
    
    if ($proc.MainWindowTitle) {
        Write-Host "Window: $($proc.MainWindowTitle)" -ForegroundColor Gray
    }
    
    $processCheats = @()
    
    # Simple checks (like Habibi)
    
    # 1. Check command line
    try {
        $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdLine) {
            foreach ($cheat in $cheatStrings) {
                if ($cmdLine -match $cheat) {
                    $processCheats += "$cheat (command line)"
                }
            }
        }
    } catch {}
    
    # 2. Check window title
    if ($proc.MainWindowTitle) {
        foreach ($cheat in $cheatStrings) {
            if ($proc.MainWindowTitle -match $cheat) {
                $processCheats += "$cheat (window title)"
            }
        }
    }
    
    # 3. Check modules (simple memory check)
    try {
        foreach ($module in $proc.Modules) {
            $moduleName = $module.ModuleName
            foreach ($cheat in $cheatStrings) {
                if ($moduleName -match $cheat) {
                    $processCheats += "$cheat (module: $moduleName)"
                }
            }
        }
    } catch {}
    
    # Show results for this process
    if ($processCheats.Count -eq 0) {
        Write-Host "[✓] Clean" -ForegroundColor Green
    } else {
        Write-Host "[!] Found $($processCheats.Count) string(s)" -ForegroundColor Red
        foreach ($cheat in $processCheats) {
            Write-Host "  - $cheat" -ForegroundColor Yellow
        }
        $foundCheats += $processCheats
    }
    
    Write-Host ""
}

# Final summary (like Habibi)
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "           SCAN RESULTS" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

if ($foundCheats.Count -eq 0) {
    Write-Host "[✓] SCAN CLEAN" -ForegroundColor Green
    Write-Host "No suspicious strings found" -ForegroundColor Green
} else {
    Write-Host "[!] SUSPICIOUS STRINGS FOUND" -ForegroundColor Red
    Write-Host "Total findings: $($foundCheats.Count)" -ForegroundColor Red
    
    # Group by cheat type
    $grouped = $foundCheats | Group-Object { ($_ -split ' ')[0] }
    
    foreach ($group in $grouped) {
        $count = $group.Count
        $cheatName = $group.Name
        Write-Host "  $cheatName: $count instance(s)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Processes scanned: $($processes.Count)" -ForegroundColor Gray
Write-Host "Press any key to exit..." -ForegroundColor Gray
[Console]::ReadKey($true) | Out-Null
