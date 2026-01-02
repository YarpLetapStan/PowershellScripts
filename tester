# JAR Cheat Scanner
# Scans JAR files for cheat strings and checks modification times

param(
    [Parameter(Mandatory=$false)]
    [string]$Path = ".",
    [Parameter(Mandatory=$false)]
    [switch]$Recursive
)

# Cheat-related strings to search for
$cheatStrings = @(
    "killaura",
    "antikb",
    "autoclick",
    "reach",
    "velocity",
    "scaffold",
    "fly",
    "speed",
    "bhop",
    "aimbot",
    "esp",
    "xray",
    "freecam",
    "noclip",
    "antiafk",
    "autotool",
    "fastbreak",
    "nuker",
    "phase",
    "step",
    "wallhack",
    "triggerbot",
    "autopotion",
    "criticals",
    "noslow",
    "legitmode",
    "blatant",
    "ghost",
    "inject"
)

Write-Host "=== JAR Cheat Scanner ===" -ForegroundColor Cyan
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

# Find JAR files
$searchParams = @{
    Path = $Path
    Filter = "*.jar"
}

if ($Recursive) {
    $searchParams.Add("Recurse", $true)
}

$jarFiles = Get-ChildItem @searchParams

if ($jarFiles.Count -eq 0) {
    Write-Host "No JAR files found in $Path" -ForegroundColor Red
    exit
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
            if ($entry.Name -match '\.(class|java|txt|json|yml|properties)$') {
                $stream = $entry.Open()
                $reader = New-Object System.IO.StreamReader($stream)
                $content = $reader.ReadToEnd().ToLower()
                $reader.Close()
                $stream.Close()
                
                foreach ($cheatString in $cheatStrings) {
                    if ($content -match $cheatString) {
                        $detections += "$cheatString (in $($entry.FullName))"
                    }
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
foreach ($jar in $jarFiles) {
    Write-Host "Scanning: $($jar.Name)" -ForegroundColor White
    
    # Check modification time
    if ($processStartTime) {
        if ($jar.LastWriteTime -gt $processStartTime) {
            Write-Host "  [!] FILE MODIFIED AFTER JAVA STARTED" -ForegroundColor Red
            Write-Host "      Modified: $($jar.LastWriteTime)" -ForegroundColor Red
        } else {
            Write-Host "  [✓] Not modified since Java started" -ForegroundColor Green
        }
    }
    
    # Scan for cheat strings
    Write-Host "  Scanning contents..." -ForegroundColor Gray
    $detections = Search-JarFile -jarPath $jar.FullName
    
    if ($detections.Count -gt 0) {
        Write-Host "  [!] SUSPICIOUS STRINGS DETECTED ($($detections.Count)):" -ForegroundColor Red
        foreach ($detection in $detections | Select-Object -Unique) {
            Write-Host "      - $detection" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [✓] No suspicious strings found" -ForegroundColor Green
    }
    
    Write-Host ""
}

Write-Host "=== Scan Complete ===" -ForegroundColor Cyan
