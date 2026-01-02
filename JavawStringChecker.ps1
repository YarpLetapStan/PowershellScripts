<#
.SYNOPSIS
    Java Memory Cheat Detector by YarpLetapStan
.DESCRIPTION
    Simple cheat string scanner for javaw processes
.NOTES
    File: JavawStringChecker.ps1
    Run as Administrator
#>

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as Admin" -ForegroundColor Yellow
    pause
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

Write-Host "Java Cheat Detector" -ForegroundColor Cyan
Write-Host "by YarpLetapStan" -ForegroundColor Gray
Write-Host ""

# Find javaw processes
$javaw = Get-Process javaw -ErrorAction SilentlyContinue | Where-Object { $_.Responding -ne $false }
if (-not $javaw) {
    Write-Host "No javaw found" -ForegroundColor Red
    Write-Host "Open Minecraft first" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "Found $($javaw.Count) javaw process(es)" -ForegroundColor Gray
Write-Host ""

# Win32 API for memory scanning
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MemScan {
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
    
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr hObject);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out int lpNumberOfBytesRead);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);
    public const int PROCESS_VM_READ = 0x0010;
    public const int PROCESS_QUERY_INFORMATION = 0x0400;
    public const uint MEM_COMMIT = 0x1000;
}
"@

$foundCheats = @{}
$totalInstances = 0

foreach ($proc in $javaw) {
    Write-Host "Scanning PID $($proc.Id)..." -ForegroundColor DarkGray
    
    $hProcess = [MemScan]::OpenProcess([MemScan]::PROCESS_VM_READ -bor [MemScan]::PROCESS_QUERY_INFORMATION, $false, $proc.Id)
    if ($hProcess -eq [IntPtr]::Zero) { 
        Write-Host "  Cannot access memory" -ForegroundColor DarkGray
        continue 
    }
    
    $address = [IntPtr]::Zero
    $mbi = New-Object MemScan+MEMORY_BASIC_INFORMATION
    $mbiSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
    $regionsScanned = 0
    
    while ([MemScan]::VirtualQueryEx($hProcess, $address, [ref] $mbi, $mbiSize)) {
        $regionSize = $mbi.RegionSize.ToInt64()
        $isReadable = $mbi.Protect -band 0x02 -or $mbi.Protect -band 0x04 -or $mbi.Protect -band 0x08 -or $mbi.Protect -band 0x10
        $isCommitted = $mbi.State -eq [MemScan]::MEM_COMMIT
        
        if ($isReadable -and $isCommitted -and $regionSize -gt 1024 -and $regionSize -lt 10485760) {
            $regionsScanned++
            
            try {
                $buffer = New-Object byte[] ([Math]::Min($regionSize, 2097152))
                $bytesRead = 0
                
                if ([MemScan]::ReadProcessMemory($hProcess, $mbi.BaseAddress, $buffer, $buffer.Length, [ref] $bytesRead)) {
                    if ($bytesRead -gt 100) {
                        $asciiText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, [Math]::Min($bytesRead, 1000000))
                        $unicodeText = [System.Text.Encoding]::Unicode.GetString($buffer, 0, [Math]::Min($bytesRead, 1000000))
                        
                        foreach ($cheat in $cheats) {
                            $foundInAscii = $asciiText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0
                            $foundInUnicode = $unicodeText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0
                            
                            if ($foundInAscii -or $foundInUnicode) {
                                if (-not $foundCheats.ContainsKey($cheat)) {
                                    $foundCheats[$cheat] = 0
                                }
                                $foundCheats[$cheat]++
                                $totalInstances++
                            }
                        }
                    }
                }
            } catch { }
        }
        
        $address = [IntPtr]($address.ToInt64() + $regionSize)
        if ($address.ToInt64() -gt 0x80000000) { break }
    }
    
    [MemScan]::CloseHandle($hProcess)
    Write-Host "  Scanned $regionsScanned memory regions" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "========================" -ForegroundColor DarkGray

if ($foundCheats.Count -eq 0) {
    Write-Host "No cheats detected" -ForegroundColor Green
} else {
    Write-Host "CHEATS DETECTED:" -ForegroundColor Red
    foreach ($cheat in ($foundCheats.Keys | Sort-Object)) {
        Write-Host "  - $cheat ($($foundCheats[$cheat]) instances)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Found $($foundCheats.Count) cheat type(s)" -ForegroundColor Red
    Write-Host "Total instances: $totalInstances" -ForegroundColor Red
}

Write-Host "========================" -ForegroundColor DarkGray
Write-Host ""
pause
