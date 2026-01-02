<#
.SYNOPSIS
    Memory String Scanner by YarpLetapStan
.DESCRIPTION
    Scans Java process memory for strings like System Informer
.NOTES
    Author: YarpLetapStan
    Requires: Administrator privileges
#>

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# MUST RUN AS ADMINISTRATOR
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "  ERROR: Run as Administrator!" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "1. Right-click PowerShell" -ForegroundColor Yellow
    Write-Host "2. Select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host "3. Run the script again" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit
}

Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "  Memory String Scanner" -ForegroundColor Magenta
Write-Host "  (System Informer Style)" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[*] Admin privileges: YES" -ForegroundColor Green
Write-Host ""

# Cheat strings to search for
$searchStrings = @(
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

# Add memory scanning capabilities
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class MemoryScanner {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    
    [DllImport("kernel32.dll")]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out int lpNumberOfBytesRead);
    
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);
    
    public const int PROCESS_VM_READ = 0x0010;
    public const int PROCESS_QUERY_INFORMATION = 0x0400;
}
"@

Write-Host "[*] Looking for Java processes..." -ForegroundColor Cyan
$processes = Get-Process javaw, java -ErrorAction SilentlyContinue | Where-Object { $_.Responding -eq $true }

if ($processes.Count -eq 0) {
    Write-Host "[X] No Java processes found" -ForegroundColor Red
    pause
    exit
}

Write-Host "[✓] Found $($processes.Count) Java process(es)" -ForegroundColor Green
Write-Host ""

$foundAnything = $false

foreach ($proc in $processes) {
    Write-Host "==========================================" -ForegroundColor DarkCyan
    Write-Host "[SCANNING] $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Cyan
    
    if ($proc.MainWindowTitle) {
        Write-Host "Title: $($proc.MainWindowTitle)" -ForegroundColor Gray
    }
    
    Write-Host "Memory: $($proc.WorkingSet64/1MB) MB" -ForegroundColor Gray
    Write-Host ""
    
    $processFindings = @()
    
    try {
        # Open process for memory reading
        Write-Host "[*] Opening process for memory access..." -ForegroundColor Yellow
        $hProcess = [MemoryScanner]::OpenProcess(
            [MemoryScanner]::PROCESS_VM_READ -bor [MemoryScanner]::PROCESS_QUERY_INFORMATION,
            $false,
            $proc.Id
        )
        
        if ($hProcess -eq [IntPtr]::Zero) {
            Write-Host "[X] Cannot access process memory" -ForegroundColor Red
            Write-Host ""
            continue
        }
        
        Write-Host "[*] Scanning memory for strings..." -ForegroundColor Yellow
        Write-Host "    This may take a moment..." -ForegroundColor Yellow
        
        # Get process modules to scan
        foreach ($module in $proc.Modules) {
            try {
                $moduleSize = $module.ModuleMemorySize
                if ($moduleSize -gt 0 -and $moduleSize -lt 100000000) { # Less than 100MB
                    # Read module memory
                    $buffer = New-Object byte[] $moduleSize
                    $bytesRead = 0
                    
                    if ([MemoryScanner]::ReadProcessMemory($hProcess, $module.BaseAddress, $buffer, $moduleSize, [ref] $bytesRead)) {
                        if ($bytesRead -gt 100) {
                            # Convert to text and search
                            $asciiText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, [Math]::Min($bytesRead, 1000000))
                            $unicodeText = [System.Text.Encoding]::Unicode.GetString($buffer, 0, [Math]::Min($bytesRead, 1000000))
                            
                            foreach ($search in $searchStrings) {
                                # Search in ASCII
                                if ($asciiText.IndexOf($search, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                    $processFindings += "[Module: $($module.ModuleName)] Found: $search"
                                }
                                # Search in Unicode (UTF-16)
                                elseif ($unicodeText.IndexOf($search, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                    $processFindings += "[Module: $($module.ModuleName)] Found: $search (Unicode)"
                                }
                            }
                        }
                    }
                }
            } catch {
                # Skip modules that can't be read
            }
        }
        
        # Close process handle
        [MemoryScanner]::CloseHandle($hProcess)
        
    } catch {
        Write-Host "[X] Error: $_" -ForegroundColor Red
    }
    
    # Show results for this process
    if ($processFindings.Count -eq 0) {
        Write-Host "[✓] No cheat strings found in memory" -ForegroundColor Green
    } else {
        Write-Host "[!] FOUND $($processFindings.Count) STRING(S) IN MEMORY:" -ForegroundColor Red
        foreach ($finding in $processFindings | Select-Object -Unique) {
            Write-Host "  - $finding" -ForegroundColor Yellow
            $foundAnything = $true
        }
    }
    
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "          SCAN COMPLETE" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host ""

if ($foundAnything) {
    Write-Host "[!] CHEAT STRINGS FOUND IN MEMORY!" -ForegroundColor Red
    Write-Host "    Memory scan successful" -ForegroundColor Red
} else {
    Write-Host "[✓] No cheat strings found in memory" -ForegroundColor Green
    Write-Host ""
    Write-Host "[?] If you see strings in System Informer but not here:" -ForegroundColor Yellow
    Write-Host "    - Try searching for different string variations" -ForegroundColor Gray
    Write-Host "    - Cheats might use different encoding" -ForegroundColor Gray
    Write-Host "    - Try manual search in System Informer to verify" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Processes scanned: $($processes.Count)" -ForegroundColor Gray
Write-Host "String patterns: $($searchStrings.Count)" -ForegroundColor Gray
Write-Host "Scan type: Memory module scanning (like System Informer)" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
pause
