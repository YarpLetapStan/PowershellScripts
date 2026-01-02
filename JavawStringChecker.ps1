<#
.SYNOPSIS
    Memory Scanner by YarpLetapStan
.DESCRIPTION
    Scans Java process memory for cheat strings
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
Write-Host "  Java Memory Scanner" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[*] Admin privileges: YES" -ForegroundColor Green
Write-Host ""

# Cheat strings to search for with more variations
$searchStrings = @(
    "autocrystal", "AutoCrystal", "AUTOCRYSTAL", "auto crystal", "Auto Crystal",
    "cw crystal", "CWcrystal", "autohitcrystal", "AutoHitCrystal",
    "autoanchor", "AutoAnchor", "auto anchor", "Auto Anchor",
    "anchortweaks", "AnchorTweaks", "anchor macro", "Anchor Macro",
    "autototem", "AutoTotem", "auto totem", "Auto Totem",
    "legittotem", "LegitTotem", "inventorytotem", "InventoryTotem",
    "hover totem", "HoverTotem", "Hover Totem",
    "autopot", "AutoPot", "auto pot", "Auto Pot",
    "velocity", "Velocity", "VELOCITY",
    "autodoublehand", "AutoDoubleHand", "auto double hand", "Auto Double Hand",
    "autoarmor", "AutoArmor", "auto armor", "Auto Armor",
    "automace", "AutoMace", "auto mace", "Auto Mace",
    "aimassist", "AimAssist", "aim assist", "Aim Assist",
    "triggerbot", "TriggerBot", "trigger bot", "Trigger Bot",
    "shieldbreaker", "ShieldBreaker", "shield breaker", "Shield Breaker",
    "axespam", "AxeSpam", "axe spam", "Axe Spam",
    "jumpreset", "JumpReset", "jump reset", "Jump Reset",
    "pingspoof", "PingSpoof", "ping spoof", "Ping Spoof",
    "fastplace", "FastPlace", "fast place", "Fast Place",
    "webmacro", "WebMacro", "web macro", "Web Macro",
    "selfdestruct", "SelfDestruct", "self destruct", "Self Destruct"
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
$realFindings = @()

foreach ($proc in $processes) {
    Write-Host "==========================================" -ForegroundColor DarkCyan
    Write-Host "[SCANNING] $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Cyan
    
    if ($proc.MainWindowTitle) {
        Write-Host "Title: $($proc.MainWindowTitle)" -ForegroundColor Gray
    }
    
    Write-Host "Memory: $([math]::Round($proc.WorkingSet64/1MB, 1)) MB" -ForegroundColor Gray
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
        
        Write-Host "[*] Scanning memory modules..." -ForegroundColor Yellow
        
        # List of Windows system files to IGNORE (avoid false positives)
        $systemFiles = @(
            "kernel32.dll", "kernelbase.dll", "ntdll.dll", "user32.dll",
            "gdi32.dll", "advapi32.dll", "msvcrt.dll", "ole32.dll",
            "oleaut32.dll", "shell32.dll", "shlwapi.dll", "ws2_32.dll",
            "wininet.dll", "urlmon.dll", "crypt32.dll", "secur32.dll",
            "imm32.dll", "comctl32.dll", "comdlg32.dll", "winmm.dll",
            "version.dll", "psapi.dll", "powrprof.dll", "setupapi.dll",
            "dwmapi.dll", "uxtheme.dll", "dinput8.dll", "xinput1_3.dll",
            "xinput1_4.dll", "d3d9.dll", "d3d11.dll", "dxgi.dll",
            "opengl32.dll", "glu32.dll", "ddraw.dll", "dsound.dll",
            "msacm32.dll", "winspool.drv", "apphelp.dll", "cryptbase.dll",
            "bcrypt.dll", "ncrypt.dll", "rsaenh.dll", "dpapi.dll",
            "credui.dll", "netapi32.dll", "netutils.dll", "wtsapi32.dll",
            "winsta.dll", "cscapi.dll", "mpr.dll", "iphlpapi.dll",
            "dhcpcsvc.dll", "dhcpcsvc6.dll", "dnsapi.dll", "wsock32.dll",
            "msimg32.dll", "usp10.dll", "gdiplus.dll", "windowscodecs.dll",
            "propsys.dll", "audioeng.dll", "audioses.dll", "avrt.dll",
            "mf.dll", "mfplat.dll", "mfreadwrite.dll", "msvcp", "msvcr",
            "vcruntime", "concrt", "api-ms-win", "openal.dll", "dxgl.dll"
        )
        
        # Get process modules to scan
        foreach ($module in $proc.Modules) {
            $moduleName = $module.ModuleName.ToLower()
            
            # Skip Windows system files to avoid false positives
            $isSystemFile = $false
            foreach ($sysFile in $systemFiles) {
                if ($moduleName.Contains($sysFile)) {
                    $isSystemFile = $true
                    break
                }
            }
            
            if ($isSystemFile) {
                continue  # Skip this system file
            }
            
            try {
                $moduleSize = $module.ModuleMemorySize
                if ($moduleSize -gt 0 -and $moduleSize -lt 50000000) { # Less than 50MB
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
                                    $processFindings += "$search (in $($module.ModuleName))"
                                }
                                # Search in Unicode (UTF-16)
                                elseif ($unicodeText.IndexOf($search, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                    $processFindings += "$search (in $($module.ModuleName))"
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
        Write-Host "[✓] No cheat strings found" -ForegroundColor Green
    } else {
        Write-Host "[!] FOUND $($processFindings.Count) STRING(S):" -ForegroundColor Red
        foreach ($finding in $processFindings | Select-Object -Unique) {
            Write-Host "  - $finding" -ForegroundColor Yellow
            $foundAnything = $true
            $realFindings += $finding
        }
    }
    
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "          SCAN COMPLETE" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host ""

if ($foundAnything) {
    Write-Host "[!] CHEAT STRINGS DETECTED!" -ForegroundColor Red
    Write-Host "    Found in memory scan" -ForegroundColor Red
    
    # Show unique findings
    Write-Host ""
    Write-Host "Unique findings:" -ForegroundColor Yellow
    foreach ($finding in $realFindings | Select-Object -Unique) {
        $cheatName = ($finding -split ' ')[0]
        Write-Host "  - $cheatName" -ForegroundColor Red
    }
} else {
    Write-Host "[✓] No cheat strings found" -ForegroundColor Green
    Write-Host ""
    Write-Host "[?] Possible reasons:" -ForegroundColor Yellow
    Write-Host "    - Cheats may use different naming" -ForegroundColor Gray
    Write-Host "    - Try different string variations" -ForegroundColor Gray
    Write-Host "    - Cheats might be packed/obfuscated" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Processes scanned: $($processes.Count)" -ForegroundColor Gray
Write-Host "String patterns: $($searchStrings.Count)" -ForegroundColor Gray
Write-Host "Memory scan: Java process modules" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
pause
