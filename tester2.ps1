Clear-Host
Write-Host "YarpLetapStan's Mod Analyzer" -ForegroundColor Magenta
Write-Host "Made by " -ForegroundColor DarkGray -NoNewline
Write-Host "YarpLetapStan"
Write-Host

Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray
$mods = Read-Host "PATH"
Write-Host

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host "Continuing with " -NoNewline
    Write-Host $mods -ForegroundColor White
    Write-Host
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    exit 1
}

$process = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $process) {
    $process = Get-Process java -ErrorAction SilentlyContinue
}

if ($process) {
    try {
        $startTime = $process.StartTime
        $elapsedTime = (Get-Date) - $startTime
    } catch {}

    Write-Host "{ Minecraft Uptime }" -ForegroundColor Cyan
    Write-Host "$($process.Name) PID $($process.Id) started at $startTime and running for $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s"
    Write-Host ""
}

function Get-SHA1 {
    param (
        [string]$filePath
    )
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash
}

function Get-ZoneIdentifier {
    param (
        [string]$filePath
    )
    try {
        $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
        if ($ads -match "HostUrl=(.+)") {
            $url = $matches[1]
            
            # Classify download source
            if ($url -match "modrinth\.com") {
                return @{ Source = "Modrinth"; URL = $url; IsModrinth = $true }
            }
            elseif ($url -match "curseforge\.com") {
                return @{ Source = "CurseForge"; URL = $url; IsModrinth = $false }
            }
            elseif ($url -match "github\.com") {
                return @{ Source = "GitHub"; URL = $url; IsModrinth = $false }
            }
            else {
                return @{ Source = "Other"; URL = $url; IsModrinth = $false }
            }
        }
    } catch {}
    
    return @{ Source = "Unknown"; URL = ""; IsModrinth = $false }
}

function Fetch-Modrinth-By-Hash {
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if ($response.project_id) {
            $projectResponse = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectResponse -Method Get -UseBasicParsing -ErrorAction Stop
            
            # Get file info with size
            $fileInfo = $response.files[0]
            
            return @{ 
                Name = $projectData.title
                Slug = $projectData.slug
                ExpectedSize = $fileInfo.size
                VersionNumber = $response.version_number
                FileName = $fileInfo.filename
                ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($response.id)"
                FoundByHash = $true
            }
        }
    } catch {}
    
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false }
}

function Fetch-Modrinth-By-Filename {
    param (
        [string]$filename
    )
    try {
        # Clean the filename by removing .temp and other non-standard parts
        $cleanFilename = $filename -replace '\.temp\.jar$', '.jar' -replace '\.tmp\.jar$', '.jar'
        $modName = [System.IO.Path]::GetFileNameWithoutExtension($cleanFilename)
        
        # IMPROVED: Better pattern matching for various mod filename formats
        $modPatterns = @(
            # Pattern for modname-version.jar (like krypton-0.2.8.jar)
            '^([a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*?)-(\d+\.\d+(?:\.\d+)?(?:-[a-zA-Z0-9]+)?)$',
            
            # Pattern for modname-mcversion-version.jar
            '^([a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*?)-mc(\d+\.\d+(?:\.\d+)?)-(\d+\.\d+(?:\.\d+)?)$',
            
            # Pattern for fabric/forge mods
            '^([a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*?)-(\d+\.\d+(?:\.\d+)?)\+mc(\d+\.\d+(?:\.\d+)?)$',
            
            # Simple pattern - just get everything before the first version number
            '^([a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*?)-\d'
        )
        
        $baseModName = ""
        
        foreach ($pattern in $modPatterns) {
            if ($modName -match $pattern) {
                $baseModName = $matches[1]
                break
            }
        }
        
        # If no pattern matched, use simple cleanup
        if (-not $baseModName) {
            # Remove version numbers and common suffixes
            $baseModName = $modName -replace '-\d+.*$', '' -replace '_[^_]*$', ''
        }
        
        # Clean up common loader prefixes/suffixes
        $baseModName = $baseModName -replace '^fabric-', '' -replace '^forge-', '' -replace '-fabric$', '' -replace '-forge$', '' -replace '-neoforge$', ''
        
        # If name is too short or suspicious, return empty
        if ($baseModName.Length -lt 3) {
            return @{ 
                Name = ""; 
                Slug = ""; 
                ExpectedSize = 0; 
                VersionNumber = ""; 
                FileName = ""; 
                FoundByHash = $false;
                ExactMatch = $false;
                IsLatestVersion = $false
            }
        }
        
        # Search Modrinth with the cleaned name
        $searchUrl = "https://api.modrinth.com/v2/search?query=`"$baseModName`"&facets=`"[[`"project_type:mod`"]]`"&limit=20"
        $searchResponse = Invoke-RestMethod -Uri $searchUrl -Method Get -UseBasicParsing -ErrorAction Stop
        
        if ($searchResponse.hits -and $searchResponse.hits.Count -gt 0) {
            # Try each search result
            foreach ($hit in $searchResponse.hits) {
                $projectId = $hit.project_id
                $hitTitle = $hit.title
                $hitSlug = $hit.slug
                
                # Check if the slug or title closely matches our base mod name
                $normalizedHitSlug = $hitSlug -replace '-', ''
                $normalizedBaseName = $baseModName -replace '-', ''
                
                # Skip if the names don't match reasonably well
                if ($normalizedBaseName.Length -gt 3 -and 
                    $normalizedHitSlug -notmatch $normalizedBaseName -and 
                    $hitTitle -notmatch $baseModName) {
                    continue
                }
                
                # Get all versions for this project
                $versionsUrl = "https://api.modrinth.com/v2/project/$projectId/version"
                $versionsResponse = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
                
                # First, try to find exact filename match (without .temp)
                foreach ($version in $versionsResponse) {
                    foreach ($file in $version.files) {
                        if ($file.filename -eq $cleanFilename -or $file.filename -eq $filename) {
                            return @{
                                Name = $hitTitle
                                Slug = $hitSlug
                                ExpectedSize = $file.size
                                VersionNumber = $version.version_number
                                FileName = $file.filename
                                ModrinthUrl = "https://modrinth.com/mod/$hitSlug/version/$($version.id)"
                                FoundByHash = $false
                                ExactMatch = $true
                            }
                        }
                    }
                }
                
                # Try to find version by version number from filename
                # Extract version from filename
                $fileVersion = ""
                if ($modName -match '(\d+\.\d+(?:\.\d+)?(?:-[a-zA-Z0-9]+)?)') {
                    $fileVersion = $matches[1]
                }
                
                if ($fileVersion) {
                    foreach ($version in $versionsResponse) {
                        # Check if version numbers match (allowing for some variation)
                        $cleanVersion = $version.version_number -replace '[^0-9.]', ''
                        $cleanFileVersion = $fileVersion -replace '[^0-9.]', ''
                        
                        if ($cleanFileVersion -eq $cleanVersion) {
                            # Use the first file from this version
                            $file = $version.files[0]
                            return @{
                                Name = $hitTitle
                                Slug = $hitSlug
                                ExpectedSize = $file.size
                                VersionNumber = $version.version_number
                                FileName = $file.filename
                                ModrinthUrl = "https://modrinth.com/mod/$hitSlug/version/$($version.id)"
                                FoundByHash = $false
                                ExactMatch = $false
                            }
                        }
                    }
                }
                
                # Return the latest version as a best guess
                if ($versionsResponse.Count -gt 0) {
                    $latestVersion = $versionsResponse[0]
                    $latestFile = $latestVersion.files[0]
                    
                    return @{
                        Name = $hitTitle
                        Slug = $hitSlug
                        ExpectedSize = $latestFile.size
                        VersionNumber = $latestVersion.version_number
                        FileName = $latestFile.filename
                        ModrinthUrl = "https://modrinth.com/mod/$hitSlug/version/$($latestVersion.id)"
                        FoundByHash = $false
                        ExactMatch = $false
                        IsLatestVersion = $true
                    }
                }
            }
        }
        
    } catch {
        # Silently handle API errors
    }
    
    return @{ 
        Name = ""; 
        Slug = ""; 
        ExpectedSize = 0; 
        VersionNumber = ""; 
        FileName = ""; 
        FoundByHash = $false;
        ExactMatch = $false;
        IsLatestVersion = $false
    }
}

function Fetch-Megabase {
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if (-not $response.error) {
            return $response.data
        }
    } catch {}
    
    return $null
}

$cheatStrings = @(
    "AimAssist",
    "AnchorTweaks",
    "AutoAnchor",
    "AutoCrystal",
    "AutoDoubleHand",
    "AutoHitCrystal",
    "AutoPot",
    "AutoTotem",
    "AutoArmor",
    "InventoryTotem",
    "Hitboxes",
    "JumpReset",
    "LegitTotem",
    "PingSpoof",
    "SelfDestruct",
    "ShieldBreaker",
    "TriggerBot",
    "Velocity",
    "AxeSpam",
    "WebMacro",
    "FastPlace",
    "KillAura",
    "Reach",
    "NoSlow",
    "Bhop",
    "Phase",
    "Freecam",
    "Xray"
)

function Check-Strings {
    param (
        [string]$filePath
    )
    
    $stringsFound = [System.Collections.Generic.HashSet[string]]::new()
    
    try {
        $fileContent = Get-Content -Raw $filePath
        foreach ($string in $cheatStrings) {
            if ($fileContent -match $string) {
                $stringsFound.Add($string) | Out-Null
            }
        }
    } catch {}
    
    return $stringsFound
}

# Collections for results
$verifiedMods = @()
$unknownMods = @()
$cheatMods = @()
$sizeMismatchMods = @()

$jarFiles = Get-ChildItem -Path $mods -Filter *.jar

$spinner = @("|", "/", "-", "\")
$totalMods = $jarFiles.Count
$counter = 0

foreach ($file in $jarFiles) {
    $counter++
    $spin = $spinner[$counter % $spinner.Length]
    Write-Host "`r[$spin] Scanning mods: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
    
    # Get file info
    $hash = Get-SHA1 -filePath $file.FullName
    $actualSize = $file.Length
    $actualSizeKB = [math]::Round($actualSize/1KB, 2)
    $zoneInfo = Get-ZoneIdentifier $file.FullName
    
    # ALWAYS try to get Modrinth info by filename (for ALL mods)
    $modrinthInfo = Fetch-Modrinth-By-Filename -filename $file.Name
    
    # Try Modrinth by hash first (most accurate)
    $modData = Fetch-Modrinth-By-Hash -hash $hash
    
    if ($modData.Name -and $modData.FoundByHash) {
        # Calculate size difference
        $sizeDiff = $actualSize - $modData.ExpectedSize
        $sizeDiffText = if ($sizeDiff -gt 0) { "+$sizeDiff bytes" } else { "$sizeDiff bytes" }
        $expectedSizeKB = [math]::Round($modData.ExpectedSize/1KB, 2)
        
        $modEntry = [PSCustomObject]@{ 
            ModName = $modData.Name
            FileName = $file.Name
            Version = $modData.VersionNumber
            ExpectedSize = $modData.ExpectedSize
            ExpectedSizeKB = $expectedSizeKB
            ActualSize = $actualSize
            ActualSizeKB = $actualSizeKB
            SizeDiff = $sizeDiff
            SizeDiffText = $sizeDiffText
            SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modData.ModrinthUrl
            VerifiedBy = "Hash"
            IsVerified = $true
        }
        
        $verifiedMods += $modEntry
        
        # Check for size mismatch
        if ($modData.ExpectedSize -gt 0 -and $actualSize -ne $modData.ExpectedSize) {
            $sizeMismatchMods += $modEntry
        }
        
        continue
    }
    
    # Check if we found mod info by filename
    if ($modrinthInfo.Name) {
        # Calculate size difference
        $sizeDiff = $actualSize - $modrinthInfo.ExpectedSize
        $sizeDiffText = if ($sizeDiff -gt 0) { "+$sizeDiff bytes" } else { "$sizeDiff bytes" }
        $expectedSizeKB = if ($modrinthInfo.ExpectedSize -gt 0) { [math]::Round($modrinthInfo.ExpectedSize/1KB, 2) } else { 0 }
        
        $modEntry = [PSCustomObject]@{ 
            ModName = $modrinthInfo.Name
            FileName = $file.Name
            Version = $modrinthInfo.VersionNumber
            ExpectedSize = $modrinthInfo.ExpectedSize
            ExpectedSizeKB = $expectedSizeKB
            ActualSize = $actualSize
            ActualSizeKB = $actualSizeKB
            SizeDiff = $sizeDiff
            SizeDiffText = $sizeDiffText
            SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modrinthInfo.ModrinthUrl
            VerifiedBy = "Filename"
            IsVerified = $true
            ExactMatch = $modrinthInfo.ExactMatch
            IsLatestVersion = $modrinthInfo.IsLatestVersion
        }
        
        $verifiedMods += $modEntry
        
        # Check for size mismatch
        if ($modrinthInfo.ExpectedSize -gt 0 -and $actualSize -ne $modrinthInfo.ExpectedSize) {
            $sizeMismatchMods += $modEntry
        }
        
        continue
    }
    
    # Try Megabase as fallback
    $megabaseData = Fetch-Megabase -hash $hash
    if ($megabaseData -and $megabaseData.name) {
        # Even for Megabase mods, try to get size info from Modrinth by filename
        $expectedSize = 0
        $expectedSizeKB = 0
        $sizeDiff = 0
        $sizeDiffText = "N/A"
        
        if ($modrinthInfo.Name -and $modrinthInfo.ExpectedSize -gt 0) {
            $expectedSize = $modrinthInfo.ExpectedSize
            $expectedSizeKB = [math]::Round($modrinthInfo.ExpectedSize/1KB, 2)
            $sizeDiff = $actualSize - $expectedSize
            $sizeDiffText = if ($sizeDiff -gt 0) { "+$sizeDiff bytes" } else { "$sizeDiff bytes" }
        }
        
        $verifiedMods += [PSCustomObject]@{ 
            ModName = $megabaseData.name
            FileName = $file.Name
            Version = "Unknown"
            ExpectedSize = $expectedSize
            ExpectedSizeKB = $expectedSizeKB
            ActualSize = $actualSize
            ActualSizeKB = $actualSizeKB
            SizeDiff = $sizeDiff
            SizeDiffText = $sizeDiffText
            SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            VerifiedBy = "Megabase"
            IsVerified = $true
        }
        continue
    }
    
    # If we get here, it's an unknown mod
    # But we still might have Modrinth info from filename search
    $expectedSize = 0
    $expectedSizeKB = 0
    $sizeDiff = 0
    $sizeDiffText = "N/A"
    $sizeDiffKB = 0
    
    if ($modrinthInfo.Name -and $modrinthInfo.ExpectedSize -gt 0) {
        $expectedSize = $modrinthInfo.ExpectedSize
        $expectedSizeKB = [math]::Round($modrinthInfo.ExpectedSize/1KB, 2)
        $sizeDiff = $actualSize - $expectedSize
        $sizeDiffText = if ($sizeDiff -gt 0) { "+$sizeDiff bytes" } else { "$sizeDiff bytes" }
        $sizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
    }
    
    $unknownMods += [PSCustomObject]@{ 
        FileName = $file.Name
        FilePath = $file.FullName
        ZoneId = $zoneInfo.URL
        DownloadSource = $zoneInfo.Source
        IsModrinthDownload = $zoneInfo.IsModrinth
        FileSize = $actualSize
        FileSizeKB = $actualSizeKB
        Hash = $hash
        ModrinthName = $modrinthInfo.Name
        ExpectedSize = $expectedSize
        ExpectedSizeKB = $expectedSizeKB
        SizeDiff = $sizeDiff
        SizeDiffText = $sizeDiffText
        SizeDiffKB = $sizeDiffKB
        ModrinthUrl = $modrinthInfo.ModrinthUrl
        HasSizeInfo = ($modrinthInfo.ExpectedSize -gt 0)
        IsLatestVersion = $modrinthInfo.IsLatestVersion
    }
}

# Scan unknown mods for cheat strings
if ($unknownMods.Count -gt 0) {
    $tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"
    
    $counter = 0
    
    try {
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
        
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        
        foreach ($mod in $unknownMods) {
            $counter++
            $spin = $spinner[$counter % $spinner.Length]
            Write-Host "`r[$spin] Scanning unknown mods for cheat strings..." -ForegroundColor Magenta -NoNewline
            
            $modStrings = Check-Strings $mod.FilePath
            if ($modStrings.Count -gt 0) {
                $cheatMods += [PSCustomObject]@{ 
                    FileName = $mod.FileName
                    StringsFound = $modStrings
                    FileSizeKB = $mod.FileSizeKB
                    DownloadSource = $mod.DownloadSource
                    SourceURL = $mod.ZoneId
                    ExpectedSizeKB = $mod.ExpectedSizeKB
                    SizeDiffKB = $mod.SizeDiffKB
                }
            }
        }
    } catch {
        Write-Host "`nError occurred while scanning: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# Display results
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan
Write-Host "=" * 80

if ($verifiedMods.Count -gt 0) {
    Write-Host "{ Verified Mods }" -ForegroundColor Cyan
    Write-Host "Total: $($verifiedMods.Count)"
    Write-Host "-" * 60
    
    foreach ($mod in $verifiedMods) {
        Write-Host ("> {0, -25}" -f $mod.ModName) -ForegroundColor Green -NoNewline
        Write-Host "$($mod.FileName)" -ForegroundColor Gray -NoNewline
        
        # Version if available
        if ($mod.Version -and $mod.Version -ne "Unknown") {
            Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray -NoNewline
        }
        
        # Download source info
        if ($mod.DownloadSource -ne "Unknown") {
            $sourceColor = if ($mod.IsModrinthDownload) { "Green" } else { "Yellow" }
            Write-Host " ($($mod.DownloadSource))" -ForegroundColor $sourceColor
        } else {
            Write-Host ""
        }
        
        # Size comparison
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                Write-Host "  Size: $($mod.ActualSizeKB) KB ✓ Matches Modrinth" -ForegroundColor Green
            } else {
                $sizeDiffSign = if ($mod.SizeDiff -gt 0) { "+" } else { "" }
                Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB ($($mod.SizeDiffText))" -ForegroundColor Yellow
            }
        }
    }
    Write-Host ""
}

if ($sizeMismatchMods.Count -gt 0) {
    Write-Host "{ File Size Mismatches }" -ForegroundColor Yellow
    Write-Host "Total: $($sizeMismatchMods.Count)"
    Write-Host "-" * 60
    
    foreach ($mod in $sizeMismatchMods) {
        $sizeDiffSign = if ($mod.SizeDiff -gt 0) { "+" } else { "" }
        Write-Host "File: $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Mod: $($mod.ModName) [$($mod.Version)]" -ForegroundColor Gray
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB ($($mod.SizeDiffText))" -ForegroundColor Magenta
        
        if ($mod.ModrinthUrl) {
            Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)"
    Write-Host "-" * 60
    
    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        
        # Show size info if we found it on Modrinth
        if ($mod.ModrinthName) {
            Write-Host "  Modrinth Name: $($mod.ModrinthName)" -ForegroundColor Cyan
            
            if ($mod.ExpectedSize -gt 0) {
                $sizeDiffSign = if ($mod.SizeDiff -gt 0) { "+" } else { "" }
                $sizeMatch = if ($mod.SizeDiff -eq 0) { "✓" } else { "⚠" }
                
                Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.FileSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB ($($mod.SizeDiffText)) $sizeMatch" -ForegroundColor Magenta
                
                if ($mod.SizeDiff -ne 0) {
                    Write-Host "  Note: File size differs from Modrinth version" -ForegroundColor Yellow
                }
                
                if ($mod.IsLatestVersion) {
                    Write-Host "  Note: Using latest version size (exact version not found)" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "  Found on Modrinth but no size data available" -ForegroundColor Gray
            }
            
            if ($mod.ModrinthUrl) {
                Write-Host "  Modrinth URL: $($mod.ModrinthUrl)" -ForegroundColor Cyan
            }
        } else {
            Write-Host "  Size: $($mod.FileSizeKB) KB (No Modrinth match found)" -ForegroundColor Gray
            Write-Host "  Note: Could not find this mod on Modrinth by filename" -ForegroundColor DarkGray
        }
        
        # Download source
        if ($mod.ZoneId) {
            $sourceColor = if ($mod.IsModrinthDownload) { "Green" } else { "Yellow" }
            Write-Host "  Downloaded from: $($mod.DownloadSource)" -ForegroundColor $sourceColor
            if ($mod.DownloadSource -eq "Other" -or $mod.DownloadSource -eq "Unknown") {
                # Truncate long URLs for display
                $displayUrl = $mod.ZoneId
                if ($displayUrl.Length -gt 80) {
                    $displayUrl = $displayUrl.Substring(0, 77) + "..."
                }
                Write-Host "  URL: $displayUrl" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "  Hash: $($mod.Hash)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

if ($cheatMods.Count -gt 0) {
    Write-Host "{ Cheat Mods Detected }" -ForegroundColor Red
    Write-Host "Total: $($cheatMods.Count) ⚠ WARNING"
    Write-Host "-" * 60
    
    foreach ($mod in $cheatMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Cheat Strings: $($mod.StringsFound)" -ForegroundColor Magenta
        
        # Show size comparison for cheat mods too if available
        if ($mod.ExpectedSizeKB -gt 0) {
            $sizeDiffSign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
            Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.FileSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB" -ForegroundColor Yellow
        } else {
            Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        }
        
        if ($mod.DownloadSource -ne "Unknown") {
            Write-Host "  Source: $($mod.DownloadSource)" -ForegroundColor Yellow
            if ($mod.SourceURL) {
                Write-Host "  URL: $($mod.SourceURL)" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }
}

# SIMPLIFIED Final summary - removed everything as requested
Write-Host "{ Final Summary }" -ForegroundColor Cyan
Write-Host "=" * 80

# Save report to file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = "mod_analyzer_report_$timestamp.txt"
$reportPath = Join-Path (Get-Location) $reportFile

$reportContent = @"
YarpLetapStan's Mod Analyzer Report
Generated: $(Get-Date)
Mods Folder: $mods

SUMMARY
Total mods scanned: $totalMods
Verified mods: $($verifiedMods.Count)
Unknown mods: $($unknownMods.Count)
Cheat mods detected: $($cheatMods.Count)

"@

if ($unknownMods.Count -gt 0) {
    $reportContent += "`nUNKNOWN MODS WITH SIZE COMPARISON`n"
    $reportContent += "=" * 50 + "`n"
    
    foreach ($mod in $unknownMods) {
        $reportContent += "File: $($mod.FileName)`n"
        $reportContent += "Size: $($mod.FileSizeKB) KB`n"
        
        if ($mod.HasSizeInfo) {
            $sizeDiffSign = if ($mod.SizeDiff -gt 0) { "+" } else { "" }
            $reportContent += "Expected on Modrinth: $($mod.ExpectedSizeKB) KB`n"
            $reportContent += "Difference: $sizeDiffSign$($mod.SizeDiffKB) KB ($($mod.SizeDiffText))`n"
            
            if ($mod.ModrinthName) {
                $reportContent += "Possible Modrinth Name: $($mod.ModrinthName)`n"
            }
        } else {
            $reportContent += "Note: No Modrinth data found for this filename`n"
        }
        
        if ($mod.ZoneId) {
            $reportContent += "Downloaded from: $($mod.DownloadSource)`n"
            $reportContent += "URL: $($mod.ZoneId)`n"
        }
        
        $reportContent += "Hash: $($mod.Hash)`n"
        $reportContent += "`n"
    }
}

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Report saved to: $reportPath" -ForegroundColor Cyan

Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
