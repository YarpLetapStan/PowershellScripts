<#
.SYNOPSIS
    Java Process Memory Scanner by YarpLetapStan
.DESCRIPTION
    Scans running Java processes memory for cheat strings (like System Informer)
.NOTES
    Author: YarpLetapStan
    Version: 2.0
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
    "selfdestruct", "self destruct",
    "killaura", "reach", "nofall", "speed", "fly", "phase", "scaffold",
    "xray", "esp", "tracers", "radar", "fullbright", "nohurtcam",
    "antiknockback", "antivoid", "jetpack", "timer", "step"
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
    public const int PAGE_READABLE = 0x02; // PAGE_READONLY
    public const int PAGE_READWRITE = 0x04;
    public const int PAGE_EXECUTE_READ = 0x20;
    public const int PAGE_EXECUTE_READWRITE = 0x40;
    
    public static bool IsReadable(uint protect) {
        return (protect == PAGE_READABLE || protect == PAGE_READWRITE || 
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

function Scan-ProcessMemoryRegions {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$SearchStrings
    )
    
    $foundStrings = @()
    
    try {
        Write-Host "  [*] Opening process for memory access..." -ForegroundColor Gray
        
        # Open the process with memory reading permissions
        $hProcess = [MemoryReader]::OpenProcess(
            [MemoryReader]::PROCESS_VM_READ -bor [MemoryReader]::PROCESS_QUERY_INFORMATION,
            $false,
            $Process.Id
        )
        
        if ($hProcess -eq [IntPtr]::Zero) {
            Write-Host "  [X] Cannot open process (access denied)" -ForegroundColor DarkRed
            return $foundStrings
        }
        
        Write-Host "  [*] Scanning memory regions..." -ForegroundColor Gray
        
        $address = [IntPtr]::Zero
        $mbi = New-Object MemoryReader+MEMORY_BASIC_INFORMATION
        $mbiSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
        
        $totalBytesScanned = 0
        $regionCount = 0
        
        # Walk through all memory regions
        while ([MemoryReader]::VirtualQueryEx($hProcess, $address, [ref] $mbi, $mbiSize) -ne 0) {
            $regionSize = $mbi.RegionSize.ToInt64()
            
            # Only scan committed, readable memory regions
            if ($mbi.State -eq [MemoryReader]::MEM_COMMIT -and 
                [MemoryReader]::IsReadable($mbi.Protect) -and
                $regionSize -gt 0 -and $regionSize -lt 100MB) {
                
                $regionCount++
                Write-Host "    Scanning region $regionCount (Size: $($regionSize/1KB)KB)..." -ForegroundColor DarkGray -NoNewline
                
                # Read the memory region
                $buffer = New-Object byte[] $regionSize
                $bytesRead = 0
                
                if ([MemoryReader]::ReadProcessMemory($hProcess, $mbi.BaseAddress, $buffer, $regionSize, [ref] $bytesRead)) {
                    $totalBytesScanned += $bytesRead
                    
                    # Convert bytes to ASCII string for searching
                    $asciiText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, [Math]::Min($bytesRead, 1000000))
                    
                    # Search for cheat strings
                    foreach ($cheat in $SearchStrings) {
                        if ($asciiText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            $foundStrings += [PSCustomObject]@{
                                Cheat = $cheat
                                Address = "0x" + $mbi.BaseAddress.ToString("X")
                                RegionSize = "$($regionSize/1KB)KB"
                            }
                            Write-Host " FOUND: $cheat" -ForegroundColor Red -NoNewline
                            break
                        }
                    }
                    
                    Write-Host ""  # New line after region scan
                }
            }
            
            # Move to next region
            $address = [IntPtr]::Add($mbi.BaseAddress, $mbi.RegionSize)
            
            # Safety check - don't scan forever
            if ($regionCount -gt 500) {
                Write-Host "  [!] Stopping after 500 regions (safety limit)" -ForegroundColor Yellow
                break
            }
        }
        
        Write-Host "  [*] Scanned $totalBytesScanned bytes in $regionCount regions" -ForegroundColor Gray
        
        [MemoryReader]::CloseHandle($hProcess)
        
    }
    catch {
        Write-Host "  [X] Error scanning memory: $_" -ForegroundColor DarkRed
    }
    
    return $foundStrings
}

function Scan-ProcessModules {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$SearchStrings
    )
    
    $foundStrings = @()
    
    try {
        Write-Host "  [*] Checking loaded modules..." -ForegroundColor Gray
        
        foreach ($module in $Process.Modules) {
            $moduleName = $module.ModuleName.ToLower()
            $fileName = $module.FileName.ToLower()
            
            foreach ($cheat in $SearchStrings) {
                if ($moduleName.Contains($cheat) -or $fileName.Contains($cheat)) {
                    $foundStrings += [PSCustomObject]@{
                        Cheat = $cheat
                        Source = "Module"
                        Module = $module.ModuleName
                    }
                }
            }
        }
    }
    catch {
        Write-Host "  [X] Error scanning modules: $_" -ForegroundColor DarkRed
    }
    
    return $foundStrings
}

# Main execution
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Java Process Memory Scanner" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[*] Running as Administrator: YES" -ForegroundColor Green
Write-Host "[*] Scanning for $($cheatStrings.Count) cheat strings in memory..." -ForegroundColor Cyan
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
$allDetections = @()

foreach ($proc in $processes) {
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[SCANNING] $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Cyan
    
    if ($proc.MainWindowTitle) {
        Write-Host "  Window: $($proc.MainWindowTitle)" -ForegroundColor Gray
    }
    
    Write-Host "  Memory: $($proc.WorkingSet64/1MB)MB" -ForegroundColor Gray
    
    $detections = @()
    
    # 1. Scan modules first (fast)
    $moduleDetections = Scan-ProcessModules -Process $proc -SearchStrings $cheatStrings
    $detections += $moduleDetections
    
    # 2. Scan memory regions (slower, but finds strings in heap/memory)
    Write-Host "  [*] Memory scan may take 10-30 seconds..." -ForegroundColor Yellow
    $memoryDetections = Scan-ProcessMemoryRegions -Process $proc -SearchStrings $cheatStrings
    $detections += $memoryDetections
    
    # Display results for this process
    if ($detections.Count -eq 0) {
        Write-Host "  [✓] No cheat strings found in memory" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] Found $($detections.Count) cheat string(s) in memory:" -ForegroundColor Red
        
        # Group by cheat type
        $grouped = $detections | Group-Object Cheat
        
        foreach ($group in $grouped) {
            Write-Host "      - $($group.Name):" -ForegroundColor Red
            foreach ($item in $group.Group) {
                if ($item.Source -eq "Module") {
                    Write-Host "        Module: $($item.Module)" -ForegroundColor Yellow
                }
                else {
                    Write-Host "        Memory at $($item.Address) ($($item.RegionSize))" -ForegroundColor Yellow
                }
            }
        }
        
        $totalDetections += $detections.Count
        $allDetections += $detections
    }
    
    Write-Host ""
}

# Final report
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "           MEMORY SCAN COMPLETE" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

if ($totalDetections -eq 0) {
    Write-Host "[✓] MEMORY SCAN CLEAN" -ForegroundColor Green
    Write-Host "    No cheat strings found in Java process memory" -ForegroundColor Green
}
else {
    Write-Host "[X] CHEAT STRINGS FOUND IN MEMORY!" -ForegroundColor Red
    Write-Host "    Found $totalDetections cheat string(s) across $($processes.Count) process(es)" -ForegroundColor Red
    Write-Host ""
    
    # Summary of what was found
    $uniqueCheats = $allDetections | Select-Object -ExpandProperty Cheat -Unique
    Write-Host "  Cheats detected: $($uniqueCheats -join ', ')" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Processes scanned: $($processes.Count)" -ForegroundColor Cyan
Write-Host "Cheat patterns: $($cheatStrings.Count)" -ForegroundColor Cyan
Write-Host "Scan time: Memory regions scanned (actual System Informer style)" -ForegroundColor Cyan
Write-Host ""

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
