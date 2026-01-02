<#
.SYNOPSIS
    Java Cheat Detector by YarpLetapStan
.DESCRIPTION
    Hybrid scanner: tries memory scanning first, falls back to module scanning
.NOTES
    File: JavawStringChecker_Hybrid.ps1
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

$foundCheats = @{}
$totalInstances = 0
$scanMethod = "Memory"

foreach ($proc in $javaw) {
    Write-Host "Scanning PID $($proc.Id)..." -ForegroundColor DarkGray
    $cheatsInProcess = 0
    
    # TRY MEMORY SCANNING FIRST
    $memoryScanSuccess = $false
    $memoryRegionsScanned = 0
    
    try {
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
        
        $hProcess = [MemScan]::OpenProcess([MemScan]::PROCESS_VM_READ -bor [MemScan]::PROCESS_QUERY_INFORMATION, $false, $proc.Id)
        
        if ($hProcess -ne [IntPtr]::Zero) {
            $address = [IntPtr]::Zero
            $mbi = New-Object MemScan+MEMORY_BASIC_INFORMATION
            $mbiSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
            
            while ([MemScan]::VirtualQueryEx($hProcess, $address, [ref] $mbi, $mbiSize)) {
                $regionSize = $mbi.RegionSize.ToInt64()
                if ($mbi.State -eq [MemScan]::MEM_COMMIT -and $regionSize -gt 1024 -and $regionSize -lt 10485760) {
                    $memoryRegionsScanned++
                    
                    try {
                        $buffer = New-Object byte[] ([Math]::Min($regionSize, 524288))
                        $bytesRead = 0
                        
                        if ([MemScan]::ReadProcessMemory($hProcess, $mbi.BaseAddress, $buffer, $buffer.Length, [ref] $bytesRead)) {
                            if ($bytesRead -gt 100) {
                                $text = [System.Text.Encoding]::ASCII.GetString($buffer, 0, [Math]::Min($bytesRead, 100000))
                                foreach ($cheat in $cheats) {
                                    if ($text.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                        if (-not $foundCheats.ContainsKey($cheat)) {
                                            $foundCheats[$cheat] = 0
                                        }
                                        $foundCheats[$cheat]++
                                        $totalInstances++
                                        $cheatsInProcess++
                                        $memoryScanSuccess = $true
                                    }
                                }
                            }
                        }
                    } catch { }
                }
                $address = [IntPtr]($address.ToInt64() + $regionSize)
                if ($address.ToInt64() -gt 0x40000000) { break }
            }
            
            [MemScan]::CloseHandle($hProcess)
        }
    } catch {
        $memoryScanSuccess = $false
    }
    
    # IF MEMORY SCAN FAILED OR FOUND NOTHING, TRY MODULE SCANNING
    if (-not $memoryScanSuccess -or $memoryRegionsScanned -eq 0) {
        $scanMethod = "Module"
        Write-Host "  Memory scan failed, trying module scan..." -ForegroundColor Yellow
        
        try {
            $modulesScanned = 0
            foreach ($module in $proc.Modules) {
                $modulesScanned++
                $moduleName = $module.ModuleName.ToLower()
                
                if ($moduleName -match "kernel|ntdll|windows|system32") {
                    continue
                }
                
                try {
                    $modulePath = $module.FileName
                    if ($modulePath -and (Test-Path $modulePath)) {
                        $bytes = [System.IO.File]::ReadAllBytes($modulePath)
                        $text = [System.Text.Encoding]::ASCII.GetString($bytes)
                        
                        foreach ($cheat in $cheats) {
                            if ($text.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                if (-not $foundCheats.ContainsKey($cheat)) {
                                    $foundCheats[$cheat] = 0
                                }
                                $foundCheats[$cheat]++
                                $totalInstances++
                                $cheatsInProcess++
                                
                                Write-Host "  [!] Found '$cheat' in $moduleName" -ForegroundColor Red
                            }
                        }
                    }
                } catch { }
            }
            Write-Host "  Scanned $modulesScanned modules" -ForegroundColor DarkGray
        } catch {
            Write-Host "  Module scan also failed" -ForegroundColor Red
        }
    } else {
        Write-Host "  Scanned $memoryRegionsScanned memory regions" -ForegroundColor DarkGray
    }
    
    if ($cheatsInProcess -gt 0) {
        Write-Host "  Found $cheatsInProcess cheat instances" -ForegroundColor Red
    }
    
    Write-Host ""
}

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
    Write-Host "Scan method: $scanMethod" -ForegroundColor Gray
}

Write-Host "========================" -ForegroundColor DarkGray
Write-Host ""
pause
