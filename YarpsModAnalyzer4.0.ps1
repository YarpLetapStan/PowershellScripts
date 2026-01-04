Clear-Host
Write-Host "Made by " -ForegroundColor Cyan -NoNewline
Write-Host "YarpLetapStan" -ForegroundColor Cyan
Write-Host "Credits to Habibi Mod Analyzer" -ForegroundColor DarkGray
Write-Host

# Create a box for the title
$boxWidth = 38
Write-Host "+" + ("-" * $boxWidth) + "+" -ForegroundColor Blue
Write-Host "|" + (" " * $boxWidth) + "|" -ForegroundColor Blue
Write-Host "|" + ("YarpLetapStan's Mod Analyzer V4.0".PadLeft(($boxWidth + 30)/2).PadRight($boxWidth)) + "|" -ForegroundColor Blue
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

function Get-Minecraft-Version-From-Mods {
    param (
        [string]$modsFolder
    )
    
    $minecraftVersions = @{}
    
    # Get all JAR files in the mods folder
    $jarFiles = Get-ChildItem -Path $modsFolder -Filter *.jar
    
    foreach ($file in $jarFiles) {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
            
            # Look for fabric.mod.json
            $fabricModJson = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1
            if ($fabricModJson) {
                $stream = $fabricModJson.Open()
                $reader = New-Object System.IO.StreamReader($stream)
                $jsonContent = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
                
                $fabricData = $jsonContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                # Check for Minecraft version in dependencies
                if ($fabricData.depends -and $fabricData.depends.minecraft) {
                    $mcVersion = $fabricData.depends.minecraft
                    
                    # Clean up version string (remove any constraints like ">=1.19.2")
                    $mcVersion = $mcVersion -replace '^[><=~^]*\s*', ''
                    $mcVersion = $mcVersion -replace '\s*$', ''
                    
                    if ($mcVersion -match '^\d+(\.\d+)+(\.\d+)?$') {
                        if ($minecraftVersions.ContainsKey($mcVersion)) {
                            $minecraftVersions[$mcVersion]++
                        } else {
                            $minecraftVersions[$mcVersion] = 1
                        }
                    }
                }
                
                # Also check for fabric.mod.json without depends
                if ($fabricData.schemaVersion -ge 1) {
                    # For newer schema, check the "minecraft" property
                    if ($fabricData.depends -and $fabricData.depends.PSObject.Properties.Name -contains 'minecraft') {
                        $mcVersion = $fabricData.depends.minecraft
                        $mcVersion = $mcVersion -replace '^[><=~^]*\s*', '' -replace '\s*$', ''
                        
                        if ($mcVersion -match '^\d+(\.\d+)+(\.\d+)?$') {
                            if ($minecraftVersions.ContainsKey($mcVersion)) {
                                $minecraftVersions[$mcVersion]++
                            } else {
                                $minecraftVersions[$mcVersion] = 1
                            }
                        }
                    }
                }
            }
            
            $zip.Dispose()
        } catch {
            # Skip file if there's an error
            continue
        }
    }
    
    # Return the most common Minecraft version
    if ($minecraftVersions.Count -gt 0) {
        $mostCommon = $minecraftVersions.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        Write-Host "`nDetected Minecraft version: $($mostCommon.Key) (from $($mostCommon.Value) mods)" -ForegroundColor Cyan
        return $mostCommon.Key
    }
    
    # Try to get from javaw process arguments
    $process = Get-Process javaw -ErrorAction SilentlyContinue
    if (-not $process) {
        $process = Get-Process java -ErrorAction SilentlyContinue
    }
    
    if ($process) {
        try {
            $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            if ($cmdLine -match '-Dfabric.gameVersion=(\d+(\.\d+)+)') {
                $mcVersion = $matches[1]
                Write-Host "`nDetected Minecraft version from process: $mcVersion" -ForegroundColor Cyan
                return $mcVersion
            }
            elseif ($cmdLine -match '--version\s+(\d+(\.\d+)+)') {
                $mcVersion = $matches[1]
                Write-Host "`nDetected Minecraft version from process: $mcVersion" -ForegroundColor Cyan
                return $mcVersion
            }
        } catch {}
    }
    
    # If we still can't determine, ask the user
    Write-Host "`nCould not auto-detect Minecraft version from mods." -ForegroundColor Yellow
    $mcVersion = Read-Host "Enter your Minecraft version (e.g., 1.21, 1.20.1) or press Enter to skip filtering"
    
    if (-not $mcVersion -or $mcVersion -eq '') {
        return $null
    }
    
    return $mcVersion
}

# Detect Minecraft version from mods
$minecraftVersion = Get-Minecraft-Version-From-Mods -modsFolder $mods
if ($minecraftVersion) {
    Write-Host "Using Minecraft version: $minecraftVersion for filtering" -ForegroundColor Green
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
            elseif ($url -match "discord\.com" -or $url -match "discordapp\.com" -or $url -match "cdn\.discordapp\.com") {
                return @{ Source = "Discord"; URL = $url; IsModrinth = $false }
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
        ModLoader = ""
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
                
                $modInfo.ModLoader = "Fabric"
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
            
            $modInfo.ModLoader = "Forge/NeoForge"
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
                ExactMatch = $true
                IsLatestVersion = $false
                MatchType = "Exact Hash"
                LoaderType = if ($response.loaders -contains "fabric") { "Fabric" } elseif ($response.loaders -contains "forge") { "Forge" } else { "Unknown" }
            }
        }
    } catch {}
    
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown" }
}

function Find-Closest-Version {
    param (
        [string]$localVersion,
        [array]$availableVersions,
        [string]$preferredLoader = "Fabric",
        [string]$minecraftVersion = $null
    )
    
    # If no local version or no available versions, return null
    if (-not $localVersion -or -not $availableVersions -or $availableVersions.Count -eq 0) {
        return $null
    }
    
    # Step 1: Filter by Minecraft version AND loader if both are provided
    $filteredVersions = @()
    foreach ($version in $availableVersions) {
        $matchesLoader = ($version.loaders -contains $preferredLoader.ToLower())
        $matchesMinecraft = if ($minecraftVersion -and $version.game_versions) {
            ($version.game_versions -contains $minecraftVersion)
        } else {
            $true
        }
        
        if ($matchesLoader -and $matchesMinecraft) {
            $filteredVersions += $version
        }
    }
    
    # Step 2: If no matches with both filters, try just Minecraft version
    if ($filteredVersions.Count -eq 0 -and $minecraftVersion) {
        foreach ($version in $availableVersions) {
            if ($version.game_versions -contains $minecraftVersion) {
                $filteredVersions += $version
            }
        }
    }
    
    # Step 3: If still no matches, try just loader
    if ($filteredVersions.Count -eq 0) {
        foreach ($version in $availableVersions) {
            if ($version.loaders -contains $preferredLoader.ToLower()) {
                $filteredVersions += $version
            }
        }
    }
    
    # Step 4: If still no matches, use all versions
    if ($filteredVersions.Count -eq 0) {
        $filteredVersions = $availableVersions
    }
    
    # Now try to find the closest version match within filtered versions
    # Try exact match first
    foreach ($version in $filteredVersions) {
        if ($version.version_number -eq $localVersion) {
            return $version
        }
    }
    
    # Try to parse semantic version
    try {
        # Clean version string
        $localVersion = $localVersion.Trim()
        
        # Try to match major.minor.pattern
        if ($localVersion -match '(\d+)\.(\d+)\.(\d+)') {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            $patch = [int]$matches[3]
            
            $closest = $null
            $closestDistance = [double]::MaxValue
            
            foreach ($version in $filteredVersions) {
                if ($version.version_number -match '(\d+)\.(\d+)\.(\d+)') {
                    $vMajor = [int]$matches[1]
                    $vMinor = [int]$matches[2]
                    $vPatch = [int]$matches[3]
                    
                    # Calculate "distance" between versions
                    $distance = [math]::Sqrt(
                        [math]::Pow($major - $vMajor, 2) * 100 + 
                        [math]::Pow($minor - $vMinor, 2) * 10 + 
                        [math]::Pow($patch - $vPatch, 2)
                    )
                    
                    if ($distance -lt $closestDistance) {
                        $closestDistance = $distance
                        $closest = $version
                    }
                }
            }
            
            if ($closest -and $closestDistance -lt 10) {  # Only consider it close enough if distance < 10
                return $closest
            }
        }
        
        # Try to match major.minor pattern
        if ($localVersion -match '(\d+)\.(\d+)') {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            
            $closest = $null
            $closestDistance = [double]::MaxValue
            
            foreach ($version in $filteredVersions) {
                if ($version.version_number -match '(\d+)\.(\d+)') {
                    $vMajor = [int]$matches[1]
                    $vMinor = [int]$matches[2]
                    
                    $distance = [math]::Sqrt([math]::Pow($major - $vMajor, 2) * 10 + [math]::Pow($minor - $vMinor, 2))
                    
                    if ($distance -lt $closestDistance) {
                        $closestDistance = $distance
                        $closest = $version
                    }
                }
            }
            
            if ($closest -and $closestDistance -lt 5) {  # Only consider it close enough if distance < 5
                return $closest
            }
        }
        
        # Try to find version containing the local version string
        foreach ($version in $filteredVersions) {
            if ($version.version_number -contains $localVersion -or $version.version_number -match [regex]::Escape($localVersion)) {
                return $version
            }
        }
        
    } catch {
        # Version parsing failed, fall back to latest
    }
    
    return $null
}

function Fetch-Modrinth-By-ModId {
    param (
        [string]$modId,
        [string]$version,
        [string]$preferredLoader = "Fabric"
    )
    try {
        # First, try direct project lookup by slug
        try {
            $projectUrl = "https://api.modrinth.com/v2/project/$modId"
            $projectData = Invoke-RestMethod -Uri $projectUrl -Method Get -UseBasicParsing -ErrorAction Stop
            
            if ($projectData.id) {
                # Get all versions for this project
                $versionsUrl = "https://api.modrinth.com/v2/project/$modId/version"
                $versionsData = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
                
                if ($versionsData.Count -gt 0) {
                    # Try to find exact version match or closest version
                    $matchedVersion = Find-Closest-Version -localVersion $version -availableVersions $versionsData -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion
                    
                    if ($matchedVersion) {
                        $file = $matchedVersion.files[0]
                        $isExact = ($matchedVersion.version_number -eq $version)
                        $loader = if ($matchedVersion.loaders -contains "fabric") { "Fabric" } elseif ($matchedVersion.loaders -contains "forge") { "Forge" } else { $matchedVersion.loaders[0] }
                        
                        return @{
                            Name = $projectData.title
                            Slug = $projectData.slug
                            ExpectedSize = $file.size
                            VersionNumber = $matchedVersion.version_number
                            FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($matchedVersion.id)"
                            FoundByHash = $false
                            ExactMatch = $isExact
                            IsLatestVersion = ($versionsData[0].id -eq $matchedVersion.id)
                            MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }
                            LoaderType = $loader
                        }
                    }
                    
                    # If no close version match, return latest version with preferred loader AND Minecraft version
                    foreach ($ver in $versionsData) {
                        $matchesLoader = ($ver.loaders -contains $preferredLoader.ToLower())
                        $matchesMinecraft = if ($minecraftVersion -and $ver.game_versions) {
                            ($ver.game_versions -contains $minecraftVersion)
                        } else {
                            $true
                        }
                        
                        if ($matchesLoader -and $matchesMinecraft) {
                            $latestFile = $ver.files[0]
                            $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                            
                            return @{
                                Name = $projectData.title
                                Slug = $projectData.slug
                                ExpectedSize = $latestFile.size
                                VersionNumber = $ver.version_number
                                FileName = $latestFile.filename
                                ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($ver.id)"
                                FoundByHash = $false
                                ExactMatch = $false
                                IsLatestVersion = ($versionsData[0].id -eq $ver.id)
                                MatchType = "Latest Version ($loader)"
                                LoaderType = $loader
                            }
                        }
                    }
                    
                    # If no version with preferred loader and Minecraft version, return latest version
                    $latestVersion = $versionsData[0]
                    $latestFile = $latestVersion.files[0]
                    $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                    
                    return @{
                        Name = $projectData.title
                        Slug = $projectData.slug
                        ExpectedSize = $latestFile.size
                        VersionNumber = $latestVersion.version_number
                        FileName = $latestFile.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($latestVersion.id)"
                        FoundByHash = $false
                        ExactMatch = $false
                        IsLatestVersion = $true
                        MatchType = "Latest Version ($loader)"
                        LoaderType = $loader
                    }
                }
            }
        } catch {
            # Direct lookup failed, try search
        }
        
        # Search for the mod by its ID
        $searchUrl = "https://api.modrinth.com/v2/search?query=`"$modId`"&facets=`"[[`"project_type:mod`"]]`"&limit=5"
        $searchData = Invoke-RestMethod -Uri $searchUrl -Method Get -UseBasicParsing -ErrorAction Stop
        
        if ($searchData.hits -and $searchData.hits.Count -gt 0) {
            # Try to find best match by mod ID/slug
            $bestMatch = $null
            $bestScore = 0
            
            foreach ($hit in $searchData.hits) {
                $score = 0
                if ($hit.slug -eq $modId) { $score += 100 }
                if ($hit.project_id -eq $modId) { $score += 100 }
                if ($hit.title -eq $modId) { $score += 80 }
                if ($hit.title -match $modId) { $score += 50 }
                if ($hit.slug -match $modId) { $score += 40 }
                
                if ($score -gt $bestScore) {
                    $bestScore = $score
                    $bestMatch = $hit
                }
            }
            
            if ($bestMatch) {
                $projectId = $bestMatch.project_id
                
                # Get all versions for this project
                $versionsUrl = "https://api.modrinth.com/v2/project/$projectId/version"
                $versionsData = Invoke-RestMethod -Uri $versionsUrl -Method Get -UseBasicParsing -ErrorAction Stop
                
                if ($versionsData.Count -gt 0) {
                    # Try to find exact version match or closest version
                    $matchedVersion = Find-Closest-Version -localVersion $version -availableVersions $versionsData -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion
                    
                    if ($matchedVersion) {
                        $file = $matchedVersion.files[0]
                        $isExact = ($matchedVersion.version_number -eq $version)
                        $loader = if ($matchedVersion.loaders -contains "fabric") { "Fabric" } elseif ($matchedVersion.loaders -contains "forge") { "Forge" } else { $matchedVersion.loaders[0] }
                        
                        return @{
                            Name = $bestMatch.title
                            Slug = $bestMatch.slug
                            ExpectedSize = $file.size
                            VersionNumber = $matchedVersion.version_number
                            FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($bestMatch.slug)/version/$($matchedVersion.id)"
                            FoundByHash = $false
                            ExactMatch = $isExact
                            IsLatestVersion = ($versionsData[0].id -eq $matchedVersion.id)
                            MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }
                            LoaderType = $loader
                        }
                    }
                    
                    # Return latest version with preferred loader AND Minecraft version
                    foreach ($ver in $versionsData) {
                        $matchesLoader = ($ver.loaders -contains $preferredLoader.ToLower())
                        $matchesMinecraft = if ($minecraftVersion -and $ver.game_versions) {
                            ($ver.game_versions -contains $minecraftVersion)
                        } else {
                            $true
                        }
                        
                        if ($matchesLoader -and $matchesMinecraft) {
                            $latestFile = $ver.files[0]
                            $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                            
                            return @{
                                Name = $bestMatch.title
                                Slug = $bestMatch.slug
                                ExpectedSize = $latestFile.size
                                VersionNumber = $ver.version_number
                                FileName = $latestFile.filename
                                ModrinthUrl = "https://modrinth.com/mod/$($bestMatch.slug)/version/$($ver.id)"
                                FoundByHash = $false
                                ExactMatch = $false
                                IsLatestVersion = ($versionsData[0].id -eq $ver.id)
                                MatchType = "Latest Version ($loader)"
                                LoaderType = $loader
                            }
                        }
                    }
                    
                    # Return latest version
                    $latestVersion = $versionsData[0]
                    $latestFile = $latestVersion.files[0]
                    $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                    
                    return @{
                        Name = $bestMatch.title
                        Slug = $bestMatch.slug
                        ExpectedSize = $latestFile.size
                        VersionNumber = $latestVersion.version_number
                        FileName = $latestFile.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($bestMatch.slug)/version/$($latestVersion.id)"
                        FoundByHash = $false
                        ExactMatch = $false
                        IsLatestVersion = $true
                        MatchType = "Latest Version ($loader)"
                        LoaderType = $loader
                    }
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
        IsLatestVersion = $false;
        MatchType = "No Match";
        LoaderType = "Unknown"
    }
}

function Fetch-Modrinth-By-Filename {
    param (
        [string]$filename,
        [string]$preferredLoader = "Fabric"
    )
    try {
        # Clean the filename
        $cleanFilename = $filename -replace '\.temp\.jar$', '.jar' -replace '\.tmp\.jar$', '.jar' -replace '_1\.jar$', '.jar'
        $modNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($cleanFilename)
        
        # Extract potential mod ID from filename
        $baseName = $modNameWithoutExt
        
        # Check for loader in filename
        $hasLoaderInName = $false
        if ($filename -match '(?i)fabric') {
            $preferredLoader = "Fabric"
            $hasLoaderInName = $true
        } elseif ($filename -match '(?i)forge') {
            $preferredLoader = "Forge"
            $hasLoaderInName = $true
        }
        
        # Try to extract version from filename
        $localVersion = ""
        if ($modNameWithoutExt -match '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$') {
            $localVersion = $matches[1]
            $baseName = $modNameWithoutExt -replace '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$', ''
        }
        
        # Remove loader suffixes from base name
        $baseName = $baseName -replace '(?i)-fabric$', '' -replace '(?i)-forge$', ''
        
        # Try direct slug lookup first
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
                            if ($file.filename -eq $cleanFilename -or $file.filename -eq $filename) {
                                $loader = if ($version.loaders -contains "fabric") { "Fabric" } elseif ($version.loaders -contains "forge") { "Forge" } else { $version.loaders[0] }
                                
                                return @{
                                    Name = $projectData.title
                                    Slug = $projectData.slug
                                    ExpectedSize = $file.size
                                    VersionNumber = $version.version_number
                                    FileName = $file.filename
                                    ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($version.id)"
                                    FoundByHash = $false
                                    ExactMatch = $true
                                    IsLatestVersion = ($versionsData[0].id -eq $version.id)
                                    MatchType = "Exact Filename"
                                    LoaderType = $loader
                                }
                            }
                        }
                    }
                    
                    # Try to find closest version match with preferred loader AND Minecraft version
                    if ($localVersion -and $versionsData.Count -gt 0) {
                        $matchedVersion = Find-Closest-Version -localVersion $localVersion -availableVersions $versionsData -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion
                        
                        if ($matchedVersion) {
                            $file = $matchedVersion.files[0]
                            $isExact = ($matchedVersion.version_number -eq $localVersion)
                            $loader = if ($matchedVersion.loaders -contains "fabric") { "Fabric" } elseif ($matchedVersion.loaders -contains "forge") { "Forge" } else { $matchedVersion.loaders[0] }
                            
                            return @{
                                Name = $projectData.title
                                Slug = $projectData.slug
                                ExpectedSize = $file.size
                                VersionNumber = $matchedVersion.version_number
                                FileName = $file.filename
                                ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($matchedVersion.id)"
                                FoundByHash = $false
                                ExactMatch = $isExact
                                IsLatestVersion = ($versionsData[0].id -eq $matchedVersion.id)
                                MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }
                                LoaderType = $loader
                            }
                        }
                    }
                    
                    # Return latest version with preferred loader AND Minecraft version
                    foreach ($version in $versionsData) {
                        $matchesLoader = ($version.loaders -contains $preferredLoader.ToLower())
                        $matchesMinecraft = if ($minecraftVersion -and $version.game_versions) {
                            ($version.game_versions -contains $minecraftVersion)
                        } else {
                            $true
                        }
                        
                        if ($matchesLoader -and $matchesMinecraft) {
                            $file = $version.files[0]
                            $loader = if ($version.loaders -contains "fabric") { "Fabric" } elseif ($version.loaders -contains "forge") { "Forge" } else { $version.loaders[0] }
                            
                            return @{
                                Name = $projectData.title
                                Slug = $projectData.slug
                                ExpectedSize = $file.size
                                VersionNumber = $version.version_number
                                FileName = $file.filename
                                ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($version.id)"
                                FoundByHash = $false
                                ExactMatch = $false
                                IsLatestVersion = ($versionsData[0].id -eq $version.id)
                                MatchType = "Latest Version ($loader)"
                                LoaderType = $loader
                            }
                        }
                    }
                    
                    # Return latest version
                    if ($versionsData.Count -gt 0) {
                        $latestVersion = $versionsData[0]
                        $latestFile = $latestVersion.files[0]
                        $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                        
                        return @{
                            Name = $projectData.title
                            Slug = $projectData.slug
                            ExpectedSize = $latestFile.size
                            VersionNumber = $latestVersion.version_number
                            FileName = $latestFile.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($latestVersion.id)"
                            FoundByHash = $false
                            ExactMatch = $false
                            IsLatestVersion = $true
                            MatchType = "Latest Version ($loader)"
                            LoaderType = $loader
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
                    if ($file.filename -eq $cleanFilename -or $file.filename -eq $filename) {
                        $loader = if ($version.loaders -contains "fabric") { "Fabric" } elseif ($version.loaders -contains "forge") { "Forge" } else { $version.loaders[0] }
                        
                        return @{
                            Name = $hit.title
                            Slug = $hit.slug
                            ExpectedSize = $file.size
                            VersionNumber = $version.version_number
                            FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($version.id)"
                            FoundByHash = $false
                            ExactMatch = $true
                            IsLatestVersion = ($versionsData[0].id -eq $version.id)
                            MatchType = "Exact Filename"
                            LoaderType = $loader
                        }
                    }
                }
            }
            
            # Return latest version with preferred loader AND Minecraft version
            foreach ($version in $versionsData) {
                $matchesLoader = ($version.loaders -contains $preferredLoader.ToLower())
                $matchesMinecraft = if ($minecraftVersion -and $version.game_versions) {
                    ($version.game_versions -contains $minecraftVersion)
                } else {
                    $true
                }
                
                if ($matchesLoader -and $matchesMinecraft) {
                    $file = $version.files[0]
                    $loader = if ($version.loaders -contains "fabric") { "Fabric" } elseif ($version.loaders -contains "forge") { "Forge" } else { $version.loaders[0] }
                    
                    return @{
                        Name = $hit.title
                        Slug = $hit.slug
                        ExpectedSize = $file.size
                        VersionNumber = $version.version_number
                        FileName = $file.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($version.id)"
                        FoundByHash = $false
                        ExactMatch = $false
                        IsLatestVersion = ($versionsData[0].id -eq $version.id)
                        MatchType = "Latest Version ($loader)"
                        LoaderType = $loader
                    }
                }
            }
            
            # Return latest version
            if ($versionsData.Count -gt 0) {
                $latestVersion = $versionsData[0]
                $latestFile = $latestVersion.files[0]
                $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                
                return @{
                    Name = $hit.title
                    Slug = $hit.slug
                    ExpectedSize = $latestFile.size
                    VersionNumber = $latestVersion.version_number
                    FileName = $latestFile.filename
                    ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($latestVersion.id)"
                    FoundByHash = $false
                    ExactMatch = $false
                    IsLatestVersion = $true
                    MatchType = "Latest Version ($loader)"
                    LoaderType = $loader
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
        IsLatestVersion = $false;
        MatchType = "No Match";
        LoaderType = "Unknown"
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

# Cheat strings - Your updated list
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

function Check-Strings {
    param (
        [string]$filePath
    )
    
    $stringsFound = [System.Collections.Generic.HashSet[string]]::new()
    
    try {
        # Try to use strings.exe if available (like HabibiModAnalyzer)
        $stringsPath = $null
        
        # Common locations for strings.exe (Git for Windows)
        $possiblePaths = @(
            "C:\Program Files\Git\usr\bin\strings.exe",
            "C:\Program Files\Git\mingw64\bin\strings.exe",
            "$env:ProgramFiles\Git\usr\bin\strings.exe",
            "C:\msys64\usr\bin\strings.exe",
            "C:\cygwin64\bin\strings.exe"
        )
        
        # Try to find strings.exe
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $stringsPath = $path
                break
            }
        }
        
        if ($stringsPath) {
            # Use strings.exe to extract human-readable strings only
            $tempFile = Join-Path $env:TEMP "temp_strings_$(Get-Random).txt"
            
            # Run strings.exe and capture output
            & $stringsPath $filePath 2>$null | Out-File $tempFile -ErrorAction SilentlyContinue
            
            if (Test-Path $tempFile) {
                $extractedContent = Get-Content $tempFile -Raw
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                
                # Search for cheat strings in extracted content only
                foreach ($string in $cheatStrings) {
                    # Use case-insensitive matching with word boundaries where possible
                    if ($extractedContent -match $string) {
                        $stringsFound.Add($string) | Out-Null
                    }
                }
            }
        } else {
            # Fallback: Use PowerShell but be more careful about false positives
            # Read file as bytes first to avoid encoding issues
            $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
            $content = [System.Text.Encoding]::ASCII.GetString($fileBytes).ToLower()
            
            # Only check for "velocity" in specific cheat contexts
            # This reduces false positives
            foreach ($string in $cheatStrings) {
                # Skip "velocity" unless it's in a cheat context
                if ($string -eq "velocity") {
                    # Only flag velocity if it's part of cheat-related terms
                    if ($content -match "velocity(hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
                        $stringsFound.Add($string) | Out-Null
                    }
                } else {
                    # Check other cheat strings
                    if ($content -match $string) {
                        $stringsFound.Add($string) | Out-Null
                    }
                }
            }
        }
        
    } catch {
        # Error reading file
    }
    
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
    
    # Extract mod info from JAR file
    $jarModInfo = Get-Mod-Info-From-Jar -jarPath $file.FullName
    
    # Determine preferred loader based on filename
    $preferredLoader = "Fabric"  # Default to Fabric
    if ($file.Name -match '(?i)fabric') {
        $preferredLoader = "Fabric"
    } elseif ($file.Name -match '(?i)forge') {
        $preferredLoader = "Forge"
    } elseif ($jarModInfo.ModLoader -eq "Fabric") {
        $preferredLoader = "Fabric"
    } elseif ($jarModInfo.ModLoader -eq "Forge/NeoForge") {
        $preferredLoader = "Forge"
    }
    
    # Try Modrinth by hash first (most accurate)
    $modData = Fetch-Modrinth-By-Hash -hash $hash
    
    if ($modData.Name -and $modData.FoundByHash) {
        # Calculate size difference
        $sizeDiff = $actualSize - $modData.ExpectedSize
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
            SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modData.ModrinthUrl
            IsVerified = $true
            MatchType = $modData.MatchType
            ExactMatch = $modData.ExactMatch
            IsLatestVersion = $modData.IsLatestVersion
            LoaderType = $modData.LoaderType
            PreferredLoader = $preferredLoader
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarModLoader = $jarModInfo.ModLoader
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
    
    # Try to find mod on Modrinth using mod ID from JAR file
    $modrinthInfoFromJar = $null
    if ($jarModInfo.ModId) {
        $modrinthInfoFromJar = Fetch-Modrinth-By-ModId -modId $jarModInfo.ModId -version $jarModInfo.Version -preferredLoader $preferredLoader
    }
    
    if ($modrinthInfoFromJar -and $modrinthInfoFromJar.Name) {
        # Calculate size difference
        $sizeDiff = $actualSize - $modrinthInfoFromJar.ExpectedSize
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
            SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modrinthInfoFromJar.ModrinthUrl
            IsVerified = $true
            MatchType = $modrinthInfoFromJar.MatchType
            ExactMatch = $modrinthInfoFromJar.ExactMatch
            IsLatestVersion = $modrinthInfoFromJar.IsLatestVersion
            LoaderType = $modrinthInfoFromJar.LoaderType
            PreferredLoader = $preferredLoader
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarModLoader = $jarModInfo.ModLoader
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
    $modrinthInfo = Fetch-Modrinth-By-Filename -filename $file.Name -preferredLoader $preferredLoader
    
    # Check if we found mod info by filename
    if ($modrinthInfo.Name) {
        # Calculate size difference
        $sizeDiff = $actualSize - $modrinthInfo.ExpectedSize
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
            SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modrinthInfo.ModrinthUrl
            IsVerified = $true
            MatchType = $modrinthInfo.MatchType
            ExactMatch = $modrinthInfo.ExactMatch
            IsLatestVersion = $modrinthInfo.IsLatestVersion
            LoaderType = $modrinthInfo.LoaderType
            PreferredLoader = $preferredLoader
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarModLoader = $jarModInfo.ModLoader
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
            SizeDiffKB = 0
            DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth
            IsVerified = $true
            MatchType = "Megabase"
            ExactMatch = $false
            IsLatestVersion = $false
            LoaderType = "Unknown"
            PreferredLoader = $preferredLoader
            FilePath = $file.FullName
            JarModId = $jarModInfo.ModId
            JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version
            JarModLoader = $jarModInfo.ModLoader
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
        SizeDiffKB = 0
        ModrinthUrl = ""
        ModName = ""
        MatchType = ""
        ExactMatch = $false
        IsLatestVersion = $false
        LoaderType = "Unknown"
        PreferredLoader = $preferredLoader
        JarModId = $jarModInfo.ModId
        JarName = $jarModInfo.Name
        JarVersion = $jarModInfo.Version
        JarModLoader = $jarModInfo.ModLoader
    }
    
    $unknownMods += $unknownModEntry
    $allModsInfo += $unknownModEntry
}

# For unknown mods, try to find Modrinth info AFTER scanning all mods
for ($i = 0; $i -lt $unknownMods.Count; $i++) {
    $mod = $unknownMods[$i]
    
    # Try by JAR mod ID first
    $modrinthInfo = $null
    if ($mod.JarModId) {
        $modrinthInfo = Fetch-Modrinth-By-ModId -modId $mod.JarModId -version $mod.JarVersion -preferredLoader $mod.PreferredLoader
    }
    
    # If not found, try by filename
    if (-not $modrinthInfo -or -not $modrinthInfo.Name) {
        $modrinthInfo = Fetch-Modrinth-By-Filename -filename $mod.FileName -preferredLoader $mod.PreferredLoader
    }
    
    if ($modrinthInfo -and $modrinthInfo.Name) {
        # Update the unknown mod entry with Modrinth info
        $mod.ModName = $modrinthInfo.Name
        $mod.ExpectedSize = $modrinthInfo.ExpectedSize
        $mod.ExpectedSizeKB = if ($modrinthInfo.ExpectedSize -gt 0) { [math]::Round($modrinthInfo.ExpectedSize/1KB, 2) } else { 0 }
        $mod.SizeDiff = $mod.FileSize - $modrinthInfo.ExpectedSize
        $mod.SizeDiffKB = [math]::Round(($mod.FileSize - $modrinthInfo.ExpectedSize)/1KB, 2)
        $mod.ModrinthUrl = $modrinthInfo.ModrinthUrl
        $mod.ModName = $modrinthInfo.Name
        $mod.MatchType = $modrinthInfo.MatchType
        $mod.ExactMatch = $modrinthInfo.ExactMatch
        $mod.IsLatestVersion = $modrinthInfo.IsLatestVersion
        $mod.LoaderType = $modrinthInfo.LoaderType
        
        # Also update in allModsInfo array
        for ($j = 0; $j -lt $allModsInfo.Count; $j++) {
            if ($allModsInfo[$j].FileName -eq $mod.FileName) {
                $allModsInfo[$j].ModName = $modrinthInfo.Name
                $allModsInfo[$j].ExpectedSize = $modrinthInfo.ExpectedSize
                $allModsInfo[$j].ExpectedSizeKB = $mod.ExpectedSizeKB
                $allModsInfo[$j].SizeDiff = $mod.SizeDiff
                $allModsInfo[$j].SizeDiffKB = $mod.SizeDiffKB
                $allModsInfo[$j].ModrinthUrl = $modrinthInfo.ModrinthUrl
                $allModsInfo[$j].ModName = $modrinthInfo.Name
                $allModsInfo[$j].MatchType = $modrinthInfo.MatchType
                $allModsInfo[$j].ExactMatch = $modrinthInfo.ExactMatch
                $allModsInfo[$j].IsLatestVersion = $modrinthInfo.IsLatestVersion
                $allModsInfo[$j].LoaderType = $modrinthInfo.LoaderType
                break
            }
        }
    }
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
            $cheatMods += [PSCustomObject]@{ 
                FileName = $mod.FileName
                StringsFound = $modStrings
                FileSizeKB = $mod.FileSizeKB
                DownloadSource = $mod.DownloadSource
                SourceURL = $mod.ZoneId
                ExpectedSizeKB = $mod.ExpectedSizeKB
                SizeDiffKB = $mod.SizeDiffKB
                IsVerifiedMod = ($mod.IsVerified -eq $true)
                ModName = $mod.ModName
                ModrinthUrl = $mod.ModrinthUrl
                FilePath = $mod.FilePath
                HasSizeMismatch = ($mod.SizeDiffKB -ne 0 -and [math]::Abs($mod.SizeDiffKB) -gt 1)
                JarModId = $mod.JarModId
                JarName = $mod.JarName
                JarVersion = $mod.JarVersion
                MatchType = $mod.MatchType
                ExactMatch = $mod.ExactMatch
                IsLatestVersion = $mod.IsLatestVersion
                LoaderType = $mod.LoaderType
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

# Display results
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
        
        # Show match type indicator
        $matchIndicator = ""
        $matchColor = "DarkGray"
        if ($mod.MatchType -eq "Exact Hash" -or $mod.MatchType -eq "Exact Version" -or $mod.MatchType -eq "Exact Filename") {
            $matchIndicator = "✓"
            $matchColor = "Green"
        } elseif ($mod.MatchType -eq "Closest Version") {
            $matchIndicator = "≈"
            $matchColor = "Yellow"
        } elseif ($mod.MatchType -match "Latest Version") {
            $matchIndicator = "↑"
            $matchColor = "Cyan"
        }
        
        if ($matchIndicator) {
            Write-Host " $matchIndicator" -ForegroundColor $matchColor -NoNewline
        }
        
        # Show loader type
        if ($mod.LoaderType -ne "Unknown") {
            $loaderColor = if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" }
            Write-Host " ($($mod.LoaderType))" -ForegroundColor $loaderColor -NoNewline
        }
        
        if ($mod.DownloadSource -ne "Unknown") {
            $sourceColor = if ($mod.IsModrinthDownload) { "Green" } else { "DarkYellow" }
            Write-Host " [$($mod.DownloadSource)]" -ForegroundColor $sourceColor
        } else {
            Write-Host ""
        }
        
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                Write-Host "  Size: $($mod.ActualSizeKB) KB ✓" -ForegroundColor Green
            } else {
                $sizeDiffSign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
                $sizeColor = if ($tamperedMods.FileName -contains $mod.FileName) { "Magenta" } else { "Yellow" }
                Write-Host "  Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB, Diff: $sizeDiffSign$($mod.SizeDiffKB) KB)" -ForegroundColor $sizeColor
            }
        }
    }
    Write-Host ""
}

if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)"
    Write-Host
    
    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        # Show Modrinth info if we found it
        if ($mod.ModName) {
            Write-Host "  Identified as: $($mod.ModName)" -ForegroundColor Cyan
            
            # Show loader type
            if ($mod.LoaderType -ne "Unknown") {
                $loaderColor = if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" }
                Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $loaderColor
            }
            
            # Show match type
            if ($mod.MatchType -eq "Closest Version") {
                Write-Host "  Using closest version: $($mod.MatchType)" -ForegroundColor Yellow
            } elseif ($mod.MatchType -match "Latest Version") {
                Write-Host "  Using latest version: $($mod.MatchType)" -ForegroundColor Cyan
            }
            
            if ($mod.ExpectedSize -gt 0) {
                if ($mod.FileSize -eq $mod.ExpectedSize) {
                    Write-Host "  Size matches Modrinth: $($mod.FileSizeKB) KB ✓" -ForegroundColor Green
                } else {
                    $sizeDiffSign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
                    Write-Host "  Size: $($mod.FileSizeKB) KB (Expected from Modrinth: $($mod.ExpectedSizeKB) KB, Diff: $sizeDiffSign$($mod.SizeDiffKB) KB)" -ForegroundColor Yellow
                }
            }
        }
        
        if ($mod.ZoneId) {
            $sourceColor = if ($mod.IsModrinthDownload) { "Green" } else { "DarkYellow" }
            Write-Host "  Downloaded from: $($mod.DownloadSource)" -ForegroundColor $sourceColor
        }
        
        Write-Host ""
    }
}

if ($tamperedMods.Count -gt 0) {
    Write-Host "{ Potentially Tampered Mods }" -ForegroundColor Red
    Write-Host "Total: $($tamperedMods.Count) ⚠ WARNING"
    Write-Host
    
    foreach ($mod in $tamperedMods) {
        $sizeDiffSign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Magenta
        
        # Show loader type
        if ($mod.LoaderType -ne "Unknown") {
            $loaderColor = if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" }
            Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $loaderColor
        }
        
        # Show match type for context
        if ($mod.MatchType -eq "Closest Version") {
            Write-Host "  Note: Compared to closest available version on Modrinth" -ForegroundColor Yellow
        } elseif ($mod.MatchType -match "Latest Version") {
            Write-Host "  Note: Compared to latest version on Modrinth" -ForegroundColor Cyan
        }
        
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sizeDiffSign$($mod.SizeDiffKB) KB" -ForegroundColor Magenta
        Write-Host "  ⚠ File size differs significantly from Modrinth version!" -ForegroundColor Red
        
        if ($mod.ModrinthUrl) {
            Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
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
            
            # Show loader type
            if ($mod.LoaderType -ne "Unknown") {
                $loaderColor = if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" }
                Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $loaderColor
            }
            
            # Show match type for context
            if ($mod.MatchType -eq "Closest Version") {
                Write-Host "  Note: Compared to closest available version on Modrinth" -ForegroundColor Yellow
            } elseif ($mod.MatchType -match "Latest Version") {
                Write-Host "  Note: Compared to latest version on Modrinth" -ForegroundColor Cyan
            }
        }
        
        Write-Host "  Cheat Strings: $($mod.StringsFound)" -ForegroundColor Magenta
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        # Show size comparison
        if ($mod.ExpectedSizeKB -gt 0) {
            $sizeDiffSign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
            if ($mod.SizeDiffKB -eq 0) {
                Write-Host "  Size matches Modrinth: $($mod.ExpectedSizeKB) KB ✓" -ForegroundColor Green
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
            $sourceColor = if ($mod.DownloadSource -eq "Modrinth") { "Green" } else { "DarkYellow" }
            Write-Host "  Source: $($mod.DownloadSource)" -ForegroundColor $sourceColor
        }
        
        if ($mod.IsVerifiedMod) {
            Write-Host "  ⚠ Legitimate mod contains cheat code!" -ForegroundColor Red
            Write-Host "  ⚠ This appears to be a tampered version of a legitimate mod" -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

Write-Host "DM YarpLetapStan for errors" -ForegroundColor Cyan
Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

