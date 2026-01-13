Clear-Host
Write-Host "Made by YarpLetapStan`nDM YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan

# Create title box
$boxWidth = 38
$border = "+" + ("-" * $boxWidth) + "+"
$empty = "|" + (" " * $boxWidth) + "|"
$title = "|" + ("YarpLetapStan's Mod Analyzer V5.0".PadLeft(($boxWidth + 30)/2).PadRight($boxWidth)) + "|"
Write-Host $border -ForegroundColor Blue
Write-Host $empty -ForegroundColor Blue
Write-Host $title -ForegroundColor Blue
Write-Host $empty -ForegroundColor Blue
Write-Host $border -ForegroundColor Blue
Write-Host ""

# Get mods folder path
Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray
$mods = Read-Host "PATH"
Write-Host

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host "Continuing with $mods`n" -ForegroundColor White
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    exit 1
}

# Check Minecraft uptime
$process = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $process) { $process = Get-Process java -ErrorAction SilentlyContinue }

if ($process) {
    try {
        $elapsedTime = (Get-Date) - $process.StartTime
        Write-Host "{ Minecraft Uptime }" -ForegroundColor Cyan
        Write-Host "$($process.Name) PID $($process.Id) started at $($process.StartTime) and running for $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s`n"
    } catch {}
}

# IMPROVED Obfuscation Detection Function (LESS FALSE POSITIVES)
function Test-ObfuscatedFile {
    param ($filePath, $fileType = "jar")
    
    $obfuscationScore = 0
    $reasons = @()
    $falsePositiveMitigations = 0
    
    try {
        # Get file size first
        $fileSize = (Get-Item $filePath).Length
        if ($fileSize -lt 10240) { # Files smaller than 10KB are often libraries/configs
            return @{ IsObfuscated = $false; Score = 0; Level = "Clean"; Reasons = @() }
        }
        
        # 1. Check for high entropy (but be more conservative)
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        
        # Calculate byte frequency and entropy
        $byteCounts = New-Object int[] 256
        foreach ($byte in $fileBytes) { $byteCounts[$byte]++ }
        
        $entropy = 0
        for ($i = 0; $i -lt 256; $i++) {
            if ($byteCounts[$i] -gt 0) {
                $p = $byteCounts[$i] / $fileSize
                $entropy += $p * [Math]::Log($p, 2)
            }
        }
        $entropy = -$entropy
        $normalizedEntropy = $entropy / 8
        
        # Higher threshold for entropy (reduces false positives)
        # Normal JARs often have entropy around 60-80%, so we set threshold at 90%
        if ($normalizedEntropy -gt 0.92) { # Increased from 0.85
            $obfuscationScore += 15  # Reduced from 20
            $reasons += "Very high entropy ($([math]::Round($normalizedEntropy*100, 1))%)"
        } elseif ($normalizedEntropy -gt 0.88) {
            $obfuscationScore += 8  # Lower score for moderately high entropy
            $reasons += "Moderately high entropy ($([math]::Round($normalizedEntropy*100, 1))%)"
        } else {
            $falsePositiveMitigations++ # Low entropy = less likely obfuscated
        }
        
        # 2. Check JAR structure with better heuristics
        if ($fileType -eq "jar") {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($filePath)
                $entries = $zip.Entries
                $totalEntries = $entries.Count
                
                # Check for reasonable number of class files
                $classFiles = $entries | Where-Object { $_.FullName.EndsWith('.class') }
                $classFileCount = $classFiles.Count
                
                # Don't flag based on class count alone unless extremely high
                if ($classFileCount -gt 2000) { # Increased threshold
                    $obfuscationScore += 10  # Reduced from 15
                    $reasons += "Very high class count ($classFileCount)"
                }
                
                # Check for short/random class names with better logic
                $randomNames = 0
                $validClassNames = 0
                
                foreach ($classFile in $classFiles) {
                    $name = [System.IO.Path]::GetFileNameWithoutExtension($classFile.Name)
                    
                    # Common legitimate patterns to allow
                    $isLikelyLegitimate = $false
                    
                    # Allow common patterns
                    if ($name -match '^[A-Z][a-zA-Z0-9_]+$' -or  # Standard class names like "Main", "ClientMod"
                        $name -match '^[A-Z][a-zA-Z0-9_]*[A-Z][a-zA-Z0-9_]*$' -or  # CamelCase
                        $name -match '^[A-Z][a-zA-Z0-9_]*Impl$' -or  # Common suffix
                        $name -match '^[A-Z][a-zA-Z0-9_]*Factory$' -or
                        $name -match '^[A-Z][a-zA-Z0-9_]*Handler$' -or
                        $name -match '^[A-Z][a-zA-Z0-9_]*Manager$' -or
                        $name -match '^[A-Z][a-zA-Z0-9_]*Container$' -or
                        $name -match '^[A-Z][a-zA-Z0-9_]*Renderer$' -or
                        $name.Length -gt 8) {  # Longer names are less likely to be obfuscated
                        $validClassNames++
                        $isLikelyLegitimate = $true
                    }
                    
                    # Flag only very suspicious patterns
                    if (-not $isLikelyLegitimate) {
                        # Very short names or single letters with numbers
                        if ($name -match '^[a-z]$' -or  # Single lowercase letter
                            $name -match '^[a-z]\d+$' -or  # Letter followed by numbers only
                            $name -match '^\d+[a-z]$' -or  # Numbers followed by single letter
                            $name -match '^[a-z][a-z]$' -or  # Two lowercase letters
                            ($name -match '^[a-zA-Z0-9]{1,2}$' -and $name -notmatch '^[A-Z]')) {  # 1-2 chars not starting with uppercase
                            $randomNames++
                        }
                    }
                }
                
                # Only flag if a significant portion AND we have enough samples
                if ($classFileCount -gt 50 -and $randomNames -gt ($classFileCount * 0.4)) { # Increased threshold from 30%
                    $obfuscationScore += 18  # Reduced from 20
                    $reasons += "Many random class names ($randomNames/$classFileCount)"
                } elseif ($validClassNames -gt ($classFileCount * 0.6)) {
                    $falsePositiveMitigations++ # Many valid names = less likely obfuscated
                }
                
                # 3. Check for known obfuscators in manifest (strong indicator)
                $manifest = $entries | Where-Object { $_.FullName -eq 'META-INF/MANIFEST.MF' } | Select-Object -First 1
                if ($manifest) {
                    $reader = New-Object System.IO.StreamReader($manifest.Open())
                    $content = $reader.ReadToEnd()
                    $reader.Close()
                    
                    # Specific obfuscator signatures (strong indicators)
                    $strongObfuscators = @(
                        "Allatori",
                        "ZKM", 
                        "DashO",
                        "KlassMaster",
                        "Smoke",
                        "Zelix",
                        "Stringer"
                    )
                    
                    $weakObfuscators = @("ProGuard", "yGuard") # These are common and sometimes legitimate
                    
                    foreach ($obf in $strongObfuscators) {
                        if ($content -match $obf) {
                            $obfuscationScore += 30  # Strong indicator
                            $reasons += "Strong obfuscator detected: $obf"
                            break
                        }
                    }
                    
                    foreach ($obf in $weakObfuscators) {
                        if ($content -match $obf) {
                            $obfuscationScore += 10  # Weaker indicator
                            $reasons += "Common tool detected: $obf"
                            break
                        }
                    }
                }
                
                # 4. Check for packed/protected JAR indicators (stronger check)
                $suspiciousFiles = $entries | Where-Object { 
                    $_.FullName -match '\.(data|pack|enc|crypt|secure)$' -or
                    $_.FullName -match 'native/' -and $_.FullName -match '\.(dll|so|dylib)$' -or
                    $_.FullName -match '^META-INF/.*\.(SF|DSA|RSA)$' -or # Signature files
                    $_.FullName -match '\.class\.data$' # Obfuscated class data
                }
                
                if ($suspiciousFiles.Count -gt 0) {
                    $obfuscationScore += 20  # Reduced from 25
                    $reasons += "Packed/protected files detected"
                }
                
                # 5. Check for legitimate indicators (reduce false positives)
                $legitimateIndicators = 0
                
                # Check for mod metadata files
                $modFiles = $entries | Where-Object {
                    $_.FullName -match 'fabric\.mod\.json' -or
                    $_.FullName -match 'META-INF/mods\.toml' -or
                    $_.FullName -match '\.mixins\.json$' -or
                    $_.FullName -match 'mcmod\.info'
                }
                
                if ($modFiles.Count -gt 0) {
                    $legitimateIndicators++
                    $falsePositiveMitigations += 2 # Strong legitimate indicator
                }
                
                # Check for resources (textures, models, etc.)
                $resourceFiles = $entries | Where-Object {
                    $_.FullName -match '\.(png|json|lang|txt|properties|cfg)$'
                }
                
                if ($resourceFiles.Count -gt 5) {
                    $legitimateIndicators++
                    $falsePositiveMitigations++ # Resources indicate legitimate mod
                }
                
                $zip.Dispose()
                
            } catch {
                # Can't read as ZIP - might be packed/encrypted or corrupted
                # Only flag if file is reasonably large
                if ($fileSize -gt 51200) { # 50KB minimum
                    $obfuscationScore += 25  # Reduced from 30
                    $reasons += "Cannot read as ZIP (possibly encrypted/packed)"
                } else {
                    # Small files might just be corrupted or not JARs
                    $falsePositiveMitigations++
                }
            }
        }
        
        # 6. Check string density with better thresholds
        $stringsExe = $null
        $possiblePaths = @(
            "C:\Program Files\Git\usr\bin\strings.exe",
            "C:\Program Files\Git\mingw64\bin\strings.exe",
            "$env:ProgramFiles\Git\usr\bin\strings.exe",
            "C:\msys64\usr\bin\strings.exe"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) { $stringsExe = $path; break }
        }
        
        if ($stringsExe -and $fileSize -gt 10240) { # Only check files > 10KB
            $tempFile = Join-Path $env:TEMP "temp_strings_$(Get-Random).txt"
            & $stringsExe $filePath 2>$null | Out-File $tempFile
            if (Test-Path $tempFile) {
                $stringCount = (Get-Content $tempFile | Measure-Object -Line).Lines
                Remove-Item $tempFile -Force
                
                $stringDensity = $stringCount / ($fileSize / 1024) # strings per KB
                
                # Adjusted thresholds for string density
                if ($stringDensity -lt 0.2) { # Reduced from 0.5
                    $obfuscationScore += 12  # Reduced from 15
                    $reasons += "Very low string density ($([math]::Round($stringDensity, 2)) strings/KB)"
                } elseif ($stringDensity -lt 0.5) {
                    $obfuscationScore += 5  # Lower score for moderately low density
                    $reasons += "Low string density ($([math]::Round($stringDensity, 2)) strings/KB)"
                } else {
                    $falsePositiveMitigations++ # Good string density = less likely obfuscated
                }
            }
        }
        
        # 7. Apply false positive mitigation
        if ($falsePositiveMitigations -ge 3) {
            $obfuscationScore = [math]::Max(0, $obfuscationScore - 15)
            if ($obfuscationScore -lt 30 -and $reasons.Count -gt 0) {
                $reasons += "(Score reduced due to legitimate indicators)"
            }
        }
        
    } catch {
        # If we can't analyze the file, assume it's clean
        return @{ IsObfuscated = $false; Score = 0; Level = "Clean"; Reasons = @() }
    }
    
    # DETERMINE OBFUSCATION LEVEL WITH HIGHER THRESHOLDS
    $level = "Clean"
    $levelColor = "Green"
    
    if ($obfuscationScore -ge 40) { # CHANGED FROM 65 TO 40 (ONLY THIS LINE CHANGED)
        $level = "Highly Obfuscated"
        $levelColor = "Red"
    } elseif ($obfuscationScore -ge 45) { # Increased from 40 - KEPT ORIGINAL
        $level = "Moderately Obfuscated"
        $levelColor = "Yellow"
    } elseif ($obfuscationScore -ge 25) { # Increased from 20 - KEPT ORIGINAL
        $level = "Slightly Obfuscated"
        $levelColor = "Cyan"
    } elseif ($obfuscationScore -ge 15) {
        $level = "Possibly Obfuscated"
        $levelColor = "DarkCyan"
    }
    
    # Only flag as truly obfuscated at higher threshold
    $isObfuscated = $obfuscationScore -ge 35  # Increased from 30 - KEPT ORIGINAL
    
    return @{
        IsObfuscated = $isObfuscated
        Score = $obfuscationScore
        Level = $level
        LevelColor = $levelColor
        Reasons = $reasons
    }
}

function Get-Minecraft-Version-From-Mods($modsFolder) {
    $minecraftVersions = @{}
    $jarFiles = Get-ChildItem -Path $modsFolder -Filter *.jar
    
    foreach ($file in $jarFiles) {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
            
            if ($fabricModJson = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1) {
                $reader = New-Object System.IO.StreamReader($fabricModJson.Open())
                $fabricData = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue
                $reader.Close()
                
                if ($fabricData.depends.minecraft) {
                    $mcVersion = $fabricData.depends.minecraft -replace '^[><=~^]*\s*' -replace '\s*$'
                    if ($mcVersion -match '^\d+(\.\d+)+(\.\d+)?$') {
                        $minecraftVersions[$mcVersion] = ($minecraftVersions[$mcVersion] + 1)
                    }
                }
            }
            $zip.Dispose()
        } catch { continue }
    }
    
    if ($minecraftVersions.Count -gt 0) {
        $mostCommon = $minecraftVersions.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        Write-Host "`nDetected Minecraft version: $($mostCommon.Key) (from $($mostCommon.Value) mods)" -ForegroundColor Cyan
        return $mostCommon.Key
    }
    
    # Try to get from process
    if ($process) {
        try {
            $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            if ($cmdLine -match '-Dfabric.gameVersion=(\d+(\.\d+)+)') {
                Write-Host "`nDetected Minecraft version from process: $($matches[1])" -ForegroundColor Cyan
                return $matches[1]
            }
            elseif ($cmdLine -match '--version\s+(\d+(\.\d+)+)') {
                Write-Host "`nDetected Minecraft version from process: $($matches[1])" -ForegroundColor Cyan
                return $matches[1]
            }
        } catch {}
    }
    
    Write-Host "`nCould not auto-detect Minecraft version from mods." -ForegroundColor Yellow
    $mcVersion = Read-Host "Enter your Minecraft version (e.g., 1.21, 1.20.1) or press Enter to skip filtering"
    return if ($mcVersion -eq '') { $null } else { $mcVersion }
}

# Detect Minecraft version
if ($minecraftVersion = Get-Minecraft-Version-From-Mods -modsFolder $mods) {
    Write-Host "Using Minecraft version: $minecraftVersion for filtering`n" -ForegroundColor Green
}

# Helper functions
function Get-SHA1($filePath) { return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash }

function Get-ZoneIdentifier($filePath) {
    try {
        if ($ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue | Where-Object { $_ -match "HostUrl=(.+)" }) {
            $url = $matches[1]
            return @{
                Source = switch -regex ($url) {
                    "modrinth\.com" { "Modrinth"; break }
                    "curseforge\.com" { "CurseForge"; break }
                    "github\.com" { "GitHub"; break }
                    "discord" { "Discord"; break }
                    default { "Other" }
                }
                URL = $url
                IsModrinth = $url -match "modrinth\.com"
            }
        }
    } catch {}
    return @{ Source = "Unknown"; URL = ""; IsModrinth = $false }
}

function Get-Mod-Info-From-Jar($jarPath) {
    $modInfo = @{ ModId = ""; Name = ""; Version = ""; Description = ""; Authors = @(); License = ""; Contact = @{}; Icon = ""; Environment = ""; Entrypoints = @{}; Mixins = @(); AccessWidener = ""; Depends = @{}; Suggests = @{}; Breaks = @{}; Conflicts = @{}; ModLoader = "" }
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        
        # Check for fabric.mod.json
        if ($entry = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1) {
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $fabricData = $reader.ReadToEnd() | ConvertFrom-Json
            $reader.Close()
            
            $modInfo.ModId = $fabricData.id; $modInfo.Name = $fabricData.name; $modInfo.Version = $fabricData.version
            $modInfo.Description = $fabricData.description; $modInfo.Authors = if ($fabricData.authors -is [array]) { $fabricData.authors } else { @($fabricData.authors) }
            $modInfo.License = $fabricData.license; $modInfo.Contact = $fabricData.contact; $modInfo.Icon = $fabricData.icon
            $modInfo.Environment = $fabricData.environment; $modInfo.Entrypoints = $fabricData.entrypoints
            $modInfo.Mixins = if ($fabricData.mixins -is [array]) { $fabricData.mixins } else { @($fabricData.mixins) }
            $modInfo.AccessWidener = $fabricData.accessWidener; $modInfo.Depends = $fabricData.depends; $modInfo.Suggests = $fabricData.suggests
            $modInfo.Breaks = $fabricData.breaks; $modInfo.Conflicts = $fabricData.conflicts; $modInfo.ModLoader = "Fabric"
            
            $zip.Dispose()
            return $modInfo
        }
        
        # Check for mods.toml (Forge/NeoForge)
        if ($entry = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' } | Select-Object -First 1) {
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $tomlContent = $reader.ReadToEnd()
            $reader.Close()
            
            if ($tomlContent -match 'modId\s*=\s*"([^"]+)"') { $modInfo.ModId = $matches[1] }
            if ($tomlContent -match 'displayName\s*=\s*"([^"]+)"') { $modInfo.Name = $matches[1] }
            if ($tomlContent -match 'version\s*=\s*"([^"]+)"') { $modInfo.Version = $matches[1] }
            if ($tomlContent -match 'description\s*=\s*"([^"]+)"') { $modInfo.Description = $matches[1] }
            if ($tomlContent -match 'authors\s*=\s*"([^"]+)"') { $modInfo.Authors = @($matches[1]) }
            
            $modInfo.ModLoader = "Forge/NeoForge"
            $zip.Dispose()
            return $modInfo
        }
        
        # Check for mixin configs
        if ($entry = $zip.Entries | Where-Object { $_.Name -match '\.mixins\.json$' } | Select-Object -First 1) {
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $mixinData = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue
            $reader.Close()
            if ($mixinData.package -and -not $modInfo.ModId) {
                $packageParts = $mixinData.package -split '\.'
                if ($packageParts.Count -ge 2) { $modInfo.ModId = $packageParts[-2] }
            }
        }
        
        # Check for manifest
        if ($entry = $zip.Entries | Where-Object { $_.Name -eq 'MANIFEST.MF' } | Select-Object -First 1) {
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $manifestContent = $reader.ReadToEnd()
            $reader.Close()
            
            $lines = $manifestContent -split "`n"
            foreach ($line in $lines) {
                if ($line -match 'Implementation-Title:\s*(.+)' -and -not $modInfo.Name) { $modInfo.Name = $matches[1].Trim() }
                if ($line -match 'Implementation-Version:\s*(.+)' -and -not $modInfo.Version) { $modInfo.Version = $matches[1].Trim() }
                if ($line -match 'Specification-Title:\s*(.+)' -and -not $modInfo.Name) { $modInfo.Name = $matches[1].Trim() }
            }
        }
        
        $zip.Dispose()
    } catch {}
    return $modInfo
}

function Fetch-Modrinth-By-Hash($hash) {
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing
        if ($response.project_id) {
            $projectData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($response.project_id)" -Method Get -UseBasicParsing
            $fileInfo = $response.files[0]
            
            return @{ 
                Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $fileInfo.size
                VersionNumber = $response.version_number; FileName = $fileInfo.filename
                ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($response.id)"
                FoundByHash = $true; ExactMatch = $true; IsLatestVersion = $false; MatchType = "Exact Hash"
                LoaderType = if ($response.loaders -contains "fabric") { "Fabric" } elseif ($response.loaders -contains "forge") { "Forge" } else { "Unknown" }
            }
        }
    } catch {}
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown" }
}

function Find-Closest-Version($localVersion, $availableVersions, $preferredLoader = "Fabric", $minecraftVersion) {
    if (-not $localVersion -or -not $availableVersions) { return $null }
    
    $filteredVersions = @()
    foreach ($version in $availableVersions) {
        $matchesLoader = ($version.loaders -contains $preferredLoader.ToLower())
        $matchesMinecraft = if ($minecraftVersion -and $version.game_versions) { ($version.game_versions -contains $minecraftVersion) } else { $true }
        if ($matchesLoader -and $matchesMinecraft) { $filteredVersions += $version }
    }
    
    if ($filteredVersions.Count -eq 0 -and $minecraftVersion) {
        $filteredVersions = $availableVersions | Where-Object { $_.game_versions -contains $minecraftVersion }
    }
    if ($filteredVersions.Count -eq 0) {
        $filteredVersions = $availableVersions | Where-Object { $_.loaders -contains $preferredLoader.ToLower() }
    }
    if ($filteredVersions.Count -eq 0) { $filteredVersions = $availableVersions }
    
    foreach ($version in $filteredVersions) {
        if ($version.version_number -eq $localVersion) { return $version }
    }
    
    try {
        if ($localVersion -match '(\d+)\.(\d+)\.(\d+)') {
            $major, $minor, $patch = [int]$matches[1], [int]$matches[2], [int]$matches[3]
            $closest = $null; $closestDistance = [double]::MaxValue
            
            foreach ($version in $filteredVersions) {
                if ($version.version_number -match '(\d+)\.(\d+)\.(\d+)') {
                    $distance = [math]::Sqrt([math]::Pow($major - [int]$matches[1], 2) * 100 + [math]::Pow($minor - [int]$matches[2], 2) * 10 + [math]::Pow($patch - [int]$matches[3], 2))
                    if ($distance -lt $closestDistance) { $closestDistance = $distance; $closest = $version }
                }
            }
            if ($closest -and $closestDistance -lt 10) { return $closest }
        }
        
        if ($localVersion -match '(\d+)\.(\d+)') {
            $major, $minor = [int]$matches[1], [int]$matches[2]
            $closest = $null; $closestDistance = [double]::MaxValue
            
            foreach ($version in $filteredVersions) {
                if ($version.version_number -match '(\d+)\.(\d+)') {
                    $distance = [math]::Sqrt([math]::Pow($major - [int]$matches[1], 2) * 10 + [math]::Pow($minor - [int]$matches[2], 2))
                    if ($distance -lt $closestDistance) { $closestDistance = $distance; $closest = $version }
                }
            }
            if ($closest -and $closestDistance -lt 5) { return $closest }
        }
    } catch {}
    
    foreach ($version in $filteredVersions) {
        if ($version.version_number -contains $localVersion -or $version.version_number -match [regex]::Escape($localVersion)) {
            return $version
        }
    }
    
    return $null
}

function Fetch-Modrinth-By-ModId($modId, $version, $preferredLoader = "Fabric") {
    try {
        $projectData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$modId" -Method Get -UseBasicParsing -ErrorAction Stop
        if ($projectData.id) {
            $versionsData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$modId/version" -Method Get -UseBasicParsing
            
            if ($matchedVersion = Find-Closest-Version -localVersion $version -availableVersions $versionsData -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion) {
                $file = $matchedVersion.files[0]
                $isExact = ($matchedVersion.version_number -eq $version)
                $loader = if ($matchedVersion.loaders -contains "fabric") { "Fabric" } elseif ($matchedVersion.loaders -contains "forge") { "Forge" } else { $matchedVersion.loaders[0] }
                
                return @{
                    Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $file.size
                    VersionNumber = $matchedVersion.version_number; FileName = $file.filename
                    ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($matchedVersion.id)"
                    FoundByHash = $false; ExactMatch = $isExact; IsLatestVersion = ($versionsData[0].id -eq $matchedVersion.id)
                    MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }; LoaderType = $loader
                }
            }
            
            foreach ($ver in $versionsData) {
                $matchesLoader = ($ver.loaders -contains $preferredLoader.ToLower())
                $matchesMinecraft = if ($minecraftVersion -and $ver.game_versions) { ($ver.game_versions -contains $minecraftVersion) } else { $true }
                
                if ($matchesLoader -and $matchesMinecraft) {
                    $file = $ver.files[0]
                    $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                    
                    return @{
                        Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $file.size
                        VersionNumber = $ver.version_number; FileName = $file.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($ver.id)"
                        FoundByHash = $false; ExactMatch = $false; IsLatestVersion = ($versionsData[0].id -eq $ver.id)
                        MatchType = "Latest Version ($loader)"; LoaderType = $loader
                    }
                }
            }
            
            if ($versionsData.Count -gt 0) {
                $latestVersion = $versionsData[0]; $latestFile = $latestVersion.files[0]
                $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                
                return @{
                    Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $latestFile.size
                    VersionNumber = $latestVersion.version_number; FileName = $latestFile.filename
                    ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($latestVersion.id)"
                    FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $true
                    MatchType = "Latest Version ($loader)"; LoaderType = $loader
                }
            }
        }
    } catch {
        try {
            $searchData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/search?query=`"$modId`"&facets=`"[[`"project_type:mod`"]]`"&limit=5" -Method Get -UseBasicParsing
            
            if ($searchData.hits -and $searchData.hits.Count -gt 0) {
                $bestMatch = $null; $bestScore = 0
                foreach ($hit in $searchData.hits) {
                    $score = 0
                    if ($hit.slug -eq $modId) { $score += 100 }
                    if ($hit.project_id -eq $modId) { $score += 100 }
                    if ($hit.title -eq $modId) { $score += 80 }
                    if ($hit.title -match $modId) { $score += 50 }
                    if ($hit.slug -match $modId) { $score += 40 }
                    
                    if ($score -gt $bestScore) { $bestScore = $score; $bestMatch = $hit }
                }
                
                if ($bestMatch) {
                    $versionsData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($bestMatch.project_id)/version" -Method Get -UseBasicParsing
                    
                    if ($matchedVersion = Find-Closest-Version -localVersion $version -availableVersions $versionsData -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion) {
                        $file = $matchedVersion.files[0]
                        $isExact = ($matchedVersion.version_number -eq $version)
                        $loader = if ($matchedVersion.loaders -contains "fabric") { "Fabric" } elseif ($matchedVersion.loaders -contains "forge") { "Forge" } else { $matchedVersion.loaders[0] }
                        
                        return @{
                            Name = $bestMatch.title; Slug = $bestMatch.slug; ExpectedSize = $file.size
                            VersionNumber = $matchedVersion.version_number; FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($bestMatch.slug)/version/$($matchedVersion.id)"
                            FoundByHash = $false; ExactMatch = $isExact; IsLatestVersion = ($versionsData[0].id -eq $matchedVersion.id)
                            MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }; LoaderType = $loader
                        }
                    }
                    
                    if ($versionsData.Count -gt 0) {
                        $latestVersion = $versionsData[0]; $latestFile = $latestVersion.files[0]
                        $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                        
                        return @{
                            Name = $bestMatch.title; Slug = $bestMatch.slug; ExpectedSize = $latestFile.size
                            VersionNumber = $latestVersion.version_number; FileName = $latestFile.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($bestMatch.slug)/version/$($latestVersion.id)"
                            FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $true
                            MatchType = "Latest Version ($loader)"; LoaderType = $loader
                        }
                    }
                }
            }
        } catch {}
    }
    
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; MatchType = "No Match"; LoaderType = "Unknown" }
}

function Fetch-Modrinth-By-Filename($filename, $preferredLoader = "Fabric") {
    $cleanFilename = $filename -replace '\.temp\.jar$|\.tmp\.jar$|_1\.jar$', '.jar'
    $modNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($cleanFilename)
    
    if ($filename -match '(?i)fabric') { $preferredLoader = "Fabric" }
    elseif ($filename -match '(?i)forge') { $preferredLoader = "Forge" }
    
    $localVersion = ""; $baseName = $modNameWithoutExt
    if ($modNameWithoutExt -match '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$') {
        $localVersion = $matches[1]; $baseName = $modNameWithoutExt -replace '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$', ''
    }
    
    $baseName = $baseName -replace '(?i)-fabric$|-forge$', ''
    
    foreach ($slug in @($baseName.ToLower(), $modNameWithoutExt.ToLower())) {
        try {
            $projectData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$slug" -Method Get -UseBasicParsing
            $versionsData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$slug/version" -Method Get -UseBasicParsing
            
            foreach ($version in $versionsData) {
                foreach ($file in $version.files) {
                    if ($file.filename -eq $cleanFilename -or $file.filename -eq $filename) {
                        $loader = if ($version.loaders -contains "fabric") { "Fabric" } elseif ($version.loaders -contains "forge") { "Forge" } else { $version.loaders[0] }
                        
                        return @{
                            Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $file.size
                            VersionNumber = $version.version_number; FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($version.id)"
                            FoundByHash = $false; ExactMatch = $true; IsLatestVersion = ($versionsData[0].id -eq $version.id)
                            MatchType = "Exact Filename"; LoaderType = $loader
                        }
                    }
                }
            }
            
            if ($matchedVersion = Find-Closest-Version -localVersion $localVersion -availableVersions $versionsData -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion) {
                $file = $matchedVersion.files[0]; $isExact = ($matchedVersion.version_number -eq $localVersion)
                $loader = if ($matchedVersion.loaders -contains "fabric") { "Fabric" } elseif ($matchedVersion.loaders -contains "forge") { "Forge" } else { $matchedVersion.loaders[0] }
                
                return @{
                    Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $file.size
                    VersionNumber = $matchedVersion.version_number; FileName = $file.filename
                    ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($matchedVersion.id)"
                    FoundByHash = $false; ExactMatch = $isExact; IsLatestVersion = ($versionsData[0].id -eq $matchedVersion.id)
                    MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }; LoaderType = $loader
                }
            }
            
            foreach ($version in $versionsData) {
                $matchesLoader = ($version.loaders -contains $preferredLoader.ToLower())
                $matchesMinecraft = if ($minecraftVersion -and $version.game_versions) { ($version.game_versions -contains $minecraftVersion) } else { $true }
                
                if ($matchesLoader -and $matchesMinecraft) {
                    $file = $version.files[0]
                    $loader = if ($version.loaders -contains "fabric") { "Fabric" } elseif ($version.loaders -contains "forge") { "Forge" } else { $version.loaders[0] }
                    
                    return @{
                        Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $file.size
                        VersionNumber = $version.version_number; FileName = $file.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($version.id)"
                        FoundByHash = $false; ExactMatch = $false; IsLatestVersion = ($versionsData[0].id -eq $version.id)
                        MatchType = "Latest Version ($loader)"; LoaderType = $loader
                    }
                }
            }
            
            if ($versionsData.Count -gt 0) {
                $latestVersion = $versionsData[0]; $latestFile = $latestVersion.files[0]
                $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                
                return @{
                    Name = $projectData.title; Slug = $projectData.slug; ExpectedSize = $latestFile.size
                    VersionNumber = $latestVersion.version_number; FileName = $latestFile.filename
                    ModrinthUrl = "https://modrinth.com/mod/$($projectData.slug)/version/$($latestVersion.id)"
                    FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $true
                    MatchType = "Latest Version ($loader)"; LoaderType = $loader
                }
            }
        } catch { continue }
    }
    
    try {
        $searchData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/search?query=`"$baseName`"&facets=`"[[`"project_type:mod`"]]`"&limit=5" -Method Get -UseBasicParsing
        
        if ($searchData.hits -and $searchData.hits.Count -gt 0) {
            $hit = $searchData.hits[0]
            $versionsData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($hit.project_id)/version" -Method Get -UseBasicParsing
            
            foreach ($version in $versionsData) {
                foreach ($file in $version.files) {
                    if ($file.filename -eq $cleanFilename -or $file.filename -eq $filename) {
                        $loader = if ($version.loaders -contains "fabric") { "Fabric" } elseif ($version.loaders -contains "forge") { "Forge" } else { $version.loaders[0] }
                        
                        return @{
                            Name = $hit.title; Slug = $hit.slug; ExpectedSize = $file.size
                            VersionNumber = $version.version_number; FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($version.id)"
                            FoundByHash = $false; ExactMatch = $true; IsLatestVersion = ($versionsData[0].id -eq $version.id)
                            MatchType = "Exact Filename"; LoaderType = $loader
                        }
                    }
                }
            }
            
            if ($versionsData.Count -gt 0) {
                $latestVersion = $versionsData[0]; $latestFile = $latestVersion.files[0]
                $loader = if ($latestVersion.loaders -contains "fabric") { "Fabric" } elseif ($latestVersion.loaders -contains "forge") { "Forge" } else { $latestVersion.loaders[0] }
                
                return @{
                    Name = $hit.title; Slug = $hit.slug; ExpectedSize = $latestFile.size
                    VersionNumber = $latestVersion.version_number; FileName = $latestFile.filename
                    ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($latestVersion.id)"
                    FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $true
                    MatchType = "Latest Version ($loader)"; LoaderType = $loader
                }
            }
        }
    } catch {}
    
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; MatchType = "No Match"; LoaderType = "Unknown" }
}

function Fetch-Megabase($hash) {
    try {
        $response = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -Method Get -UseBasicParsing
        if (-not $response.error) { return $response.data }
    } catch {}
    return $null
}

# Cheat strings
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
    "hitboxes", "lvstrng"
)

function Check-Strings($filePath) {
    $stringsFound = [System.Collections.Generic.HashSet[string]]::new()
    
    try {
        $possiblePaths = @(
            "C:\Program Files\Git\usr\bin\strings.exe",
            "C:\Program Files\Git\mingw64\bin\strings.exe",
            "$env:ProgramFiles\Git\usr\bin\strings.exe",
            "C:\msys64\usr\bin\strings.exe",
            "C:\cygwin64\bin\strings.exe"
        )
        
        if ($stringsPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1) {
            $tempFile = Join-Path $env:TEMP "temp_strings_$(Get-Random).txt"
            & $stringsPath $filePath 2>$null | Out-File $tempFile
            if (Test-Path $tempFile) {
                $extractedContent = Get-Content $tempFile -Raw
                Remove-Item $tempFile -Force
                
                foreach ($string in $cheatStrings) {
                    if ($extractedContent -match $string) { $stringsFound.Add($string) | Out-Null }
                }
            }
        } else {
            $content = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($filePath)).ToLower()
            foreach ($string in $cheatStrings) {
                if ($string -eq "velocity") {
                    if ($content -match "velocity(hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
                        $stringsFound.Add($string) | Out-Null
                    }
                } elseif ($content -match $string) {
                    $stringsFound.Add($string) | Out-Null
                }
            }
        }
    } catch {}
    return $stringsFound
}

# Collections for results
$verifiedMods = @(); $unknownMods = @(); $cheatMods = @(); $sizeMismatchMods = @(); $tamperedMods = @(); $allModsInfo = @()
$obfuscatedMods = @()  # Collection for obfuscated mods

# Process all mods
$jarFiles = Get-ChildItem -Path $mods -Filter *.jar
$spinner = @("|", "/", "-", "\"); $totalMods = $jarFiles.Count

# First pass: Check for obfuscation
Write-Host "{ Obfuscation Detection }" -ForegroundColor Cyan
$obfCounter = 0
foreach ($file in $jarFiles) {
    $obfCounter++
    Write-Host "`r[$($spinner[$obfCounter % $spinner.Length])] Checking for obfuscation: $obfCounter / $totalMods" -ForegroundColor Cyan -NoNewline
    $obfResult = Test-ObfuscatedFile -filePath $file.FullName -fileType "jar"
    if ($obfResult.IsObfuscated) {
        $obfuscatedMods += [PSCustomObject]@{
            FileName = $file.Name
            FilePath = $file.FullName
            ObfuscationScore = $obfResult.Score
            ObfuscationLevel = $obfResult.Level
            LevelColor = $obfResult.LevelColor
            Reasons = $obfResult.Reasons
            FileSizeKB = [math]::Round($file.Length/1KB, 2)
        }
    }
}
Write-Host "`r$(' ' * 80)`r" -NoNewline
if ($obfuscatedMods.Count -gt 0) {
    Write-Host "Found $($obfuscatedMods.Count) potentially obfuscated files`n" -ForegroundColor Yellow
}

# Continue with original scanning
for ($i = 0; $i -lt $jarFiles.Count; $i++) {
    $file = $jarFiles[$i]
    Write-Host "`r[$($spinner[$i % $spinner.Length])] Scanning mods: $($i+1) / $totalMods" -ForegroundColor Magenta -NoNewline
    
    # Check if file is obfuscated
    $isObfuscated = $false
    $obfuscationInfo = $null
    foreach ($obfMod in $obfuscatedMods) {
        if ($obfMod.FileName -eq $file.Name) {
            $isObfuscated = $true
            $obfuscationInfo = $obfMod
            break
        }
    }
    
    # Get file info
    $hash = Get-SHA1 -filePath $file.FullName
    $actualSize = $file.Length; $actualSizeKB = [math]::Round($actualSize/1KB, 2)
    $zoneInfo = Get-ZoneIdentifier $file.FullName
    $jarModInfo = Get-Mod-Info-From-Jar -jarPath $file.FullName
    
    # Determine preferred loader
    $preferredLoader = "Fabric"
    if ($file.Name -match '(?i)fabric') { $preferredLoader = "Fabric" }
    elseif ($file.Name -match '(?i)forge') { $preferredLoader = "Forge" }
    elseif ($jarModInfo.ModLoader -eq "Fabric") { $preferredLoader = "Fabric" }
    elseif ($jarModInfo.ModLoader -eq "Forge/NeoForge") { $preferredLoader = "Forge" }
    
    # Try to find mod info
    $modData = Fetch-Modrinth-By-Hash -hash $hash
    if (-not $modData.Name -and $jarModInfo.ModId) {
        $modData = Fetch-Modrinth-By-ModId -modId $jarModInfo.ModId -version $jarModInfo.Version -preferredLoader $preferredLoader
    }
    if (-not $modData.Name) {
        $modData = Fetch-Modrinth-By-Filename -filename $file.Name -preferredLoader $preferredLoader
    }
    
    if ($modData.Name) {
        $sizeDiff = $actualSize - $modData.ExpectedSize
        $expectedSizeKB = if ($modData.ExpectedSize -gt 0) { [math]::Round($modData.ExpectedSize/1KB, 2) } else { 0 }
        
        $modEntry = [PSCustomObject]@{ 
            ModName = $modData.Name; FileName = $file.Name; Version = $modData.VersionNumber
            ExpectedSize = $modData.ExpectedSize; ExpectedSizeKB = $expectedSizeKB; ActualSize = $actualSize; ActualSizeKB = $actualSizeKB
            SizeDiff = $sizeDiff; SizeDiffKB = [math]::Round($sizeDiff/1KB, 2); DownloadSource = $zoneInfo.Source; SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth; ModrinthUrl = $modData.ModrinthUrl; IsVerified = $true; MatchType = $modData.MatchType
            ExactMatch = $modData.ExactMatch; IsLatestVersion = $modData.IsLatestVersion; LoaderType = $modData.LoaderType
            PreferredLoader = $preferredLoader; FilePath = $file.FullName; JarModId = $jarModInfo.ModId; JarName = $jarModInfo.Name
            JarVersion = $jarModInfo.Version; JarModLoader = $jarModInfo.ModLoader
            IsObfuscated = $isObfuscated; ObfuscationScore = if ($isObfuscated) { $obfuscationInfo.ObfuscationScore } else { 0 }
            ObfuscationLevel = if ($isObfuscated) { $obfuscationInfo.ObfuscationLevel } else { "Clean" }
        }
        
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
        
        if ($modData.ExpectedSize -gt 0 -and $actualSize -ne $modData.ExpectedSize) {
            $sizeMismatchMods += $modEntry
            if ([math]::Abs($sizeDiff) -gt 1024) { $tamperedMods += $modEntry }
        }
    } elseif ($megabaseData = Fetch-Megabase -hash $hash) {
        $modEntry = [PSCustomObject]@{ 
            ModName = $megabaseData.name; FileName = $file.Name; Version = "Unknown"; ExpectedSize = 0; ExpectedSizeKB = 0
            ActualSize = $actualSize; ActualSizeKB = $actualSizeKB; SizeDiff = 0; SizeDiffKB = 0; DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL; IsModrinthDownload = $zoneInfo.IsModrinth; IsVerified = $true; MatchType = "Megabase"
            ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown"; PreferredLoader = $preferredLoader
            FilePath = $file.FullName; JarModId = $jarModInfo.ModId; JarName = $jarModInfo.Name; JarVersion = $jarModInfo.Version
            JarModLoader = $jarModInfo.ModLoader
            IsObfuscated = $isObfuscated; ObfuscationScore = if ($isObfuscated) { $obfuscationInfo.ObfuscationScore } else { 0 }
            ObfuscationLevel = if ($isObfuscated) { $obfuscationInfo.ObfuscationLevel } else { "Clean" }
        }
        
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
    } else {
        $unknownModEntry = [PSCustomObject]@{ 
            FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneInfo.URL; DownloadSource = $zoneInfo.Source
            IsModrinthDownload = $zoneInfo.IsModrinth; FileSize = $actualSize; FileSizeKB = $actualSizeKB; Hash = $hash
            ExpectedSize = 0; ExpectedSizeKB = 0; SizeDiff = 0; SizeDiffKB = 0; ModrinthUrl = ""; ModName = ""; MatchType = ""
            ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown"; PreferredLoader = $preferredLoader
            JarModId = $jarModInfo.ModId; JarName = $jarModInfo.Name; JarVersion = $jarModInfo.Version; JarModLoader = $jarModInfo.ModLoader
            IsObfuscated = $isObfuscated; ObfuscationScore = if ($isObfuscated) { $obfuscationInfo.ObfuscationScore } else { 0 }
            ObfuscationLevel = if ($isObfuscated) { $obfuscationInfo.ObfuscationLevel } else { "Clean" }
        }
        
        $unknownMods += $unknownModEntry; $allModsInfo += $unknownModEntry
    }
}

# Try to identify unknown mods
for ($i = 0; $i -lt $unknownMods.Count; $i++) {
    $mod = $unknownMods[$i]
    $modrinthInfo = if ($mod.JarModId) { Fetch-Modrinth-By-ModId -modId $mod.JarModId -version $mod.JarVersion -preferredLoader $mod.PreferredLoader }
    if (-not $modrinthInfo -or -not $modrinthInfo.Name) { $modrinthInfo = Fetch-Modrinth-By-Filename -filename $mod.FileName -preferredLoader $mod.PreferredLoader }
    
    if ($modrinthInfo -and $modrinthInfo.Name) {
        $mod.ModName = $modrinthInfo.Name; $mod.ExpectedSize = $modrinthInfo.ExpectedSize
        $mod.ExpectedSizeKB = if ($modrinthInfo.ExpectedSize -gt 0) { [math]::Round($modrinthInfo.ExpectedSize/1KB, 2) } else { 0 }
        $mod.SizeDiff = $mod.FileSize - $modrinthInfo.ExpectedSize
        $mod.SizeDiffKB = [math]::Round(($mod.FileSize - $modrinthInfo.ExpectedSize)/1KB, 2)
        $mod.ModrinthUrl = $modrinthInfo.ModrinthUrl; $mod.ModName = $modrinthInfo.Name; $mod.MatchType = $modrinthInfo.MatchType
        $mod.ExactMatch = $modrinthInfo.ExactMatch; $mod.IsLatestVersion = $modrinthInfo.IsLatestVersion; $mod.LoaderType = $modrinthInfo.LoaderType
        
        for ($j = 0; $j -lt $allModsInfo.Count; $j++) {
            if ($allModsInfo[$j].FileName -eq $mod.FileName) {
                $allModsInfo[$j].ModName = $modrinthInfo.Name; $allModsInfo[$j].ExpectedSize = $modrinthInfo.ExpectedSize
                $allModsInfo[$j].ExpectedSizeKB = $mod.ExpectedSizeKB; $allModsInfo[$j].SizeDiff = $mod.SizeDiff
                $allModsInfo[$j].SizeDiffKB = $mod.SizeDiffKB; $allModsInfo[$j].ModrinthUrl = $modrinthInfo.ModrinthUrl
                $allModsInfo[$j].ModName = $modrinthInfo.Name; $allModsInfo[$j].MatchType = $modrinthInfo.MatchType
                $allModsInfo[$j].ExactMatch = $modrinthInfo.ExactMatch; $allModsInfo[$j].IsLatestVersion = $modrinthInfo.IsLatestVersion
                $allModsInfo[$j].LoaderType = $modrinthInfo.LoaderType
                break
            }
        }
    }
}

# Scan for cheat strings
$counter = 0
$tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"

try {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    foreach ($mod in $allModsInfo) {
        $counter++
        Write-Host "`r[$($spinner[$counter % $spinner.Length])] Scanning mods for cheat strings: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
        
        if ($modStrings = Check-Strings $mod.FilePath) {
            $cheatMods += [PSCustomObject]@{ 
                FileName = $mod.FileName; StringsFound = $modStrings; FileSizeKB = $mod.FileSizeKB
                DownloadSource = $mod.DownloadSource; SourceURL = $mod.ZoneId; ExpectedSizeKB = $mod.ExpectedSizeKB
                SizeDiffKB = $mod.SizeDiffKB; IsVerifiedMod = ($mod.IsVerified -eq $true); ModName = $mod.ModName
                ModrinthUrl = $mod.ModrinthUrl; FilePath = $mod.FilePath
                HasSizeMismatch = ($mod.SizeDiffKB -ne 0 -and [math]::Abs($mod.SizeDiffKB) -gt 1)
                JarModId = $mod.JarModId; JarName = $mod.JarName; JarVersion = $mod.JarVersion
                MatchType = $mod.MatchType; ExactMatch = $mod.ExactMatch; IsLatestVersion = $mod.IsLatestVersion
                LoaderType = $mod.LoaderType
                IsObfuscated = $mod.IsObfuscated; ObfuscationScore = $mod.ObfuscationScore; ObfuscationLevel = $mod.ObfuscationLevel
            }
        }
    }
} catch {
    Write-Host "`nError occurred while scanning: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# Display results
Write-Host "`n{ Results Summary }`n" -ForegroundColor Cyan

# Display Obfuscated Mods Section
if ($obfuscatedMods.Count -gt 0) {
    Write-Host "{ Obfuscated Mods Detected }" -ForegroundColor Yellow
    Write-Host "Total: $($obfuscatedMods.Count) ⚠ WARNING`n"
    
    foreach ($mod in $obfuscatedMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Obfuscation Level: " -NoNewline
        Write-Host "$($mod.ObfuscationLevel)" -ForegroundColor $mod.LevelColor
        Write-Host "  Obfuscation Score: $($mod.ObfuscationScore)/100" -ForegroundColor Gray
        Write-Host "  File Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        if ($mod.Reasons.Count -gt 0) {
            Write-Host "  Reasons:" -ForegroundColor DarkGray
            foreach ($reason in $mod.Reasons) {
                Write-Host "    - $reason" -ForegroundColor DarkGray
            }
        }
        
        Write-Host ""
    }
}

# Verified Mods
if ($verifiedMods.Count -gt 0) {
    Write-Host "{ Verified Mods }" -ForegroundColor Cyan
    Write-Host "Total: $($verifiedMods.Count)`n"
    
    foreach ($mod in $verifiedMods) {
        $isCheatMod = $cheatMods.FileName -contains $mod.FileName
        $isTampered = $tamperedMods.FileName -contains $mod.FileName
        
        # Only show yellow for "Moderately" or "Highly" obfuscated
        $showObfuscatedWarning = $mod.IsObfuscated -and $mod.ObfuscationLevel -match "Moderately|Highly"
        
        if ($isTampered) { Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline }
        elseif ($isCheatMod) { Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline }
        elseif ($showObfuscatedWarning) { Write-Host "> $($mod.ModName)" -ForegroundColor Yellow -NoNewline }
        else { Write-Host "> $($mod.ModName)" -ForegroundColor Green -NoNewline }
        
        Write-Host " - $($mod.FileName)" -ForegroundColor $(if ($isTampered -or $isCheatMod) { 'Magenta' } elseif ($showObfuscatedWarning) { 'Yellow' } else { 'Gray' }) -NoNewline
        
        if ($mod.Version -and $mod.Version -ne "Unknown") {
            Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray -NoNewline
        }
        
        $matchIndicator = switch ($mod.MatchType) {
            { $_ -match "Exact" } { @{ Symbol = "✓"; Color = "Green" } }
            { $_ -match "Closest" } { @{ Symbol = "≈"; Color = "Yellow" } }
            { $_ -match "Latest" } { @{ Symbol = "↑"; Color = "Cyan" } }
            default { $null }
        }
        
        if ($matchIndicator) { Write-Host " $($matchIndicator.Symbol)" -ForegroundColor $matchIndicator.Color -NoNewline }
        if ($mod.LoaderType -ne "Unknown") { Write-Host " ($($mod.LoaderType))" -ForegroundColor $(if ($mod.LoaderType -eq "Fabric") { 'Magenta' } else { 'Yellow' }) -NoNewline }
        # Only show [Obfuscated] for significant levels
        if ($showObfuscatedWarning) { Write-Host " [Obfuscated]" -ForegroundColor Yellow -NoNewline }
        if ($mod.DownloadSource -ne "Unknown") { Write-Host " [$($mod.DownloadSource)]" -ForegroundColor $(if ($mod.IsModrinthDownload) { 'Green' } else { 'DarkYellow' }) }
        else { Write-Host "" }
        
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                Write-Host "  Size: $($mod.ActualSizeKB) KB ✓" -ForegroundColor Green
            } else {
                $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
                $color = if ($isTampered) { 'Magenta' } else { 'Yellow' }
                Write-Host "  Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB, Diff: $sign$($mod.SizeDiffKB) KB)" -ForegroundColor $color
            }
        }
    }
    Write-Host ""
}

# Unknown Mods
if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)`n"
    
    foreach ($mod in $unknownMods) {
        # Only show red for "Highly Obfuscated"
        $isHighlyObfuscated = $mod.IsObfuscated -and $mod.ObfuscationLevel -eq "Highly Obfuscated"
        $isModeratelyObfuscated = $mod.IsObfuscated -and $mod.ObfuscationLevel -eq "Moderately Obfuscated"
        
        if ($isHighlyObfuscated) {
            Write-Host "> $($mod.FileName)" -ForegroundColor Red -NoNewline
            Write-Host " [Highly Obfuscated]" -ForegroundColor Red
        } elseif ($isModeratelyObfuscated) {
            Write-Host "> $($mod.FileName)" -ForegroundColor Yellow -NoNewline
            Write-Host " [Obfuscated]" -ForegroundColor Yellow
        } else {
            Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        }
        
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        # Show obfuscation info only for significant levels
        if ($mod.IsObfuscated -and $mod.ObfuscationLevel -ne "Clean") {
            Write-Host "  Obfuscation Level: " -NoNewline
            Write-Host "$($mod.ObfuscationLevel)" -ForegroundColor $mod.LevelColor
            Write-Host "  Obfuscation Score: $($mod.ObfuscationScore)/100" -ForegroundColor Gray
        }
        
        if ($mod.ModName) {
            Write-Host "  Identified as: $($mod.ModName)" -ForegroundColor Cyan
            
            if ($mod.LoaderType -ne "Unknown") {
                $loaderColor = if ($mod.LoaderType -eq "Fabric") { 'Magenta' } else { 'Yellow' }
                Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $loaderColor
            }
            
            if ($mod.MatchType -eq "Closest Version") {
                Write-Host "  Using closest version: $($mod.MatchType)" -ForegroundColor Yellow
            } elseif ($mod.MatchType -match "Latest Version") {
                Write-Host "  Using latest version: $($mod.MatchType)" -ForegroundColor Cyan
            }
            
            if ($mod.ExpectedSize -gt 0) {
                if ($mod.FileSize -eq $mod.ExpectedSize) {
                    Write-Host "  Size matches Modrinth: $($mod.FileSizeKB) KB ✓" -ForegroundColor Green
                } else {
                    $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
                    Write-Host "  Size: $($mod.FileSizeKB) KB (Expected from Modrinth: $($mod.ExpectedSizeKB) KB, Diff: $sign$($mod.SizeDiffKB) KB)" -ForegroundColor Yellow
                }
            }
        }
        
        if ($mod.ZoneId) {
            $sourceColor = if ($mod.IsModrinthDownload) { 'Green' } else { 'DarkYellow' }
            Write-Host "  Downloaded from: $($mod.DownloadSource)" -ForegroundColor $sourceColor
        }
        
        Write-Host ""
    }
}

# Tampered Mods
if ($tamperedMods.Count -gt 0) {
    Write-Host "{ Potentially Tampered Mods }" -ForegroundColor Red
    Write-Host "Total: $($tamperedMods.Count) ⚠ WARNING`n"
    
    foreach ($mod in $tamperedMods) {
        $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Magenta
        
        # Only show obfuscation warning for significant levels
        if ($mod.IsObfuscated -and $mod.ObfuscationLevel -match "Moderately|Highly") {
            Write-Host "  ⚠ Also Obfuscated: $($mod.ObfuscationLevel)" -ForegroundColor Yellow
        }
        
        if ($mod.LoaderType -ne "Unknown") {
            $loaderColor = if ($mod.LoaderType -eq "Fabric") { 'Magenta' } else { 'Yellow' }
            Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $loaderColor
        }
        
        if ($mod.MatchType -eq "Closest Version") {
            Write-Host "  Note: Compared to closest available version on Modrinth" -ForegroundColor Yellow
        } elseif ($mod.MatchType -match "Latest Version") {
            Write-Host "  Note: Compared to latest version on Modrinth" -ForegroundColor Cyan
        }
        
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Magenta
        Write-Host "  ⚠ File size differs significantly from Modrinth version!" -ForegroundColor Red
        
        if ($mod.ModrinthUrl) {
            Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray
        }
        
        Write-Host ""
    }
}

# Cheat Mods
if ($cheatMods.Count -gt 0) {
    Write-Host "{ Cheat Mods Detected }" -ForegroundColor Red
    Write-Host "Total: $($cheatMods.Count) ⚠ WARNING`n"
    
    foreach ($mod in $cheatMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        
        # Check if also significantly obfuscated
        $isSignificantlyObfuscated = $mod.IsObfuscated -and $mod.ObfuscationLevel -match "Moderately|Highly"
        
        if ($mod.ModName) {
            Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Gray
            
            if ($mod.LoaderType -ne "Unknown") {
                $loaderColor = if ($mod.LoaderType -eq "Fabric") { 'Magenta' } else { 'Yellow' }
                Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $loaderColor
            }
            
            # Show obfuscation status only for significant levels
            if ($isSignificantlyObfuscated) {
                Write-Host "  ⚠ Also Obfuscated: $($mod.ObfuscationLevel) (Score: $($mod.ObfuscationScore))" -ForegroundColor Yellow
            }
            
            if ($mod.MatchType -eq "Closest Version") {
                Write-Host "  Note: Compared to closest available version on Modrinth" -ForegroundColor Yellow
            } elseif ($mod.MatchType -match "Latest Version") {
                Write-Host "  Note: Compared to latest version on Modrinth" -ForegroundColor Cyan
            }
        }
        
        Write-Host "  Cheat Strings: $($mod.StringsFound)" -ForegroundColor Magenta
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        if ($mod.ExpectedSizeKB -gt 0) {
            $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
            if ($mod.SizeDiffKB -eq 0) {
                Write-Host "  Size matches Modrinth: $($mod.ExpectedSizeKB) KB ✓" -ForegroundColor Green
            } else {
                Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Yellow
                
                if ([math]::Abs($mod.SizeDiffKB) -gt 1) {
                    Write-Host "  ⚠ Size mismatch detected! Could be tampered with cheat code." -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  Note: No Modrinth size data available for comparison" -ForegroundColor DarkGray
        }
        
        if ($mod.DownloadSource -ne "Unknown") {
            $sourceColor = if ($mod.DownloadSource -eq "Modrinth") { 'Green' } else { 'DarkYellow' }
            Write-Host "  Source: $($mod.DownloadSource)" -ForegroundColor $sourceColor
        }
        
        if ($mod.IsVerifiedMod) {
            Write-Host "  ⚠ Legitimate mod contains cheat code!" -ForegroundColor Red
            Write-Host "  ⚠ This appears to be a tampered version of a legitimate mod" -ForegroundColor Red
            # Extra warning only for significantly obfuscated cheat mods
            if ($isSignificantlyObfuscated) {
                Write-Host "  ⚠ EXTREMELY SUSPICIOUS: Tampered + Cheat + Obfuscated!" -ForegroundColor Red -BackgroundColor DarkRed
            }
        }
        
        Write-Host ""
    }
}

# Summary Statistics
Write-Host "{ Summary Statistics }" -ForegroundColor Cyan
Write-Host "Total Mods Analyzed: $totalMods"
Write-Host "Verified Mods: $($verifiedMods.Count)" -ForegroundColor Green
Write-Host "Unknown Mods: $($unknownMods.Count)" -ForegroundColor Yellow
Write-Host "Potentially Tampered: $($tamperedMods.Count)" -ForegroundColor Red
Write-Host "Cheat Mods Detected: $($cheatMods.Count)" -ForegroundColor Red
Write-Host "Significantly Obfuscated Mods: $($obfuscatedMods.Count)" -ForegroundColor Yellow
Write-Host

Write-Host "`nCredits to Habibi Mod Analyzer" -ForegroundColor DarkGray -BackgroundColor Black
Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
