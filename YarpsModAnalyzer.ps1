Clear-Host
# Create a box for the title
$boxWidth = 38
Write-Host "+" + ("-" * $boxWidth) + "+" -ForegroundColor Blue
Write-Host "|" + (" " * $boxWidth) + "|" -ForegroundColor Blue
Write-Host "|" + ("YarpLetapStan's Mod Analyzer V2.0".PadLeft(($boxWidth + 30)/2).PadRight($boxWidth)) + "|" -ForegroundColor Blue
Write-Host "|" + (" " * $boxWidth) + "|" -ForegroundColor Blue
Write-Host "+" + ("-" * $boxWidth) + "+" -ForegroundColor Blue
Write-Host ""

Write-Host "Made by " -ForegroundColor Blue -NoNewline
Write-Host "YarpLetapStan" -ForegroundColor Blue
Write-Host "Credit to Habibi Mod Analyzer" -ForegroundColor DarkGray
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
        # Clean the filename
        $cleanFilename = $filename -replace '\.temp\.jar$', '.jar' -replace '\.tmp\.jar$', '.jar' -replace '_1\.jar$', '.jar'
        $modNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($cleanFilename)
        
        # SIMPLE APPROACH: Just extract the first part before any hyphen or underscore
        $baseName = $modNameWithoutExt
        if ($baseName -match '^([a-zA-Z0-9]+)') {
            $baseName = $matches[1]
        }
        
        # Try direct slug lookup first (most common mod slugs)
        $possibleSlugs = @(
            $baseName.ToLower(),
            $modNameWithoutExt.ToLower()
        )
        
        foreach ($slug in $possibleSlugs) {
            try {
                $projectUrl = "https://api.modrinth.com/v2/project/$slug"
                $projectData = Invoke-RestMethod -Uri $projectUrl -Method Get -UseBasicParsing -ErrorAction Stop
                
                if ($projectData.id) {
                    # Get all versions
                    $versionsUrl = "https://api.modrinth.com/v2/project/$slug/version"
                    $versionsData = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
                    
                    # Try to find exact filename match
                    foreach ($version in $versionsData) {
                        foreach ($file in $version.files) {
                            if ($file.filename -eq $cleanFilename) {
                                return @{
                                    Name = $projectData.title
                                    Slug = $projectData.slug
                                    ExpectedSize = $file.size
                                    VersionNumber = $version.version_number
                                    FileName = $file.filename
                                    ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($version.id)"
                                    FoundByHash = $false
                                    ExactMatch = $true
                                }
                            }
                        }
                    }
                    
                    # If no exact match, try to find by version number
                    if ($modNameWithoutExt -match '(\d+\.\d+(?:\.\d+)?)') {
                        $fileVersion = $matches[1]
                        foreach ($version in $versionsData) {
                            if ($version.version_number -contains $fileVersion -or $version.version_number -match $fileVersion) {
                                $file = $version.files[0]
                                return @{
                                    Name = $projectData.title
                                    Slug = $projectData.slug
                                    ExpectedSize = $file.size
                                    VersionNumber = $version.version_number
                                    FileName = $file.filename
                                    ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($version.id)"
                                    FoundByHash = $false
                                    ExactMatch = false
                                }
                            }
                        }
                    }
                    
                    # Return latest version
                    if ($versionsData.Count -gt 0) {
                        $latestVersion = $versionsData[0]
                        $latestFile = $latestVersion.files[0]
                        
                        return @{
                            Name = $projectData.title
                            Slug = $projectData.slug
                            ExpectedSize = $latestFile.size
                            VersionNumber = $latestVersion.version_number
                            FileName = $latestFile.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($latestVersion.id)"
                            FoundByHash = $false
                            ExactMatch = false
                            IsLatestVersion = true
                        }
                    }
                }
            } catch {
                # Continue to next slug
            }
        }
        
        # If direct slug search failed, try search API
        $searchUrl = "https://api.modrinth.com/v2/search?query=`"$baseName`"&facets=`"[[`"project_type:mod`"]]`"&limit=5"
        $searchData = Invoke-RestMethod -Uri $searchUrl -Method Get -UseBasicParsing -ErrorAction Stop
        
        if ($searchData.hits -and $searchData.hits.Count -gt 0) {
            # Use the first search result
            $hit = $searchData.hits[0]
            
            # Get versions for this project
            $versionsUrl = "https://api.modrinth.com/v2/project/$($hit.project_id)/version"
            $versionsData = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
            
            # Try exact filename match
            foreach ($version in $versionsData) {
                foreach ($file in $version.files) {
                    if ($file.filename -eq $cleanFilename) {
                        return @{
                            Name = $hit.title
                            Slug = $hit.slug
                            ExpectedSize = $file.size
                            VersionNumber = $version.version_number
                            FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($version.id)"
                            FoundByHash = $false
                            ExactMatch = true
                        }
                    }
                }
            }
            
            # Return latest version
            if ($versionsData.Count -gt 0) {
                $latestVersion = $versionsData[0]
                $latestFile = $latestVersion.files[0]
                
                return @{
                    Name = $hit.title
                    Slug = $hit.slug
                    ExpectedSize = $latestFile.size
                    VersionNumber = $latestVersion.version_number
                    FileName = $latestFile.filename
                    ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($latestVersion.id)"
                    FoundByHash = $false
                    ExactMatch = false
                    IsLatestVersion = true
                }
            }
        }
        
    } catch {
        # Silently handle errors
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

# Cheat strings - KEEP Velocity for detecting cheat clients
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
$tamperedMods = @()

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
            if ([math]::Abs($sizeDiff) -gt 1024) {
                $tamperedMods += $modEntry
            }
        }
        
        continue
    }
    
    # Try to get Modrinth info by filename
    $modrinthInfo = Fetch-Modrinth-By-Filename -filename $file.Name
    
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
            if ([math]::Abs($sizeDiff) -gt 1024) {
                $tamperedMods += $modEntry
            }
        }
        
        continue
    }
    
    # Try Megabase as fallback
    $megabaseData = Fetch-Megabase -hash $hash
    if ($megabaseData -and $megabaseData.name) {
        $verifiedMods += [PSCustomObject]@{ 
            ModName = $megabaseData.name
            FileName = $file.Name
            Version = "Unknown"
            ExpectedSize = 0
            ExpectedSizeKB = 0
            ActualSize = $actualSize
            ActualSizeKB = $actualSizeKB
            SizeDiff = 0
            SizeDiffText = "N/A"
            SizeDiffKB = 0
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            VerifiedBy = "Megabase"
            IsVerified = $true
        }
        continue
    }
    
    # If we get here, it's an unknown mod
    $unknownMods += [PSCustomObject]@{ 
        FileName = $file.Name
        FilePath = $file.FullName
        ZoneId = $zoneInfo.URL
        DownloadSource = $zoneInfo.Source
        IsModrinthDownload = $zoneInfo.IsModrinth
        FileSize = $actualSize
        FileSizeKB = $actualSizeKB
        Hash = $hash
        ExpectedSize = 0
        ExpectedSizeKB = 0
        SizeDiff = 0
        SizeDiffText = "N/A"
        SizeDiffKB = 0
        ModrinthUrl = ""
        HasSizeInfo = $false
        IsLatestVersion = $false
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

# Also check verified mods for cheat strings
foreach ($mod in $verifiedMods) {
    $modStrings = Check-Strings $mod.FilePath
    if ($modStrings.Count -gt 0) {
        $existingCheatMod = $cheatMods | Where-Object { $_.FileName -eq $mod.FileName }
        if (-not $existingCheatMod) {
            $cheatMods += [PSCustomObject]@{ 
                FileName = $mod.FileName
                StringsFound = $modStrings
                FileSizeKB = $mod.ActualSizeKB
                DownloadSource = $mod.DownloadSource
                SourceURL = $mod.SourceURL
                ExpectedSizeKB = $mod.ExpectedSizeKB
                SizeDiffKB = $mod.SizeDiffKB
                IsVerifiedMod = $true
                ModName = $mod.ModName
            }
        }
    }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# Display results
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan
Write-Host

if ($verifiedMods.Count -gt 0) {
    Write-Host "{ Verified Mods }" -ForegroundColor Cyan
    Write-Host "Total: $($verifiedMods.Count)"
    Write-Host
    
    foreach ($mod in $verifiedMods) {
        # CHANGED: Make tampered mods display in red and magenta
        if ($tamperedMods.FileName -contains $mod.FileName) {
            Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline
            Write-Host " - $($mod.FileName)" -ForegroundColor Magenta -NoNewline
        } else {
            Write-Host "> $($mod.ModName)" -ForegroundColor Green -NoNewline
            Write-Host " - $($mod.FileName)" -ForegroundColor Gray -NoNewline
        }
        
        if ($mod.Version -and $mod.Version -ne "Unknown") {
            Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray -NoNewline
        }
        
        if ($mod.DownloadSource -ne "Unknown") {
            $sourceColor = if ($mod.IsModrinthDownload) { "Green" } else { "Yellow" }
            Write-Host " ($($mod.DownloadSource))" -ForegroundColor $sourceColor
        } else {
            Write-Host ""
        }
        
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                Write-Host "  Size: $($mod.ActualSizeKB) KB ✓" -ForegroundColor Green
            } else {
                $sizeDiffSign = if ($mod.SizeDiff -gt 0) { "+" } else { "" }
                # CHANGED: Make tampered mod size display in magenta
                if ($tamperedMods.FileName -contains $mod.FileName) {
                    Write-Host "  Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB, Diff: $sizeDiffSign$($mod.SizeDiffKB) KB)" -ForegroundColor Magenta
                } else {
                    Write-Host "  Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB, Diff: $sizeDiffSign$($mod.SizeDiffKB) KB)" -ForegroundColor Yellow
                }
            }
        }
    }
    Write-Host ""
}

if ($tamperedMods.Count -gt 0) {
    Write-Host "{ Potentially Tampered Mods }" -ForegroundColor Red
    Write-Host "Total: $($tamperedMods.Count) ⚠ WARNING"
    Write-Host
    
    foreach ($mod in $tamperedMods) {
        $sizeDiffSign = if ($mod.SizeDiff -gt 0) { "+" } else { "" }
        # CHANGED: Make tampered mod display in red and magenta
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Magenta
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB" -ForegroundColor Magenta
        Write-Host "  ⚠ File size differs significantly from Modrinth version!" -ForegroundColor Red
        
        if ($mod.ModrinthUrl) {
            Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)"
    Write-Host
    
    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        if ($mod.ZoneId) {
            $sourceColor = if ($mod.IsModrinthDownload) { "Green" } else { "Yellow" }
            Write-Host "  Downloaded from: $($mod.DownloadSource)" -ForegroundColor $sourceColor
            if ($mod.DownloadSource -eq "Other" -or $mod.DownloadSource -eq "Unknown") {
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
    Write-Host
    
    foreach ($mod in $cheatMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        
        if ($mod.ModName) {
            Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Gray
        }
        
        Write-Host "  Cheat Strings: $($mod.StringsFound)" -ForegroundColor Magenta
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        if ($mod.ExpectedSizeKB -gt 0) {
            $sizeDiffSign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
            Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB" -ForegroundColor Yellow
        }
        
        if ($mod.DownloadSource -ne "Unknown") {
            Write-Host "  Source: $($mod.DownloadSource)" -ForegroundColor Yellow
            if ($mod.SourceURL) {
                Write-Host "  URL: $($mod.SourceURL)" -ForegroundColor DarkGray
            }
        }
        
        if ($mod.IsVerifiedMod) {
            Write-Host "  ⚠ Verified mod contains cheat code!" -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
