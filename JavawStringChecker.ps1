<#
.SYNOPSIS
    Java Memory Cheat Detector by YarpLetapStan
.DESCRIPTION
    Detects cheat strings in Java process memory
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
Write-Host "  Java Cheat Detector" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[*] Admin privileges: YES" -ForegroundColor Green
Write-Host ""

# EXACT CHEAT STRINGS FROM YOUR HABIBI OUTPUT
$searchStrings = @(
    # From Habibi output - these are the EXACT strings to search for
    "AutoCrystal", "AutoTotem", "AutoAnchor", "AutoArmor",
    "InventoryTotem", "JumpReset", "PingReset", "SelfDestruct",
    "TriggerBot", "Velocity", "AxeSpam", "WebMacro", "FastPlace",
    
    # Additional variations (case-insensitive)
    "autocrystal", "autototem", "autoanchor", "autoarmor",
    "inventorytotem", "jumpreset", "pingreset", "selfdestruct",
    "triggerbot", "velocity", "axespam", "webmacro", "fastplace",
    
    # Module/class patterns (from JAR files)
    "AutoCrystal", "AutoTotem", "AutoAnchor", # Exact class names
    "CrystalAura", "Crystal", "Aura",         # Common cheat names
    "Anchor", "Totem", "Armor"                # Component names
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
$processes = Get-Process javaw -ErrorAction SilentlyContinue | Where-Object { $_.Responding -eq $true }

if ($processes.Count -eq 0) {
    Write-Host "[X] No javaw processes found" -ForegroundColor Red
    Write-Host "    Make sure Minecraft is running" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "[✓] Found $($processes.Count) javaw process(es)" -ForegroundColor Green
Write-Host ""

$foundCheats = @()
$cheatDetails = @()

foreach ($proc in $processes) {
    Write-Host "==========================================" -ForegroundColor DarkCyan
    Write-Host "[SCANNING] javaw (PID: $($proc.Id))" -ForegroundColor Cyan
    
    if ($proc.MainWindowTitle) {
        Write-Host "Client: $($proc.MainWindowTitle)" -ForegroundColor Gray
    }
    
    Write-Host "Memory: $([math]::Round($proc.WorkingSet64/1MB, 1)) MB" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[*] Opening process memory..." -ForegroundColor Yellow
    
    try {
        # Open process for memory reading
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
        
        Write-Host "[*] Scanning loaded modules..." -ForegroundColor Yellow
        
        # Scan each module in the process
        foreach ($module in $proc.Modules) {
            $moduleName = $module.ModuleName.ToLower()
            
            # Skip common Windows system files
            if ($moduleName -match "kernel|ntdll|user32|gdi32|advapi|msvcrt|ole32|shell32") {
                continue
            }
            
            # Skip very small modules
            if ($module.ModuleMemorySize -lt 4096) {
                continue
            }
            
            try {
                # Read module memory
                $bufferSize = [Math]::Min($module.ModuleMemorySize, 10485760) # Max 10MB
                $buffer = New-Object byte[] $bufferSize
                $bytesRead = 0
                
                if ([MemoryScanner]::ReadProcessMemory($hProcess, $module.BaseAddress, $buffer, $bufferSize, [ref] $bytesRead)) {
                    if ($bytesRead -gt 1000) {
                        # Convert to Unicode (Java uses UTF-16)
                        $unicodeText = [System.Text.Encoding]::Unicode.GetString($buffer, 0, $bytesRead)
                        
                        # Search for each cheat string
                        foreach ($cheat in $searchStrings) {
                            if ($unicodeText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                $cheatDetails += [PSCustomObject]@{
                                    CheatName = $cheat
                                    Module = $module.ModuleName
                                    ProcessId = $proc.Id
                                }
                                
                                if (-not ($foundCheats -contains $cheat)) {
                                    $foundCheats += $cheat
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
        Write-Host "[X] Error scanning memory: $_" -ForegroundColor Red
    }
    
    # Show preliminary results for this process
    $processCheats = $cheatDetails | Where-Object { $_.ProcessId -eq $proc.Id } | Select-Object -ExpandProperty CheatName -Unique
    
    if ($processCheats.Count -eq 0) {
        Write-Host "[✓] No cheat strings found" -ForegroundColor Green
    } else {
        Write-Host "[!] Found in this process:" -ForegroundColor Red
        foreach ($cheat in $processCheats) {
            Write-Host "  - $cheat" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "          DETECTION RESULTS" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host ""

if ($foundCheats.Count -eq 0) {
    Write-Host "[✓] NO CHEATS DETECTED" -ForegroundColor Green
    Write-Host ""
    Write-Host "[?] Possible reasons:" -ForegroundColor Yellow
    Write-Host "    - Cheats not loaded into memory yet" -ForegroundColor Gray
    Write-Host "    - Cheats use obfuscated names" -ForegroundColor Gray
    Write-Host "    - Different string encoding" -ForegroundColor Gray
} else {
    Write-Host "[!] CHEATS DETECTED IN MEMORY!" -ForegroundColor Red
    Write-Host "    Found $($foundCheats.Count) cheat type(s)" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "Detected cheats:" -ForegroundColor Yellow
    foreach ($cheat in $foundCheats | Sort-Object) {
        $count = ($cheatDetails | Where-Object { $_.CheatName -eq $cheat }).Count
        Write-Host "  - $cheat ($count instances)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Found in modules:" -ForegroundColor Gray
    $uniqueModules = $cheatDetails | Select-Object -ExpandProperty Module -Unique
    foreach ($module in $uniqueModules) {
        $moduleCheats = $cheatDetails | Where-Object { $_.Module -eq $module } | Select-Object -ExpandProperty CheatName -Unique
        Write-Host "  $module : $($moduleCheats -join ', ')" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "Scan summary:" -ForegroundColor Gray
Write-Host "  Processes scanned: $($processes.Count)" -ForegroundColor Gray
Write-Host "  Cheat patterns: $($searchStrings.Count)" -ForegroundColor Gray
Write-Host "  Scan type: Memory string search" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
pause
