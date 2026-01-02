<#
.SYNOPSIS
    Process Scanner by YarpLetapStan
.DESCRIPTION
    Simple scanner for Java processes
.NOTES
    Author: YarpLetapStan
#>

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "================================" -ForegroundColor Magenta
Write-Host "  Process Scanner" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host ""

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

Write-Host "[*] Looking for Java processes..." -ForegroundColor Cyan

$processes = Get-Process javaw, java -ErrorAction SilentlyContinue

if ($processes.Count -eq 0) {
    Write-Host "[X] No Java processes found" -ForegroundColor Red
    pause
    exit
}

Write-Host "[✓] Found $($processes.Count) process(es)" -ForegroundColor Green
Write-Host ""

$foundAnything = $false
$allFindings = @()

foreach ($proc in $processes) {
    Write-Host "--- Process: $($proc.ProcessName) (PID: $($proc.Id)) ---" -ForegroundColor Cyan
    
    $findings = @()
    
    # Check command line
    $cmd = ""
    try {
        $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
    } catch {}
    
    if ($cmd) {
        foreach ($cheat in $cheatStrings) {
            if ($cmd.ToLower().Contains($cheat)) {
                $findings += "Found '$cheat' in command line"
            }
        }
    }
    
    # Check window title
    $title = $proc.MainWindowTitle
    if ($title) {
        foreach ($cheat in $cheatStrings) {
            if ($title.ToLower().Contains($cheat)) {
                $findings += "Found '$cheat' in window title"
            }
        }
    }
    
    # Show results
    if ($findings.Count -eq 0) {
        Write-Host "[✓] Clean" -ForegroundColor Green
    } else {
        Write-Host "[!] Found:" -ForegroundColor Red
        foreach ($finding in $findings) {
            Write-Host "  - $finding" -ForegroundColor Yellow
        }
        $foundAnything = $true
        $allFindings += $findings
    }
    
    Write-Host ""
}

Write-Host "================================" -ForegroundColor Magenta
Write-Host "          RESULTS" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host ""

if (-not $foundAnything) {
    Write-Host "[✓] SCAN CLEAN" -ForegroundColor Green
    Write-Host "No suspicious strings found" -ForegroundColor Green
} else {
    Write-Host "[!] FOUND $($allFindings.Count) SUSPICIOUS ITEM(S)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Processes scanned: $($processes.Count)" -ForegroundColor Gray
Write-Host "Press any key to exit..." -ForegroundColor Gray
pause
