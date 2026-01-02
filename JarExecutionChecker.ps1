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

$pid = $msmpeng.Id
Write-Host "Found msmpeng.exe (PID: $pid)" -ForegroundColor Green
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
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out int lpNumberOfBytesRead);
    
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
    public const uint MEM_PRIVATE = 0x20000;
    public const uint MEM_IMAGE = 0x1000000;
    public const uint MEM_MAPPED = 0x40000;
}
"@

Write-Host "Opening process memory..." -ForegroundColor Yellow

$processHandle = [MemoryReader]::OpenProcess(0x0410, $false, $pid)
if ($processHandle -eq [IntPtr]::Zero) {
    Write-Host "ERROR: Could not open process!" -ForegroundColor Red
    pause
    exit
}

$jarStrings = @()
$address = [IntPtr]::Zero
$mbi = New-Object MemoryReader+MEMORY_BASIC_INFORMATION
$mbiSize = [Runtime.InteropServices.Marshal]::SizeOf($mbi)

Write-Host "Scanning memory regions (this may take a minute)..." -ForegroundColor Yellow

# Scan memory regions
$scanned = 0
while ([MemoryReader]::VirtualQueryEx($processHandle, $address, [ref]$mbi, $mbiSize) -ne 0) {
    # Check if region is committed and readable (Image, Mapped, or Private)
    if ($mbi.State -eq 0x1000 -and 
        ($mbi.Type -eq 0x1000000 -or $mbi.Type -eq 0x40000 -or $mbi.Type -eq 0x20000) -and
        ($mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x20)) {
        
        $regionSize = [int]$mbi.RegionSize
        if ($regionSize -gt 0 -and $regionSize -lt 100MB) {
            $buffer = New-Object byte[] $regionSize
            $bytesRead = 0
            
            if ([MemoryReader]::ReadProcessMemory($processHandle, $mbi.BaseAddress, $buffer, $regionSize, [ref]$bytesRead)) {
                # Search for ASCII strings containing "-jar" (minimum length 5)
                $ascii = [System.Text.Encoding]::ASCII.GetString($buffer)
                if ($ascii -match '-jar') {
                    $matches = [regex]::Matches($ascii, '[\x20-\x7E]{5,}')
                    foreach ($match in $matches) {
                        if ($match.Value -match '-jar') {
                            $jarStrings += $match.Value
                        }
                    }
                }
                
                # Search for Unicode strings containing "-jar"
                $unicode = [System.Text.Encoding]::Unicode.GetString($buffer)
                if ($unicode -match '-jar') {
                    $matches = [regex]::Matches($unicode, '[\x20-\x7E]{5,}')
                    foreach ($match in $matches) {
                        if ($match.Value -match '-jar') {
                            $jarStrings += $match.Value
                        }
                    }
                }
            }
        }
        $scanned++
    }
    
    # Move to next region
    $address = [IntPtr]::Add($mbi.BaseAddress, [int]$mbi.RegionSize)
}

[MemoryReader]::CloseHandle($processHandle)

Write-Host ""
Write-Host "Scan complete! Scanned $scanned memory regions." -ForegroundColor Green
Write-Host ""

if ($jarStrings.Count -eq 0) {
    Write-Host "No JAR executions found in memory." -ForegroundColor Yellow
} else {
    Write-Host "Found $($jarStrings.Count) strings containing '-jar':" -ForegroundColor Green
    Write-Host ""
    $jarStrings | Select-Object -Unique | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
pause > $null
