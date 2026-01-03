Clear-Host
Write-Host "Made by " -ForegroundColor Cyan -NoNewline
Write-Host "YarpLetapStan" -ForegroundColor Cyan
Write-Host "Credit to Habibi Mod Analyzer" -ForegroundColor DarkGray
Write-Host

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
    param ([string]$filePath)
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash
}

function Get-ZoneIdentifier {
    param ([string]$filePath)
    try {
        $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
        if ($ads -match "HostUrl=(.+)") {
            $url = $matches[1]
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
    param ([string]$jarPath)
    $modInfo = @{ModId="";Name="";Version="";Description="";Authors=@();License="";Contact=@{};Icon="";Environment="";Entrypoints=@{};Mixins=@();AccessWidener="";Depends=@{};Suggests=@{};Breaks=@{};Conflicts=@{}}
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        $fabricModJson = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1
        if ($fabricModJson) {
            $stream = $fabricModJson.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $jsonContent = $reader.ReadToEnd()
            $reader.Close(); $stream.Close()
            try {
                $fabricData = $jsonContent | ConvertFrom-Json
                if ($fabricData.id) { $modInfo.ModId = $fabricData.id }
                if ($fabricData.name) { $modInfo.Name = $fabricData.name }
                if ($fabricData.version) { $modInfo.Version = $fabricData.version }
                if ($fabricData.description) { $modInfo.Description = $fabricData.description }
                if ($fabricData.authors) { $modInfo.Authors = if ($fabricData.authors -is [array]) { $fabricData.authors } else { @($fabricData.authors) } }
                if ($fabricData.license) { $modInfo.License = $fabricData.license }
                if ($fabricData.contact) { $modInfo.Contact = $fabricData.contact }
                if ($fabricData.icon) { $modInfo.Icon = $fabricData.icon }
                if ($fabricData.environment) { $modInfo.Environment = $fabricData.environment }
                if ($fabricData.entrypoints) { $modInfo.Entrypoints = $fabricData.entrypoints }
                if ($fabricData.mixins) { $modInfo.Mixins = if ($fabricData.mixins -is [array]) { $fabricData.mixins } else { @($fabricData.mixins) } }
                if ($fabricData.accessWidener) { $modInfo.AccessWidener = $fabricData.accessWidener }
                if ($fabricData.depends) { $modInfo.Depends = $fabricData.depends }
                if ($fabricData.suggests) { $modInfo.Suggests = $fabricData.suggests }
                if ($fabricData.breaks) { $modInfo.Breaks = $fabricData.breaks }
                if ($fabricData.conflicts) { $modInfo.Conflicts = $fabricData.conflicts }
                $zip.Dispose(); return $modInfo
            } catch {}
        }
        $modsToml = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' } | Select-Object -First 1
        if ($modsToml) {
            $stream = $modsToml.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $tomlContent = $reader.ReadToEnd()
            $reader.Close(); $stream.Close()
            if ($tomlContent -match 'modId\s*=\s*"([^"]+)"') { $modInfo.ModId = $matches[1] }
            if ($tomlContent -match 'displayName\s*=\s*"([^"]+)"') { $modInfo.Name = $matches[1] }
            if ($tomlContent -match 'version\s*=\s*"([^"]+)"') { $modInfo.Version = $matches[1] }
            if ($tomlContent -match 'description\s*=\s*"([^"]+)"') { $modInfo.Description = $matches[1] }
            if ($tomlContent -match 'authors\s*=\s*"([^"]+)"') { $modInfo.Authors = @($matches[1]) }
            $zip.Dispose(); return $modInfo
        }
        $zip.Dispose()
    } catch {}
    return $modInfo
}

function Fetch-Modrinth-By-Hash {
    param ([string]$hash)
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if ($response.project_id) {
            $projectData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($response.project_id)" -Method Get -UseBasicParsing -ErrorAction Stop
            $fileInfo = $response.files[0]
            return @{Name=$projectData.title;Slug=$projectData.slug;ExpectedSize=$fileInfo.size;VersionNumber=$response.version_number;FileName=$fileInfo.filename;ModrinthUrl="https://modrinth.com/mod/$($projectData.slug)/version/$($response.id)";FoundByHash=$true}
        }
    } catch {}
    return @{Name="";Slug="";ExpectedSize=0;VersionNumber="";FileName="";FoundByHash=$false}
}

function Fetch-Modrinth-By-ModId {
    param ([string]$modId, [string]$version)
    try {
        $searchUrl = "https://api.modrinth.com/v2/search?query=`"$modId`"&facets=`"[[`"project_type:mod`"]]`"&limit=5"
        $searchData = Invoke-RestMethod -Uri $searchUrl -Method Get -UseBasicParsing -ErrorAction Stop
        if ($searchData.hits -and $searchData.hits.Count -gt 0) {
            $matchedProject = $null
            foreach ($hit in $searchData.hits) {
                if ($hit.slug -eq $modId -or $hit.project_id -eq $modId -or $hit.title -match [regex]::Escape($modId)) {
                    $matchedProject = $hit; break
                }
            }
            if (-not $matchedProject) { $matchedProject = $searchData.hits[0] }
            $projectId = $matchedProject.project_id
            $versionsData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$projectId/version" -Method Get -UseBasicParsing -ErrorAction Stop
            if ($versionsData.Count -eq 0) { return @{Name="";Slug="";ExpectedSize=0;VersionNumber="";FileName="";FoundByHash=$false;ExactMatch=$false;IsLatestVersion=$false} }
            $bestMatch = $null; $exactMatch = $false
            if ($version) {
                $cleanVersion = $version -replace '[^0-9\.]', ''
                foreach ($ver in $versionsData) {
                    $verNum = $ver.version_number -replace '[^0-9\.]', ''
                    if ($verNum -eq $cleanVersion) { $bestMatch = $ver; $exactMatch = $true; break }
                }
                if (-not $bestMatch) {
                    foreach ($ver in $versionsData) {
                        if ($ver.version_number -match [regex]::Escape($version) -or $version -match [regex]::Escape($ver.version_number)) {
                            $bestMatch = $ver; break
                        }
                    }
                }
                if (-not $bestMatch) {
                    $targetVersionParts = $cleanVersion -split '\.' | ForEach-Object { try { [int]$_ } catch { 0 } }
                    $closestVersion = $null; $closestDifference = [int]::MaxValue
                    foreach ($ver in $versionsData) {
                        $verNum = $ver.version_number -replace '[^0-9\.]', ''
                        $verParts = $verNum -split '\.' | ForEach-Object { try { [int]$_ } catch { 0 } }
                        $diff = 0
                        for ($i = 0; $i -lt [Math]::Min($targetVersionParts.Count, $verParts.Count); $i++) {
                            $weight = [Math]::Pow(1000, ($targetVersionParts.Count - $i))
                            $diff += [Math]::Abs($targetVersionParts[$i] - $verParts[$i]) * $weight
                        }
                        if ($diff -lt $closestDifference) { $closestDifference = $diff; $closestVersion = $ver }
                    }
                    $bestMatch = $closestVersion
                }
            }
            if (-not $bestMatch) { $bestMatch = $versionsData[0] }
            if ($bestMatch.files -and $bestMatch.files.Count -gt 0) {
                $file = $bestMatch.files[0]
                return @{Name=$matchedProject.title;Slug=$matchedProject.slug;ExpectedSize=$file.size;VersionNumber=$bestMatch.version_number;FileName=$file.filename;ModrinthUrl="https://modrinth.com/mod/$($matchedProject.slug)/version/$($bestMatch.id)";FoundByHash=$false;ExactMatch=$exactMatch;IsLatestVersion=($bestMatch.id -eq $versionsData[0].id);IsClosestMatch=(-not $exactMatch -and $version)}
            }
        }
    } catch {}
    return @{Name="";Slug="";ExpectedSize=0;VersionNumber="";FileName="";FoundByHash=$false;ExactMatch=$false;IsLatestVersion=$false;IsClosestMatch=$false}
}

function Fetch-Megabase {
    param ([string]$hash)
    try {
        $response = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if (-not $response.error) { return $response.data }
    } catch {}
    return $null
}

$cheatStrings = @("AimAssist","AnchorTweaks","AutoAnchor","AutoCrystal","AutoDoubleHand","AutoHitCrystal","AutoPot","AutoTotem","AutoArmor","InventoryTotem","Hitboxes","JumpReset","LegitTotem","PingSpoof","SelfDestruct","ShieldBreaker","TriggerBot","Velocity","AxeSpam","WebMacro","FastPlace","KillAura","Reach","NoSlow","Bhop","Phase","Freecam","Xray")

function Check-Strings {
    param ([string]$filePath)
    $stringsFound = [System.Collections.Generic.HashSet[string]]::new()
    try {
        $fileContent = Get-Content -Raw $filePath
        foreach ($string in $cheatStrings) {
            if ($fileContent -match $string) { $stringsFound.Add($string) | Out-Null }
        }
    } catch {}
    return $stringsFound
}

$verifiedMods = @(); $unknownMods = @(); $cheatMods = @(); $sizeMismatchMods = @(); $tamperedMods = @(); $allModsInfo = @()
$jarFiles = Get-ChildItem -Path $mods -Filter *.jar
$spinner = @("|","/","-","\"); $totalMods = $jarFiles.Count; $counter = 0

foreach ($file in $jarFiles) {
    $counter++
    Write-Host "`r[$($spinner[$counter % $spinner.Length])] Scanning mods: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
    $hash = Get-SHA1 -filePath $file.FullName
    $actualSize = $file.Length; $actualSizeKB = [math]::Round($actualSize/1KB, 2)
    $zoneInfo = Get-ZoneIdentifier $file.FullName
    $jarModInfo = Get-Mod-Info-From-Jar -jarPath $file.FullName
    $modData = Fetch-Modrinth-By-Hash -hash $hash
    
    if ($modData.Name -and $modData.FoundByHash) {
        $sizeDiff = $actualSize - $modData.ExpectedSize
        $modEntry = [PSCustomObject]@{ModName=$modData.Name;FileName=$file.Name;Version=$modData.VersionNumber;ExpectedSize=$modData.ExpectedSize;ExpectedSizeKB=[math]::Round($modData.ExpectedSize/1KB, 2);ActualSize=$actualSize;ActualSizeKB=$actualSizeKB;SizeDiff=$sizeDiff;SizeDiffKB=[math]::Round($sizeDiff/1KB, 2);DownloadSource=$zoneInfo.Source;SourceURL=$zoneInfo.URL;IsModrinthDownload=$zoneInfo.IsModrinth;ModrinthUrl=$modData.ModrinthUrl;IsVerified=$true;FilePath=$file.FullName;JarModId=$jarModInfo.ModId;JarName=$jarModInfo.Name;JarVersion=$jarModInfo.Version}
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
        if ($modData.ExpectedSize -gt 0 -and $actualSize -ne $modData.ExpectedSize) {
            $sizeMismatchMods += $modEntry
            if ([math]::Abs($sizeDiff) -gt 1024) { $tamperedMods += $modEntry }
        }
        continue
    }
    
    $modrinthInfoFromJar = $null
    if ($jarModInfo.ModId) { $modrinthInfoFromJar = Fetch-Modrinth-By-ModId -modId $jarModInfo.ModId -version $jarModInfo.Version }
    
    if ($modrinthInfoFromJar -and $modrinthInfoFromJar.Name) {
        $sizeDiff = $actualSize - $modrinthInfoFromJar.ExpectedSize
        $modEntry = [PSCustomObject]@{ModName=$modrinthInfoFromJar.Name;FileName=$file.Name;Version=$modrinthInfoFromJar.VersionNumber;ExpectedSize=$modrinthInfoFromJar.ExpectedSize;ExpectedSizeKB=if($modrinthInfoFromJar.ExpectedSize -gt 0){[math]::Round($modrinthInfoFromJar.ExpectedSize/1KB, 2)}else{0};ActualSize=$actualSize;ActualSizeKB=$actualSizeKB;SizeDiff=$sizeDiff;SizeDiffKB=[math]::Round($sizeDiff/1KB, 2);DownloadSource=$zoneInfo.Source;SourceURL=$zoneInfo.URL;IsModrinthDownload=$zoneInfo.IsModrinth;ModrinthUrl=$modrinthInfoFromJar.ModrinthUrl;IsVerified=$true;ExactMatch=$modrinthInfoFromJar.ExactMatch;IsLatestVersion=$modrinthInfoFromJar.IsLatestVersion;FilePath=$file.FullName;JarModId=$jarModInfo.ModId;JarName=$jarModInfo.Name;JarVersion=$jarModInfo.Version}
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
        if ($modrinthInfoFromJar.ExpectedSize -gt 0 -and $actualSize -ne $modrinthInfoFromJar.ExpectedSize) {
            $sizeMismatchMods += $modEntry
            if ([math]::Abs($sizeDiff) -gt 1024) { $tamperedMods += $modEntry }
        }
        continue
    }
    
    $megabaseData = Fetch-Megabase -hash $hash
    if ($megabaseData -and $megabaseData.name) {
        $modEntry = [PSCustomObject]@{ModName=$megabaseData.name;FileName=$file.Name;Version="Unknown";ExpectedSize=0;ExpectedSizeKB=0;ActualSize=$actualSize;ActualSizeKB=$actualSizeKB;SizeDiff=0;SizeDiffKB=0;DownloadSource=$zoneInfo.Source;SourceURL=$zoneInfo.URL;IsModrinthDownload=$zoneInfo.IsModrinth;IsVerified=$true;FilePath=$file.FullName;JarModId=$jarModInfo.ModId;JarName=$jarModInfo.Name;JarVersion=$jarModInfo.Version}
        $verifiedMods += $modEntry; $allModsInfo += $modEntry
        continue
    }
    
    $unknownModEntry = [PSCustomObject]@{FileName=$file.Name;FilePath=$file.FullName;ZoneId=$zoneInfo.URL;DownloadSource=$zoneInfo.Source;IsModrinthDownload=$zoneInfo.IsModrinth;FileSize=$actualSize;FileSizeKB=$actualSizeKB;Hash=$hash;ExpectedSize=0;ExpectedSizeKB=0;SizeDiff=0;SizeDiffKB=0;ModrinthUrl="";ModName="";JarModId=$jarModInfo.ModId;JarName=$jarModInfo.Name;JarVersion=$jarModInfo.Version}
    $unknownMods += $unknownModEntry; $allModsInfo += $unknownModEntry
}

$tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"; $counter = 0
try {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    foreach ($mod in $allModsInfo) {
        $counter++
        Write-Host "`r[$($spinner[$counter % $spinner.Length])] Scanning for cheat strings: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
        $modStrings = Check-Strings $mod.FilePath
        if ($modStrings.Count -gt 0) {
            $cheatMods += [PSCustomObject]@{FileName=$mod.FileName;StringsFound=$modStrings;FileSizeKB=$mod.FileSizeKB;DownloadSource=$mod.DownloadSource;SourceURL=$mod.ZoneId;ExpectedSizeKB=$mod.ExpectedSizeKB;SizeDiffKB=$mod.SizeDiffKB;IsVerifiedMod=($mod.IsVerified -eq $true);ModName=$mod.ModName;ModrinthUrl=$mod.ModrinthUrl;FilePath=$mod.FilePath;HasSizeMismatch=($mod.SizeDiffKB -ne 0 -and [math]::Abs($mod.SizeDiffKB) -gt 1);JarModId=$mod.JarModId;JarName=$mod.JarName;JarVersion=$mod.JarVersion}
        }
    }
} finally {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline
Write-Host "`n{ Results Summary }" -ForegroundColor Cyan
Write-Host

if ($verifiedMods.Count -gt 0) {
    Write-Host "{ Verified Mods }" -ForegroundColor Cyan
    Write-Host "Total: $($verifiedMods.Count)"; Write-Host
    foreach ($mod in $verifiedMods) {
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
        if ($mod.Version -and $mod.Version -ne "Unknown") { Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray -NoNewline }
        if ($mod.DownloadSource -ne "Unknown") {
            Write-Host " ($($mod.DownloadSource))" -ForegroundColor $(if($mod.IsModrinthDownload){"Green"}else{"Yellow"})
        } else { Write-Host "" }
        if ($mod.ExpectedSize -gt 0) {
            if ($mod.ActualSize -eq $mod.ExpectedSize) {
                Write-Host "  Size: $($mod.ActualSizeKB) KB ✓" -ForegroundColor Green
            } else {
                $sizeDiffSign = if($mod.SizeDiffKB -gt 0){"+"}else{""}
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

if ($unknownMods.Count -gt 0) {
    Write-Host "{ Unknown Mods }" -ForegroundColor Yellow
    Write-Host "Total: $($unknownMods.Count)"; Write-Host
    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        if ($mod.ModName) {
            Write-Host "  Identified as: $($mod.ModName)" -ForegroundColor Cyan
            if ($mod.ExpectedSize -gt 0) {
                if ($mod.FileSize -eq $mod.ExpectedSize) {
                    Write-Host "  Size matches Modrinth: $($mod.FileSizeKB) KB ✓" -ForegroundColor Green
                } else {
                    Write-Host "  Size: $($mod.FileSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB, Diff: $(if($mod.SizeDiffKB -gt 0){'+'}else{''})$($mod.SizeDiffKB) KB)" -ForegroundColor Yellow
                }
            }
        }
        if ($mod.ZoneId) { Write-Host "  Downloaded from: $($mod.DownloadSource)" -ForegroundColor $(if($mod.IsModrinthDownload){"Green"}else{"Yellow"}) }
        Write-Host ""
    }
}

if ($tamperedMods.Count -gt 0) {
    Write-Host "{ Potentially Tampered Mods }" -ForegroundColor Red
    Write-Host "Total: $($tamperedMods.Count) ⚠ WARNING"; Write-Host
    foreach ($mod in $tamperedMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Magenta
        Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Actual: $($mod.ActualSizeKB) KB | Difference: $(if($mod.SizeDiffKB -gt 0){'+'}else{''})$($mod.SizeDiffKB) KB" -ForegroundColor Magenta
        Write-Host "  ⚠ File size differs significantly from Modrinth version!" -ForegroundColor Red
        if ($mod.ModrinthUrl) { Write-Host "  Verify: $($mod.ModrinthUrl)" -ForegroundColor DarkGray }
        Write-Host ""
    }
}

if ($cheatMods.Count -gt 0) {
    Write-Host "{ Cheat Mods Detected }" -ForegroundColor Red
    Write-Host "Total: $($cheatMods.Count) ⚠ WARNING"; Write-Host
    foreach ($mod in $cheatMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        if ($mod.ModName) { Write-Host "  Mod: $($mod.ModName)" -ForegroundColor Gray }
        Write-Host "  Cheat Strings: $($mod.StringsFound)" -ForegroundColor Magenta
        Write-Host "  Size: $($mod.FileSizeKB) KB" -ForegroundColor Gray
        if ($mod.ExpectedSizeKB -gt 0) {
            if ($mod.SizeDiffKB -eq 0) {
                Write-Host "  Size matches Modrinth: $($mod.ExpectedSizeKB) KB ✓" -ForegroundColor Green
            } else {
                Write-Host "  Expected: $($mod.ExpectedSizeKB) KB | Difference: $(if($mod.SizeDiffKB -gt 0){'+'}else{''})$($mod.SizeDiffKB) KB" -ForegroundColor Yellow
                if ([math]::Abs($mod.SizeDiffKB) -gt 1) { Write-Host "  ⚠ Size mismatch detected! Could be tampered with cheat code." -ForegroundColor Red }
            }
        } else {
            Write-Host "  Note: No Modrinth size data available for comparison" -ForegroundColor DarkGray
        }
        if ($mod.DownloadSource -ne "Unknown") { Write-Host "  Source: $($mod.DownloadSource)" -ForegroundColor Yellow }
        if ($mod.IsVerifiedMod) {
            Write-Host "  ⚠ Legitimate mod contains cheat code!" -ForegroundColor Red
            Write-Host "  ⚠ This appears to be a tampered version of a legitimate mod" -ForegroundColor Red
        }
        Write-Host ""
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
