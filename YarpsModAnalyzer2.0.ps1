Clear-Host
Write-Host "Made by " -ForegroundColor Cyan -NoNewline
Write-Host "YarpLetapStan" -ForegroundColor Cyan
Write-Host "Credit to Habibi Mod Analyzer" -ForegroundColor DarkGray
Write-Host

# Create a box for the title
$boxWidth = 38
Write-Host "+" + ("-" * $boxWidth) + "+" -ForegroundColor Blue
Write-Host "|" + (" " * $boxWidth) + "|" -ForegroundColor Blue
Write-Host "|" + ("YarpLetapStan Mod Analyzer V2.0".PadLeft(($boxWidth + 30)/2).PadRight($boxWidth)) + "|" -ForegroundColor Blue
Write-Host "|" + (" " * $boxWidth) + "|" -ForegroundColor Blue
Write-Host "+" + ("-" * $boxWidth) + "+" -ForegroundColor Blue
Write-Host ""

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

function Get-Mod-Info-From-Jar {
    param (
        [string]$jarPath
    )
    
    $modInfo = @{
        ModId = ""
        Name = ""
        Version = ""
        Description = ""
        Authors = @()
        License = ""
        Contact = @{}
        Icon = ""
        Environment = ""
        Entrypoints = @{}
        Mixins = @()
        AccessWidener = ""
        Depends = @{}
        Suggests = @{}
        Breaks = @{}
        Conflicts = @{}
    }
    
    try {
        # Try to read the JAR as a ZIP file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        
        # Look for fabric.mod.json (Fabric mods)
        $fabricModJson = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1
        if ($fabricModJson) {
            $stream = $fabricModJson.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $jsonContent = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            
            try {
                $fabricData = $jsonContent | ConvertFrom-Json
                
                if ($fabricData.id) { $modInfo.ModId = $fabricData.id }
                if ($fabricData.name) { $modInfo.Name = $fabricData.name }
                if ($fabricData.version) { $modInfo.Version = $fabricData.version }
                if ($fabricData.description) { $modInfo.Description = $fabricData.description }
                if ($fabricData.authors) { 
                    if ($fabricData.authors -is [array]) {
                        $modInfo.Authors = $fabricData.authors
                    } else {
                        $modInfo.Authors = @($fabricData.authors)
                    }
                }
                if ($fabricData.license) { $modInfo.License = $fabricData.license }
                if ($fabricData.contact) { $modInfo.Contact = $fabricData.contact }
                if ($fabricData.icon) { $modInfo.Icon = $fabricData.icon }
                if ($fabricData.environment) { $modInfo.Environment = $fabricData.environment }
                if ($fabricData.entrypoints) { $modInfo.Entrypoints = $fabricData.entrypoints }
                if ($fabricData.mixins) { 
                    if ($fabricData.mixins -is [array]) {
                        $modInfo.Mixins = $fabricData.mixins
                    } else {
                        $modInfo.Mixins = @($fabricData.mixins)
                    }
                }
                if ($fabricData.accessWidener) { $modInfo.AccessWidener = $fabricData.accessWidener }
                if ($fabricData.depends) { $modInfo.Depends = $fabricData.depends }
                if ($fabricData.suggests) { $modInfo.Suggests = $fabricData.suggests }
                if ($fabricData.breaks) { $modInfo.Breaks = $fabricData.breaks }
                if ($fabricData.conflicts) { $modInfo.Conflicts = $fabricData.conflicts }
                
                $modInfo.Source = "fabric.mod.json"
                $zip.Dispose()
                return $modInfo
            } catch {
                # JSON parsing failed
            }
        }
        
        # Look for META-INF/mods.toml (Forge/NeoForge mods)
        $modsToml = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' } | Select-Object -First 1
        if ($modsToml) {
            $stream = $modsToml.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $tomlContent = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            
            # Simple TOML parsing for basic info
            if ($tomlContent -match 'modId\s*=\s*"([^"]+)"') {
                $modInfo.ModId = $matches[1]
            }
            if ($tomlContent -match 'displayName\s*=\s*"([^"]+)"') {
                $modInfo.Name = $matches[1]
            }
            if ($tomlContent -match 'version\s*=\s*"([^"]+)"') {
                $modInfo.Version = $matches[1]
            }
            if ($tomlContent -match 'description\s*=\s*"([^"]+)"') {
                $modInfo.Description = $matches[1]
            }
            if ($tomlContent -match 'authors\s*=\s*"([^"]+)"') {
                $modInfo.Authors = @($matches[1])
            }
            
            $modInfo.Source = "META-INF/mods.toml"
            $zip.Dispose()
            return $modInfo
        }
        
        # Look for modid.mixins.json (Mixin config)
        $mixinJson = $zip.Entries | Where-Object { $_.Name -match '\.mixins\.json$' } | Select-Object -First 1
        if ($mixinJson) {
            $stream = $mixinJson.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $jsonContent = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            
            try {
                $mixinData = $jsonContent | ConvertFrom-Json
                # Mixin config might have package info that hints at mod ID
                if ($mixinData.package) {
                    $packageParts = $mixinData.package -split '\.'
                    if ($packageParts.Count -ge 2) {
                        $modInfo.ModId = $packageParts[-2]  # Often the mod ID is second-to-last part
                    }
                }
                $modInfo.Source = "mixins.json"
            } catch {
                # JSON parsing failed
            }
        }
        
        # Look for MANIFEST.MF for additional info
        $manifest = $zip.Entries | Where-Object { $_.Name -eq 'MANIFEST.MF' } | Select-Object -First 1
        if ($manifest) {
            $stream = $manifest.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $manifestContent = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            
            # Parse manifest for useful info
            $lines = $manifestContent -split "`n"
            foreach ($line in $lines) {
                if ($line -match 'Implementation-Title:\s*(.+)') {
                    if (-not $modInfo.Name) { $modInfo.Name = $matches[1].Trim() }
                }
                if ($line -match 'Implementation-Version:\s*(.+)') {
                    if (-not $modInfo.Version) { $modInfo.Version = $matches[1].Trim() }
                }
                if ($line -match 'Specification-Title:\s*(.+)') {
                    if (-not $modInfo.Name) { $modInfo.Name = $matches[1].Trim() }
                }
            }
        }
        
        $zip.Dispose()
        
    } catch {
        # Error reading JAR file
    }
    
    return $modInfo
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

function Fetch-Modrinth-By-ModId {
    param (
        [string]$modId,
        [string]$version
    )
    try {
        # First, search for the mod by its ID
        $searchUrl = "https://api.modrinth.com/v2/search?query=`"$modId`"&facets=`"[[`"project_type:mod`"]]`"&limit=5"
        $searchData = Invoke-RestMethod -Uri $searchUrl -Method Get -UseBasicParsing -ErrorAction Stop
        
        if ($searchData.hits -and $searchData.hits.Count -gt 0) {
            # Try to find exact match by mod ID/slug
            foreach ($hit in $searchData.hits) {
                if ($hit.slug -eq $modId -or $hit.project_id -eq $modId -or $hit.title -match $modId) {
                    $projectId = $hit.project_id
                    
                    # Get all versions for this project
                    $versionsUrl = "https://api.modrinth.com/v2/project/$projectId/version"
                    $versionsData = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
                    
                    # If we have a version, try to find exact match
                    if ($version) {
                        foreach ($ver in $versionsData) {
                            if ($ver.version_number -eq $version -or $ver.version_number -match $version) {
                                $file = $ver.files[0]
                                return @{
                                    Name = $hit.title
                                    Slug = $hit.slug
                                    ExpectedSize = $file.size
                                    VersionNumber = $ver.version_number
                                    FileName = $file.filename
                                    ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($ver.id)"
                                    FoundByHash = $false
                                    ExactMatch = true
                                }
                            }
                        }
                    }
                    
                    # Return latest version if no version match or no version specified
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
            }
            
            # If no exact match, use first result
            $hit = $searchData.hits[0]
            $projectId = $hit.project_id
            
            $versionsUrl = "https://api.modrinth.com/v2/project/$projectId/version"
            $versionsData = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
            
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

# Store all mod info for later cheat string checking
$allModsInfo = @()

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
    
    # NEW: Extract mod info from JAR file
    $jarModInfo = Get-Mod-Info-From-Jar -jarPath $file.FullName
    
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
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarSource = $jarModInfo.Source
        }
        
        $verifiedMods += $modEntry
        $allModsInfo += $modEntry
        
        # Check for size mismatch
        if ($modData.ExpectedSize -gt 0 -and $actualSize -ne $modData.ExpectedSize) {
            $sizeMismatchMods += $modEntry
            if ([math]::Abs($sizeDiff) -gt 1024) {
                $tamperedMods += $modEntry
            }
        }
        
        continue
    }
    
    # NEW: Try to find mod on Modrinth using mod ID from JAR file
    $modrinthInfoFromJar = $null
    if ($jarModInfo.ModId) {
        $modrinthInfoFromJar = Fetch-Modrinth-By-ModId -modId $jarModInfo.ModId -version $jarModInfo.Version
    }
    
    if ($modrinthInfoFromJar -and $modrinthInfoFromJar.Name) {
        # Calculate size difference
        $sizeDiff = $actualSize - $modrinthInfoFromJar.ExpectedSize
        $sizeDiffText = if ($sizeDiff -gt 0) { "+$sizeDiff bytes" } else { "$sizeDiff bytes" }
        $expectedSizeKB = if ($modrinthInfoFromJar.ExpectedSize -gt 0) { [math]::Round($modrinthInfoFromJar.ExpectedSize/1KB, 2) } else { 0 }
        
        $modEntry = [PSCustomObject]@{ 
            ModName = $modrinthInfoFromJar.Name
            FileName = $file.Name
            Version = $modrinthInfoFromJar.VersionNumber
            ExpectedSize = $modrinthInfoFromJar.ExpectedSize
            ExpectedSizeKB = $expectedSizeKB
            ActualSize = $actualSize
            ActualSizeKB = $actualSizeKB
            SizeDiff = $sizeDiff
            SizeDiffText = $sizeDiffText
            SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modrinthInfoFromJar.ModrinthUrl
            VerifiedBy = "JAR Metadata"
            IsVerified = $true
            ExactMatch = $modrinthInfoFromJar.ExactMatch
            IsLatestVersion = $modrinthInfoFromJar.IsLatestVersion
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarSource = $jarModInfo.Source
        }
        
        $verifiedMods += $modEntry
        $allModsInfo += $modEntry
        
        # Check for size mismatch
        if ($modrinthInfoFromJar.ExpectedSize -gt 0 -and $actualSize -ne $modrinthInfoFromJar.ExpectedSize) {
            $sizeMismatchMods += $modEntry
            if ([math]::Abs($sizeDiff) -gt 1024) {
                $tamperedMods += $modEntry
            }
        }
        
        continue
    }
    
    # Try to get Modrinth info by filename (fallback)
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
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarSource = $jarModInfo.Source
        }
        
        $verifiedMods += $modEntry
        $allModsInfo += $modEntry
        
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
        $modEntry = [PSCustomObject]@{ 
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
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarSource = $jarModInfo.Source
        }
        
        $verifiedMods += $modEntry
        $allModsInfo += $modEntry
        continue
    }
    
    # If we get here, it's an unknown mod
    $unknownModEntry = [PSCustomObject]@{ 
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
        ModName = ""
        JarModId = $jarModInfo.ModId
        JarName = $jarModInfo.Name
        JarVersion = $jarModInfo.Version
        JarSource = $jarModInfo.Source
    }
    
    $unknownMods += $unknownModEntry
    $allModsInfo += $unknownModEntry
}

# Scan ALL mods for cheat strings (including verified ones)
$tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"
$counter = 0

try {
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir
    }
    
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    foreach ($mod in $allModsInfo) {
        $counter++
        $spin = $spinner[$counter % $spinner.Length]
        Write-Host "`r[$spin] Scanning mods for cheat strings: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
        
        $modStrings = Check-Strings $mod.FilePath
        if ($modStrings.Count -gt 0) {
            # Try to get Modrinth info for this cheat mod if we don't already have it
            $expectedSizeKB = $mod.ExpectedSizeKB
            $sizeDiffKB = $mod.SizeDiffKB
            
            # If this is an unknown mod or doesn't have size info, try to get it
            if ($expectedSizeKB -eq 0 -or $mod.HasSizeInfo -eq $false) {
                # Try to get Modrinth info by mod ID from JAR first
                if ($mod.JarModId) {
                    $modrinthInfoFromJar = Fetch-Modrinth-By-ModId -modId $mod.JarModId -version $mod.JarVersion
                    if ($modrinthInfoFromJar.Name -and $modrinthInfoFromJar.ExpectedSize -gt 0) {
                        $expectedSizeKB = [math]::Round($modrinthInfoFromJar.ExpectedSize/1KB, 2)
                        $sizeDiff = $mod.FileSize - $modrinthInfoFromJar.ExpectedSize
                        $sizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
                        
                        # Update the mod entry with this new info
                        $mod.ExpectedSizeKB = $expectedSizeKB
                        $mod.SizeDiffKB = $sizeDiffKB
                        $mod.ModName = $modrinthInfoFromJar.Name
                        $mod.ModrinthUrl = $modrinthInfoFromJar.ModrinthUrl
                    }
                }
                
                # If still no info, try by filename
                if ($expectedSizeKB -eq 0) {
                    $modrinthInfo = Fetch-Modrinth-By-Filename -filename $mod.FileName
                    if ($modrinthInfo.Name -and $modrinthInfo.ExpectedSize -gt 0) {
                        $expectedSizeKB = [math]::Round($modrinthInfo.ExpectedSize/1KB, 2)
                        $sizeDiff = $mod.FileSize - $modrinthInfo.ExpectedSize
                        $sizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
                        
                        # Update the mod entry with this new info
                        $mod.ExpectedSizeKB = $expectedSizeKB
                        $mod.SizeDiffKB = $sizeDiffKB
                        $mod.ModName = $modrinthInfo.Name
                        $mod.ModrinthUrl = $modrinthInfo.ModrinthUrl
                    }
                }
            }
            
            $cheatMods += [PSCustomObject]@{ 
                FileName = $mod.FileName
                StringsFound = $modStrings
                FileSizeKB = $mod.FileSizeKB
                DownloadSource = $mod.DownloadSource
                SourceURL = $mod.ZoneId
                ExpectedSizeKB = $expectedSizeKB
                SizeDiffKB = $sizeDiffKB
                IsVerifiedMod = ($mod.IsVerified -eq $true)
                ModName = $mod.ModName
                ModrinthUrl = $mod.ModrinthUrl
                FilePath = $mod.FilePath
                HasSizeMismatch = ($sizeDiffKB -ne 0 -and [math]::Abs($sizeDiffKB) -gt 1)
                JarModId = $mod.JarModId
                JarName = $mod.JarName
                JarVersion = $mod.JarVersion
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

Write-Host "`r$(' ' * 80)`r" -NoNewline

# Display results - CHANGED ORDER: Unknown Mods before Potentially Tampered Mods
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan
Write-Host

if ($verifiedMods.Count -gt 0) {
    Write-Host "{ Verified Mods }" -ForegroundColor Cyan
    Write-Host "Total: $($verifiedMods.Count)"
    Write-Host
    
    foreach ($mod in $verifiedMods) {
        # Check if this mod is also in cheat mods
        $isCheatMod = $cheatMods.FileName -contains $mod.FileName
        
        if ($tamperedMods.FileName -contains $mod.FileName) {
            Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline
            Write-Host " - $($mod.FileName)" -ForegroundColor Magenta -NoNewline
        } elseif ($isCheatMod) {
            Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline
            Write-Host " - $($mod.FileName)" -ForegroundColor Red -NoNewline
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
        
        # Show JAR metadata info if available
        if ($mod.JarSource) {
            Write-Host "  Source: $($mod.JarSource)" -ForegroundColor DarkGray
            if ($mod.JarModId) {
                Write-Host "  Mod ID: $($mod.JarModId)" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""
}

# CHANGED: Unknown Mods now come before Potentially Tampered Mods
if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)"
    Write-Host
    
    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        # Show JAR metadata if we found any
        if ($mod.JarSource) {
            Write-Host "  Found in JAR: $($mod.JarSource)" -ForegroundColor DarkGray
            if ($mod.JarModId) {
                Write-Host "  Mod ID: $($mod.JarModId)" -ForegroundColor DarkGray
            }
            if ($mod.JarName) {
                Write-Host "  Name: $($mod.JarName)" -ForegroundColor DarkGray
            }
            if ($mod.JarVersion) {
                Write-Host "  Version: $($mod.JarVersion)" -ForegroundColor DarkGray
            }
        }
        
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

# CHANGED: Potentially Tampered Mods now come after Unknown Mods
if ($tamperedMods.Count -gt 0) {
    Write-Host "{ Potentially Tampered Mods }" -ForegroundColor Red
    Write-Host "Total: $($tamperedMods.Count) ⚠ WARNING"
    Write-Host
    
    foreach ($mod in $tamperedMods) {
        $sizeDiffSign = if ($mod.SizeDiff -gt 0) { "+" } else { "" }
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Magenta
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB" -ForegroundColor Magenta
        Write-Host "  ⚠ File size differs significantly from Modrinth version!" -ForegroundColor Red
        
        if ($mod.ModrinthUrl) {
            Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
        }
        
        # Show JAR metadata
        if ($mod.JarSource) {
            Write-Host "  Source: $($mod.JarSource)" -ForegroundColor DarkGray
            if ($mod.JarModId) {
                Write-Host "  Mod ID: $($mod.JarModId)" -ForegroundColor DarkGray
            }
        }
        
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
        
        # Show JAR metadata if available
        if ($mod.JarModId) {
            Write-Host "  Mod ID from JAR: $($mod.JarModId)" -ForegroundColor DarkGray
            if ($mod.JarName) {
                Write-Host "  Name from JAR: $($mod.JarName)" -ForegroundColor DarkGray
            }
            if ($mod.JarVersion) {
                Write-Host "  Version from JAR: $($mod.JarVersion)" -ForegroundColor DarkGray
            }
        }
        
        # NEW: Show size comparison for cheat mods
        if ($mod.ExpectedSizeKB -gt 0) {
            $sizeDiffSign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
            if ($mod.SizeDiffKB -eq 0) {
                Write-Host "  Expected: $($mod.ExpectedSizeKB) KB ✓ Matches Modrinth" -ForegroundColor Green
            } else {
                Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB" -ForegroundColor Yellow
                
                # Warning for size mismatch in cheat mods
                if ([math]::Abs($mod.SizeDiffKB) -gt 1) {
                    Write-Host "  ⚠ Size mismatch detected! Could be tampered with cheat code." -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  Note: No Modrinth size data available for comparison" -ForegroundColor DarkGray
        }
        
        if ($mod.DownloadSource -ne "Unknown") {
            Write-Host "  Source: $($mod.DownloadSource)" -ForegroundColor Yellow
            if ($mod.SourceURL) {
                Write-Host "  URL: $($mod.SourceURL)" -ForegroundColor DarkGray
            }
        }
        
        if ($mod.IsVerifiedMod) {
            Write-Host "  ⚠ Legitimate mod contains cheat code!" -ForegroundColor Red
            Write-Host "  ⚠ This appears to be a tampered version of a legitimate mod" -ForegroundColor Red
        }
        
        # Show Modrinth URL if available
        if ($mod.ModrinthUrl) {
            Write-Host "  Modrinth: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
        }
        
        Write-Host ""
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
