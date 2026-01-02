<#
.SYNOPSIS
    Java Memory String Scanner by YarpLetapStan
.DESCRIPTION
    Scans javaw process memory for strings like Process Hacker/System Informer
.NOTES
    Scans ALL memory regions, not just DLLs
#>

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Run as Administrator!" -ForegroundColor Red
    exit
}

# Cheat strings
$cheats = @(
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
    "pingspoof", "ping spoof",
    "webmacro", "web macro",
    "selfdestruct", "self destruct",
    "hitboxes"
)

Write-Host "Memory String Scanner" -ForegroundColor Cyan
Write-Host "by YarpLetapStan" -ForegroundColor Gray
Write-Host ""

# Find javaw
$javaw = Get-Process javaw -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $javaw) {
    Write-Host "No javaw process found" -ForegroundColor Red
    Write-Host "Start Minecraft first" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "Scanning javaw PID: $($javaw.Id)" -ForegroundColor Green
Write-Host "Memory: $([math]::Round($javaw.WorkingSet64/1MB, 1)) MB" -ForegroundColor Gray
Write-Host ""

# Add Win32 API for memory scanning
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class MemoryReader {
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
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);
    
    [DllImport("kernel32.dll")]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, 
        byte[] lpBuffer, int dwSize, out int lpNumberOfBytesRead);
    
    [DllImport("kernel32.dll")]
    public static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, 
        out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);
    
    public const int PROCESS_VM_READ = 0x0010;
    public const int PROCESS_QUERY_INFORMATION = 0x0400;
    public const uint MEM_COMMIT = 0x1000;
    public const uint PAGE_READONLY = 0x02;
    public const uint PAGE_READWRITE = 0x04;
    public const uint PAGE_EXECUTE_READ = 0x20;
    public const uint PAGE_EXECUTE_READWRITE = 0x40;
}
"@

# Open the process
$hProcess = [MemoryReader]::OpenProcess(
    [MemoryReader]::PROCESS_VM_READ -bor [MemoryReader]::PROCESS_QUERY_INFORMATION,
    $false,
    $javaw.Id
)

if ($hProcess -eq [IntPtr]::Zero) {
    Write-Host "Cannot access process memory" -ForegroundColor Red
    Write-Host "Make sure you're running as Administrator" -ForegroundColor Yellow
    pause
    exit
}

$foundCheats = @{}
$totalRegions = 0
$totalBytes = 0
$foundCount = 0

Write-Host "Scanning memory regions (like Process Hacker)..." -ForegroundColor Yellow
Write-Host ""

# Scan ALL memory regions
$address = [IntPtr]::Zero
$mbi = New-Object MemoryReader+MEMORY_BASIC_INFORMATION

while ([MemoryReader]::VirtualQueryEx($hProcess, $address, [ref] $mbi, 
        [System.Runtime.InteropServices.Marshal]::SizeOf($mbi))) {
    
    $regionSize = $mbi.RegionSize.ToInt64()
    $baseAddress = $mbi.BaseAddress
    
    # Check if region is readable and committed (like Process Hacker shows)
    $protection = $mbi.Protect
    $isReadable = ($protection -band [MemoryReader]::PAGE_READONLY) -ne 0 -or
                 ($protection -band [MemoryReader]::PAGE_READWRITE) -ne 0 -or
                 ($protection -band [MemoryReader]::PAGE_EXECUTE_READ) -ne 0 -or
                 ($protection -band [MemoryReader]::PAGE_EXECUTE_READWRITE) -ne 0
    
    $isCommitted = ($mbi.State -eq [MemoryReader]::MEM_COMMIT)
    
    if ($isReadable -and $isCommitted -and $regionSize -gt 1024) {
        $totalRegions++
        $totalBytes += $regionSize
        
        # Show progress
        if ($totalRegions % 50 -eq 0) {
            Write-Host "  Scanned $totalRegions regions ($([math]::Round($totalBytes/1MB, 1)) MB)..." -ForegroundColor DarkGray
        }
        
        try {
            # Read a chunk of the memory region
            $chunkSize = [Math]::Min($regionSize, 1048576)  # 1MB max per read
            $buffer = New-Object byte[] $chunkSize
            $bytesRead = 0
            
            if ([MemoryReader]::ReadProcessMemory($hProcess, $baseAddress, $buffer, $chunkSize, [ref] $bytesRead)) {
                if ($bytesRead -gt 100) {
                    # Extract strings from this memory chunk (like Process Hacker's string search)
                    # Try ASCII encoding first
                    $asciiText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
                    
                    # Then Unicode/UTF-16
                    $unicodeText = [System.Text.Encoding]::Unicode.GetString($buffer, 0, $bytesRead)
                    
                    # Search for each cheat string
                    foreach ($cheat in $cheats) {
                        # Check in ASCII
                        $indexAscii = $asciiText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase)
                        if ($indexAscii -ge 0) {
                            if (-not $foundCheats.ContainsKey($cheat)) {
                                $foundCheats[$cheat] = 0
                            }
                            $foundCheats[$cheat]++
                            $foundCount++
                            
                            # Show immediate detection
                            Write-Host "  [!] Found '$cheat' at 0x$($baseAddress.ToString('X'))" -ForegroundColor Red
                        }
                        
                        # Check in Unicode
                        $indexUnicode = $unicodeText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase)
                        if ($indexUnicode -ge 0) {
                            if (-not $foundCheats.ContainsKey($cheat)) {
                                $foundCheats[$cheat] = 0
                            }
                            $foundCheats[$cheat]++
                            $foundCount++
                            
                            Write-Host "  [!] Found '$cheat' (Unicode) at 0x$($baseAddress.ToString('X'))" -ForegroundColor Red
                        }
                    }
                }
            }
        } catch {
            # Skip regions that can't be read
        }
    }
    
    # Move to next memory region
    $nextAddress = $baseAddress.ToInt64() + $regionSize
    $address = [IntPtr]$nextAddress
    
    # Stop if we've scanned too much (safety)
    if ($nextAddress -gt 0x7FFFFFFF) {
        break
    }
}

# Close process handle
[MemoryReader]::CloseHandle($hProcess)

Write-Host ""
Write-Host "Scan completed:" -ForegroundColor Gray
Write-Host "  Memory regions scanned: $totalRegions" -ForegroundColor Gray
Write-Host "  Total memory scanned: $([math]::Round($totalBytes/1MB, 1)) MB" -ForegroundColor Gray
Write-Host ""

Write-Host "========================" -ForegroundColor DarkGray

if ($foundCount -eq 0) {
    Write-Host "No cheat strings found in memory" -ForegroundColor Green
} else {
    Write-Host "CHEAT STRINGS FOUND IN MEMORY:" -ForegroundColor Red
    Write-Host ""
    foreach ($cheat in ($foundCheats.Keys | Sort-Object)) {
        $count = $foundCheats[$cheat]
        Write-Host "  $cheat ($count locations)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Total detections: $foundCount" -ForegroundColor Red
}

Write-Host "========================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Scan type: Process memory string search" -ForegroundColor Gray
Write-Host "(Like Process Hacker/System Informer)" -ForegroundColor Gray
Write-Host ""
pause
