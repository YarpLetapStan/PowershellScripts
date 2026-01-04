Clear-Host
Write-Host "Made by " -ForegroundColor Cyan -NoNewline
Write-Host "YarpLetapStan" -ForegroundColor Cyan
Write-Host "Credits to Habibi Mod Analyzer" -ForegroundColor DarkGray
Write-Host

# Create a box for the title
$boxWidth = 38
Write-Host "+" + ("-" * $boxWidth) + "+" -ForegroundColor Blue
Write-Host "|" + (" " * $boxWidth) + "|" -ForegroundColor Blue
Write-Host "|" + ("YarpLetapStan's Mod Analyzer V3.0".PadLeft(($boxWidth + 30)/2).PadRight($boxWidth)) + "|" -ForegroundColor Blue
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
    param ($modsFolder)
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
                if ($data.schemaVersion -ge 1 -and $data.depends -and $data.depends.PSObject.Properties.Name -contains 'minecraft') {
                    $ver = $data.depends.minecraft -replace '^[><=~^]*\s*|\s*$', ''
                    if ($ver -match '^\d+(\.\d+)+(\.\d+)?$') { $versions[$ver]++ }
                }
            }
            $zip.Dispose()
        } catch { }
    }
    if ($versions.Count -gt 0) {
        $common = $versions.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        Write-Host "`nDetected Minecraft version: $($common.Key) (from $($common.Value) mods)" -ForegroundColor Cyan
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
    
    Write-Host "`nCould not auto-detect Minecraft version from mods." -ForegroundColor Yellow
    $ver = Read-Host "Enter your Minecraft version (e.g., 1.21, 1.20.1) or press Enter to skip filtering"
    return if ($ver -eq '') { $null } else { $ver }
}

$minecraftVersion = Get-Minecraft-Version-From-Mods $mods
if ($minecraftVersion) { Write-Host "Using Minecraft version: $minecraftVersion for filtering`n" -ForegroundColor Green }

function Get-SHA1($filePath) { return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash }

function Get-ZoneIdentifier($filePath) {
    try {
        $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
        if ($ads -match "HostUrl=(.+)") {
            $url = $matches[1]
            if ($url -match "modrinth\.com") { return @{ Source = "Modrinth"; URL = $url; IsModrinth = $true } }
            elseif ($url -match "curseforge\.com") { return @{ Source = "CurseForge"; URL = $url; IsModrinth = $false } }
            elseif ($url -match "github\.com") { return @{ Source = "GitHub"; URL = $url; IsModrinth = $false } }
            elseif ($url -match "discord") { return @{ Source = "Discord"; URL = $url; IsModrinth = $false } }
            else { return @{ Source = "Other"; URL = $url; IsModrinth = $false } }
        }
    } catch { }
    return @{ Source = "Unknown"; URL = ""; IsModrinth = $false }
}

function Get-Mod-Info-From-Jar($jarPath) {
    $modInfo = @{ ModId = ""; Name = ""; Version = ""; Description = ""; Authors = @(); ModLoader = "" }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        
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
        
        $mixinJson = $zip.Entries | Where-Object { $_.Name -match '\.mixins\.json$' } | Select-Object -First 1
        if ($mixinJson) {
            $reader = New-Object System.IO.StreamReader($mixinJson.Open())
            $data = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue
            $reader.Close()
            if ($data.package) {
                $parts = $data.package -split '\.'
                if ($parts.Count -ge 2 -and -not $modInfo.ModId) { $modInfo.ModId = $parts[-2] }
            }
        }
        
        $manifest = $zip.Entries | Where-Object { $_.Name -eq 'MANIFEST.MF' } | Select-Object -First 1
        if ($manifest) {
            $reader = New-Object System.IO.StreamReader($manifest.Open())
            $content = $reader.ReadToEnd()
            $reader.Close()
            $lines = $content -split "`n"
            foreach ($line in $lines) {
                if ($line -match 'Implementation-Title:\s*(.+)' -and -not $modInfo.Name) { $modInfo.Name = $matches[1].Trim() }
                if ($line -match 'Implementation-Version:\s*(.+)' -and -not $modInfo.Version) { $modInfo.Version = $matches[1].Trim() }
                if ($line -match 'Specification-Title:\s*(.+)' -and -not $modInfo.Name) { $modInfo.Name = $matches[1].Trim() }
            }
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
    
    foreach ($ver in $filtered) {
        if ($ver.version_number -eq $localVersion) { return $ver }
    }
    
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
    
    if ($localVersion -match '(\d+)\.(\d+)') {
        $major, $minor = [int]$matches[1], [int]$matches[2]
        $closest = $null; $closestDist = [double]::MaxValue
        foreach ($ver in $filtered) {
            if ($ver.version_number -match '(\d+)\.(\d+)') {
                $dist = [math]::Sqrt([math]::Pow($major - [int]$matches[1], 2) * 10 + [math]::Pow($minor - [int]$matches[2], 2))
                if ($dist -lt $closestDist) { $closestDist = $dist; $closest = $ver }
            }
        }
        if ($closest -and $closestDist -lt 5) { return $closest }
    }
    
    foreach ($ver in $filtered) {
        if ($ver.version_number -contains $localVersion -or $ver.version_number -match [regex]::Escape($localVersion)) {
            return $ver
        }
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
            if ($search.hits -and $search.hits.Count -gt 0) { 
                $bestMatch = $null; $bestScore = 0
                foreach ($hit in $search.hits) {
                    $score = 0
                    if ($hit.slug -eq $modId) { $score += 100 }
                    if ($hit.project_id -eq $modId) { $score += 100 }
                    if ($hit.title -eq $modId) { $score += 80 }
                    if ($hit.title -match $modId) { $score += 50 }
                    if ($hit.slug -match $modId) { $score += 40 }
                    if ($score -gt $bestScore) { $bestScore = $score; $bestMatch = $hit }
                }
                if ($bestMatch) { $proj = $bestMatch }
            }
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
        
        @($baseName.ToLower(), [System.IO.Path]::GetFileNameWithoutExtension($cleanName).ToLower()) | ForEach-Object {
            try {
                $proj = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$_" -UseBasicParsing
                if ($proj.id) {
                    $versions = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($proj.slug)/version" -UseBasicParsing
                    if ($versions.Count -gt 0) {
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
                        
                        if ($versions.Count -gt 0) {
                            $latest = $versions[0]; $file = $latest.files[0]
                            $loader = if ($latest.loaders -contains "fabric") { "Fabric" } elseif ($latest.loaders -contains "forge") { "Forge" } else { $latest.loaders[0] }
                            return @{
                                Name = $proj.title; Slug = $proj.slug; ExpectedSize = $file.size
                                VersionNumber = $latest.version_number; FileName = $file.filename
                                ModrinthUrl = "https://modrinth.com/mod/$($proj.slug)/version/$($latest.id)"
                                FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $true
                                MatchType = "Latest Version ($loader)"; LoaderType = $loader
                            }
                        }
                    }
                }
            } catch { }
        }
        
        $search = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/search?query=`"$baseName`"&facets=`"[[`"project_type:mod`"]]`"&limit=5" -UseBasicParsing
        if ($search.hits -and $search.hits.Count -gt 0) {
            $hit = $search.hits[0]
            $versions = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($hit.project_id)/version" -UseBasicParsing
            if ($versions.Count -gt 0) {
                foreach ($ver in $versions) {
                    foreach ($file in $ver.files) {
                        if ($file.filename -eq $cleanName -or $file.filename -eq $filename) {
                            $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                            return @{
                                Name = $hit.title; Slug = $hit.slug; ExpectedSize = $file.size
                                VersionNumber = $ver.version_number; FileName = $file.filename
                                ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($ver.id)"
                                FoundByHash = $false; ExactMatch = $true; IsLatestVersion = ($versions[0].id -eq $ver.id)
                                MatchType = "Exact Filename"; LoaderType = $loader
                            }
                        }
                    }
                }
                
                foreach ($ver in $versions) {
                    $loaderMatch = $ver.loaders -contains $preferredLoader.ToLower()
                    $mcMatch = if ($minecraftVersion -and $ver.game_versions) { $ver.game_versions -contains $minecraftVersion } else { $true }
                    if ($loaderMatch -and $mcMatch) {
                        $file = $ver.files[0]
                        $loader = if ($ver.loaders -contains "fabric") { "Fabric" } elseif ($ver.loaders -contains "forge") { "Forge" } else { $ver.loaders[0] }
                        return @{
                            Name = $hit.title; Slug = $hit.slug; ExpectedSize = $file.size
                            VersionNumber = $ver.version_number; FileName = $file.filename
                            ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($ver.id)"
                            FoundByHash = $false; ExactMatch = $false; IsLatestVersion = ($versions[0].id -eq $ver.id)
                            MatchType = "Latest Version ($loader)"; LoaderType = $loader
                        }
                    }
                }
                
                if ($versions.Count -gt 0) {
                    $latest = $versions[0]; $file = $latest.files[0]
                    $loader = if ($latest.loaders -contains "fabric") { "Fabric" } elseif ($latest.loaders -contains "forge") { "Forge" } else { $latest.loaders[0] }
                    return @{
                        Name = $hit.title; Slug = $hit.slug; ExpectedSize = $file.size
                        VersionNumber = $latest.version_number; FileName = $file.filename
                        ModrinthUrl = "https://modrinth.com/mod/$($hit.slug)/version/$($latest.id)"
                        FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $true
                        MatchType = "Latest Version ($loader)"; LoaderType = $loader
                    }
                }
            }
        }
    } catch { }
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; FileName = ""; FoundByHash = $false; ExactMatch = $false; IsLatestVersion = $false; MatchType = "No Match"; LoaderType = "Unknown" }
}

function Fetch-Megabase($hash) {
    try {
        $resp = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -UseBasicParsing
        if (-not $resp.error) { return $resp.data }
    } catch { }
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
    "hitboxes"
)

function Check-Strings($filePath) {
    $stringsFound = [System.Collections.Generic.HashSet[string]]::new()
    try {
        $stringsPath = $null
        @(
            "C:\Program Files\Git\usr\bin\strings.exe",
            "C:\Program Files\Git\mingw64\bin\strings.exe",
            "$env:ProgramFiles\Git\usr\bin\strings.exe",
            "C:\msys64\usr\bin\strings.exe",
            "C:\cygwin64\bin\strings.exe"
        ) | ForEach-Object {
            if (Test-Path $_) { $stringsPath = $_; break }
        }
        
        if ($stringsPath) {
            $tempFile = Join-Path $env:TEMP "temp_strings_$(Get-Random).txt"
            & $stringsPath $filePath 2>$null | Out-File $tempFile -ErrorAction SilentlyContinue
            if (Test-Path $tempFile) {
                $content = Get-Content $tempFile -Raw
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                foreach ($string in $cheatStrings) {
                    if ($content -match $string) { $stringsFound.Add($string) | Out-Null }
                }
            }
        } else {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $content = [System.Text.Encoding]::ASCII.GetString($bytes).ToLower()
            foreach ($string in $cheatStrings) {
                if ($string -eq "velocity") {
                    if ($content -match "velocity(hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
                        $stringsFound.Add($string) | Out-Null
                    }
                } else {
                    if ($content -match $string) { $stringsFound.Add($string) | Out-Null }
                }
            }
        }
    } catch { }
    return $stringsFound
}

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
    
    $megabaseData = Fetch-Megabase $hash
    if ($megabaseData -and $megabaseData.name) {
        $modEntry = [PSCustomObject]@{ 
            ModName = $megabaseData.name; FileName = $file.Name; Version = "Unknown"
            ExpectedSize = 0; ExpectedSizeKB = 0; ActualSize = $actualSize; ActualSizeKB = $actualSizeKB
            SizeDiff = 0; SizeDiffKB = 0; DownloadSource = $zoneInfo.Source; SourceURL = $zoneInfo.URL
            IsModrinthDownload = $zoneInfo.IsModrinth; IsVerified = $true; MatchType = "Megabase"
            ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown"; PreferredLoader = $preferredLoader
            FilePath = $file.FullName; JarModId = $jarInfo.ModId; JarName = $jarInfo.Name
            JarVersion = $jarInfo.Version; JarModLoader = $jarInfo.ModLoader
        }
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
        continue
    }
    
    $modEntry = [PSCustomObject]@{ 
        FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneInfo.URL; DownloadSource = $zoneInfo.Source
        IsModrinthDownload = $zoneInfo.IsModrinth; FileSize = $actualSize; FileSizeKB = $actualSizeKB; Hash = $hash
        ExpectedSize = 0; ExpectedSizeKB = 0; SizeDiff = 0; SizeDiffKB = 0; ModrinthUrl = ""; ModName = ""; MatchType = ""
        ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown"; PreferredLoader = $preferredLoader
        JarModId = $jarInfo.ModId; JarName = $jarInfo.Name; JarVersion = $jarInfo.Version; JarModLoader = $jarInfo.ModLoader
    }
    $unknownMods += $modEntry; $allModsInfo += $modEntry
}

for ($i = 0; $i -lt $unknownMods.Count; $i++) {
    $mod = $unknownMods[$i]
    $modrinthInfo = $null
    if ($mod.JarModId) { $modrinthInfo = Fetch-Modrinth-By-ModId -modId $mod.JarModId -version $mod.JarVersion -preferredLoader $mod.PreferredLoader }
    if (-not $modrinthInfo -or -not $modrinthInfo.Name) { $modrinthInfo = Fetch-Modrinth-By-Filename -filename $mod.FileName -preferredLoader $mod.PreferredLoader }
    
    if ($modrinthInfo -and $modrinthInfo.Name) {
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

$tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"
$counter = 0

try {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    for ($i = 0; $i -lt $allModsInfo.Count; $i++) {
        $mod = $allModsInfo[$i]
        Write-Host "`r[$($spinner[$i % $spinner.Length])] Scanning mods for cheat strings: $($i+1)/$($allModsInfo.Count)" -ForegroundColor Magenta -NoNewline
        
        $modStrings = Check-Strings $mod.FilePath
        if ($modStrings.Count -gt 0) {
            $cheatMods += [PSCustomObject]@{ 
                FileName = $mod.FileName; StringsFound = $modStrings; FileSizeKB = $mod.FileSizeKB
                DownloadSource = $mod.DownloadSource; SourceURL = $mod.ZoneId
                ExpectedSizeKB = $mod.ExpectedSizeKB; SizeDiffKB = $mod.SizeDiffKB
                IsVerifiedMod = ($mod.IsVerified -eq $true); ModName = $mod.ModName; ModrinthUrl = $mod.ModrinthUrl
                FilePath = $mod.FilePath; HasSizeMismatch = ($mod.SizeDiffKB -ne 0 -and [math]::Abs($mod.SizeDiffKB) -gt 1)
                JarModId = $mod.JarModId; JarName = $mod.JarName; JarVersion = $mod.JarVersion
                MatchType = $mod.MatchType; ExactMatch = $mod.ExactMatch; IsLatestVersion = $mod.IsLatestVersion
                LoaderType = $mod.LoaderType
            }
        }
    }
} catch {
    Write-Host "`nError occurred while scanning: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan
Write-Host

if ($verifiedMods.Count -gt 0) {
    Write-Host "{ Verified Mods }" -ForegroundColor Cyan
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
    Write-Host ""
}

if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)`n"
    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        
        if ($mod.ModName) {
            Write-Host "  Identified as: $($mod.ModName)" -ForegroundColor Cyan
            if ($mod.LoaderType -ne "Unknown") {
                Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $(if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" })
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
        if ($mod.MatchType -eq "Closest Version") {
            Write-Host "  Note: Compared to closest available version on Modrinth" -ForegroundColor Yellow
        } elseif ($mod.MatchType -match "Latest Version") {
            Write-Host "  Note: Compared to latest version on Modrinth" -ForegroundColor Cyan
        }
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Magenta
        Write-Host "  ⚠ File size differs significantly from Modrinth version!" -ForegroundColor Red
        if ($mod.ModrinthUrl) { Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray }
        Write-Host ""
    }
}

if ($cheatMods.Count -gt 0) {
    Write-Host "`n{ Cheat Mods Detected }" -ForegroundColor Red
    Write-Host "Total: $($cheatMods.Count) ⚠ WARNING`n"
    foreach ($mod in $cheatMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        if ($mod.ModName) { Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Gray }
        if ($mod.LoaderType -ne "Unknown") {
            Write-Host "  Loader: $($mod.LoaderType)" -ForegroundColor $(if ($mod.LoaderType -eq "Fabric") { "Magenta" } else { "Yellow" })
        }
        if ($mod.MatchType -eq "Closest Version") {
            Write-Host "  Note: Compared to closest available version on Modrinth" -ForegroundColor Yellow
        } elseif ($mod.MatchType -match "Latest Version") {
            Write-Host "  Note: Compared to latest version on Modrinth" -ForegroundColor Cyan
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
            Write-Host "  Source: $($mod.DownloadSource)" -ForegroundColor $(if ($mod.DownloadSource -eq "Modrinth") { "Green" } else { "DarkYellow" })
        }
        
        if ($mod.IsVerifiedMod) {
            Write-Host "  ⚠ Legitimate mod contains cheat code!" -ForegroundColor Red
            Write-Host "  ⚠ This appears to be a tampered version of a legitimate mod" -ForegroundColor Red
        }
        Write-Host ""
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
