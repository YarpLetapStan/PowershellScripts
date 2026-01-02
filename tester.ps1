Clear-Host
Write-Host "YarpLetapStan Mod Analyzer" -ForegroundColor Magenta
Write-Host "Made by " -ForegroundColor DarkGray -NoNewline
Write-Host "YarpLetapStan"
Write-Host

Write-Host "Enter path to the mods folder: " -NoNewline
$mods = Read-Host
Write-Host

if (-not $mods) {
    Write-Host "No path provided!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    exit 1
}

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
	$ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
	if ($ads -match "HostUrl=(.+)") {
		return $matches[1]
	}
	
	return $null
}

function Fetch-Modrinth-By-Filename {
    param (
        [string]$filename
    )
    try {
        # Try to extract mod slug and version from filename
        # Common patterns: modname-version.jar, modname-mc.version-modversion.jar
        if ($filename -match '^([a-zA-Z0-9\-]+?)(?:-fabric|-forge|-mc\.[\d\.]+)?-([\d\.]+(?:\+mc[\d\.]+)?)[^\/]*\.jar
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
		if ($response.project_id) {
            $projectResponse = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectResponse -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ 
                Name = $projectData.title
                Slug = $projectData.slug
                ExpectedSize = $response.files[0].size
                VersionNumber = $response.version_number
                VersionName = $response.name
            }
        }
    } catch {}
	
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; VersionName = "" }
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
	"autocrystal",
	"auto crystal",
	"cw crystal",
	"autohitcrystal",
	"autoanchor",
	"auto anchor",
	"anchortweaks",
	"anchor macro",
	"autototem",
	"auto totem",
	"legittotem",
	"inventorytotem",
	"hover totem",
	"autopot",
	"auto pot",
	"velocity",
	"autodoublehand",
	"auto double hand",
	"autoarmor",
	"auto armor",
	"automace",
	"aimassist",
	"aim assist",
	"triggerbot",
	"trigger bot",
	"shieldbreaker",
	"shield breaker",
	"axespam",
	"axe spam",
	"pingspoof",
	"ping spoof",
	"webmacro",
	"web macro",
	"selfdestruct",
	"self destruct",
	"hitboxes"
)

function Check-Strings {
	param (
        [string]$filePath
    )
	
	$stringsFound = [System.Collections.Generic.HashSet[string]]::new()
	
	$fileContent = Get-Content -Raw $filePath
	
	foreach ($line in $fileContent) {
		foreach ($string in $cheatStrings) {
			if ($line -match $string) {
				$stringsFound.Add($string) | Out-Null
				continue
			}
		}
	}
	
	return $stringsFound
}


$verifiedMods = @()
$unknownMods = @()
$cheatMods = @()
$modifiedMods = @()
$sizeModifiedMods = @()
$unknownSizeMismatch = @()

$jarFiles = Get-ChildItem -Path $mods -Filter *.jar

$spinner = @("|", "/", "-", "\")
$totalMods = $jarFiles.Count
$counter = 0

foreach ($file in $jarFiles) {
	$counter++
	$spin = $spinner[$counter % $spinner.Length]
	Write-Host "`r[$spin] Scanning mods: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
	
	# Check if file was modified after javaw started
	if ($process -and $startTime -and $file.LastWriteTime -gt $startTime) {
		$modifiedMods += [PSCustomObject]@{ FileName = $file.Name; ModifiedTime = $file.LastWriteTime }
	}
	
	$hash = Get-SHA1 -filePath $file.FullName
	
    $modDataModrinth = Fetch-Modrinth -hash $hash
    if ($modDataModrinth.Slug) {
		# Check if file size matches expected size from Modrinth
		$actualSize = $file.Length
		$expectedSize = $modDataModrinth.ExpectedSize
		
		if ($expectedSize -gt 0 -and $actualSize -ne $expectedSize) {
			$sizeDiff = $actualSize - $expectedSize
			$sizeModifiedMods += [PSCustomObject]@{
				ModName = $modDataModrinth.Name
				FileName = $file.Name
				Version = $modDataModrinth.VersionName
				ExpectedSize = $expectedSize
				ActualSize = $actualSize
				SizeDiff = $sizeDiff
			}
		}
		
		$verifiedMods += [PSCustomObject]@{ 
			ModName = $modDataModrinth.Name
			FileName = $file.Name
			Version = $modDataModrinth.VersionName
			ExpectedSize = $expectedSize
		}
		continue;
    }
	
	$modDataMegabase = Fetch-Megabase -hash $hash
	if ($modDataMegabase.name) {
		$verifiedMods += [PSCustomObject]@{ 
			ModName = $modDataMegabase.Name
			FileName = $file.Name
			Version = "Unknown"
			ExpectedSize = 0
		}
		continue;
	}
	
	$zoneId = Get-ZoneIdentifier $file.FullName
	$unknownMods += [PSCustomObject]@{ FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneId; FileSize = $file.Length }
}

if ($unknownMods.Count -gt 0) {
	$tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"
	
	$counter = 0
	
	try {
		if (Test-Path $tempDir) {
			Remove-Item -Recurse -Force $tempDir
		}
		
		New-Item -ItemType Directory -Path $tempDir | Out-Null
		Add-Type -AssemblyName System.IO.Compression.FileSystem
	
		foreach ($mod in $unknownMods) {
			$counter++
			$spin = $spinner[$counter % $spinner.Length]
			Write-Host "`r[$spin] Scanning unknown mods for cheat strings..." -ForegroundColor Magenta -NoNewline
			
			$modStrings = Check-Strings $mod.FilePath
			if ($modStrings.Count -gt 0) {
				$unknownMods = @($unknownMods | Where-Object -FilterScript {$_ -ne $mod})
				$cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; StringsFound = $modStrings; FileSize = $mod.FileSize }
				continue
			}
			
			$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($mod.FileName)
			$extractPath = Join-Path $tempDir $fileNameWithoutExt
			New-Item -ItemType Directory -Path $extractPath | Out-Null
			
			[System.IO.Compression.ZipFile]::ExtractToDirectory($mod.FilePath, $extractPath)
			
			$depJarsPath = Join-Path $extractPath "META-INF/jars"
			if (-not $(Test-Path $depJarsPath)) {
				continue
			}
			
			$depJars = Get-ChildItem -Path $depJarsPath
			foreach ($jar in $depJars) {
				$depStrings = Check-Strings $jar.FullName
				if (-not $depStrings) {
					continue
				}
				$unknownMods = @($unknownMods | Where-Object -FilterScript {$_ -ne $mod})
				$cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; DepFileName = $jar.Name; StringsFound = $depStrings; FileSize = $mod.FileSize }
			}
			
		}
	} catch {
		Write-Host "Error occured while scanning jar files! $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Remove-Item -Recurse -Force $tempDir
	}
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# For unknown mods, try to check file size by filename
if ($unknownMods.Count -gt 0) {
	$counter = 0
	foreach ($mod in $unknownMods) {
		$counter++
		$spin = $spinner[$counter % $spinner.Length]
		Write-Host "`r[$spin] Checking unknown mod sizes by filename..." -ForegroundColor Magenta -NoNewline
		
		$filenameCheck = Fetch-Modrinth-By-Filename -filename $mod.FileName
		if ($filenameCheck.Found -and $filenameCheck.ExpectedSize -gt 0) {
			if ($mod.FileSize -ne $filenameCheck.ExpectedSize) {
				$sizeDiff = $mod.FileSize - $filenameCheck.ExpectedSize
				$unknownSizeMismatch += [PSCustomObject]@{
					ModName = $filenameCheck.ModName
					FileName = $mod.FileName
					Version = $filenameCheck.Version
					ExpectedSize = $filenameCheck.ExpectedSize
					ActualSize = $mod.FileSize
					SizeDiff = $sizeDiff
					ZoneId = $mod.ZoneId
				}
			}
		}
	}
	Write-Host "`r$(' ' * 80)`r" -NoNewline
}

if ($verifiedMods.Count -gt 0) {
	Write-Host "{ Verified Mods }" -ForegroundColor Cyan
	foreach ($mod in $verifiedMods) {
		Write-Host ("> {0, -30}" -f $mod.ModName) -ForegroundColor Green -NoNewline
		Write-Host "$($mod.FileName)" -ForegroundColor Gray -NoNewline
		if ($mod.Version -and $mod.Version -ne "Unknown") {
			Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray -NoNewline
		}
		if ($mod.ExpectedSize -and $mod.ExpectedSize -gt 0) {
			Write-Host " ($([math]::Round($mod.ExpectedSize/1KB, 2)) KB)" -ForegroundColor DarkGray
		} else {
			Write-Host ""
		}
	}
	Write-Host
}

if ($unknownMods.Count -gt 0) {
	Write-Host "{ Unknown Mods }" -ForegroundColor Cyan
	foreach ($mod in $unknownMods) {
		if ($mod.ZoneId) {
			Write-Host ("> {0, -30}" -f $mod.FileName) -ForegroundColor Yellow -NoNewline
			Write-Host "$($mod.ZoneId)" -ForegroundColor DarkGray -NoNewline
			Write-Host " ($([math]::Round($mod.FileSize/1KB, 2)) KB)" -ForegroundColor DarkGray
			continue
		}
		Write-Host "> $($mod.FileName)" -ForegroundColor Yellow -NoNewline
		Write-Host " ($([math]::Round($mod.FileSize/1KB, 2)) KB)" -ForegroundColor DarkGray
	}
	Write-Host
}

if ($cheatMods.Count -gt 0) {
	Write-Host "{ Cheat Mods }" -ForegroundColor Cyan
	foreach ($mod in $cheatMods) {
		Write-Host "> $($mod.FileName)" -ForegroundColor Red -NoNewline
		if ($mod.DepFileName) {
			Write-Host " ->" -ForegroundColor Gray -NoNewline
			Write-Host " $($mod.DepFileName)" -ForegroundColor Red -NoNewline
		}
		Write-Host " [$($mod.StringsFound)]" -ForegroundColor Magenta -NoNewline
		Write-Host " ($([math]::Round($mod.FileSize/1KB, 2)) KB)" -ForegroundColor DarkGray
	}
	Write-Host
}

if ($modifiedMods.Count -gt 0) {
	Write-Host "{ Modified After Javaw Started }" -ForegroundColor Cyan
	foreach ($mod in $modifiedMods) {
		Write-Host "> $($mod.FileName)" -ForegroundColor Red -NoNewline
		Write-Host " (Modified: $($mod.ModifiedTime))" -ForegroundColor DarkGray
	}
	Write-Host
}

if ($sizeModifiedMods.Count -gt 0) {
	Write-Host "{ File Size Mismatch (Modified Files) }" -ForegroundColor Cyan
	foreach ($mod in $sizeModifiedMods) {
		$sizeChangeText = if ($mod.SizeDiff -gt 0) { "+$($mod.SizeDiff) bytes" } else { "$($mod.SizeDiff) bytes" }
		Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline
		Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray
		Write-Host "  File: $($mod.FileName)" -ForegroundColor Yellow
		Write-Host "  Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $sizeChangeText" -ForegroundColor Magenta
	}
	Write-Host
}

if ($unknownSizeMismatch.Count -gt 0) {
	Write-Host "{ Unknown Mods - Size Mismatch }" -ForegroundColor Cyan
	foreach ($mod in $unknownSizeMismatch) {
		$sizeChangeText = if ($mod.SizeDiff -gt 0) { "+$($mod.SizeDiff) bytes" } else { "$($mod.SizeDiff) bytes" }
		Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline
		Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray
		Write-Host "  File: $($mod.FileName)" -ForegroundColor Yellow
		Write-Host "  Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $sizeChangeText" -ForegroundColor Magenta
		if ($mod.ZoneId) {
			Write-Host "  Source: $($mod.ZoneId)" -ForegroundColor DarkGray
		}
	}
	Write-Host
}) {
            $modSlug = $matches[1].ToLower()
            $versionString = $matches[2]
            
            # Search Modrinth for the mod
            $searchResponse = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$modSlug" -Method Get -UseBasicParsing -ErrorAction Stop
            
            if ($searchResponse.id) {
                # Get all versions for this project
                $versionsResponse = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($searchResponse.id)/version" -Method Get -UseBasicParsing -ErrorAction Stop
                
                # Try to find matching version
                foreach ($version in $versionsResponse) {
                    if ($version.files -and $version.files.Count -gt 0) {
                        $versionFile = $version.files[0]
                        if ($versionFile.filename -eq $filename) {
                            return @{
                                Found = $true
                                ModName = $searchResponse.title
                                Version = $version.name
                                ExpectedSize = $versionFile.size
                                FileName = $versionFile.filename
                            }
                        }
                    }
                }
            }
        }
    } catch {}
    
    return @{ Found = $false; ModName = ""; Version = ""; ExpectedSize = 0; FileName = "" }
}
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
		if ($response.project_id) {
            $projectResponse = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectResponse -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ 
                Name = $projectData.title
                Slug = $projectData.slug
                ExpectedSize = $response.files[0].size
                VersionNumber = $response.version_number
                VersionName = $response.name
            }
        }
    } catch {}
	
    return @{ Name = ""; Slug = ""; ExpectedSize = 0; VersionNumber = ""; VersionName = "" }
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
	"autocrystal",
	"auto crystal",
	"cw crystal",
	"autohitcrystal",
	"autoanchor",
	"auto anchor",
	"anchortweaks",
	"anchor macro",
	"autototem",
	"auto totem",
	"legittotem",
	"inventorytotem",
	"hover totem",
	"autopot",
	"auto pot",
	"velocity",
	"autodoublehand",
	"auto double hand",
	"autoarmor",
	"auto armor",
	"automace",
	"aimassist",
	"aim assist",
	"triggerbot",
	"trigger bot",
	"shieldbreaker",
	"shield breaker",
	"axespam",
	"axe spam",
	"pingspoof",
	"ping spoof",
	"webmacro",
	"web macro",
	"selfdestruct",
	"self destruct",
	"hitboxes"
)

function Check-Strings {
	param (
        [string]$filePath
    )
	
	$stringsFound = [System.Collections.Generic.HashSet[string]]::new()
	
	$fileContent = Get-Content -Raw $filePath
	
	foreach ($line in $fileContent) {
		foreach ($string in $cheatStrings) {
			if ($line -match $string) {
				$stringsFound.Add($string) | Out-Null
				continue
			}
		}
	}
	
	return $stringsFound
}


$verifiedMods = @()
$unknownMods = @()
$cheatMods = @()
$modifiedMods = @()
$sizeModifiedMods = @()

$jarFiles = Get-ChildItem -Path $mods -Filter *.jar

$spinner = @("|", "/", "-", "\")
$totalMods = $jarFiles.Count
$counter = 0

foreach ($file in $jarFiles) {
	$counter++
	$spin = $spinner[$counter % $spinner.Length]
	Write-Host "`r[$spin] Scanning mods: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
	
	# Check if file was modified after javaw started
	if ($process -and $startTime -and $file.LastWriteTime -gt $startTime) {
		$modifiedMods += [PSCustomObject]@{ FileName = $file.Name; ModifiedTime = $file.LastWriteTime }
	}
	
	$hash = Get-SHA1 -filePath $file.FullName
	
    $modDataModrinth = Fetch-Modrinth -hash $hash
    if ($modDataModrinth.Slug) {
		# Check if file size matches expected size from Modrinth
		$actualSize = $file.Length
		$expectedSize = $modDataModrinth.ExpectedSize
		
		if ($expectedSize -gt 0 -and $actualSize -ne $expectedSize) {
			$sizeDiff = $actualSize - $expectedSize
			$sizeModifiedMods += [PSCustomObject]@{
				ModName = $modDataModrinth.Name
				FileName = $file.Name
				Version = $modDataModrinth.VersionName
				ExpectedSize = $expectedSize
				ActualSize = $actualSize
				SizeDiff = $sizeDiff
			}
		}
		
		$verifiedMods += [PSCustomObject]@{ 
			ModName = $modDataModrinth.Name
			FileName = $file.Name
			Version = $modDataModrinth.VersionName
			ExpectedSize = $expectedSize
		}
		continue;
    }
	
	$modDataMegabase = Fetch-Megabase -hash $hash
	if ($modDataMegabase.name) {
		$verifiedMods += [PSCustomObject]@{ 
			ModName = $modDataMegabase.Name
			FileName = $file.Name
			Version = "Unknown"
			ExpectedSize = 0
		}
		continue;
	}
	
	$zoneId = Get-ZoneIdentifier $file.FullName
	$unknownMods += [PSCustomObject]@{ FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneId; FileSize = $file.Length }
}

if ($unknownMods.Count -gt 0) {
	$tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"
	
	$counter = 0
	
	try {
		if (Test-Path $tempDir) {
			Remove-Item -Recurse -Force $tempDir
		}
		
		New-Item -ItemType Directory -Path $tempDir | Out-Null
		Add-Type -AssemblyName System.IO.Compression.FileSystem
	
		foreach ($mod in $unknownMods) {
			$counter++
			$spin = $spinner[$counter % $spinner.Length]
			Write-Host "`r[$spin] Scanning unknown mods for cheat strings..." -ForegroundColor Magenta -NoNewline
			
			$modStrings = Check-Strings $mod.FilePath
			if ($modStrings.Count -gt 0) {
				$unknownMods = @($unknownMods | Where-Object -FilterScript {$_ -ne $mod})
				$cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; StringsFound = $modStrings; FileSize = $mod.FileSize }
				continue
			}
			
			$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($mod.FileName)
			$extractPath = Join-Path $tempDir $fileNameWithoutExt
			New-Item -ItemType Directory -Path $extractPath | Out-Null
			
			[System.IO.Compression.ZipFile]::ExtractToDirectory($mod.FilePath, $extractPath)
			
			$depJarsPath = Join-Path $extractPath "META-INF/jars"
			if (-not $(Test-Path $depJarsPath)) {
				continue
			}
			
			$depJars = Get-ChildItem -Path $depJarsPath
			foreach ($jar in $depJars) {
				$depStrings = Check-Strings $jar.FullName
				if (-not $depStrings) {
					continue
				}
				$unknownMods = @($unknownMods | Where-Object -FilterScript {$_ -ne $mod})
				$cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; DepFileName = $jar.Name; StringsFound = $depStrings; FileSize = $mod.FileSize }
			}
			
		}
	} catch {
		Write-Host "Error occured while scanning jar files! $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Remove-Item -Recurse -Force $tempDir
	}
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

if ($verifiedMods.Count -gt 0) {
	Write-Host "{ Verified Mods }" -ForegroundColor Cyan
	foreach ($mod in $verifiedMods) {
		Write-Host ("> {0, -30}" -f $mod.ModName) -ForegroundColor Green -NoNewline
		Write-Host "$($mod.FileName)" -ForegroundColor Gray -NoNewline
		if ($mod.Version -and $mod.Version -ne "Unknown") {
			Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray -NoNewline
		}
		if ($mod.ExpectedSize -and $mod.ExpectedSize -gt 0) {
			Write-Host " ($([math]::Round($mod.ExpectedSize/1KB, 2)) KB)" -ForegroundColor DarkGray
		} else {
			Write-Host ""
		}
	}
	Write-Host
}

if ($unknownMods.Count -gt 0) {
	Write-Host "{ Unknown Mods }" -ForegroundColor Cyan
	foreach ($mod in $unknownMods) {
		if ($mod.ZoneId) {
			Write-Host ("> {0, -30}" -f $mod.FileName) -ForegroundColor Yellow -NoNewline
			Write-Host "$($mod.ZoneId)" -ForegroundColor DarkGray -NoNewline
			Write-Host " ($([math]::Round($mod.FileSize/1KB, 2)) KB)" -ForegroundColor DarkGray
			continue
		}
		Write-Host "> $($mod.FileName)" -ForegroundColor Yellow -NoNewline
		Write-Host " ($([math]::Round($mod.FileSize/1KB, 2)) KB)" -ForegroundColor DarkGray
	}
	Write-Host
}

if ($cheatMods.Count -gt 0) {
	Write-Host "{ Cheat Mods }" -ForegroundColor Cyan
	foreach ($mod in $cheatMods) {
		Write-Host "> $($mod.FileName)" -ForegroundColor Red -NoNewline
		if ($mod.DepFileName) {
			Write-Host " ->" -ForegroundColor Gray -NoNewline
			Write-Host " $($mod.DepFileName)" -ForegroundColor Red -NoNewline
		}
		Write-Host " [$($mod.StringsFound)]" -ForegroundColor Magenta -NoNewline
		Write-Host " ($([math]::Round($mod.FileSize/1KB, 2)) KB)" -ForegroundColor DarkGray
	}
	Write-Host
}

if ($modifiedMods.Count -gt 0) {
	Write-Host "{ Modified After Javaw Started }" -ForegroundColor Cyan
	foreach ($mod in $modifiedMods) {
		Write-Host "> $($mod.FileName)" -ForegroundColor Red -NoNewline
		Write-Host " (Modified: $($mod.ModifiedTime))" -ForegroundColor DarkGray
	}
	Write-Host
}

if ($sizeModifiedMods.Count -gt 0) {
	Write-Host "{ File Size Mismatch (Modified Files) }" -ForegroundColor Cyan
	foreach ($mod in $sizeModifiedMods) {
		$sizeChangeText = if ($mod.SizeDiff -gt 0) { "+$($mod.SizeDiff) bytes" } else { "$($mod.SizeDiff) bytes" }
		Write-Host "> $($mod.ModName)" -ForegroundColor Red -NoNewline
		Write-Host " [$($mod.Version)]" -ForegroundColor DarkGray
		Write-Host "  File: $($mod.FileName)" -ForegroundColor Yellow
		Write-Host "  Expected: $([math]::Round($mod.ExpectedSize/1KB, 2)) KB | Actual: $([math]::Round($mod.ActualSize/1KB, 2)) KB | Difference: $sizeChangeText" -ForegroundColor Magenta
	}
	Write-Host
}
