Clear-Host
Write-Host "Made by YarpLetapStan - Credits to Habibi Mod Analyzer`n" -ForegroundColor Cyan

$boxWidth = 38
Write-Host "+$('-'*$boxWidth)+" -ForegroundColor Blue
Write-Host "|$(' '*$boxWidth)|" -ForegroundColor Blue
Write-Host "|$('YarpLetapStan''s Mod Analyzer V3.0'.PadLeft(($boxWidth+30)/2).PadRight($boxWidth))|" -ForegroundColor Blue
Write-Host "|$(' '*$boxWidth)|" -ForegroundColor Blue
Write-Host "+$('-'*$boxWidth)+`n" -ForegroundColor Blue

$mods = Read-Host "Enter path to the mods folder (press Enter for default)"
if (-not $mods) { 
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host "Using default: $mods`n" -ForegroundColor White 
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    exit 1
}

# Minecraft version detection
function Get-Minecraft-Version {
    param($modsFolder)
    $versions = @{}
    Get-ChildItem $modsFolder -Filter *.jar | ForEach-Object {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($_.FullName)
            $json = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1
            if ($json) {
                $reader = New-Object System.IO.StreamReader($json.Open())
                $data = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue
                $reader.Close()
                if ($data.depends -and $data.depends.minecraft) {
                    $ver = $data.depends.minecraft -replace '^[><=~^]*\s*|\s*$', ''
                    if ($ver -match '^\d+(\.\d+)+(\.\d+)?$') { $versions[$ver]++ }
                }
            }
            $zip.Dispose()
        } catch { }
    }
    if ($versions.Count -gt 0) {
        $common = $versions.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        Write-Host "Detected Minecraft version: $($common.Key) (from $($common.Value) mods)`n" -ForegroundColor Cyan
        return $common.Key
    }
    
    $process = Get-Process javaw, java -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($process) {
        try {
            $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            if ($cmdLine -match '-Dfabric.gameVersion=(\d+(\.\d+)+)') { return $matches[1] }
            if ($cmdLine -match '--version\s+(\d+(\.\d+)+)') { return $matches[1] }
        } catch { }
    }
    
    Write-Host "Could not auto-detect Minecraft version." -ForegroundColor Yellow
    $ver = Read-Host "Enter your Minecraft version or press Enter to skip"
    return if ($ver -eq '') { $null } else { $ver }
}

$minecraftVersion = Get-Minecraft-Version $mods
if ($minecraftVersion) { Write-Host "Using Minecraft version: $minecraftVersion for filtering`n" -ForegroundColor Green }

# Helper functions
function Get-SHA1($filePath) { return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash }
function Get-ZoneIdentifier($filePath) {
    try {
        $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
        if ($ads -match "HostUrl=(.+)") {
            $url = $matches[1]
            $source = if ($url -match "modrinth\.com") { "Modrinth"; $isModrinth = $true }
                      elseif ($url -match "curseforge\.com") { "CurseForge"; $isModrinth = $false }
                      elseif ($url -match "github\.com") { "GitHub"; $isModrinth = $false }
                      elseif ($url -match "discord") { "Discord"; $isModrinth = $false }
                      else { "Other"; $isModrinth = $false }
            return @{ Source = $source; URL = $url; IsModrinth = $isModrinth }
        }
    } catch { }
    return @{ Source = "Unknown"; URL = ""; IsModrinth = $false }
}

function Get-Mod-Info-From-Jar($jarPath) {
    $modInfo = @{ ModId = ""; Name = ""; Version = ""; Description = ""; Authors = @(); ModLoader = "" }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        
        # Fabric mods
        $fabricJson = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1
        if ($fabricJson) {
            $reader = New-Object System.IO.StreamReader($fabricJson.Open())
            $data = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue
            $reader.Close()
            if ($data) {
                $modInfo.ModId = $data.id; $modInfo.Name = $data.name; $modInfo.Version = $data.version
                $modInfo.Description = $data.description; $modInfo.Authors = if ($data.authors -is [array]) { $data.authors } else { @($data.authors) }
                $modInfo.ModLoader = "Fabric"
                $zip.Dispose()
                return $modInfo
            }
        }
        
        # Forge/NeoForge mods
        $modsToml = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' } | Select-Object -First 1
        if ($modsToml) {
            $reader = New-Object System.IO.StreamReader($modsToml.Open())
            $content = $reader.ReadToEnd()
            $reader.Close()
            if ($content -match 'modId\s*=\s*"([^"]+)"') { $modInfo.ModId = $matches[1] }
            if ($content -match 'displayName\s*=\s*"([^"]+)"') { $modInfo.Name = $matches[1] }
            if ($content -match 'version\s*=\s*"([^"]+)"') { $modInfo.Version = $matches[1] }
            $modInfo.ModLoader = "Forge/NeoForge"
        }
        $zip.Dispose()
    } catch { }
    return $modInfo
}

function Find-Closest-Version($localVersion, $availableVersions, $preferredLoader = "Fabric", $minecraftVersion = $null) {
    if (-not $localVersion -or -not $availableVersions -or $availableVersions.Count -eq 0) { return $null }
    
    $filtered = @()
    foreach ($ver in $availableVersions) {
        $loaderMatch = $ver.loaders -contains $preferredLoader.ToLower()
        $mcMatch = if ($minecraftVersion -and $ver.game_versions) { $ver.game_versions -contains $minecraftVersion } else { $true }
        if ($loaderMatch -and $mcMatch) { $filtered += $ver }
    }
    
    if ($filtered.Count -eq 0 -and $minecraftVersion) {
        $filtered = $availableVersions | Where-Object { $_.game_versions -contains $minecraftVersion }
    }
    if ($filtered.Count -eq 0) {
        $filtered = $availableVersions | Where-Object { $_.loaders -contains $preferredLoader.ToLower() }
    }
    if ($filtered.Count -eq 0) { $filtered = $availableVersions }
    
    # Try exact match first
    foreach ($ver in $filtered) {
        if ($ver.version_number -eq $localVersion) { return $ver }
    }
    
    # Try semantic version matching
    if ($localVersion -match '(\d+)\.(\d+)\.(\d+)') {
        $major, $minor, $patch = [int]$matches[1], [int]$matches[2], [int]$matches[3]
        $closest = $null; $closestDist = [double]::MaxValue
        foreach ($ver in $filtered) {
            if ($ver.version_number -match '(\d+)\.(\d+)\.(\d+)') {
                $dist = [math]::Sqrt([math]::Pow($major - [int]$matches[1], 2) * 100 + 
                                     [math]::Pow($minor - [int]$matches[2], 2) * 10 + 
                                     [math]::Pow($patch - [int]$matches[3], 2))
                if ($dist -lt $closestDist) { $closestDist = $dist; $closest = $ver }
            }
        }
        if ($closest -and $closestDist -lt 10) { return $closest }
    }
    return $null
}

function Fetch-Modrinth-By-Hash($hash) {
    try {
        $resp = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -UseBasicParsing
        if ($resp.project_id) {
            $proj = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($resp.project_id)" -UseBasicParsing
            $file = $resp.files[0]
            return @{ 
                Name = $proj.title; Slug = $proj.slug; ExpectedSize = $file.size
                VersionNumber = $resp.version_number; FileName = $file.filename
                ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($resp.id)"
                FoundByHash = $true; ExactMatch = $true; IsLatestVersion = $false
                MatchType = "Exact Hash"
                LoaderType = if ($resp.loaders -contains "fabric") { "Fabric" } elseif ($resp.loaders -contains "forge") { "Forge" } else { "Unknown" }
            }
        }
    } catch { }
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown" }
}

function Fetch-Modrinth-By-ModId($modId, $version, $preferredLoader = "Fabric") {
    try {
        $proj = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$modId" -UseBasicParsing -ErrorAction SilentlyContinue
        if (-not $proj.id) {
            $search = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/search?query=`"$modId`"&facets=`"[[`"project_type:mod`"]]`"&limit=5" -UseBasicParsing
            if ($search.hits -and $search.hits.Count -gt 0) { $proj = $search.hits[0] }
        }
        if ($proj.id -or $proj.project_id) {
            $projId = if ($proj.id) { $proj.id } else { $proj.project_id }
            $versions = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$projId/version" -UseBasicParsing
            if ($versions.Count -gt 0) {
                $matched = Find-Closest-Version -localVersion $version -availableVersions $versions -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion
                if ($matched) {
                    $file = $matched.files[0]
                    $isExact = ($matched.version_number -eq $version)
                    $loader = if ($matched.loaders -contains "fabric") { "Fabric" } elseif ($matched.loaders -contains "forge") { "Forge" } else { $matched.loaders[0] }
                    return @{
                        Name = if ($proj.title) { $proj.title } else { $proj.name }; Slug = $proj.slug; ExpectedSize = $file.size
                        VersionNumber = $matched.version_number; FileName = $file.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($matched.id)"
                        FoundByHash = $false; ExactMatch = $isExact; IsLatestVersion = ($versions[0].id -eq $matched.id)
                        MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }; LoaderType = $loader
                    }
                }
                
                # Return latest version with Minecraft version filter
                foreach ($ver in $versions) {
                    $loaderMatch = $ver.loaders -contains $preferredLoader.ToLower()
                    $mcMatch = if ($minecraftVersion -and $ver.game_versions) { $ver.game_versions -contains $minecraftVersion } else { $true }
                    if ($loaderMatch -and $mcMatch) {
                        $file = $ver.files[0]
                        $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                        return @{
                            Name = if ($proj.title) { $proj.title } else { $proj.name }; Slug = $proj.slug; ExpectedSize = $file.size
                            VersionNumber = $ver.version_number; FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($ver.id)"
                            FoundByHash = $false; ExactMatch = $false; IsLatestVersion = ($versions[0].id -eq $ver.id)
                            MatchType = "Latest Version ($loader)"; LoaderType = $loader
                        }
                    }
                }
                
                # Fallback to latest version
                if ($versions.Count -gt 0) {
                    $latest = $versions[0]; $file = $latest.files[0]
                    $loader = if ($latest.loaders -contains "fabric") { "Fabric" } elseif ($latest.loaders -contains "forge") { "Forge" } else { $latest.loaders[0] }
                    return @{
                        Name = if ($proj.title) { $proj.title } else { $proj.name }; Slug = $proj.slug; ExpectedSize = $file.size
                        VersionNumber = $latest.version_number; FileName = $file.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($latest.id)"
                        FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $true
                        MatchType = "Latest Version ($loader)"; LoaderType = $loader
                    }
                }
            }
        }
    } catch { }
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; MatchType = "No Match"; LoaderType = "Unknown" }
}

function Fetch-Modrinth-By-Filename($filename, $preferredLoader = "Fabric") {
    try {
        $cleanName = $filename -replace '\.(temp|tmp)\.jar$', '.jar' -replace '_1\.jar$', '.jar'
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($cleanName)
        
        if ($filename -match '(?i)fabric') { $preferredLoader = "Fabric" }
        elseif ($filename -match '(?i)forge') { $preferredLoader = "Forge" }
        
        $localVersion = ""
        if ($baseName -match '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$') {
            $localVersion = $matches[1]
            $baseName = $baseName -replace '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$', ''
        }
        $baseName = $baseName -replace '(?i)-(fabric|forge)$', ''
        
        # Try direct slug lookup
        @($baseName.ToLower(), [System.IO.Path]::GetFileNameWithoutExtension($cleanName).ToLower()) | ForEach-Object {
            try {
                $proj = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$_" -UseBasicParsing
                if ($proj.id) {
                    $versions = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($proj.slug)/version" -UseBasicParsing
                    if ($versions.Count -gt 0) {
                        # Try exact filename match
                        foreach ($ver in $versions) {
                            foreach ($file in $ver.files) {
                                if ($file.filename -eq $cleanName -or $file.filename -eq $filename) {
                                    $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                                    return @{
                                        Name = $proj.title; Slug = $proj.slug; ExpectedSize = $file.size
                                        VersionNumber = $ver.version_number; FileName = $file.filename
                                        ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($ver.id)"
                                        FoundByHash = $false; ExactMatch = $true; IsLatestVersion = ($versions[0].id -eq $ver.id)
                                        MatchType = "Exact Filename"; LoaderType = $loader
                                    }
                                }
                            }
                        }
                        
                        # Try closest version with Minecraft filter
                        if ($localVersion) {
                            $matched = Find-Closest-Version -localVersion $localVersion -availableVersions $versions -preferredLoader $preferredLoader -minecraftVersion $minecraftVersion
                            if ($matched) {
                                $file = $matched.files[0]; $isExact = ($matched.version_number -eq $localVersion)
                                $loader = if ($matched.loaders -contains "fabric") { "Fabric" } elseif ($matched.loaders -contains "forge") { "Forge" } else { $matched.loaders[0] }
                                return @{
                                    Name = $proj.title; Slug = $proj.slug; ExpectedSize = $file.size
                                    VersionNumber = $matched.version_number; FileName = $file.filename
                                    ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($matched.id)"
                                    FoundByHash = $false; ExactMatch = $isExact; IsLatestVersion = ($versions[0].id -eq $matched.id)
                                    MatchType = if ($isExact) { "Exact Version" } else { "Closest Version" }; LoaderType = $loader
                                }
                            }
                        }
                        
                        # Return latest with Minecraft filter
                        foreach ($ver in $versions) {
                            $loaderMatch = $ver.loaders -contains $preferredLoader.ToLower()
                            $mcMatch = if ($minecraftVersion -and $ver.game_versions) { $ver.game_versions -contains $minecraftVersion } else { $true }
                            if ($loaderMatch -and $mcMatch) {
                                $file = $ver.files[0]
                                $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                                return @{
                                    Name = $proj.title; Slug = $proj.slug; ExpectedSize = $file.size
                                    VersionNumber = $ver.version_number; FileName = $file.filename
                                    ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($ver.id)"
                                    FoundByHash = $false; ExactMatch = $false; IsLatestVersion = ($versions[0].id -eq $ver.id)
                                    MatchType = "Latest Version ($loader)"; LoaderType = $loader
                                }
                            }
                        }
                    }
                }
            } catch { }
        }
    } catch { }
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; MatchType = "No Match"; LoaderType = "Unknown" }
}

# Main scanning
$jarFiles = Get-ChildItem -Path $mods -Filter *.jar
$spinner = @("|", "/", "-", "\")
$verifiedMods = @(); $unknownMods = @(); $cheatMods = @(); $sizeMismatchMods = @(); $tamperedMods = @(); $allModsInfo = @()

for ($i = 0; $i -lt $jarFiles.Count; $i++) {
    $file = $jarFiles[$i]
    Write-Host "`r[$($spinner[$i % $spinner.Length])] Scanning mods: $($i+1)/$($jarFiles.Count)" -ForegroundColor Magenta -NoNewline
    
    $hash = Get-SHA1 $file.FullName
    $actualSize = $file.Length
    $actualSizeKB = [math]::Round($actualSize/1KB, 2)
    $zoneInfo = Get-ZoneIdentifier $file.FullName
    $jarInfo = Get-Mod-Info-From-Jar $file.FullName
    
    $preferredLoader = "Fabric"
    if ($file.Name -match '(?i)forge') { $preferredLoader = "Forge" }
    elseif ($jarInfo.ModLoader -eq "Fabric") { $preferredLoader = "Fabric" }
    elseif ($jarInfo.ModLoader -eq "Forge/NeoForge") { $preferredLoader = "Forge" }
    
    $modData = Fetch-Modrinth-By-Hash $hash
    if ($modData.Name -and $modData.FoundByHash) {
        $sizeDiff = $actualSize - $modData.ExpectedSize
        $modEntry = [PSCustomObject]@{ 
            ModName = $modData.Name; FileName = $file.Name; Version = $modData.VersionNumber
            ExpectedSize = $modData.ExpectedSize; ExpectedSizeKB = [math]::Round($modData.ExpectedSize/1KB, 2)
            ActualSize = $actualSize; ActualSizeKB = $actualSizeKB; SizeDiff = $sizeDiff; SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source; SourceURL = $zoneInfo.URL; IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modData.ModrinthUrl; IsVerified = $true; MatchType = $modData.MatchType
            ExactMatch = $modData.ExactMatch; IsLatestVersion = $modData.IsLatestVersion; LoaderType = $modData.LoaderType
            PreferredLoader = $preferredLoader; FilePath = $file.FullName; JarModId = $jarInfo.ModId
            JarName = $jarInfo.Name; JarVersion = $jarInfo.Version; JarModLoader = $jarInfo.ModLoader
        }
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
        if ($modData.ExpectedSize -gt 0 -and $actualSize -ne $modData.ExpectedSize) {
            $sizeMismatchMods += $modEntry
            if ([math]::Abs($sizeDiff) -gt 1024) { $tamperedMods += $modEntry }
        }
        continue
    }
    
    $modrinthInfo = $null
    if ($jarInfo.ModId) { $modrinthInfo = Fetch-Modrinth-By-ModId -modId $jarInfo.ModId -version $jarInfo.Version -preferredLoader $preferredLoader }
    if (-not $modrinthInfo -or -not $modrinthInfo.Name) { $modrinthInfo = Fetch-Modrinth-By-Filename -filename $file.Name -preferredLoader $preferredLoader }
    
    if ($modrinthInfo -and $modrinthInfo.Name) {
        $sizeDiff = $actualSize - $modrinthInfo.ExpectedSize
        $modEntry = [PSCustomObject]@{ 
            ModName = $modrinthInfo.Name; FileName = $file.Name; Version = $modrinthInfo.VersionNumber
            ExpectedSize = $modrinthInfo.ExpectedSize; ExpectedSizeKB = if ($modrinthInfo.ExpectedSize -gt 0) { [math]::Round($modrinthInfo.ExpectedSize/1KB, 2) } else { 0 }
            ActualSize = $actualSize; ActualSizeKB = $actualSizeKB; SizeDiff = $sizeDiff; SizeDiffKB = [math]::Round($sizeDiff/1KB, 2)
            DownloadSource = $zoneInfo.Source; SourceURL = $zoneInfo.URL; IsModrinthDownload = $zoneInfo.IsModrinth
            ModrinthUrl = $modrinthInfo.ModrinthUrl; IsVerified = $true; MatchType = $modrinthInfo.MatchType
            ExactMatch = $modrinthInfo.ExactMatch; IsLatestVersion = $modrinthInfo.IsLatestVersion; LoaderType = $modrinthInfo.LoaderType
            PreferredLoader = $preferredLoader; FilePath = $file.FullName; JarModId = $jarInfo.ModId
            JarName = $jarInfo.Name; JarVersion = $jarInfo.Version; JarModLoader = $jarInfo.ModLoader
        }
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
        if ($modrinthInfo.ExpectedSize -gt 0 -and $actualSize -ne $modrinthInfo.ExpectedSize) {
            $sizeMismatchMods += $modEntry
            if ([math]::Abs($sizeDiff) -gt 1024) { $tamperedMods += $modEntry }
        }
        continue
    }
    
    # Unknown mod
    $modEntry = [PSCustomObject]@{ 
        FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneInfo.URL; DownloadSource = $zoneInfo.Source
        IsModrinthDownload = $zoneInfo.IsModrinth; FileSize = $actualSize; FileSizeKB = $actualSizeKB; Hash = $hash
        ExpectedSize = 0; ExpectedSizeKB = 0; SizeDiff = 0; SizeDiffKB = 0; ModrinthUrl = ""; ModName = ""; MatchType = ""
        ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown"; PreferredLoader = $preferredLoader
        JarModId = $jarInfo.ModId; JarName = $jarInfo.Name; JarVersion = $jarInfo.Version; JarModLoader = $jarInfo.ModLoader
    }
    $unknownMods += $modEntry; $allModsInfo += $modEntry
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# Display results
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan

if ($verifiedMods.Count -gt 0) {
    Write-Host "`n{ Verified Mods }" -ForegroundColor Cyan
    Write-Host "Total: $($verifiedMods.Count)`n"
    foreach ($mod in $verifiedMods) {
        $isCheatMod = $cheatMods.FileName -contains $mod.FileName
        $isTampered = $tamperedMods.FileName -contains $mod.FileName
        $color = if ($isTampered) { "Red" } elseif ($isCheatMod) { "Red" } else { "Green" }
        Write-Host "> $($mod.ModName)" -ForegroundColor $color -NoNewline
        Write-Host " - $($mod.FileName)" -ForegroundColor $(if ($isTampered) { "Magenta" } elseif ($isCheatMod) { "Red" } else { "Gray" }) -NoNewline
        if ($mod.Version -and $mod.Version -ne "Unknown") { Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray -NoNewline }
        
        $matchIndicator = ""; $matchColor = "DarkGray"
        if ($mod.MatchType -eq "Exact Hash" -or $mod.MatchType -eq "Exact Version" -or $mod.MatchType -eq "Exact Filename") {
            $matchIndicator = "✓"; $matchColor = "Green"
        } elseif ($mod.MatchType -eq "Closest Version") { $matchIndicator = "≈"; $matchColor = "Yellow" }
        elseif ($mod.MatchType -match "Latest Version") { $matchIndicator = "↑"; $matchColor = "Cyan" }
        if ($matchIndicator) { Write-Host " $matchIndicator" -ForegroundColor $matchColor -NoNewline }
        
        if ($mod.LoaderType -ne "Unknown") {
            Write-Host " ($($mod.LoaderType))" -ForegroundColor $(if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" }) -NoNewline
        }
        if ($mod.DownloadSource -ne "Unknown") {
            Write-Host " [$($mod.DownloadSource)]" -ForegroundColor $(if ($mod.IsModrinthDownload) { "Green" } else { "DarkYellow" })
        } else { Write-Host "" }
        
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                Write-Host "  Size: $($mod.ActualSizeKB) KB ✓" -ForegroundColor Green
            } else {
                $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
                $sizeColor = if ($isTampered) { "Magenta" } else { "Yellow" }
                Write-Host "  Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB, Diff: $sign$($mod.SizeDiffKB) KB)" -ForegroundColor $sizeColor
            }
        }
    }
}

if ($unknownMods.Count -gt 0) {
    Write-Host "`n{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)`n"
    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        if ($mod.ZoneId) {
            Write-Host "  Downloaded from: $($mod.DownloadSource)" -ForegroundColor $(if ($mod.IsModrinthDownload) { "Green" } else { "DarkYellow" })
        }
        Write-Host ""
    }
}

if ($tamperedMods.Count -gt 0) {
    Write-Host "`n{ Potentially Tampered Mods }" -ForegroundColor Red
    Write-Host "Total: $($tamperedMods.Count) ⚠ WARNING`n"
    foreach ($mod in $tamperedMods) {
        $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Magenta
        if ($mod.LoaderType -ne "Unknown") {
            Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $(if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" })
        }
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Magenta
        Write-Host "  ⚠ File size differs significantly from Modrinth version!" -ForegroundColor Red
        if ($mod.ModrinthUrl) { Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray }
        Write-Host ""
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
