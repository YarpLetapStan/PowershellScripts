<#
.SYNOPSIS
    Java Process String Scanner by YarpLetapStan
.DESCRIPTION
    Scans running Java processes for cheat strings (like Habibi script but for processes)
.NOTES
    Author: YarpLetapStan
    Version: 1.0
#>

# Set execution policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Cheat strings to search for
$cheatStrings = @(
    "autocrystal", "auto crystal", "cw crystal", "autohitcrystal",
    "autoanchor", "auto anchor", "anchortweaks", "anchor macro",
    "autototem", "auto totem", "legittotem", "inventorytotem", "hover totem",
    "autopot", "auto pot", "velocity autopot",
    "autodoublehand", "auto double hand",
    "autoarmor", "auto armor",
    "automace",
    "aimassist", "aim assist",
    "triggerbot", "trigger bot",
    "velocity",
    "shieldbreaker", "shield breaker",
    "axespam", "axe spam",
    "jumpreset", "jump reset",
    "pingspoof", "ping spoof",
    "fastplace", "fast place",
    "webmacro", "web macro",
    "hitboxes", "hitbox",
    "playeresp",
    "selfdestruct", "self destruct"
)

# Colors for output
$Red = "Red"
$Yellow = "Yellow"
$Green = "Green"
$Cyan = "Cyan"
$Gray = "Gray"

function Get-JavaProcesses {
    Write-Host "[*] Looking for Java processes..." -ForegroundColor $Cyan
    try {
        $processes = Get-Process javaw, java -ErrorAction SilentlyContinue | Where-Object {
            $_.Responding -eq $true
        }
        return $processes
    }
    catch {
        Write-Host "[X] Error finding processes: $_" -ForegroundColor $Red
        return @()
    }
}

function Get-ProcessStrings {
    param(
        [System.Diagnostics.Process]$Process
    )
    
    $foundStrings = @()
    
    try {
        # 1. Check command line
        $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($Process.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdLine) {
            foreach ($cheat in $cheatStrings) {
                if ($cmdLine -match $cheat) {
                    $foundStrings += [PSCustomObject]@{
                        Type = "Command Line"
                        Cheat = $cheat
                        Context = $cmdLine
                    }
                }
            }
        }
        
        # 2. Check window title
        $windowTitle = $Process.MainWindowTitle
        if ($windowTitle) {
            foreach ($cheat in $cheatStrings) {
                if ($windowTitle -match $cheat) {
                    $foundStrings += [PSCustomObject]@{
                        Type = "Window Title"
                        Cheat = $cheat
                        Context = $windowTitle
                    }
                }
            }
        }
        
        # 3. Check process name
        $procName = $Process.ProcessName
        foreach ($cheat in $cheatStrings) {
            if ($procName -match $cheat) {
                $foundStrings += [PSCustomObject]@{
                    Type = "Process Name"
                    Cheat = $cheat
                    Context = $procName
                }
            }
        }
        
    }
    catch {
        Write-Host "  [X] Error scanning process: $_" -ForegroundColor $Red
    }
    
    return $foundStrings
}

# Main execution
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Java Process String Scanner" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[*] Scanning for $($cheatStrings.Count) cheat strings..." -ForegroundColor $Cyan
Write-Host ""

# Get Java processes
$processes = Get-JavaProcesses

if ($processes.Count -eq 0) {
    Write-Host "[X] No Java processes found!" -ForegroundColor $Red
    Write-Host "    Make sure Minecraft/Java is running" -ForegroundColor $Yellow
    timeout /t 5
    exit
}

Write-Host "[✓] Found $($processes.Count) Java process(es)" -ForegroundColor $Green
Write-Host ""

$totalDetections = 0
$allDetections = @()

foreach ($proc in $processes) {
    Write-Host "=== Scanning Process: $($proc.ProcessName) (PID: $($proc.Id)) ===" -ForegroundColor $Cyan
    
    if ($proc.MainWindowTitle) {
        Write-Host "  Window: $($proc.MainWindowTitle)" -ForegroundColor $Gray
    }
    
    # Get cheat strings from this process
    $detections = Get-ProcessStrings -Process $proc
    
    if ($detections.Count -eq 0) {
        Write-Host "  [✓] No cheat strings found" -ForegroundColor $Green
    }
    else {
        Write-Host "  [X] Found $($detections.Count) cheat string(s):" -ForegroundColor $Red
        foreach ($detect in $detections) {
            Write-Host "      - $($detect.Type): $($detect.Cheat)" -ForegroundColor $Red
            # Show context if it's not too long
            if ($detect.Context.Length -lt 150) {
                Write-Host "        Context: $($detect.Context)" -ForegroundColor $Gray
            }
        }
        $totalDetections += $detections.Count
        $allDetections += $detections
    }
    
    Write-Host ""
}

# Final report
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "           SCAN RESULTS" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

if ($totalDetections -eq 0) {
    Write-Host "[✓] SCAN CLEAN" -ForegroundColor $Green
    Write-Host "    No cheat strings found in any Java process" -ForegroundColor $Green
}
else {
    Write-Host "[X] CHEAT STRINGS DETECTED!" -ForegroundColor $Red
    Write-Host "    Found $totalDetections cheat string(s) across $($processes.Count) process(es)" -ForegroundColor $Red
    Write-Host ""
    
    # Group by process
    $processGroups = $allDetections | Group-Object { $_.Context }
    
    foreach ($group in $processGroups) {
        Write-Host "  In: $($group.Name)" -ForegroundColor $Yellow
        foreach ($detect in $group.Group) {
            Write-Host "    - $($detect.Type): $($detect.Cheat)" -ForegroundColor $Red
        }
        Write-Host ""
    }
}

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Processes scanned: $($processes.Count)" -ForegroundColor $Cyan
Write-Host "Cheat patterns: $($cheatStrings.Count)" -ForegroundColor $Cyan
Write-Host ""

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
