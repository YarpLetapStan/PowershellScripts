# System Informer JAR Execution Checker
# Directly searches msmpeng.exe memory for "-jar" strings
# Made by YarpLetapStan

Write-Host "=== JAR Execution Checker ===" -ForegroundColor Cyan
Write-Host "Made by YarpLetapStan" -ForegroundColor Gray
Write-Host "Scanning msmpeng.exe memory for executed JAR files..." -ForegroundColor Yellow
Write-Host ""

# Find msmpeng.exe process
$msmpeng = Get-Process -Name "MsMpEng" -ErrorAction SilentlyContinue

if (-not $msmpeng) {
    Write-Host "ERROR: msmpeng.exe process not found!" -ForegroundColor Red
    Write-Host "Windows Defender may not be running." -ForegroundColor Yellow
    pause
    exit
}

$processId = $msmpeng.Id
Write-Host "Found msmpeng.exe (PID: $processId)" -ForegroundColor Green
Write-Host ""

# Memory reading requires admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run CMD as Administrator and try again." -ForegroundColor Yellow
    pause
    exit
}

# P/Invoke declarations for reading process memory
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class MemoryReader {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    
    [DllImport("kernel32.dll")]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, long dwSize, out long lpNumberOfBytesRead);
    
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);
    
    [DllImport("kernel32.dll")]
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
    
    public const int PROCESS_QUERY_INFORMATION = 0x0400;
    public const int PROCESS_VM_READ = 0x0010;
    public const uint MEM_COMMIT = 0x1000;
    public const uint PAGE_READWRITE = 0x04;
    public const uint PAGE_READONLY = 0x02;
    public const uint PAGE_EXECUTE_READ = 0x20;
    public const uint MEM_PRIVATE = 0x20000;
    public const uint MEM_IMAGE = 0x1000000;
    public const uint MEM_MAPPED = 0x40000;
}
"@

Write-Host "Opening process memory..." -ForegroundColor Yellow

# Try with PROCESS_ALL_ACCESS first
$processHandle = [MemoryReader]::OpenProcess(0x1F0FFF, $false, $processId)
if ($processHandle -eq [IntPtr]::Zero) {
    # Try with minimum required access
    $processHandle = [MemoryReader]::OpenProcess(0x0410, $false, $processId)
}

if ($processHandle -eq [IntPtr]::Zero) {
    $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Host "ERROR: Could not open process!" -ForegroundColor Red
    Write-Host "Error Code: $lastError" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  - Need to run as SYSTEM (not just Administrator)" -ForegroundColor Gray
    Write-Host "  - Windows Defender has protected process light (PPL)" -ForegroundColor Gray
    Write-Host "  - Anti-tampering protection is enabled" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Try using System Informer/Process Hacker instead:" -ForegroundColor Cyan
    Write-Host "  1. Open System Informer as Admin" -ForegroundColor White
    Write-Host "  2. Right-click MsMpEng.exe > Properties" -ForegroundColor White
    Write-Host "  3. Memory tab > Options > Strings" -ForegroundColor White
    Write-Host "  4. Min length: 5, Check all boxes" -ForegroundColor White
    Write-Host "  5. Search for: -jar" -ForegroundColor White
    pause
    exit
}

$jarStrings = New-Object System.Collections.Generic.HashSet[string]
$address = [IntPtr]::Zero
$mbi = New-Object MemoryReader+MEMORY_BASIC_INFORMATION
$mbiSize = [Runtime.InteropServices.Marshal]::SizeOf($mbi)

Write-Host "Scanning memory regions (this may take a minute)..." -ForegroundColor Yellow
Write-Host ""

# Scan memory regions
$scanned = 0
$totalRegions = 0

while ([MemoryReader]::VirtualQueryEx($processHandle, $address, [ref]$mbi, $mbiSize) -ne 0) {
    $totalRegions++
    
    # Check if region is committed and readable (Image, Mapped, or Private)
    if ($mbi.State -eq 0x1000 -and 
        ($mbi.Type -eq 0x1000000 -or $mbi.Type -eq 0x40000 -or $mbi.Type -eq 0x20000) -and
        ($mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x20)) {
        
        $regionSize = [long]$mbi.RegionSize
        if ($regionSize -gt 0 -and $regionSize -lt 100MB) {
            try {
                $buffer = New-Object byte[] $regionSize
                $bytesRead = [long]0
                
                if ([MemoryReader]::ReadProcessMemory($processHandle, $mbi.BaseAddress, $buffer, $regionSize, [ref]$bytesRead) -and $bytesRead -gt 0) {
                    # Search for ASCII strings containing "-jar" (minimum length 5)
                    $ascii = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
                    $matches = [regex]::Matches($ascii, '[\x20-\x7E]{5,}')
                    foreach ($match in $matches) {
                        if ($match.Value -match '-jar') {
                            [void]$jarStrings.Add($match.Value.Trim())
                        }
                    }
                    
                    # Search for Unicode strings containing "-jar"
                    try {
                        $unicode = [System.Text.Encoding]::Unicode.GetString($buffer, 0, $bytesRead)
                        $matches = [regex]::Matches($unicode, '[\x20-\x7E]{5,}')
                        foreach ($match in $matches) {
                            if ($match.Value -match '-jar') {
                                [void]$jarStrings.Add($match.Value.Trim())
                            }
                        }
                    } catch {
                        # Unicode conversion can fail on some data
                    }
                    
                    $scanned++
                    Write-Host "." -NoNewline -ForegroundColor Gray
                }
            } catch {
                # Skip regions that can't be read
            }
        }
    }
    
    # Move to next region (handle large addresses properly)
    try {
        $address = [IntPtr]::Add($mbi.BaseAddress, $mbi.RegionSize.ToInt64())
    } catch {
        # If we overflow, we've reached the end of addressable memory
        break
    }
}

[MemoryReader]::CloseHandle($processHandle)

Write-Host ""
Write-Host ""
Write-Host "Scan complete! Scanned $scanned readable regions out of $totalRegions total." -ForegroundColor Green
Write-Host ""

if ($jarStrings.Count -eq 0) {
    Write-Host "No JAR executions found in memory." -ForegroundColor Yellow
    Write-Host "This could mean:" -ForegroundColor Gray
    Write-Host "  - No JAR files have been executed recently" -ForegroundColor Gray
    Write-Host "  - The strings have been cleared from memory" -ForegroundColor Gray
    Write-Host "  - JAR executions are in protected memory regions" -ForegroundColor Gray
} else {
    Write-Host "Found $($jarStrings.Count) unique strings containing '-jar':" -ForegroundColor Green
    Write-Host ""
    Write-Host "=================================" -ForegroundColor Cyan
    $counter = 1
    foreach ($str in $jarStrings | Sort-Object) {
        Write-Host "[$counter] " -NoNewline -ForegroundColor Yellow
        Write-Host "$str" -ForegroundColor White
        $counter++
    }
    Write-Host "=================================" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
pause > $null
