<#
.SYNOPSIS
YarpLetapStan Mod Analyzer - Scan and analyze Minecraft mod files
.DESCRIPTION
Analyze Minecraft mod folder, verify mod authenticity, detect cheat mods, compare file sizes
.AUTHOR
YarpLetapStan
.GITHUB
https://github.com/YarpLetapStan/PowershellScripts
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ModsFolder,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoPause = $false
)

# Script configuration
$SCRIPT_VERSION = "1.2.0"
$SCRIPT_NAME = "YarpLetapStan Mod Analyzer"

# Clear screen and display title
if ($Host.Name -eq "ConsoleHost") {
    Clear-Host
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Magenta
Write-Host "  $SCRIPT_NAME" -ForegroundColor Magenta
Write-Host "  Version $SCRIPT_VERSION" -ForegroundColor DarkGray
Write-Host "================================================" -ForegroundColor Magenta
Write-Host ""

# Function to get mods folder if not provided
function Get-ModsFolder {
    if ($ModsFolder) {
        return $ModsFolder
    }
    
    Write-Host "Enter path to the mods folder: " -ForegroundColor Cyan -NoNewline
    $inputPath = Read-Host
    
    if (-not $inputPath) {
        Write-Host "No path provided!" -ForegroundColor Red
        exit 1
    }
    
    return $inputPath
}

# Get mods folder
$mods = Get-ModsFolder

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid path! Please provide a valid folder path." -ForegroundColor Red
    exit 1
}

# Check for running Minecraft
$process = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $process) {
    $process = Get-Process java -ErrorAction SilentlyContinue
}

$startTime = $null

if ($process) {
    try {
        $startTime = $process.StartTime
        $elapsedTime = (Get-Date) - $startTime
    } catch {}

    Write-Host "{ Minecraft Uptime }" -ForegroundColor Cyan
    Write-Host "$($process.Name) PID $($process.Id) started at $startTime and running for $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s"
    Write-Host ""
}

# Core functions
function Get-SHA1 {
    param (
        [string]$filePath
    )
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash.ToLower()
}

function Get-ZoneIdentifier {
    param (
        [string]$filePath
    )
    try {
        $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
        if ($ads -match "HostUrl=(.+)") {
            return $matches[1]
        }
    } catch {}
    
    return $null
}

function Fetch-Modrinth-By-Filename {
    param (
        [string]$filename
    )
    try {
        # Extract clean mod name from filename
        $modName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        
        # Remove version numbers and platform indicators
        $cleanName = $modName -replace '[-_]\d+\.\d+\.\d+.*$', '' -replace '-fabric$', '' -replace '-forge$', '' -replace '-mc\d+.*$', ''
        
        # Search Modrinth API
        $searchUrl = "https://api.modrinth.com/v2/search?query=`"$cleanName`"&facets=`"[[`"project_type:mod`"]]`""
        Write-Host "  Searching Modrinth for: $cleanName" -ForegroundColor DarkGray
        $searchResponse = Invoke-RestMethod -Uri $searchUrl -Method Get -UseBasicParsing -ErrorAction Stop
        
        if ($searchResponse.hits -and $searchResponse.hits.Count -gt 0) {
            foreach ($hit in $searchResponse.hits) {
                $projectId = $hit.project_id
                
                # Get project versions
                $versionsUrl = "https://api.modrinth.com/v2/project/$projectId/version"
                $versionsResponse = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
                
                # Look for exact filename match
                foreach ($version in $versionsResponse) {
                    foreach ($file in $version.files) {
                        if ($file.filename -eq $filename) {
                            return @{
                                Found = $true
                                ModName = $hit.title
                                Version = $version.version_number
                                ExpectedSize = $file.size
                                FileName = $file.filename
                                ProjectSlug = $hit.slug
                                ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($version.id)"
                            }
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "  [WARN] API error for $filename" -ForegroundColor Yellow
    }
    
    return @{ Found = $false; ModName = ""; Version = ""; ExpectedSize = 0; FileName = "" }
}

function Fetch-Modrinth-By-Hash {
    param (
        [string]$hash
    )
    try {
        $url = "https://api.modrinth.com/v2/version_file/$hash?algorithm=sha1"
        Write-Host "  Checking hash on Modrinth: $hash" -ForegroundColor DarkGray
        $response = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing -ErrorAction Stop
        
        if ($response.project_id) {
            $projectUrl = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectUrl -Method Get -UseBasicParsing -ErrorAction Stop
            
            $fileData = $response.files | Where-Object { $_.hashes.sha1 -eq $hash } | Select-Object -First 1
            
            return @{ 
                Success = $true
                Name = $projectData.title
                Slug = $projectData.slug
                ExpectedSize = if ($fileData) { $fileData.size } else { 0 }
                VersionNumber = $response.version_number
                VersionName = $response.name
                ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($response.id)"
            }
        }
    } catch {
        # 404 is expected for unknown files
        if ($_.Exception.Response.StatusCode -ne 404) {
            Write-Host "  [WARN] Modrinth API error" -ForegroundColor Yellow
        }
    }
    
    return @{ Success = $false; Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; VersionName = "" }
}

# Cheat strings to detect
$cheatStrings = @(
    "autocrystal",
    "auto crystal",
    "cw crystal",
    "autototem",
    "auto totem",
    "autopot",
    "auto pot",
    "velocity",
    "aimassist",
    "aim assist",
    "triggerbot",
    "shieldbreaker",
    "shield breaker",
    "axespam",
    "axe spam",
    "pingspoof",
    "ping spoof",
    "killaura",
    "kill aura",
    "reach",
    "antikb",
    "anti knockback",
    "noslow",
    "no slow",
    "scaffold",
    "bhop",
    "bunnyhop",
    "freecam",
    "free cam",
    "xray",
    "x-ray"
)

function Check-Strings {
    param (
        [string]$filePath
    )
    
    $stringsFound = [System.Collections.Generic.HashSet[string]]::new()
    
    try {
        # Read file as binary for string search
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $fileText = [System.Text.Encoding]::ASCII.GetString($fileBytes)
        
        foreach ($string in $cheatStrings) {
            if ($fileText -match $string) {
                $stringsFound.Add($string) | Out-Null
            }
        }
    } catch {
        Write-Host "  [WARN] Could not read file" -ForegroundColor Yellow
    }
    
    return $stringsFound
}

# Main scanning logic
Write-Host "{ Scanning Mods }" -ForegroundColor Cyan
Write-Host "Folder: $mods" -ForegroundColor Gray

$jarFiles = Get-ChildItem -Path $mods -Filter *.jar -ErrorAction SilentlyContinue

if (-not $jarFiles -or $jarFiles.Count -eq 0) {
    Write-Host "No .jar files found in the specified folder!" -ForegroundColor Red
    if (-not $NoPause) {
        Write-Host "Press any key to exit..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit 1
}

Write-Host "Found $($jarFiles.Count) mod file(s)" -ForegroundColor Green
Write-Host ""

# Collections for results
$verifiedMods = @()
$unknownMods = @()
$cheatMods = @()
$modifiedMods = @()
$sizeMismatchMods = @()

$spinner = @("|", "/", "-", "\")
$totalMods = $jarFiles.Count
$counter = 0

foreach ($file in $jarFiles) {
    $counter++
    $spin = $spinner[$counter % $spinner.Length]
    Write-Host "`r[$spin] Scanning mods: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
    
    # Check if file was modified after Minecraft started
    if ($process -and $startTime -and $file.LastWriteTime -gt $startTime) {
        $modifiedMods += [PSCustomObject]@{ 
            FileName = $file.Name
            ModifiedTime = $file.LastWriteTime
            FilePath = $file.FullName
        }
    }
    
    $hash = Get-SHA1 -filePath $file.FullName
    $actualSize = $file.Length
    
    Write-Host "`n  File: $($file.Name)" -ForegroundColor Gray
    Write-Host "  Size: $([math]::Round($actualSize/1KB, 2)) KB" -ForegroundColor Gray
    
    # Try Modrinth by hash first (most accurate)
    $modData = Fetch-Modrinth-By-Hash -hash $hash
    
    if ($modData.Success) {
        $sizeDiff = $actualSize - $modData.ExpectedSize
        
        $verifiedMods += [PSCustomObject]@{ 
            ModName = $modData.Name
            FileName = $file.Name
            Version = $modData.VersionName
            ExpectedSize = $modData.ExpectedSize
            ActualSize = $actualSize
            SizeDiff = $sizeDiff
            ModrinthUrl = $modData.ModrinthUrl
        }
        
        if ($modData.ExpectedSize -gt 0 -and $actualSize -ne $modData.ExpectedSize) {
            $sizeMismatchMods += [PSCustomObject]@{
                FileName = $file.Name
                ModName = $modData.Name
                Version = $modData.VersionName
                ExpectedSize = $modData.ExpectedSize
                ActualSize = $actualSize
                SizeDiff = $sizeDiff
                Source = "Modrinth (Hash)"
                ModrinthUrl = $modData.ModrinthUrl
            }
        }
        
        Write-Host "  Status: Verified on Modrinth" -ForegroundColor Green
        Write-Host "  Mod: $($modData.Name) [$($modData.VersionName)]" -ForegroundColor Green
        
        if ($modData.ExpectedSize -gt 0) {
            if ($sizeDiff -eq 0) {
                Write-Host "  Size: ✓ Matches expected size" -ForegroundColor Green
            } else {
                Write-Host "  Size: ⚠ Mismatch - $(if ($sizeDiff -gt 0) { '+' } else { '' })$sizeDiff bytes" -ForegroundColor Yellow
            }
        }
        
        continue
    }
    
    # Try Modrinth by filename
    $filenameData = Fetch-Modrinth-By-Filename -filename $file.Name
    
    if ($filenameData.Found) {
        $sizeDiff = $actualSize - $filenameData.ExpectedSize
        
        $verifiedMods += [PSCustomObject]@{ 
            ModName = $filenameData.ModName
            FileName = $file.Name
            Version = $filenameData.Version
            ExpectedSize = $filenameData.ExpectedSize
            ActualSize = $actualSize
            SizeDiff = $sizeDiff
            ModrinthUrl = $filenameData.ModrinthUrl
        }
        
        if ($filenameData.ExpectedSize -gt 0 -and $actualSize -ne $filenameData.ExpectedSize) {
            $sizeMismatchMods += [PSCustomObject]@{
                FileName = $file.Name
                ModName = $filenameData.ModName
                Version = $filenameData.Version
                ExpectedSize = $filenameData.ExpectedSize
                ActualSize = $actualSize
                SizeDiff = $sizeDiff
                Source = "Modrinth (Filename)"
                ModrinthUrl = $filenameData.ModrinthUrl
            }
        }
        
        Write-Host "  Status: Verified on Modrinth" -ForegroundColor Green
        Write-Host "  Mod: $($filenameData.ModName) [$($filenameData.Version)]" -ForegroundColor Green
        
        if ($filenameData.ExpectedSize -gt 0) {
            if ($sizeDiff -eq 0) {
                Write-Host "  Size: ✓ Matches expected size" -ForegroundColor Green
            } else {
                Write-Host "  Size: ⚠ Mismatch - $(if ($sizeDiff -gt 0) { '+' } else { '' })$sizeDiff bytes" -ForegroundColor Yellow
            }
        }
        
        continue
    }
    
    # Check for Zone Identifier
    $zoneId = Get-ZoneIdentifier $file.FullName
    
    # Add to unknown mods
    $unknownMods += [PSCustomObject]@{ 
        FileName = $file.Name
        FilePath = $file.FullName
        ZoneId = $zoneId
        FileSize = $actualSize
        ExpectedSize = 0
        Note = "No API match found"
    }
    
    Write-Host "  Status: Unknown mod" -ForegroundColor Yellow
    if ($zoneId) {
        Write-Host "  Source: $zoneId" -ForegroundColor Gray
    }
}

# Scan unknown mods for cheat strings
if ($unknownMods.Count -gt 0) {
    Write-Host "`n{ Scanning Unknown Mods for Cheat Strings }" -ForegroundColor Cyan
    
    $counter = 0
    
    foreach ($mod in $unknownMods) {
        $counter++
        $spin = $spinner[$counter % $spinner.Length]
        Write-Host "`r[$spin] Scanning unknown mods: $counter / $($unknownMods.Count)" -ForegroundColor Magenta -NoNewline
        
        $modStrings = Check-Strings $mod.FilePath
        if ($modStrings.Count -gt 0) {
            $cheatMods += [PSCustomObject]@{ 
                FileName = $mod.FileName
                StringsFound = $modStrings
                FileSize = $mod.FileSize
                FilePath = $mod.FilePath
            }
        }
    }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# Display results
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan
Write-Host "=" * 60

if ($verifiedMods.Count -gt 0) {
    Write-Host "{ Verified Mods }" -ForegroundColor Green
    Write-Host "Total: $($verifiedMods.Count)"
    
    foreach ($mod in $verifiedMods) {
        if ($mod.ExpectedSize -gt 0 -and $mod.ActualSize -ne $mod.ExpectedSize) {
            Write-Host "  $($mod.ModName) [$($mod.Version)]" -ForegroundColor Gray
            Write-Host "    File: $($mod.FileName)" -ForegroundColor DarkGray
            Write-Host "    Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $(if ($mod.SizeDiff -gt 0) { '+' } else { '' })$($mod.SizeDiff) bytes" -ForegroundColor Magenta
        }
    }
    Write-Host ""
}

if ($sizeMismatchMods.Count -gt 0) {
    Write-Host "{ File Size Mismatches }" -ForegroundColor Yellow
    Write-Host "Total: $($sizeMismatchMods.Count)"
    
    foreach ($mod in $sizeMismatchMods) {
        Write-Host "  File: $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "    Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $(if ($mod.SizeDiff -gt 0) { '+' } else { '' })$($mod.SizeDiff) bytes" -ForegroundColor Magenta
        
        if ($mod.ModrinthUrl) {
            Write-Host "    Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)"
    
    foreach ($mod in $unknownMods) {
        Write-Host "  File: $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "    Size: $([math]::Round($mod.FileSize/1KB, 2)) KB" -ForegroundColor Gray
        
        if ($mod.ZoneId) {
            Write-Host "    Downloaded from: $($mod.ZoneId)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($cheatMods.Count -gt 0) {
    Write-Host "{ Cheat Mods Detected }" -ForegroundColor Red
    Write-Host "Total: $($cheatMods.Count) ⚠ WARNING"
    
    foreach ($mod in $cheatMods) {
        Write-Host "  File: $($mod.FileName)" -ForegroundColor Red
        Write-Host "    Strings: $($mod.StringsFound -join ', ')" -ForegroundColor Magenta
    }
    Write-Host ""
}

# Final summary
Write-Host "{ Final Summary }" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host "Total mods scanned: $totalMods" -ForegroundColor White
Write-Host "Verified mods: $($verifiedMods.Count)" -ForegroundColor Green
Write-Host "Unknown mods: $($unknownMods.Count)" -ForegroundColor $(if ($unknownMods.Count -gt 0) { "Yellow" } else { "Gray" })
Write-Host "Size mismatches: $($sizeMismatchMods.Count)" -ForegroundColor $(if ($sizeMismatchMods.Count -gt 0) { "Magenta" } else { "Gray" })
Write-Host "Cheat mods: $($cheatMods.Count)" -ForegroundColor $(if ($cheatMods.Count -gt 0) { "Red" } else { "Gray" })
Write-Host "=" * 60

# Generate report file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = "mod_report_$timestamp.txt"
$reportPath = Join-Path (Get-Location) $reportFile

$reportContent = @"
YarpLetapStan Mod Analyzer Report
Generated: $(Get-Date)
Version: $SCRIPT_VERSION
Mods Folder: $mods

SUMMARY
Total mods scanned: $totalMods
Verified mods: $($verifiedMods.Count)
Unknown mods: $($unknownMods.Count)
Size mismatches: $($sizeMismatchMods.Count)
Cheat mods detected: $($cheatMods.Count)

"@

if ($sizeMismatchMods.Count -gt 0) {
    $reportContent += "`nFILE SIZE MISMATCHES`n"
    $reportContent += "=" * 40 + "`n"
    
    foreach ($mod in $sizeMismatchMods) {
        $reportContent += "File: $($mod.FileName)`n"
        $reportContent += "Mod: $($mod.ModName) [$($mod.Version)]`n"
        $reportContent += "Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $(if ($mod.SizeDiff -gt 0) { '+' } else { '' })$($mod.SizeDiff) bytes`n"
        $reportContent += "`n"
    }
}

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Report saved to: $reportPath" -ForegroundColor Cyan

# Pause if requested
if (-not $NoPause) {
    Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
