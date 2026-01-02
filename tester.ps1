# JAR Cheat Scanner
# Scans JAR files for cheat strings and checks modification times
# Usage: powershell -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/YourUsername/YourRepo/main/JarCheatScanner.ps1)"

Clear-Host

# Cheat-related strings to search for
$cheatStrings = @(
    "autocrystal",
    "auto crystal",
    "cw crystal",
    "autohitcrystal",
    "autoanchor",
    "auto anchor",
    "anchortweaks",
    "anchor macro",
    "autototem",
    "auto totem",
    "legittotem",
    "inventorytotem",
    "hover totem",
    "autopot",
    "auto pot",
    "velocity",
    "autodoublehand",
    "auto double hand",
    "autoarmor",
    "auto armor",
    "automace",
    "aimassist",
    "aim assist",
    "triggerbot",
    "trigger bot",
    "shieldbreaker",
    "shield breaker",
    "axespam",
    "axe spam",
    "pingspoof",
    "ping spoof",
    "webmacro",
    "web macro",
    "selfdestruct",
    "self destruct",
    "hitboxes"
)

Write-Host "=== JAR Cheat Scanner ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for folder path
$FolderPath = Read-Host "Enter the folder path to scan for JAR files"

if ([string]::IsNullOrWhiteSpace($FolderPath)) {
    Write-Host "Error: No folder path provided" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Remove quotes if user pasted path with quotes
$FolderPath = $FolderPath.Trim('"').Trim("'")

# Validate folder path
if (-not (Test-Path -Path $FolderPath -PathType Container)) {
    Write-Host "Error: Folder path '$FolderPath' does not exist or is not a directory" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Scanning folder: $FolderPath" -ForegroundColor White
Write-Host ""

# Get javaw process start time
$javawProcess = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Sort-Object StartTime | Select-Object -First 1

if ($javawProcess) {
    $processStartTime = $javawProcess.StartTime
    Write-Host "Java process started at: $processStartTime" -ForegroundColor Green
} else {
    Write-Host "No javaw process currently running - will only scan for cheat strings" -ForegroundColor Yellow
    $processStartTime = $null
}

Write-Host ""

# Find all JAR files in the folder
$jarFiles = Get-ChildItem -Path $FolderPath -Filter "*.jar" -File -ErrorAction SilentlyContinue

if ($jarFiles.Count -eq 0) {
    Write-Host "No JAR files found in $FolderPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host "Found $($jarFiles.Count) JAR file(s) to scan" -ForegroundColor Cyan
Write-Host ""

# Function to extract and search JAR contents
function Search-JarFile {
    param($jarPath)
    
    $detections = @()
    
    try {
        # Load the JAR as a ZIP file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        
        foreach ($entry in $zip.Entries) {
            # Search in class files, source files, and config files
            if ($entry.Name -match '\.(class|java|txt|json|yml|yaml|properties|cfg|toml)$') {
                try {
                    $stream = $entry.Open()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $content = $reader.ReadToEnd().ToLower()
                    $reader.Close()
                    $stream.Close()
                    
                    foreach ($cheatString in $cheatStrings) {
                        if ($content -match [regex]::Escape($cheatString.ToLower())) {
                            $detections += "$cheatString (in $($entry.FullName))"
                        }
                    }
                }
                catch {
                    # Skip files that can't be read as text
                }
            }
        }
        
        $zip.Dispose()
    }
    catch {
        Write-Host "  Error reading JAR: $_" -ForegroundColor Red
    }
    
    return $detections
}

# Scan each JAR file
$suspiciousCount = 0
$modifiedCount = 0

foreach ($jar in $jarFiles) {
    Write-Host "Scanning: $($jar.Name)" -ForegroundColor White
    
    # Check modification time
    $wasModified = $false
    if ($processStartTime) {
        if ($jar.LastWriteTime -gt $processStartTime) {
            Write-Host "  [!] FILE MODIFIED AFTER JAVA STARTED" -ForegroundColor Red
            Write-Host "      Modified: $($jar.LastWriteTime)" -ForegroundColor Red
            $wasModified = $true
            $modifiedCount++
        } else {
            Write-Host "  [✓] Not modified since Java started" -ForegroundColor Green
        }
    }
    
    # Scan for cheat strings
    Write-Host "  Scanning contents..." -ForegroundColor Gray
    $detections = Search-JarFile -jarPath $jar.FullName
    
    if ($detections.Count -gt 0) {
        Write-Host "  [!] SUSPICIOUS STRINGS DETECTED ($($detections.Count)):" -ForegroundColor Red
        $uniqueDetections = $detections | Select-Object -Unique
        foreach ($detection in $uniqueDetections) {
            Write-Host "      - $detection" -ForegroundColor Yellow
        }
        $suspiciousCount++
    } else {
        Write-Host "  [✓] No suspicious strings found" -ForegroundColor Green
    }
    
    Write-Host ""
}

Write-Host "=== Scan Complete ===" -ForegroundColor Cyan
Write-Host "Total JAR files scanned: $($jarFiles.Count)" -ForegroundColor White
Write-Host "Files with suspicious strings: $suspiciousCount" -ForegroundColor $(if ($suspiciousCount -gt 0) { "Red" } else { "Green" })
if ($processStartTime) {
    Write-Host "Files modified after Java started: $modifiedCount" -ForegroundColor $(if ($modifiedCount -gt 0) { "Red" } else { "Green" })
}
Write-Host ""
Read-Host "Press Enter to exit"
