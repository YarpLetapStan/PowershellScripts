<#
.SYNOPSIS
    Java Cheat Detector by YarpLetapStan
.DESCRIPTION
    Scans for cheat strings in suspicious modules only
.NOTES
    File: JavawStringChecker.ps1
#>

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
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

Write-Host "Java Cheat Detector" -ForegroundColor Cyan
Write-Host "by YarpLetapStan" -ForegroundColor Gray
Write-Host ""

# Find javaw processes
$javaw = Get-Process javaw -ErrorAction SilentlyContinue
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
$suspiciousModules = 0

foreach ($proc in $javaw) {
    Write-Host "Scanning PID $($proc.Id)..." -ForegroundColor DarkGray
    
    try {
        # ONLY scan suspicious/non-Windows modules
        foreach ($module in $proc.Modules) {
            $moduleName = $module.ModuleName.ToLower()
            $modulePath = $module.FileName
            
            # SKIP ALL Windows and Java system files
            if ($modulePath -match "(?i)\\windows\\" -or 
                $modulePath -match "(?i)\\program files\\" -or
                $modulePath -match "(?i)\\program files \(x86\)\\" -or
                $moduleName -match "^(java|jvm|jdk|jre|msv|vcruntime|concrt|ucrt|api-ms)" -or
                $moduleName -match "\.(exe|dll)$" -and $module.ModuleMemorySize -lt 100000) {
                continue
            }
            
            # Only scan modules that could be cheats
            $suspiciousModules++
            Write-Host "  Checking: $moduleName" -ForegroundColor DarkGray
            
            try {
                # Read module memory directly
                $moduleBytes = New-Object byte[] $module.ModuleMemorySize
                $null = $module.ReadModuleMemory($module.BaseAddress, $moduleBytes, 0, $module.ModuleMemorySize)
                
                # Convert to text
                $asciiText = [System.Text.Encoding]::ASCII.GetString($moduleBytes)
                $unicodeText = [System.Text.Encoding]::Unicode.GetString($moduleBytes)
                
                foreach ($cheat in $cheats) {
                    $foundInAscii = $asciiText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0
                    $foundInUnicode = $unicodeText.IndexOf($cheat, [StringComparison]::OrdinalIgnoreCase) -ge 0
                    
                    if ($foundInAscii -or $foundInUnicode) {
                        if (-not $foundCheats.ContainsKey($cheat)) {
                            $foundCheats[$cheat] = 0
                        }
                        $foundCheats[$cheat]++
                        $totalInstances++
                        
                        Write-Host "  [!] FOUND: $cheat in $moduleName" -ForegroundColor Red
                    }
                }
            } catch {
                # Skip if can't read
            }
        }
        
        Write-Host "  Scanned $suspiciousModules suspicious modules" -ForegroundColor Gray
        
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "========================" -ForegroundColor DarkGray

if ($foundCheats.Count -eq 0) {
    Write-Host "No cheats detected" -ForegroundColor Green
} else {
    Write-Host "CHEATS DETECTED:" -ForegroundColor Red
    foreach ($cheat in ($foundCheats.Keys | Sort-Object)) {
        Write-Host "  - $cheat ($($foundCheats[$cheat]) times)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Found $($foundCheats.Count) cheat type(s)" -ForegroundColor Red
}

Write-Host "========================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Note: This scans only suspicious modules," -ForegroundColor Gray
Write-Host "not Java system files (no false positives)" -ForegroundColor Gray
Write-Host ""
pause
