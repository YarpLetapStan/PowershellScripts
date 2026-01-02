<#
.SYNOPSIS
    Java Process Memory String Scanner by YarpLetapStan
.DESCRIPTION
    Aggressive memory scanner for cheat strings in javaw processes
.NOTES
    Author: YarpLetapStan
    Version: 4.1
    Requires: Administrator privileges
#>

# Set execution policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host "Then run the script again." -ForegroundColor Yellow
    timeout /t 5
    exit
}

# Cheat strings to search for (Updated per your request)
$cheatStrings = @(
    "autocrystal", "auto crystal", "cw crystal", "autohitcrystal",
    "autoanchor", "auto anchor", "anchortweaks", "anchor macro",
    "autototem", "auto totem", "legittotem", "inventorytotem", "hover totem",
    "autopot", "auto pot", 
    "velocity",  # Separate from autopot
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

# Add .NET memory reading capabilities
Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public class MemoryReader {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    
    [DllImport("kernel32.dll")]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out int lpNumberOfBytesRead);
    
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_BASIC_INFORMATION {
        public IntPtr BaseAddress;
        public IntPtr AllocationBase;
        public uint AllocationProtect;
        public IntPtr RegionSize;
        public uint State;
        public uint Protect;
        public uint Type;
    }
    
    public const int PROCESS_VM_READ = 0x0010;
    public const int PROCESS_QUERY_INFORMATION = 0x0400;
    public const int MEM_COMMIT = 0x1000;
    public const int PAGE_READONLY = 0x02;
    public const int PAGE_READWRITE = 0x04;
    public const int PAGE_EXECUTE_READ = 0x20;
    public const int PAGE_EXECUTE_READWRITE = 0x40;
    
    public static bool IsReadable(uint protect) {
        return (protect == PAGE_READONLY || protect == PAGE_READWRITE || 
                protect == PAGE_EXECUTE_READ || protect == PAGE_EXECUTE_READWRITE);
    }
}
"@

function Get-JavaProcesses {
    Write-Host "[*] Looking for Java processes..." -ForegroundColor Cyan
    try {
        $processes = Get-Process javaw, java -ErrorAction SilentlyContinue | Where-Object {
            $_.Responding -eq $true -and $_.Id -gt 0
        }
        return $processes
    }
    catch {
        Write-Host "[X] Error finding processes: $_" -ForegroundColor Red
        return @()
    }
}

function Scan-ProcessMemoryAggressive {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$SearchStrings
    )
    
    $foundStrings = @()
    
    try {
        Write-Host "  [*] Opening process PID $($Process.Id)..." -ForegroundColor Gray
        
        # Open process for memory reading
        $hProcess = [MemoryReader]::OpenProcess(
            [MemoryReader]::PROCESS_VM_READ -bor [MemoryReader]::PROCESS_QUERY_INFORMATION,
            $false,
            $Process.Id
        )
        
        if ($hProcess -eq [IntPtr]::Zero) {
            Write-Host "  [X] Cannot access process memory" -ForegroundColor DarkRed
            return $foundStrings
        }
        
        Write-Host "  [*] Starting aggressive memory scan..." -ForegroundColor Yellow
        Write-Host "  [*] This may take 30-60 seconds..." -ForegroundColor Yellow
        
        $address = [IntPtr]::Zero
        $mbi = New-Object MemoryReader+MEMORY_BASIC_INFORMATION
        $mbiSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
        
        $totalBytesScanned = 0
        $regionCount = 0
        $scannedRegions = 0
        
        # Walk through all memory regions - MORE AGGRESSIVE
        while ([MemoryReader]::VirtualQueryEx($hProcess, $address, [ref] $mbi, $mbiSize) -ne 0) {
            $regionSize = $mbi.RegionSize.ToInt64()
            
            # More aggressive scanning - scan larger regions and more of them
            if ($mbi.State -eq [MemoryReader]::MEM_COMMIT -and 
                [MemoryReader]::IsReadable($mbi.Protect) -and
                $regionSize -gt 0 -and $regionSize -lt 500MB) {  # Increased limit to 500MB
                
                $scannedRegions++
                $regionCount++
                
                # Show progress
                if ($regionCount % 20 -eq 0) {
                    Write-Host "    Scanned $regionCount regions ($($totalBytesScanned/1MB)MB)..." -ForegroundColor DarkGray
                }
                
                # Read the memory region (sample if too large)
                $readSize = $regionSize
                if ($regionSize -gt 10MB) {
                    $readSize = 10MB  # Sample 10MB from large regions
                }
                
                $buffer = New-Object byte[] $readSize
                $bytesRead = 0
                
                # Try to read from start of region
                if ([MemoryReader]::ReadProcessMemory($hProcess, $mbi.BaseAddress, $buffer, $readSize, [ref] $bytesRead) -and $bytesRead -gt 1000) {
                    $totalBytesScanned += $bytesRead
                    
                    # Search for strings in multiple encodings
                    $asciiText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
                    $unicodeText = [System.Text.Encoding]::Unicode.GetString($buffer, 0, $bytesRead)
                    
                    foreach ($cheat in $SearchStrings) {
                        # Check ASCII
                        if ($asciiText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            $foundStrings += [PSCustomObject]@{
                                Cheat = $cheat
                                Encoding = "ASCII"
                                Address = "0x" + $mbi.BaseAddress.ToString("X")
                                RegionSize = "$($regionSize/1MB)MB"
                            }
                        }
                        # Check Unicode (UTF-16)
                        elseif ($unicodeText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            $foundStrings += [PSCustomObject]@{
                                Cheat = $cheat
                                Encoding = "Unicode"
                                Address = "0x" + $mbi.BaseAddress.ToString("X")
                                RegionSize = "$($regionSize/1MB)MB"
                            }
                        }
                    }
                }
                
                # If region is very large (>50MB), sample multiple locations
                if ($regionSize -gt 50MB) {
                    # Sample from middle
                    $middleAddr = [IntPtr]::Add($mbi.BaseAddress, [int]($regionSize / 2))
                    if ([MemoryReader]::ReadProcessMemory($hProcess, $middleAddr, $buffer, $readSize, [ref] $bytesRead) -and $bytesRead -gt 1000) {
                        $asciiText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
                        $unicodeText = [System.Text.Encoding]::Unicode.GetString($buffer, 0, $bytesRead)
                        
                        foreach ($cheat in $SearchStrings) {
                            if ($asciiText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or 
                                $unicodeText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                $foundStrings += [PSCustomObject]@{
                                    Cheat = $cheat
                                    Encoding = "Found in large region sample"
                                    Address = "0x" + $middleAddr.ToString("X")
                                }
                            }
                        }
                    }
                }
            }
            
            # Move to next region
            $address = [IntPtr]::Add($mbi.BaseAddress, $mbi.RegionSize)
            
            # Don't stop early - scan MORE regions
            if ($regionCount -gt 2000) {
                Write-Host "  [!] Scanned 2000 regions, continuing..." -ForegroundColor Yellow
                # Continue anyway for aggressive scan
            }
        }
        
        Write-Host "  [*] Aggressive scan complete:" -ForegroundColor Gray
        Write-Host "      Regions scanned: $scannedRegions" -ForegroundColor Gray
        Write-Host "      Total bytes scanned: $($totalBytesScanned/1MB)MB" -ForegroundColor Gray
        
        [MemoryReader]::CloseHandle($hProcess)
        
    }
    catch {
        Write-Host "  [X] Error scanning: $_" -ForegroundColor DarkRed
    }
    
    return $foundStrings
}

# Main execution
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  AGGRESSIVE Java Memory Scanner" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[*] Running as Administrator: YES" -ForegroundColor Green
Write-Host "[*] Scanning for $($cheatStrings.Count) cheat strings" -ForegroundColor Cyan
Write-Host "[*] Using aggressive memory scanning" -ForegroundColor Yellow
Write-Host ""

# Display cheat strings being scanned
Write-Host "[*] Scanning for these strings:" -ForegroundColor Cyan
for ($i = 0; $i -lt $cheatStrings.Count; $i += 4) {
    $line = $cheatStrings[$i..($i+3)] | Where-Object { $_ } | ForEach-Object { "  $_" }
    Write-Host $line -ForegroundColor Gray
}
Write-Host ""

# Get Java processes
$processes = Get-JavaProcesses

if ($processes.Count -eq 0) {
    Write-Host "[X] No Java processes found!" -ForegroundColor Red
    Write-Host "    Make sure Minecraft/Java is running" -ForegroundColor Yellow
    timeout /t 5
    exit
}

Write-Host "[✓] Found $($processes.Count) Java process(es)" -ForegroundColor Green
Write-Host ""

$totalDetections = 0

foreach ($proc in $processes) {
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[SCANNING] $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Cyan
    
    if ($proc.MainWindowTitle) {
        Write-Host "  Window: $($proc.MainWindowTitle)" -ForegroundColor Gray
    }
    
    Write-Host "  Memory: $($proc.WorkingSet64/1MB)MB" -ForegroundColor Gray
    
    # Scan memory aggressively
    $detections = Scan-ProcessMemoryAggressive -Process $proc -SearchStrings $cheatStrings
    
    if ($detections.Count -eq 0) {
        Write-Host "  [✓] No cheat strings found" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] FOUND $($detections.Count) CHEAT STRING(S)!" -ForegroundColor Red
        
        # Remove duplicates and show unique findings
        $uniqueDetections = $detections | Sort-Object Cheat -Unique
        
        foreach ($detect in $uniqueDetections) {
            Write-Host "      - $($detect.Cheat)" -ForegroundColor Red
        }
        
        $totalDetections += $uniqueDetections.Count
    }
    
    Write-Host ""
}

# Final report
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "           SCAN COMPLETE" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

if ($totalDetections -eq 0) {
    Write-Host "[✓] NO CHEAT STRINGS FOUND" -ForegroundColor Green
    Write-Host "    If you see strings in System Informer but not here," -ForegroundColor Gray
    Write-Host "    the cheats might be obfuscated or packed." -ForegroundColor Gray
}
else {
    Write-Host "[X] CHEAT STRINGS DETECTED!" -ForegroundColor Red
    Write-Host "    Found $totalDetections unique cheat string(s)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Cheat patterns scanned: $($cheatStrings.Count)" -ForegroundColor Cyan
Write-Host "Processes scanned: $($processes.Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
