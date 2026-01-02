<#
.SYNOPSIS
    Java Process Unicode Memory Scanner by YarpLetapStan
.DESCRIPTION
    Scans running Java processes memory for UNICODE cheat strings (like System Informer String Search)
.NOTES
    Author: YarpLetapStan
    Version: 3.0
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

# Cheat strings to search for (Java stores strings as Unicode!)
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
    "hitboxes", 
    "selfdestruct", "self destruct",
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
    
    [DllImport("psapi.dll", SetLastError = true)]
    public static extern bool GetMappedFileName(IntPtr hProcess, IntPtr lpv, System.Text.StringBuilder lpFilename, uint nSize);
    
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
    public const int MEM_IMAGE = 0x1000000;
    public const int MEM_MAPPED = 0x40000;
    public const int MEM_PRIVATE = 0x20000;
    public const int PAGE_READONLY = 0x02;
    public const int PAGE_READWRITE = 0x04;
    public const int PAGE_EXECUTE_READ = 0x20;
    public const int PAGE_EXECUTE_READWRITE = 0x40;
    
    public static bool IsReadable(uint protect) {
        return (protect == PAGE_READONLY || protect == PAGE_READWRITE || 
                protect == PAGE_EXECUTE_READ || protect == PAGE_EXECUTE_READWRITE);
    }
    
    public static string GetRegionType(uint type) {
        if ((type & MEM_IMAGE) != 0) return "Image";
        if ((type & MEM_MAPPED) != 0) return "Mapped";
        if ((type & MEM_PRIVATE) != 0) return "Private";
        return "Unknown";
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

function Search-BufferForUnicodeStrings {
    param(
        [byte[]]$Buffer,
        [string[]]$SearchStrings
    )
    
    $found = @()
    
    # Convert buffer to Unicode string (UTF-16LE)
    # Java strings are stored as UTF-16 with 2 bytes per character
    $unicodeText = [System.Text.Encoding]::Unicode.GetString($Buffer)
    
    # Also check for ASCII (some strings might be stored differently)
    $asciiText = [System.Text.Encoding]::ASCII.GetString($Buffer)
    
    foreach ($cheat in $SearchStrings) {
        # Search in Unicode (UTF-16) - this is what Java uses!
        if ($unicodeText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $found += @{
                Cheat = $cheat
                Encoding = "Unicode"
            }
        }
        # Also check ASCII just in case
        elseif ($asciiText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $found += @{
                Cheat = $cheat
                Encoding = "ASCII"
            }
        }
    }
    
    return $found
}

function Scan-ProcessMemoryLikeSystemInformer {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$SearchStrings
    )
    
    $foundStrings = @()
    
    try {
        Write-Host "  [*] Opening process for memory access..." -ForegroundColor Gray
        
        $hProcess = [MemoryReader]::OpenProcess(
            [MemoryReader]::PROCESS_VM_READ -bor [MemoryReader]::PROCESS_QUERY_INFORMATION,
            $false,
            $Process.Id
        )
        
        if ($hProcess -eq [IntPtr]::Zero) {
            Write-Host "  [X] Cannot open process (access denied)" -ForegroundColor DarkRed
            return $foundStrings
        }
        
        Write-Host "  [*] Scanning memory regions (like System Informer)..." -ForegroundColor Gray
        
        $address = [IntPtr]::Zero
        $mbi = New-Object MemoryReader+MEMORY_BASIC_INFORMATION
        $mbiSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
        
        $totalBytesScanned = 0
        $regionCount = 0
        $privateRegions = 0
        $imageRegions = 0
        $mappedRegions = 0
        
        # Scan like System Informer does
        while ([MemoryReader]::VirtualQueryEx($hProcess, $address, [ref] $mbi, $mbiSize) -ne 0) {
            $regionSize = $mbi.RegionSize.ToInt64()
            $regionType = [MemoryReader]::GetRegionType($mbi.Type)
            
            # Only scan committed, readable memory
            if ($mbi.State -eq [MemoryReader]::MEM_COMMIT -and 
                [MemoryReader]::IsReadable($mbi.Protect) -and
                $regionSize -gt 0 -and $regionSize -lt 50MB) {
                
                # Track region types
                switch ($regionType) {
                    "Private" { $privateRegions++ }
                    "Image" { $imageRegions++ }
                    "Mapped" { $mappedRegions++ }
                }
                
                $regionCount++
                
                # Show progress every 10 regions
                if ($regionCount % 10 -eq 0) {
                    Write-Host "    Scanned $regionCount regions ($($totalBytesScanned/1MB)MB)..." -ForegroundColor DarkGray
                }
                
                # Read the memory region
                $buffer = New-Object byte[] $regionSize
                $bytesRead = 0
                
                if ([MemoryReader]::ReadProcessMemory($hProcess, $mbi.BaseAddress, $buffer, $regionSize, [ref] $bytesRead) -and $bytesRead -gt 100) {
                    $totalBytesScanned += $bytesRead
                    
                    # Search for Unicode strings (like System Informer does)
                    $hits = Search-BufferForUnicodeStrings -Buffer $buffer[0..($bytesRead-1)] -SearchStrings $SearchStrings
                    
                    if ($hits.Count -gt 0) {
                        foreach ($hit in $hits) {
                            $foundStrings += [PSCustomObject]@{
                                Cheat = $hit.Cheat
                                Address = "0x" + $mbi.BaseAddress.ToString("X")
                                RegionSize = "$($regionSize/1KB)KB"
                                RegionType = $regionType
                                Encoding = $hit.Encoding
                            }
                        }
                        
                        Write-Host "    [$regionType] FOUND: $($hits[0].Cheat) ($($hits[0].Encoding))" -ForegroundColor Red
                    }
                }
            }
            
            # Move to next region
            $address = [IntPtr]::Add($mbi.BaseAddress, $mbi.RegionSize)
            
            # Safety limit
            if ($regionCount -gt 1000) {
                Write-Host "  [!] Stopping after 1000 regions" -ForegroundColor Yellow
                break
            }
        }
        
        Write-Host "  [*] Memory scan complete:" -ForegroundColor Gray
        Write-Host "      Regions: $regionCount (Private: $privateRegions, Image: $imageRegions, Mapped: $mappedRegions)" -ForegroundColor Gray
        Write-Host "      Bytes scanned: $($totalBytesScanned/1MB)MB" -ForegroundColor Gray
        
        [MemoryReader]::CloseHandle($hProcess)
        
    }
    catch {
        Write-Host "  [X] Error: $_" -ForegroundColor DarkRed
    }
    
    return $foundStrings
}

function Scan-JavaHeapSpecific {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$SearchStrings
    )
    
    $foundStrings = @()
    
    try {
        Write-Host "  [*] Looking for Java heap regions (large Private regions)..." -ForegroundColor Gray
        
        $hProcess = [MemoryReader]::OpenProcess(
            [MemoryReader]::PROCESS_VM_READ -bor [MemoryReader]::PROCESS_QUERY_INFORMATION,
            $false,
            $Process.Id
        )
        
        if ($hProcess -eq [IntPtr]::Zero) {
            return $foundStrings
        }
        
        $address = [IntPtr]::Zero
        $mbi = New-Object MemoryReader+MEMORY_BASIC_INFORMATION
        $mbiSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
        
        # Java heap is usually large Private regions (100MB+)
        while ([MemoryReader]::VirtualQueryEx($hProcess, $address, [ref] $mbi, $mbiSize) -ne 0) {
            $regionSize = $mbi.RegionSize.ToInt64()
            $regionType = [MemoryReader]::GetRegionType($mbi.Type)
            
            # Look for large Private regions (likely Java heap)
            if ($mbi.State -eq [MemoryReader]::MEM_COMMIT -and 
                $regionType -eq "Private" -and
                $regionSize -gt 50MB -and $regionSize -lt 2GB) {
                
                Write-Host "    [Heap] Scanning large Private region: $($regionSize/1MB)MB" -ForegroundColor DarkCyan
                
                # Sample the region (don't read it all at once)
                $sampleSize = [Math]::Min($regionSize, 10MB)
                $buffer = New-Object byte[] $sampleSize
                $bytesRead = 0
                
                # Sample from beginning, middle, and end of region
                $sampleOffsets = @(0, $regionSize/3, 2*$regionSize/3)
                
                foreach ($offset in $sampleOffsets) {
                    if ($offset + $sampleSize -lt $regionSize) {
                        $sampleAddr = [IntPtr]::Add($mbi.BaseAddress, [int]$offset)
                        
                        if ([MemoryReader]::ReadProcessMemory($hProcess, $sampleAddr, $buffer, $sampleSize, [ref] $bytesRead)) {
                            $hits = Search-BufferForUnicodeStrings -Buffer $buffer[0..($bytesRead-1)] -SearchStrings $SearchStrings
                            
                            if ($hits.Count -gt 0) {
                                foreach ($hit in $hits) {
                                    $foundStrings += [PSCustomObject]@{
                                        Cheat = $hit.Cheat
                                        Address = "0x" + $sampleAddr.ToString("X")
                                        Source = "Java Heap"
                                        Encoding = $hit.Encoding
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            $address = [IntPtr]::Add($mbi.BaseAddress, $mbi.RegionSize)
        }
        
        [MemoryReader]::CloseHandle($hProcess)
        
    }
    catch {
        # Silent fail for heap scan
    }
    
    return $foundStrings
}

# Main execution
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Java Memory String Scanner" -ForegroundColor Magenta
Write-Host "  (System Informer Style - Unicode Scan)" -ForegroundColor Magenta
Write-Host "  by YarpLetapStan" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[*] Running as Administrator: YES" -ForegroundColor Green
Write-Host "[*] Scanning for UNICODE cheat strings (Java uses UTF-16)" -ForegroundColor Cyan
Write-Host "[*] Search strings: $($cheatStrings.Count)" -ForegroundColor Cyan
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
    Write-Host "  [*] This will scan memory like System Informer String Search..." -ForegroundColor Yellow
    Write-Host "  [*] Scanning Private/Image/Mapped regions for Unicode strings..." -ForegroundColor Yellow
    
    $detections = @()
    
    # 1. Full memory scan (like System Informer)
    $memoryDetections = Scan-ProcessMemoryLikeSystemInformer -Process $proc -SearchStrings $cheatStrings
    $detections += $memoryDetections
    
    # 2. Special Java heap scan
    $heapDetections = Scan-JavaHeapSpecific -Process $proc -SearchStrings $cheatStrings
    $detections += $heapDetections
    
    # Display results
    if ($detections.Count -eq 0) {
        Write-Host "  [✓] No cheat strings found" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] Found $($detections.Count) cheat string(s):" -ForegroundColor Red
        
        # Group by cheat and show details
        $grouped = $detections | Group-Object Cheat | Sort-Object Count -Descending
        
        foreach ($group in $grouped) {
            $cheatName = $group.Name
            $count = $group.Count
            $encodings = ($group.Group | Select-Object -ExpandProperty Encoding -Unique) -join "/"
            $sources = ($group.Group | Select-Object -ExpandProperty RegionType -Unique | Where-Object { $_ }) -join ", "
            
            Write-Host "      [$count×] $cheatName" -ForegroundColor Red
            if ($sources) {
                Write-Host "        Found in: $sources ($encodings)" -ForegroundColor Yellow
            }
        }
        
        $totalDetections += $detections.Count
        $allDetections += $detections
    }
    
    Write-Host ""
}

# Final report
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "           SCAN COMPLETE" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

if ($totalDetections -eq 0) {
    Write-Host "[✓] NO CHEAT STRINGS FOUND IN MEMORY" -ForegroundColor Green
    Write-Host "    Note: Cheats may use obfuscated names or different encodings" -ForegroundColor Gray
}
else {
    Write-Host "[X] CHEAT STRINGS DETECTED IN MEMORY!" -ForegroundColor Red
    Write-Host "    Found $totalDetections instances across $($processes.Count) process(es)" -ForegroundColor Red
    
    # Show top findings
    $topCheats = $allDetections | Group-Object Cheat | Sort-Object Count -Descending | Select-Object -First 5
    Write-Host ""
    Write-Host "  Most common findings:" -ForegroundColor Yellow
    foreach ($cheat in $topCheats) {
        Write-Host "    $($cheat.Name): $($cheat.Count) times" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "Scan Method: System Informer-style Unicode memory scan" -ForegroundColor Gray
Write-Host "Memory Regions: Private, Image, Mapped (all readable regions)" -ForegroundColor Gray
Write-Host "Encoding: UTF-16 Unicode (Java standard)" -ForegroundColor Gray
Write-Host ""

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
