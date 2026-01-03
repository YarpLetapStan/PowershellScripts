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
$SCRIPT_VERSION = "2.0.0"
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
        Write-Host "{ Minecraft Uptime }" -ForegroundColor Cyan
        Write-Host "$($process.Name) PID $($process.Id) started at $startTime and running for $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s"
        Write-Host ""
    } catch {}
}

# Core functions
function Get-SHA1 {
    param (
        [string]$filePath
    )
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash.ToLower()
}

function Get-Download-Source {
    param (
        [string]$filePath
    )
    try {
        $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
        if ($ads -match "HostUrl=(.+)") {
            $url = $matches[1]
            return $url
        }
    } catch {}
    
    return "Unknown"
}

function Fetch-Modrinth-Mod-Info {
    param (
        [string]$filename,
        [string]$hash
    )
    
    $result = @{
        Found = $false
        ModName = ""
        Version = ""
        ExpectedSize = 0
        ModrinthUrl = ""
        Source = "Unknown"
    }
    
    # Try by hash first (most accurate)
    if ($hash) {
        try {
            $url = "https://api.modrinth.com/v2/version_file/$hash?algorithm=sha1"
            $response = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing -ErrorAction Stop
            
            if ($response.project_id) {
                $projectUrl = "https://api.modrinth.com/v2/project/$($response.project_id)"
                $projectData = Invoke-RestMethod -Uri $projectUrl -Method Get -UseBasicParsing -ErrorAction Stop
                
                $fileData = $response.files | Where-Object { $_.hashes.sha1 -eq $hash } | Select-Object -First 1
                
                $result.Found = $true
                $result.ModName = $projectData.title
                $result.Version = $response.version_number
                $result.ExpectedSize = if ($fileData) { $fileData.size } else { 0 }
                $result.ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($response.id)"
                $result.Source = "Modrinth (Hash Verified)"
                
                return $result
            }
        } catch {
            # 404 is expected for unknown files
        }
    }
    
    # Try by filename if hash search failed
    try {
        # Extract mod name from filename
        $modName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        
        # Try to extract version from filename
        if ($modName -match '^(.*?)[-_](\d+\.\d+(?:\.\d+)?(?:-[a-zA-Z0-9]+)?)(?:-fabric|-forge|-neoforge)?$') {
            $cleanName = $matches[1]
            $versionGuess = $matches[2]
            
            # Search Modrinth
            $searchUrl = "https://api.modrinth.com/v2/search?query=`"$cleanName`"&facets=`"[[`"project_type:mod`"]]`""
            $searchResponse = Invoke-RestMethod -Uri $searchUrl -Method Get -UseBasicParsing -ErrorAction Stop
            
            if ($searchResponse.hits -and $searchResponse.hits.Count -gt 0) {
                $hit = $searchResponse.hits[0]
                $projectId = $hit.project_id
                
                # Get all versions
                $versionsUrl = "https://api.modrinth.com/v2/project/$projectId/version"
                $versionsResponse = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
                
                # Look for matching filename
                foreach ($version in $versionsResponse) {
                    foreach ($file in $version.files) {
                        if ($file.filename -eq $filename) {
                            $result.Found = $true
                            $result.ModName = $hit.title
                            $result.Version = $version.version_number
                            $result.ExpectedSize = $file.size
                            $result.ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($version.id)"
                            $result.Source = "Modrinth (Filename Match)"
                            
                            return $result
                        }
                    }
                }
                
                # If no exact filename match, return closest match
                $result.Found = $true
                $result.ModName = $hit.title
                $result.Version = "Unknown"
                $result.ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)"
                $result.Source = "Modrinth (Similar Name)"
                
                return $result
            }
        }
    } catch {
        # API call failed
    }
    
    return $result
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
$knownMods = @()      # Verified on Modrinth
$unknownMods = @()    # Not on Modrinth or unknown source
$sizeMismatches = @() # Files with size differences

$spinner = @("|", "/", "-", "\")
$totalMods = $jarFiles.Count
$counter = 0

foreach ($file in $jarFiles) {
    $counter++
    $spin = $spinner[$counter % $spinner.Length]
    Write-Host "`r[$spin] Scanning: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
    
    $hash = Get-SHA1 -filePath $file.FullName
    $actualSize = $file.Length
    $downloadSource = Get-Download-Source -filePath $file.FullName
    
    Write-Host "`n  File: $($file.Name)" -ForegroundColor Gray
    
    # Get Modrinth info
    $modInfo = Fetch-Modrinth-Mod-Info -filename $file.Name -hash $hash
    
    if ($modInfo.Found) {
        # This is a KNOWN mod (on Modrinth)
        $sizeDiff = $actualSize - $modInfo.ExpectedSize
        
        $modData = [PSCustomObject]@{
            ModName = $modInfo.ModName
            FileName = $file.Name
            Version = $modInfo.Version
            ExpectedSize = $modInfo.ExpectedSize
            ActualSize = $actualSize
            SizeDiff = $sizeDiff
            Source = $modInfo.Source
            DownloadSource = $downloadSource
            ModrinthUrl = $modInfo.ModrinthUrl
        }
        
        $knownMods += $modData
        
        if ($modInfo.ExpectedSize -gt 0 -and $actualSize -ne $modInfo.ExpectedSize) {
            $sizeMismatches += $modData
        }
        
        Write-Host "  Status: Verified on Modrinth" -ForegroundColor Green
        Write-Host "  Mod: $($modInfo.ModName) [$($modInfo.Version)]" -ForegroundColor Green
        
        if ($downloadSource -ne "Unknown") {
            if ($downloadSource -match "modrinth\.com") {
                Write-Host "  Downloaded from: Modrinth" -ForegroundColor Green
            } else {
                Write-Host "  Downloaded from: Other Source" -ForegroundColor Yellow
            }
        }
        
        if ($modInfo.ExpectedSize -gt 0) {
            if ($sizeDiff -eq 0) {
                Write-Host "  Size: ✓ Matches expected size" -ForegroundColor Green
            } else {
                Write-Host "  Size: ⚠ Mismatch - $(if ($sizeDiff -gt 0) { '+' } else { '' })$sizeDiff bytes" -ForegroundColor Yellow
            }
        }
    } else {
        # This is an UNKNOWN mod (not on Modrinth)
        $unknownMods += [PSCustomObject]@{
            FileName = $file.Name
            FilePath = $file.FullName
            FileSize = $actualSize
            DownloadSource = $downloadSource
            Hash = $hash
            Note = "Not found on Modrinth"
        }
        
        Write-Host "  Status: Unknown mod" -ForegroundColor Yellow
        Write-Host "  Size: $([math]::Round($actualSize/1KB, 2)) KB" -ForegroundColor Gray
        
        if ($downloadSource -ne "Unknown") {
            if ($downloadSource -match "modrinth\.com") {
                Write-Host "  Downloaded from: Modrinth" -ForegroundColor Green
            } else {
                Write-Host "  Downloaded from: $downloadSource" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# Display results
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan
Write-Host "=" * 70

if ($knownMods.Count -gt 0) {
    Write-Host "{ Known Mods (On Modrinth) }" -ForegroundColor Green
    Write-Host "Total: $($knownMods.Count)"
    Write-Host "-" * 40
    
    foreach ($mod in $knownMods) {
        Write-Host "✓ $($mod.ModName)" -ForegroundColor Green -NoNewline
        Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray
        
        if ($mod.DownloadSource -ne "Unknown") {
            $sourceColor = if ($mod.DownloadSource -match "modrinth\.com") { "Green" } else { "Yellow" }
            Write-Host "  Downloaded from: $(if ($mod.DownloadSource -match 'modrinth\.com') { 'Modrinth' } else { 'Other Source' })" -ForegroundColor $sourceColor
        }
        
        Write-Host "  File: $($mod.FileName)" -ForegroundColor DarkGray
        
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                Write-Host "  Size: $([math]::Round($mod.ActualSize/1KB, 2)) KB ✓" -ForegroundColor Green
            } else {
                $sizeDiffText = if ($mod.SizeDiff -gt 0) { "+$($mod.SizeDiff) bytes" } else { "$($mod.SizeDiff) bytes" }
                Write-Host "  Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $sizeDiffText" -ForegroundColor Magenta
            }
        }
        Write-Host ""
    }
}

if ($sizeMismatches.Count -gt 0) {
    Write-Host "{ File Size Mismatches }" -ForegroundColor Magenta
    Write-Host "Total: $($sizeMismatches.Count)"
    Write-Host "-" * 40
    
    foreach ($mod in $sizeMismatches) {
        $sizeDiffText = if ($mod.SizeDiff -gt 0) { "+$($mod.SizeDiff) bytes" } else { "$($mod.SizeDiff) bytes" }
        Write-Host "File: $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Mod: $($mod.ModName) [$($mod.Version)]" -ForegroundColor Gray
        Write-Host "  Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $sizeDiffText" -ForegroundColor Magenta
        
        if ($mod.ModrinthUrl) {
            Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods (Not on Modrinth) }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)"
    Write-Host "-" * 40
    
    foreach ($mod in $unknownMods) {
        Write-Host "⚠ $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Size: $([math]::Round($mod.FileSize/1KB, 2)) KB" -ForegroundColor Gray
        
        if ($mod.DownloadSource -ne "Unknown") {
            if ($mod.DownloadSource -match "modrinth\.com") {
                Write-Host "  Downloaded from: Modrinth" -ForegroundColor Green
                Write-Host "  Note: File not found on Modrinth API" -ForegroundColor Magenta
            } else {
                Write-Host "  Downloaded from: $($mod.DownloadSource)" -ForegroundColor Yellow
                Write-Host "  Note: Downloaded from non-Modrinth source" -ForegroundColor Magenta
            }
        } else {
            Write-Host "  Source: Unknown (no download history)" -ForegroundColor DarkGray
        }
        
        Write-Host "  Hash: $($mod.Hash)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Final summary
Write-Host "{ Final Summary }" -ForegroundColor Cyan
Write-Host "=" * 70
Write-Host "Total mods scanned: $totalMods" -ForegroundColor White
Write-Host "Known Mods (on Modrinth): $($knownMods.Count)" -ForegroundColor Green
Write-Host "Unknown Mods (not on Modrinth): $($unknownMods.Count)" -ForegroundColor $(if ($unknownMods.Count -gt 0) { "Yellow" } else { "Gray" })
Write-Host "File size mismatches: $($sizeMismatches.Count)" -ForegroundColor $(if ($sizeMismatches.Count -gt 0) { "Magenta" } else { "Gray" })
Write-Host "=" * 70

# Generate detailed report file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = "mod_analysis_report_$timestamp.txt"
$reportPath = Join-Path (Get-Location) $reportFile

$reportContent = @"
YarpLetapStan Mod Analyzer Report
Generated: $(Get-Date)
Version: $SCRIPT_VERSION
Mods Folder: $mods
Total mods scanned: $totalMods

SUMMARY
Known Mods (on Modrinth): $($knownMods.Count)
Unknown Mods (not on Modrinth): $($unknownMods.Count)
File size mismatches: $($sizeMismatches.Count)

"@

if ($knownMods.Count -gt 0) {
    $reportContent += "`nKNOWN MODS (ON MODRINTH)`n"
    $reportContent += "=" * 50 + "`n"
    
    foreach ($mod in $knownMods) {
        $reportContent += "✓ $($mod.ModName) [$($mod.Version)]`n"
        $reportContent += "  File: $($mod.FileName)`n"
        
        if ($mod.DownloadSource -ne "Unknown") {
            $source = if ($mod.DownloadSource -match "modrinth\.com") { "Modrinth" } else { "Other Source" }
            $reportContent += "  Downloaded from: $source`n"
        }
        
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                $reportContent += "  Size: $([math]::Round($mod.ActualSize/1KB, 2)) KB ✓`n"
            } else {
                $sizeDiffText = if ($mod.SizeDiff -gt 0) { "+$($mod.SizeDiff) bytes" } else { "$($mod.SizeDiff) bytes" }
                $reportContent += "  Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $sizeDiffText`n"
            }
        }
        $reportContent += "`n"
    }
}

if ($sizeMismatches.Count -gt 0) {
    $reportContent += "`nFILE SIZE MISMATCHES`n"
    $reportContent += "=" * 50 + "`n"
    
    foreach ($mod in $sizeMismatches) {
        $sizeDiffText = if ($mod.SizeDiff -gt 0) { "+$($mod.SizeDiff) bytes" } else { "$($mod.SizeDiff) bytes" }
        $reportContent += "File: $($mod.FileName)`n"
        $reportContent += "Mod: $($mod.ModName) [$($mod.Version)]`n"
        $reportContent += "Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $sizeDiffText`n"
        
        if ($mod.ModrinthUrl) {
            $reportContent += "Verify: $($mod.ModrinthUrl)`n"
        }
        $reportContent += "`n"
    }
}

if ($unknownMods.Count -gt 0) {
    $reportContent += "`nUNKNOWN MODS (NOT ON MODRINTH)`n"
    $reportContent += "=" * 50 + "`n"
    
    foreach ($mod in $unknownMods) {
        $reportContent += "⚠ $($mod.FileName)`n"
        $reportContent += "  Size: $([math]::Round($mod.FileSize/1KB, 2)) KB`n"
        
        if ($mod.DownloadSource -ne "Unknown") {
            if ($mod.DownloadSource -match "modrinth\.com") {
                $reportContent += "  Downloaded from: Modrinth (but file not found in API)`n"
            } else {
                $reportContent += "  Downloaded from: $($mod.DownloadSource)`n"
                $reportContent += "  Note: Downloaded from non-Modrinth source`n"
            }
        } else {
            $reportContent += "  Source: Unknown (no download history)`n"
        }
        
        $reportContent += "  Hash: $($mod.Hash)`n"
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
