# JAR Cheat Scanner by YarpLetapStan
# Scans JAR files for cheat strings and checks modification times

Clear-Host

Write-Host "==================================" -ForegroundColor Magenta
Write-Host "   JAR Cheat Scanner" -ForegroundColor Cyan
Write-Host "   by YarpLetapStan" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Magenta
Write-Host ""

# Get javaw process and its start time
$javawProcess = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Sort-Object StartTime | Select-Object -First 1

if (-not $javawProcess) {
    Write-Host "[ERROR] No javaw process is currently running!" -ForegroundColor Red
    Write-Host "Please start Minecraft/Java and try again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$processStartTime = $javawProcess.StartTime
$processPath = $javawProcess.Path

Write-Host "[INFO] Found javaw process" -ForegroundColor Green
Write-Host "       Started at: $processStartTime" -ForegroundColor Gray
Write-Host "       Path: $processPath" -ForegroundColor Gray
Write-Host ""

# Try to determine mods folder from process path
$modsFolder = $null
if ($processPath -match "\.minecraft") {
    $minecraftPath = $processPath -replace "\\(bin|runtime)\\.*", ""
    $modsFolder = Join-Path $minecraftPath "mods"
}

# Prompt for folder path
if ($modsFolder -and (Test-Path $modsFolder)) {
    Write-Host "[DETECTED] Minecraft mods folder: $modsFolder" -ForegroundColor Cyan
    $useDetected = Read-Host "Use this folder? (Y/N)"
    if ($useDetected -eq "Y" -or $useDetected -eq "y" -or $useDetected -eq "") {
        $FolderPath = $modsFolder
    } else {
        $FolderPath = Read-Host "Enter folder path to scan"
    }
} else {
    $FolderPath = Read-Host "Enter folder path to scan for JAR files"
}

if ([string]::IsNullOrWhiteSpace($FolderPath)) {
    Write-Host "[ERROR] No folder path provided" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$FolderPath = $FolderPath.Trim('"').Trim("'")

if (-not (Test-Path -Path $FolderPath -PathType Container)) {
    Write-Host "[ERROR] Folder '$FolderPath' does not exist" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "[SCANNING] $FolderPath" -ForegroundColor Magenta
Write-Host ""

# Cheat strings to search for
$cheatStrings = @(
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

# Find JAR files
$jarFiles = Get-ChildItem -Path $FolderPath -Filter "*.jar" -File -ErrorAction SilentlyContinue

if ($jarFiles.Count -eq 0) {
    Write-Host "[WARNING] No JAR files found in folder" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host "[INFO] Found $($jarFiles.Count) JAR file(s)" -ForegroundColor Green
Write-Host ""

# Search function
function Search-JarFile {
    param($jarPath)
    
    $detections = @()
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        
        foreach ($entry in $zip.Entries) {
            if ($entry.Name -match '\.(class|java|txt|json|yml|yaml|properties|cfg|toml)$') {
                try {
                    $stream = $entry.Open()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $content = $reader.ReadToEnd().ToLower()
                    $reader.Close()
                    $stream.Close()
                    
                    foreach ($cheatString in $cheatStrings) {
                        if ($content -match [regex]::Escape($cheatString.ToLower())) {
                            $detections += "$cheatString"
                        }
                    }
                }
                catch { }
            }
        }
        
        $zip.Dispose()
    }
    catch { }
    
    return ($detections | Select-Object -Unique)
}

# Scan files
$suspiciousFiles = @()
$modifiedFiles = @()

foreach ($jar in $jarFiles) {
    Write-Host "► $($jar.Name)" -ForegroundColor White
    
    # Check if modified after javaw started
    if ($jar.LastWriteTime -gt $processStartTime) {
        Write-Host "  [!] MODIFIED AFTER JAVAW STARTED" -ForegroundColor Red
        Write-Host "      Last Modified: $($jar.LastWriteTime)" -ForegroundColor Yellow
        $modifiedFiles += $jar.Name
    } else {
        Write-Host "  [✓] File not modified since javaw started" -ForegroundColor Gray
    }
    
    # Scan contents
    $detections = Search-JarFile -jarPath $jar.FullName
    
    if ($detections.Count -gt 0) {
        Write-Host "  [!] CHEAT STRINGS DETECTED: $($detections.Count)" -ForegroundColor Red
        foreach ($detection in $detections) {
            Write-Host "      • $detection" -ForegroundColor Magenta
        }
        $suspiciousFiles += $jar.Name
    } else {
        Write-Host "  [✓] No suspicious strings found" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Summary
Write-Host "==================================" -ForegroundColor Magenta
Write-Host "   SCAN RESULTS" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Magenta
Write-Host "Total files scanned: $($jarFiles.Count)" -ForegroundColor White
Write-Host "Suspicious files: $($suspiciousFiles.Count)" -ForegroundColor $(if ($suspiciousFiles.Count -gt 0) { "Red" } else { "Green" })
Write-Host "Modified files: $($modifiedFiles.Count)" -ForegroundColor $(if ($modifiedFiles.Count -gt 0) { "Red" } else { "Green" })

if ($suspiciousFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "[FLAGGED FILES]" -ForegroundColor Red
    foreach ($file in $suspiciousFiles) {
        Write-Host "  • $file" -ForegroundColor Yellow
    }
}

if ($modifiedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "[MODIFIED FILES]" -ForegroundColor Red
    foreach ($file in $modifiedFiles) {
        Write-Host "  • $file" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Scan completed by YarpLetapStan" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
