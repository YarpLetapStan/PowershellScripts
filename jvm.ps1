[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Clear-Host
Write-Host "Made by YarpLetapStan`nDm YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan

$asciiTitle = @"
██╗   ██╗ █████╗ ██████╗ ██████╗ ██╗     ███████╗████████╗ █████╗ ██████╗ ███████╗████████╗ █████╗ ███╗   ██╗ ╗███████╗
╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗██║     ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔══██╗████╗  ██║╔╝██╔════╝
 ╚████╔╝ ███████║██████╔╝██████╔╝██║     █████╗     ██║   ███████║██████╔╝███████╗   ██║   ███████║██╔██╗ ██║  ███████╗
  ╚██╔╝  ██╔══██║██╔══██╗██╔═══╝ ██║     ██╔══╝     ██║   ██╔══██║██╔═══╝ ╚════██║   ██║   ██╔══██║██║╚██╗██║  ╚════██║
   ██║   ██║  ██║██║  ██║██║     ███████╗███████╗   ██║   ██║  ██║██║     ███████║   ██║   ██║  ██║██║ ╚████║  ███████║
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝

███╗   ███╗ ██████╗ ██████╗      █████╗ ███╗   ██╗ █████╗ ██╗    ██╗   ██╗███████╗███████╗██████╗ 
████╗ ████║██╔═══██╗██╔══██╗    ██╔══██╗████╗  ██║██╔══██╗██║    ╚██╗ ██╔╝╚══███╔╝██╔════╝██╔══██╗
██╔████╔██║██║   ██║██║  ██║    ███████║██╔██╗ ██║███████║██║     ╚████╔╝   ███╔╝ █████╗  ██████╔╝
██║╚██╔╝██║██║   ██║██║  ██║    ██╔══██║██║╚██╗██║██╔══██║██║      ╚██╔╝   ███╔╝  ██╔══╝  ██╔══██╗
██║ ╚═╝ ██║╚██████╔╝██████╔╝    ██║  ██║██║ ╚████║██║  ██║███████╗  ██║   ███████╗███████╗██║  ██║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝  ╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝
"@

Write-Host $asciiTitle -ForegroundColor Blue
Write-Host ""

# Create subtitle line style with double solid lines
$subtitleText = "YarpLetapStan's Mod Analyzer V6.0"
$lineWidth = 100
$line = "━" * $lineWidth

Write-Host $subtitleText.PadLeft(($lineWidth + $subtitleText.Length) / 2) -ForegroundColor Cyan
Write-Host $line -ForegroundColor cyan
Write-Host ""

# Get mods folder path
Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray
$mods = Read-Host "PATH"
Write-Host

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host "Using default path: $mods`n" -ForegroundColor White
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    exit 1
}

# Check Minecraft uptime - KEPT ORIGINAL FORMAT
$process = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $process) { $process = Get-Process java -ErrorAction SilentlyContinue }

if ($process) {
    try {
        $elapsedTime = (Get-Date) - $process.StartTime
        Write-Host "Minecraft Uptime: $($process.Name) PID $($process.Id) started at $($process.StartTime) and running for $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s`n" -ForegroundColor Cyan
    } catch {}
}

# ==================== Enhanced Fabric/JVM Arguments Injection Detector ====================
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "JVM ARGUMENTS INJECTION SCANNER" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

# Find all javaw.exe processes
$javaProcesses = Get-Process -Name javaw -ErrorAction SilentlyContinue

if ($javaProcesses.Count -eq 0) {
    Write-Host "  [!] No javaw.exe processes found" -ForegroundColor Yellow
    Write-Host "  [i] Make sure Minecraft is running" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "  [i] Scanning $($javaProcesses.Count) Java process(es)..." -ForegroundColor White
    Write-Host ""

    $foundInjection = $false
    $injectionCount = 0

    # Comprehensive Fabric/JVM injection patterns
    $fabricPatterns = @{
        # ===== FABRIC SPECIFIC INJECTION =====
        "fabric.addMods" = '-Dfabric\.addMods='
        "fabric.loadMods" = '-Dfabric\.loadMods='
        "fabric.classPathGroups" = '-Dfabric\.classPathGroups='
        "fabric.gameJarPath" = '-Dfabric\.gameJarPath='
        "fabric.skipMcProvider" = '-Dfabric\.skipMcProvider='
        "fabric.development" = '-Dfabric\.development='
        "fabric.allowUnsupportedVersion" = '-Dfabric\.allowUnsupportedVersion='
        
        # Classpath manipulation
        "fabric.remapClasspathFile" = '-Dfabric\.remapClasspathFile='
        "fabric.skipIntermediary" = '-Dfabric\.skipIntermediary='
        
        # Configuration directories
        "fabric.configDir" = '-Dfabric\.configDir='
        "fabric.loader.config" = '-Dfabric\.loader\.config='
        
        # Debug/development
        "fabric.log.level" = '-Dfabric\.log\.level='
        "fabric.debug.dumpClasspath" = '-Dfabric\.debug\.dumpClasspath='
        "fabric.log.config" = '-Dfabric\.log\.config='
        "fabric.dli.config" = '-Dfabric\.dli\.config='
        
        # Mixin/transformation
        "fabric.mixin.configs" = '-Dfabric\.mixin\.configs='
        "fabric.mixin.hotSwap" = '-Dfabric\.mixin\.hotSwap='
        "fabric.mixin.debug.export" = '-Dfabric\.mixin\.debug\.export='
        "fabric.mixin.debug.verbose" = '-Dfabric\.mixin\.debug\.verbose='
        
        # Game/version
        "fabric.gameVersion" = '-Dfabric\.gameVersion='
        "fabric.forceVersion" = '-Dfabric\.forceVersion='
        "fabric.autoDetectVersion" = '-Dfabric\.autoDetectVersion='
        
        # Launcher/brand
        "fabric.launcher.name" = '-Dfabric\.launcher\.name='
        "fabric.launcher.brand" = '-Dfabric\.launcher\.brand='
        
        # Mod metadata
        "fabric.mods.toml.path" = '-Dfabric\.mods\.toml\.path='
        "fabric.customModList" = '-Dfabric\.customModList='
        
        # Dependency resolution
        "fabric.resolve.modFiles" = '-Dfabric\.resolve\.modFiles='
        "fabric.skipDependencyResolution" = '-Dfabric\.skipDependencyResolution='
        
        # Entrypoints/providers
        "fabric.loader.entrypoints" = '-Dfabric\.loader\.entrypoints='
        "fabric.language.providers" = '-Dfabric\.language\.providers='
        
        # ===== FORGE SPECIFIC INJECTION =====
        "forge.addMods" = '-Dforge\.addMods='
        "forge.mods" = '-Dforge\.mods='
        "fml.coreMods.load" = '-Dfml\.coreMods\.load='
        "forge.coreMods.dir" = '-Dforge\.coreMods\.dir='
        "forge.modDir" = '-Dforge\.modDir='
        "forge.modsDirectories" = '-Dforge\.modsDirectories='
        "fml.customModList" = '-Dfml\.customModList='
        "forge.disableModScan" = '-Dforge\.disableModScan='
        "forge.modList" = '-Dforge\.modList='
        "forge.forceVersion" = '-Dforge\.forceVersion='
        "forge.disableUpdateCheck" = '-Dforge\.disableUpdateCheck='
        "forge.logging.mojang.level" = '-Dforge\.logging\.mojang\.level='
        "forge.mixin.hotSwap" = '-Dforge\.mixin\.hotSwap='
        "forge.resourcePack" = '-Dforge\.resourcePack='
        "forge.defaultResourcePack" = '-Dforge\.defaultResourcePack='
        "forge.texturePacks" = '-Dforge\.texturePacks='
        "forge.assetIndex" = '-Dforge\.assetIndex='
        "forge.assetsDir" = '-Dforge\.assetsDir='
        
        # ===== SECURITY BYPASS =====
        "javaSecurityManager" = '-Djava\.security\.manager='
        "javaSecurityPolicy" = '-Djava\.security\.policy='
        
        # ===== CLASSPATH MANIPULATION =====
        "bootClasspath" = '-Xbootclasspath'
        "systemClassLoader" = '-Djava\.system\.class\.loader='
        "javaClassPath" = '-Djava\.class\.path='
        "cp" = '-cp\s+["''][^"'';]*\.jar'
        
        # ===== CHEAT CLIENT SIGNATURES =====
        "cheatClientBrand" = '-D(client|launcher)\.brand=(Wurst|Aristois|Impact|Kilo|Future|Lambda|Rusher|Konas|Phobos|Salhack|ForgeHax|Mathax|Meteor|Async|Seppuku|Xatz|Wolfram|Huzuni|Jigsaw|Zamorozka|Moon|Rage|Exhibition|Virtue|Novoline|Rekt|Skid|Ares|Abyss|Thunder|Tenacity|Rise|Flux|Gamesense|Intent|Remix|Sight|Vape|Shield|Ghost|Crispy|Inertia)'
        
        # ===== OPTIFINE/SHADERS =====
        "optifine" = '-Doptifine\.'
        "shadersmod" = '-Dshaders?\.'
        "shaderPack" = '-Dshader[sP]ack='
        
        # ===== CHEAT MOD PATTERNS =====
        "cheatPattern" = '-D(xray|fly|speed|killaura|reach|esp|wallhack|noclip|autoclick|aimbot|triggerbot|antiknockback|nofall|timer|step|fullbright|nightvision|cavefinder)\.'
    }

    foreach ($proc in $javaProcesses) {
        $processInjectionFound = $false
        
        try {
            $wmiProcess = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction Stop
            $commandLine = $wmiProcess.CommandLine
            
            if ($commandLine) {
                Write-Host "  ┌─ Process: PID $($proc.Id) - $($proc.ProcessName)" -ForegroundColor Green
                
                # Skip checking the executable path itself
                if ($commandLine -match '^"([^"]+)"') {
                    $exePath = $matches[1]
                    $commandLine = $commandLine.Substring($exePath.Length + 2).Trim()
                }
                
                # Check all patterns
                $detectedPatterns = @()
                $suspiciousArgs = @()
                
                foreach ($patternName in $fabricPatterns.Keys) {
                    $regexPattern = $fabricPatterns[$patternName]
                    if ($commandLine -match $regexPattern) {
                        # Skip legitimate Java module opens
                        if ($patternName -eq "addOpens" -or $patternName -eq "addExports") {
                            continue
                        }
                        
                        $detectedPatterns += $patternName
                        
                        # Extract the suspicious argument
                        $argLines = $commandLine -split '\s+'
                        foreach ($arg in $argLines) {
                            if ($arg -match $regexPattern) {
                                $suspiciousArgs += $arg
                            }
                        }
                        $processInjectionFound = $true
                    }
                }
                
                # Check for cheat client names
                $cheatClients = @('Wurst', 'Aristois', 'Impact', 'Kilo', 'Future', 'Lambda', 'Rusher', 'Konas', 'Phobos', 
                                 'Salhack', 'ForgeHax', 'Mathax', 'Meteor', 'Async', 'Seppuku', 'Xatz', 'Wolfram', 
                                 'Huzuni', 'Jigsaw', 'Zamorozka', 'Moon', 'Rage', 'Exhibition', 'Virtue', 'Novoline', 
                                 'Rekt', 'Skid', 'Ares', 'Abyss', 'Thunder', 'Tenacity', 'Rise', 'Flux', 'Gamesense', 
                                 'Intent', 'Remix', 'Sight', 'Vape', 'Shield', 'Ghost', 'Crispy', 'Inertia')
                
                foreach ($cheatClient in $cheatClients) {
                    if ($commandLine -match "(?i)\b$cheatClient\b") {
                        if ($detectedPatterns -notcontains "CheatClient-$cheatClient") {
                            $detectedPatterns += "CheatClient-$cheatClient"
                            $processInjectionFound = $true
                        }
                    }
                }
                
                # Check for encoded/suspicious command execution
                if ($commandLine -match '(%3B|%26%26|%7C%7C|%7C|%60|%24|%3C|%3E)') {
                    $detectedPatterns += "EncodedInjection"
                    $processInjectionFound = $true
                }
                
                if ($processInjectionFound -and $detectedPatterns.Count -gt 0) {
                    $foundInjection = $true
                    $injectionCount++
                    
                    Write-Host "  ├─ [✗] JVM INJECTION DETECTED" -ForegroundColor Red
                    Write-Host ""
                    
                    # Show detected patterns grouped by type
                    $groupedPatterns = @{}
                    foreach ($pattern in $detectedPatterns) {
                        if ($pattern -match "^(fabric|forge|javaSecurity|bootClasspath|systemClassLoader|javaClassPath|cp|cheatClient|optifine|shadersmod|shaderPack|cheatPattern|EncodedInjection)") {
                            $type = $matches[1]
                        } else {
                            $type = "other"
                        }
                        if (-not $groupedPatterns.ContainsKey($type)) {
                            $groupedPatterns[$type] = @()
                        }
                        $groupedPatterns[$type] += $pattern
                    }
                    
                    Write-Host "  │  Detected JVM Arguments:" -ForegroundColor Yellow
                    foreach ($arg in $suspiciousArgs | Select-Object -Unique) {
                        Write-Host "  │    • $arg" -ForegroundColor Magenta
                    }
                    Write-Host ""
                    
                    Write-Host "  │  Detected Pattern Categories:" -ForegroundColor Yellow
                    foreach ($type in $groupedPatterns.Keys | Sort-Object) {
                        $typeName = switch ($type) {
                            "fabric" { "Fabric Injection" }
                            "forge" { "Forge Injection" }
                            "javaSecurity" { "Security Bypass" }
                            "bootClasspath" { "Classpath Manipulation" }
                            "systemClassLoader" { "Class Loader" }
                            "javaClassPath" { "Class Path" }
                            "cp" { "Classpath (-cp)" }
                            "cheatClient" { "Cheat Client" }
                            "optifine" { "Optifine/Shaders" }
                            "shadersmod" { "Shader Mod" }
                            "shaderPack" { "Shader Pack" }
                            "cheatPattern" { "Cheat Pattern" }
                            "EncodedInjection" { "Encoded Injection" }
                            default { "Other" }
                        }
                        Write-Host "  │    └─ $typeName" -ForegroundColor White
                        foreach ($pattern in $groupedPatterns[$type]) {
                            $displayPattern = $pattern -replace 'CheatClient-', ''
                            Write-Host "  │        • $displayPattern" -ForegroundColor Red
                        }
                    }
                    Write-Host ""
                    
                    Write-Host "  └─ ⚠ WARNING: Potential cheat client or mod injection detected!" -ForegroundColor Red
                    Write-Host ""
                } else {
                    Write-Host "  └─ [✓] No JVM injection patterns detected" -ForegroundColor Green
                    Write-Host ""
                }
            }
        } catch {
            Write-Host "  └─ [!] Warning: Could not retrieve command line for PID $($proc.Id)" -ForegroundColor DarkYellow
            Write-Host "      [i] Run as Administrator for complete detection." -ForegroundColor DarkYellow
            Write-Host ""
        }
    }

    if (-not $foundInjection) {
        Write-Host "  [✓] CLEAN: No JVM argument injections detected in any Java process" -ForegroundColor Green
    }

    Write-Host ""
}
# ==================== End of Enhanced Fabric/JVM Arguments Scanner ====================

function Get-Minecraft-Version-From-Mods($modsFolder) {
    $minecraftVersions = @{}
    $jarFiles = Get-ChildItem -Path $modsFolder -Filter *.jar
    $modsScanned = 0
    
    Write-Host "Analyzing mods for Minecraft version..." -ForegroundColor Cyan
    
    foreach ($file in $jarFiles) {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
            
            # Check fabric.mod.json
            if ($fabricModJson = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1) {
                $reader = New-Object System.IO.StreamReader($fabricModJson.Open())
                $fabricData = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue
                $reader.Close()
                
                if ($fabricData.depends.minecraft) {
                    $mcVersionString = $fabricData.depends.minecraft
                    $extractedVersions = @()
                    
                    # Handle version ranges like ">=1.20 <=1.21.4"
                    if ($mcVersionString -match '>=\s*(\d+\.\d+(?:\.\d+)?).*<=\s*(\d+\.\d+(?:\.\d+)?)') {
                        # Range detected: use the upper bound as it's more specific
                        $extractedVersions += $matches[2]
                    }
                    # Handle single constraints like ">=1.20", "~1.21", "^1.20.1"
                    elseif ($mcVersionString -match '[><=~\^]+\s*(\d+\.\d+(?:\.\d+)?)') {
                        $extractedVersions += $matches[1]
                    }
                    # Handle exact version like "1.21.4"
                    elseif ($mcVersionString -match '^(\d+\.\d+(?:\.\d+)?)$') {
                        $extractedVersions += $matches[1]
                    }
                    # Fallback: extract any version number pattern
                    elseif ($mcVersionString -match '(\d+\.\d+(?:\.\d+)?)') {
                        $extractedVersions += $matches[1]
                    }
                    
                    # Add all found versions to the count
                    foreach ($ver in $extractedVersions) {
                        if ($ver -match '^\d+\.\d+(?:\.\d+)?$') {
                            if (-not $minecraftVersions.ContainsKey($ver)) {
                                $minecraftVersions[$ver] = 0
                            }
                            $minecraftVersions[$ver]++
                            $modsScanned++
                        }
                    }
                }
            }
            
            # Check mods.toml for Forge/NeoForge mods
            if ($modsToml = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' } | Select-Object -First 1) {
                $reader = New-Object System.IO.StreamReader($modsToml.Open())
                $tomlContent = $reader.ReadToEnd()
                $reader.Close()
                
                # Extract Minecraft version from mods.toml
                if ($tomlContent -match 'modId\s*=\s*"minecraft"[\s\S]{0,200}versionRange\s*=\s*"([^"]+)"') {
                    $versionRange = $matches[1]
                    
                    # Parse version range [1.20.1,1.21) or [1.20.1]
                    if ($versionRange -match '\[(\d+\.\d+(?:\.\d+)?),(\d+\.\d+(?:\.\d+)?)\)') {
                        # Use lower bound of range as it's the minimum required
                        $ver = $matches[1]
                        if (-not $minecraftVersions.ContainsKey($ver)) {
                            $minecraftVersions[$ver] = 0
                        }
                        $minecraftVersions[$ver]++
                        $modsScanned++
                    }
                    elseif ($versionRange -match '\[(\d+\.\d+(?:\.\d+)?)\]') {
                        # Exact version
                        $ver = $matches[1]
                        if (-not $minecraftVersions.ContainsKey($ver)) {
                            $minecraftVersions[$ver] = 0
                        }
                        $minecraftVersions[$ver]++
                        $modsScanned++
                    }
                    elseif ($versionRange -match '(\d+\.\d+(?:\.\d+)?)') {
                        # Fallback: extract any version
                        $ver = $matches[1]
                        if (-not $minecraftVersions.ContainsKey($ver)) {
                            $minecraftVersions[$ver] = 0
                        }
                        $minecraftVersions[$ver]++
                        $modsScanned++
                    }
                }
            }
            
            $zip.Dispose()
        } catch { 
            continue 
        }
    }
    
    if ($minecraftVersions.Count -gt 0) {
        # Sort by count (descending) and then by version number (descending) for ties
        $sortedVersions = $minecraftVersions.GetEnumerator() | Sort-Object -Property @{Expression={$_.Value}; Descending=$true}, @{Expression={$_.Key}; Descending=$true}
        $mostCommon = $sortedVersions | Select-Object -First 1
        
        Write-Host "Detected Minecraft version: $($mostCommon.Key) (from $($mostCommon.Value) out of $modsScanned mods)" -ForegroundColor Cyan
        
  
        
        return $mostCommon.Key
    }
    
    # Enhanced process detection with multiple patterns
    if ($process) {
        try {
            $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            
            # Try multiple patterns in order of reliability
            $patterns = @(
                'versions[/\\](\d+\.\d+(?:\.\d+)?)[/\\]',
                '-Dminecraft\.version=(\d+\.\d+(?:\.\d+)?)',
                '-Dfabric\.gameVersion=(\d+\.\d+(?:\.\d+)?)',
                '--version\s+(\d+\.\d+(?:\.\d+)?)',
                'net\.minecraft\.client\.main\.Main.*?(\d+\.\d+(?:\.\d+)?)'
            )
            
            foreach ($pattern in $patterns) {
                if ($cmdLine -match $pattern) {
                    $detectedVersion = $matches[1]
                    Write-Host "Detected Minecraft version from process: $detectedVersion" -ForegroundColor Cyan
                    return $detectedVersion
                }
            }
        } catch {
            Write-Host "Warning: Could not read process command line" -ForegroundColor DarkYellow
        }
    }
    
    Write-Host "Could not auto-detect Minecraft version from mods." -ForegroundColor Yellow
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
            $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
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
            $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
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
           $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
            $mixinData = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue
            $reader.Close()
            if ($mixinData.package -and -not $modInfo.ModId) {
                $packageParts = $mixinData.package -split '\.'
                if ($packageParts.Count -ge 2) { $modInfo.ModId = $packageParts[-2] }
            }
        }
        
        # Check for manifest
        if ($entry = $zip.Entries | Where-Object { $_.Name -eq 'MANIFEST.MF' } | Select-Object -First 1) {
           $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
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

$cheatStrings = @(
   "clickSimulation", "switchDelay", "switchChance", "placeChance", "glowstoneDelay", "glowstoneChance", "explodeDelay", "explodeChance", "explodeSlot", "antiWeakness", "damageTick", "breakChance", "breakDelay", 
   "stopOnCrystal", "processCrystal", "swapToWeapon", "isObsidianOrBedrock", "isValidCrystalPosition", "processAnchorPvP", "isValidAnchorPosition",

"AutoCrystal", "autocrystal", "auto crystal", "AutoHitCrystal", "autohitcrystal", "dontPlaceCrystal", "dontBreakCrystal", "canPlaceCrystalServer", "autoCrystalPlaceClock",
"AutoAnchor", "autoanchor", "auto anchor", "DoubleAnchor", "safe anchor", "safeanchor", "anchortweaks", "anchor macro", "hasGlowstone", "HasAnchor",

"AutoTotem", "autototem", "auto totem", "InventoryTotem", "inventorytotem", "HoverTotem", "hover totem", "legittotem",

"AutoPot", "autopot", "auto pot", "speedPotSlot", "strengthPotSlot",
"AutoArmor", "autoarmor", "auto armor", "preventSwordBlockBreaking", "preventSwordBlockAttack",

"AutoDoubleHand", "autodoublehand", "auto double hand", "AutoClicker",
"AimAssist", "aimassist", "aim assist", "triggerbot", "trigger bot",
"shieldbreaker", "shield breaker", "axespam", "axe spam",
"findKnockbackSword", "attackRegisteredThisClick",

"FakeLag", "pingspoof", "ping spoof", "freecam", "Freecam", "FakeInv",
"pushOutOfBlocks", "onPushOutOfBlocks",
"webmacro", "web macro", "JumpReset", "Donut",

"setBlockBreakingCooldown", "getBlockBreakingCooldown", "setItemUseCooldown",
"onBlockBreaking", "invokeDoAttack", "invokeDoItemUse",
"setSelectedSlot", "getSelectedSlot", "swapBackToOriginalSlot",
"blockBreakingCooldown", "invokeOnMouseButton",
"onSwapLastAttackedTicksReset", "getVisualAttackCooldownProgressPerTick",
"getHandSwingDuration", "onBeginRenderTick",
"PlayerMoveC2SPacketAccessor", "redirectSelectedSlot", "hookCancelBlockBreaking",

"EndCrystalItemMixin", "endcrystalitemmixin", "WalksyCrystalOptimizerMod",
"arrayOfString", "lvstrng", "dqrkis", "StringObfuscator", "POT_CHEATS",

"onShouldRenderBlockOutline", "predictCrystals", "noOffhandTotem", "getNearByCrystals",
"slotExplode", "needToPlaceRails", "findTotemSlot", "activateOnRightClick",
"crystalPlaceClock", "isDeadBodyNearby", "CrystalTwiceClock",
"mainHandStack", "attackInAir", "attackOnJump", "onDestruct",
"getGlowstoneChance", "isAutoCharge", "getPlaceChance", "getSwitchDelay",
"getGlowstoneDelay", "getExplodeDelay", "getExplodeSlotIndex",
"getPlaceDelayTicks", "getBreakDelayTicks", "getBreakChance",

"isSpawnersEnabled", "isShulkersEnabled", "onModuleDisabled",
"switchToBestTool", "switchToBestWeapon",
"isLootProtect", "getMinHunger", "isTracersEnabled",
"getSelectedBlocks", "isChestsEnabled",
"inventoryToMenuSlot", "throwPearl", "isLeftHoldOnly",

"Automatically switches to sword when hitting with totem",
"Failed to switch to mace after axe!",
"Breaking shield with axe...",
"selfdestruct", "self destruct",

"ＡｕｔｏＣｒｙｓｔａｌ", "Ａｕｔｏ Ｃｒｙｓｔａｌ", "ＡｕｔｏＨｉｔＣｒｙｓｔａｌ", "Ａ．ｕｔｏ Ｃｒｙｓｔａｌ", "Ａ．ｕｔｏＣｒｙｓｔａｌＬＶ２", "Ａ．ｕｔｏ Ｈｉｔ Ｃｒｙｓｔａｌ",
"ＡｕｔｏＡｎｃｈｏｒ", "Ａｕｔｏ Ａｎｃｈｏｒ", "ＤｏｕｂｌｅＡｎｃｈｏｒ", "Ｄｏｕｂｌｅ Ａｎｃｈｏｒ", "ＳａｆｅＡｎｃｈｏｒ", "Ｓａｆｅ Ａｎｃｈｏｒ",
"Ａｎｃｈｏｒ Ｍａｃｒｏ", "Ａ．ｎｃｈｏｒ Ｍａｃｒｏ", "Ａ．ｎｃｈｏｒ Ｍａｃｒｏ Ｖ２", "Ｄ．ｏｕｂｌｅ Ａｎｃｈｏｒ", "Ｓ．ａｆｅＡｎｃｈｏｒ",
"ＡｕｔｏＴｏｔｅｍ", "Ａｕｔｏ Ｔｏｔｅｍ", "Ａｕｔｏ Ｔｏｔｅｍ Ｈｉｔ", "Ａ．ｕｔｏ Ｔｏｔｅｍ Ｈｉｔ", "ＨｏｖｅｒＴｏｔｅｍ", "Ｈｏｖｅｒ Ｔｏｔｅｍ",
"ＩｎｖｅｎｔｏｒｙＴｏｔｅｍ", "Ｈ．ｏｖｅｒ Ｔｏｔｅｍ", "Ａ．ｕｔｏ Ｉｎｖｅｎｔｏｒｙ Ｔｏｔｅｍ", "Ｆ．ｏｒｃｅ Ｔｏｔｅｍ", "Ｔ．ｏｔｅｍ Ｆｉｒｓｔ",
"Ｔ．ｏｔｅｍ Ｏｆｆｈａｎｄ", "Ｔ．ｏｔｅｍ Ｓｌｏｔ", "Ｈ．ｏｖｅｒ", "Ｗ．ｏｒｋ Ｗｉｔｈ Ｔｏｔｅｍ",
"ＡｕｔｏＰｏｔ", "Ａｕｔｏ Ｐｏｔ", "Ａ．ｕｔｏ Ｐｏｔ", "Ａ．ｕｔｏ Ｐｏｔ Ｒｅｆｉｌｌ", "Ａ．ｕｔｏ Ｒｅｆｉｌｌ", "Ｐ．ｏｔ Ｃｏｕｎｔ",
"Ｒ．ｅｆｉｌｌ Ｓｌｏｔ", "Ｒ．ｅｆｉｌｌｓ ｙｏｕｒ ｈｏｔｂａｒ ｗｉｔｈ ｐｏｔｉｏｎｓ", "Ａ．ｕｔｏ Ｐｏｔ Ｒｅｆｉｌｌ",
"ＡｕｔｏＡｒｍｏｒ", "Ａｕｔｏ Ａｒｍｏｒ", "ＳｈｉｅｌｄＤｉｓａｂｌｅｒ", "Ｓｈｉｅｌｄ Ｄｉｓａｂｌｅｒ", "Ｓ．ｈｉｅｌｄＤｉｓａｂｌｅｒ", "Ｓ．ｈｉｅｌｄ Ｔｉｍｅ",
"ＡｕｔｏＤｏｕｂｌｅＨａｎｄ", "Ａｕｔｏ Ｄｏｕｂｌｅ Ｈａｎｄ", "Ａ．ｕｔｏ Ｄｏｕｂｌｅ Ｈａｎｄ", "Ｓ．ｗｉｎｇ Ｈａｎｄ",
"ＡｕｔｏＣｌｉｃｋｅｒ", "ＡｕｔｏＭａｃｅ", "Ａｕｔｏ Ｍａｃｅ", "Ａ．ｕｔｏ Ｍａｃｅ", "ＭａｃｅＳｗａｐ", "Ｍａｃｅ Ｓｗａｐ",
"Ｍ．ａｃｅ Ｓｗａｐ", "Ｍ．ａｃｅ Ｐｒｉｏｒｉｔｙ", "Ａ．ｕｔｏｍａｔｉｃａｌｌｙ ａｘｅ ａｎｄ ｍａｃｅ ｓｈｉｅｌｄｅｄ ｐｌａｙｅｒｓ",
"ＡｉｍＡｓｓｉｓｔ", "Ａｉｍ Ａｓｓｉｓｔ", "Ａ．ｉｍ Ａｓｓｉｓｔ", "ＴｒｉｇｇｅｒＢｏｔ", "Ｔｒｉｇｇｅｒ ＴｒｉｇｇｅｒＢｏｔ", "Ｔ．ｒｉｇｇｅｒＢｏｔ",
"Ｔ．ｒｉｇｇｅｒ Ｋｅｙ", "Ｔ．ｒｉｇ Ｈｅａｌｔｈ", "ＦａｋｅＬａｇ", "Ｆａｋｅ Ｌａｇ", "Ｆ．ａｋｅ Ｐｕｎｃｈ", "Ｆ．ａｋｅ ｐｕｎｃｈ",
"Ｆｒｅｅｃａｍ", "Ｆ．ｒｅｅｃａｍ", "Ｎｏ Ｃｌｉｐ", "Ｎ．ｏ Ｃｌｉｐ", "Ｆａｓｔ Ｐｌａｃｅ", "Ｆ．ａｓｔ Ｐｌａｃｅ", "Ｆ．ａｓｔ Ｍｏｄｅ",
"Ｌｏｏｔ Ｙｅｅｔｅｒ", "Ｌ．ｏｏｔ Ｙｅｅｔｅｒ", "Ｗａｌｋｓｙ Ｏｐｔｉｍｉｚｅｒ", "Ｗ．ａｌｋｓｙ Ｏｐｔｉｍｉｚｅｒ",
"ＥｌｙｔｒａＳｗａｐ", "Ｅｌｙｔｒａ Ｓｗａｐ", "Ｒ．ｅｑｕｉｒｅ Ｅｌｙｔｒａ",
"Ａ．ｃｔｉｖａｔｅ Ｋｅｙ", "Ａ．ｃｔｉｖａｔｅ ｋｅｙ", "Ａ．ｃｔｉｖａｔｅｓ Ａｂｏｖｅ", "Ａ．ｌｌ Ｅｎｔｉｔｉｅｓ", "Ａ．ｌｌ Ｉｔｅｍｓ",
"Ａ．ｐｐｌｙ ｇｌｏｗ ｅｆｆｅｃｔ ｔｏ ａｌｌ ｅｎｔｉｔｉｅｓ", "Ａ．ｓｐｅｃｔ Ｒａｔｉｏ", "Ａ．ｔｔａｃｋ Ｄｅｌａｙ",
"Ａ．ｕｔｏ", "Ａ．ｕｔｏ Ｂｒｅａｃｈ", "Ａ．ｕｔｏ ＤＴＡＰ", "Ａ．ｕｔｏ Ｊｕｍｐ Ｒｅｓｅｔ", "Ａ．ｕｔｏ Ｏｐｅｎ",
"Ａ．ｕｔｏ Ｓｗｉｔｃｈ", "Ａ．ｕｔｏ Ｓｗｉｔｃｈ． Ｂａｃｋ", "Ａ．ｕｔｏ Ｗｅｂ", "Ａ．ｕｔｏＷｅｂ", "Ａ．ｎｔｉＷｅｂ",
"Ａ．ｕｔｏ ｓｗａｐ ｔｏ ｓｐｅａｒ ｏｎ ａｔｔａｃｋ", "Ａ．ｕｔｏｍａｔｉｃａｌｌｙ ｂｒｅａｋｓ ｗｅｂｓ ａｒｏｕｎｄ ｙｏｕ",
"Ａ．ｘｅ Ｄｅｌａｙ Ｍａｘ", "Ａ．ｘｅ Ｄｅｌａｙ Ｍｉｎ", "Ａ．ｎｔｉ Ｗｅｂ", "Ａ．ｎｔｉ－Ｗｅａｋｎｅｓｓ", "Ａ．ｎｔｉ Ｗｅａｋｎｅｓｓ",
"Ｂ．ａｃｋｇｒｏｕｎｄ", "Ｂ．ｌａｔａｎｔ", "Ｂ．ｌａｔａｎｔ Ｍｏｄｅ", "Ｂ．ｏｘ Ａｌｐｈａ", "Ｂ．ｒｅａｃｈ", "Ｂ．ｒｅａｃｈ Ｄｅｌａｙ",
"Ｂ．ｒｅａｋ Ｂｌｏｃｋｓ", "Ｂ．ｒｅａｋ Ｃｈａｎｃｅ", "Ｂ．ｒｅａｋ Ｄｅｌａｙ", "Ｂ．ｒｅａｋ ｃｈａｎｃｅ", "Ｂ．ｒｅａｋ ｄｅｌａｙ",
"Ｃ．ｈａｎｃｅ", "Ｃ．ｈｅｃｋ Ａｉｍ", "Ｃ．ｈｅｃｋ Ｉｔｅｍｓ", "Ｃ．ｈｅｃｋ Ｌｉｎｅ ｏｆ Ｓｉｇｈｔ", "Ｃ．ｈｅｃｋ Ｐｌａｃｅ",
"Ｃ．ｈｅｃｋ Ｐｌａｙｅｒｓ", "Ｃ．ｈｅｃｋ Ｓｈｉｅｌｄ", "Ｃ．ｈｎｃｅ", "Ｃ．ｌｉｃｋ Ｄｅｌａｙ", "Ｃ．ｌｉｃｋ Ｓｉｍｕｌａｔｉｏｎ",
"Ｃ．ｌｉｃｋ Ｓｔｉｍｕｌａｔｉｏｎ", "Ｃ．ｌｉｃｋｉｎｇ", "Ｄ．ａｍａｇｅ Ｔｉｃｋ", "Ｄ．ａｍａｇｅ ｔｉｃｋ", "Ｄ．ｅｌａｙ",
"Ｄ．ｅｎｓｉｔｙ Ｔｈｒｅｓｈｏｌｄ", "Ｄ．ｉｓｔａｎｃｅ", "Ｄ．ｒｏｐ Ｉｎｔｅｒｖａｌ", "Ｅ．ＳＰ", "Ｅ．ａｓｉｎｇ Ｓｔｒｅｎｇｔｈ",
"Ｅ．ｘｐａｎｄ Ａｍｏｕｎｔ", "Ｅ．ｘｐｌｏｄｅ Ｃｈａｎｃｅ", "Ｅ．ｘｐｌｏｄｅ Ｄｅｌａｙ", "Ｅ．ｘｐｌｏｄｅ Ｓｌｏｔ",
"Ｆ．ＯＶ", "Ｆ．ｒｅｅｚｅ Ｐｌａｙｅｒ", "Ｆ．ｒｉｅｎｄｓ", "Ｇ．ＵＩ Ｋｅｙ", "Ｇ．ｌｏｗ", "Ｇ．ｌｏｗｓｔｏｎｅ Ｃｈａｎｃｅ",
"Ｇ．ｌｏｗｓｔｏｎｅ Ｄｅｌａｙ", "Ｇ．ｒａｄｉｅｎｔ", "Ｈ．ＵＤ", "Ｈ．ｅａｌｔｈ", "Ｈ．ｉｔＤｅｌａｙ", "Ｈ．ｉｔｂｏｘｅｓ",
"Ｈ．ｏｌｄｉｎｇ Ｗｅｂ", "Ｈ．ｏｒｉｚｏｎｔａｌ", "Ｈ．ｏｒｉｚｏｎｔａｌ Ａｉｍ Ｓｐｅｅｄ", "Ｈ．ｏｔｂａｒ",
"Ｉ．ｎｃｌｕｄｅ Ｈｅａｄ", "Ｉ．ｎｆｏ", "Ｉ．ｎｖｉｓｉｂｌｅｓ", "Ｉ．ｔｅｍｓ", "Ｊ．ｕｍｐ Ｒｅｓｅｔ Ｃｈａｎｃｅ",
"Ｋ．ｅｐｓ ｙｏｕ ｓｐｒｉｎｔｉｎｇ ａｔ ａｌｌ ｔｉｍｅｓ", "Ｋ．ｅｙＰｅａｒｌ", "Ｌ．ＷＦＨ Ｃｒｙｓｔａｌ", "Ｌ．ｉｎｅ Ｗｉｄｔｈ",
"Ｍ．ａｃｒｏ Ｋｅｙ", "Ｍ．ａｘ Ｓｐｅｅｄ", "Ｍ．ｉｎ Ｆａｌｌ Ｄｉｓｔａｎｃｅ", "Ｍ．ｉｎ Ｆａｌｌ Ｓｐｅｅｄ", "Ｍ．ｉｎ Ｈｅｉｇｈｔ",
"Ｍ．ｉｎ Ｐｅａｒｌｓ", "Ｍ．ｉｎ Ｓｐｅｅｄ", "Ｍ．ｉｎ Ｔｏｔｅｍｓ", "Ｍ．ｏｄｅ", "Ｍ．ｏｄｕｌｅｓ",
"Ｍ．ｏｖｅ ｆｒｅｅｌｙ ｔｈｒｏｕｇｈ ｗａｌｌｓ", "Ｍｉｎ． Ｈｅｉｇｈｔ", "Ｎ．ａｍｅＴａｇｓ", "Ｎ．ｅｔｈＰｏｔ",
"Ｎ．ｏ Ｂｏｕｎｃｅ", "Ｎ．ｏ Ｃｏｕｎｔ Ｇｌｉｔｃｈ", "Ｎ．ｏ Ｓｌｏｗｄｏｗｎ", "Ｎ．ｏＢｏｕｎｃｅ", "Ｎ．ｏｔ Ｗｈｅｎ Ａｆｆｅｃｔｓ Ｐｌａｙｅｒ",
"Ｏ．ｎ Ｇｒｏｕｎｄ", "Ｏ．ｎ Ｈｅａｌｔｈ", "Ｏ．ｎ Ｌｅｆｔ Ｃｌｉｃｋ", "Ｏ．ｎ Ｐｏｐ", "Ｏ．ｎ ＲＭＢ",
"Ｏ．ｎｌｙ Ａｘｅ", "Ｏ．ｎｌｙ Ｃｈａｒｇｅ", "Ｏ．ｎｌｙ Ｃｒｉｔ Ａｘｅ", "Ｏ．ｎｌｙ Ｃｒｉｔ Ｓｗｏｒｄ", "Ｏ．ｎｌｙ Ｏｎ． Ｐｏｐ",
"Ｏ．ｎｌｙ Ｏｗｎ", "Ｏ．ｎｌｙ Ｓｗｏｒｄ", "Ｏ．ｎｌｙ Ｗｈｅｎ Ｆａｌｌｉｎｇ", "Ｏ．ｎｌｙ Ｗｈｅｎ Ｈｕｒｔ", "Ｏ．ｎｌｙ Ｗｈｉｌｅ Ｉｎ Ｗｅｂ",
"Ｐ．ａｒｔｉｃｌｅ Ｃｈａｎｃｅ", "Ｐ．ｌａｃｅ Ｃｈａｎｃｅ", "Ｐ．ｌａｃｅ Ｄｅｌａｙ", "Ｐ．ｌａｃｅ Ｉｎｔｅｒｖａｌ",
"Ｐ．ｌａｃｅ ｂｌｏｃｋｓ ｆａｓｔｅｒ", "Ｐ．ｌａｃｅ ｃｈａｎｃｅ", "Ｐ．ｌａｃｅ ｄｅｌａｙ", "Ｐ．ｌａｃｅｓ Ｗｅｂｓ Ｏｎ Ｅｎｅｍｉｅｓ",
"Ｐ．ｌａｃｅｓ ａｎｃｈｏｒ， ｃｈａｒｇｅｓ ｉｔ， ｐｒｏｔｅｃｔｓ ｙｏｕ， ａｎｄ ｅｘｐｌｏｄｅｓ", "Ｐ．ｌａｙｅｒｓ", "Ｐ．ｌａｙｅｒｓ Ｏｎｌｙ",
"Ｐ．ｒｅｄｉｃｔ Ｃｒｙｓｔａｌｓ", "Ｐ．ｒｅｄｉｃｔ Ｄａｍａｇｅ", "Ｐ．ｒｅｖｅｎｔ", "Ｐ．ｒｅｖｅｎｔ Ａｎｃｈｏｒ", "Ｐ．ｒｅｖｅｎｔｓ ｃｅｒｔａｉｎ ａｃｔｉｏｎｓ",
"Ｒ．ａｉｎｂｏｗ", "Ｒ．ａｎｄ Ｇｌｏｗ Ｍａｘ", "Ｒ．ａｎｄ Ｇｌｏｗ Ｍｉｎ", "Ｒ．ａｎｄｏｍ Ｄｅｌａｙ Ｍａｘ", "Ｒ．ａｎｄｏｍ Ｄｅｌａｙ Ｍｉｎ",
"Ｒ．ａｎｄｏｍ Ｇｌｏｗｓｔｏｎｅ", "Ｒ．ａｎｄｏｍ Ｐａｔｔｅｒｎ", "Ｒ．ａｎｄｏｍｉｚｅ", "Ｒ．ａｎｇｅ", "Ｒ．ｅａｃｈ Ｄｉｓｔａｎｃｅ",
"Ｒ．ｅｍｏｖｅｓ ｔｈｅ ｃｒｙｓｔａｌ ｂｏｕｎｃｅ ａｎｉｍａｔｉｏｎ", "Ｒ．ｅｎｄｅｒ Ｈｉｔｂｏｘｅｓ", "Ｒ．ｅｎｄｅｒｓ ｃｕｓｔｏｍ ｎａｍｅｔａｇｓ ａｂｏｖｅ ｐｌａｙｅｒｓ",
"Ｒ．ｅｎｄｅｒｓ ｅｎｔｉｔｉｅｓ ｔｈｒｏｕｇｈ ｗａｌｌｓ", "Ｒ．ｅｑｕｉｒｅ Ｃｌｉｃｋ", "Ｒ．ｅｑｕｉｒｅ Ｃｏｂｗｅｂ", "Ｒ．ｅｑｕｉｒｅ Ｃｒｉｔ",
"Ｒ．ｅｑｕｉｒｅ Ｓｗｏｒｄ", "Ｒ．ｅｑｕｉｒｅＨｏｌｄＡｘｅ", "Ｒ．ｅｓｅｔ Ｄｅｌａｙ", "Ｒ．ｏｔａｔｉｏｎ Ｓｐｅｅｄ",
"Ｓ．ａｍｅ Ｐｌａｙｅｒ", "Ｓ．ｃａｌｅ", "Ｓ．ｈｏｗ Ｄｉｓｔａｎｃｅ", "Ｓ．ｈｏｗ Ｆｒｉｅｎｄｓ", "Ｓ．ｈｏｗ Ｈｅａｌｔｈ",
"Ｓ．ｈｏｗ Ｓｔａｔｕｓ Ｄｉｓｐｌａｙ", "Ｓ．ｉｌｅｎｔ Ｒｏｔａｔｉｏｎｓ", "Ｓ．ｋｅｌｅｔｏｎ", "Ｓ．ｌｏｔ", "Ｓ．ｍａｒｔ Ｊｉｔｔｅｒ",
"Ｓ．ｍｏｏｔｈ Ｒｏｔａｔｉｏｎｓ", "Ｓ．ｐｅａｒ Ｓｗａｐ", "Ｓ．ｐｅｅｄ", "Ｓ．ｐｒｉｎｔ", "Ｓ．ｔａｙ Ｏｐｅｎ Ｆｏｒ",
"Ｓ．ｔｏｐ Ｏｎ Ｃｒｙｓｔａｌ", "Ｓ．ｔｏｐ Ｏｎ Ｋｉｌｌ", "Ｓ．ｔｏｐ ｏｎ Ｋｉｌｌ", "Ｓ．ｔｏｐ ｏｎ ｋｉｌｌ",
"Ｓ．ｔｒａｙ Ｂｙｐａｓｓ", "Ｓ．ｔｒｉｃｔ Ｏｎｅ－Ｔｉｃｋ", "Ｓ．ｔｕｎ", "Ｓ．ｔｕｎ Ｓｌａｍ", "Ｓ．ｗａｐ Ｓｐｅｅｄ",
"Ｓ．ｗｉｔｃｈ Ｂａｃｋ", "Ｓ．ｗｉｔｃｈ Ｃｈａｎｃｅ", "Ｓ．ｗｉｔｃｈ Ｄｅｌａｙ", "Ｓ．ｗｉｔｃｈＢａｃｋ", "Ｓ．ｗｉｔｃｈＤｅｌａｙ",
"Ｓ．ｗｏｒｄ Ｄｅｌａｙ Ｍａｘ", "Ｓ．ｗｏｒｄ Ｄｅｌａｙ Ｍｉｎ", "Ｓ．ｗｏｒｄ Ｓｗａｐ", "Ｓ．ｗｔｃｈ Ｃｈａｎｃｅ",
"Ｔ．ａｒｇｅｔ Ｍｏｂｓ", "Ｔ．ａｒｇｅｔ Ｐｌａｙｅｒｓ", "Ｔ．ｈｒｏｗ Ｄｅｌａｙ", "Ｔ．ｒａｃｅｒｓ",
"Ｕ．ｓｅ Ｅａｓｉｎｇ", "Ｕ．ｓｅ Ｓｈｉｅｌｄ", "Ｖ．ｅｌｏｃｉｔｙ", "Ｖ．ｅｒｔｉｃａｌ", "Ｖ．ｅｒｔｉｃａｌ Ａｉｍ Ｓｐｅｅｄ",
"Ｖ．ｅｒｔｉｃａｌ Ｓｐｅｅｄ", "Ｖ．ｉｓｉｂｉｌｉｔｙ Ｃｈｅｃｋ", "Ｗ．ｅｂ Ｄｅｌａｙ", "Ｗ．ｈｉｌｅ Ａｓｃｅｎｄｉｎｇ", "Ｗ．ｈｉｌｅ Ｕｓｅ",
"Ｗ．ｉｎｄ", "Ｗ．ｉｎｄ Ｂｕｒｓｔ", "Ｗ．ｏｒｋ Ｉｎ Ｓｃｒｅｅｎ", "Ｗ．ｏｒｋ Ｗｉｔｈ Ｃｒｙｓｔａｌ", "Ｘ．Ｐ Ｍａｎａｇｅｒ",
"ａ．ｃｔｉｖａｔｅＯｎＲｉｇｈｔＣｌｉｃｋ", "ｂ．ｒｅａｋＩｎｔｅｒｖａｌ", "ｄ．ａｍａｇｅｔｉｃｋ", "ｆ．ａｋｅＰｕｎｃｈ",
"ｈ．ｏｌｄＣｒｙｓｔａｌ", "ｏ．ｎｅ ｎｉｎｅ ｅｉｇｈｔ Ｍａｃｒｏ", "ｐ．ｌａｃｅＩｎｔｅｒｖａｌ", "ｓ．ｔｏｐＯｎＫｉｌｌ"
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
           & $stringsPath $filePath 2>$null | Out-File $tempFile -Encoding UTF8
            if (Test-Path $tempFile) {
                $extractedContent = Get-Content $tempFile -Raw
                Remove-Item $tempFile -Force
                
                foreach ($string in $cheatStrings) {
                    if ($extractedContent -match $string) { $stringsFound.Add($string) | Out-Null }
                }
            }
        } else {
            # Check main file content
           $content = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($filePath)).ToLower()
foreach ($string in $cheatStrings) {
    if ($string -eq "velocity") {
        if ($content -match "velocity(hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
            $stringsFound.Add($string) | Out-Null
        }
    } elseif ($content -match [regex]::Escape($string.ToLower())) {
        $stringsFound.Add($string) | Out-Null
    }
}
            
            # Also check .class files and .json files inside the JAR
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($filePath)
           $entries = $zip.Entries | Where-Object { $_.Name -match '\.(class|json|jar)$' }

foreach ($entry in $entries) {

    # ===== Nested JAR scanning =====
    if ($entry.Name -like "*.jar") {
        try {

            $ms = New-Object System.IO.MemoryStream
            $entry.Open().CopyTo($ms)
            $ms.Position = 0

            $nestedZip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)

            foreach ($nestedEntry in $nestedZip.Entries) {

                if ($nestedEntry.Name -match '\.(class|json)$') {

                    $reader = New-Object System.IO.StreamReader($nestedEntry.Open(), [System.Text.Encoding]::UTF8)
                    $nestedContent = $reader.ReadToEnd().ToLower()
                    $reader.Close()

                    foreach ($string in $cheatStrings) {
                        if ($nestedContent -match [regex]::Escape($string.ToLower())) {
                            $stringsFound.Add($string) | Out-Null
                        }
                    }

                }

            }

        } catch {}

        continue
    }

    # ===== Normal class/json scanning =====
    try {
        $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
        $entryContent = $reader.ReadToEnd().ToLower()
        $reader.Close()

        foreach ($string in $cheatStrings) {
            if ($string -eq "velocity") {
                if ($entryContent -match "velocity(hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
                    $stringsFound.Add($string) | Out-Null
                }
            }
           elseif ($entryContent -match [regex]::Escape($string.ToLower())) {
                $stringsFound.Add($string) | Out-Null
            }
        }

    } catch {}
}
$zip.Dispose()
        }
    }
    catch {}
    
    return $stringsFound
}

# Collections for results
$verifiedMods = [System.Collections.Generic.List[object]]::new()
$unknownMods = [System.Collections.Generic.List[object]]::new()
$cheatMods = [System.Collections.Generic.List[object]]::new()
$sizeMismatchMods = [System.Collections.Generic.List[object]]::new()
$tamperedMods = [System.Collections.Generic.List[object]]::new()
$allModsInfo = [System.Collections.Generic.List[object]]::new()

# Process all mods
$jarFiles = Get-ChildItem -Path $mods -Filter *.jar
$spinner = @("|", "/", "-", "\"); $totalMods = $jarFiles.Count

Write-Host "Scanning $totalMods mods..." -ForegroundColor White

for ($i = 0; $i -lt $jarFiles.Count; $i++) {
    $file = $jarFiles[$i]
    Write-Host "`r[$($spinner[$i % $spinner.Length])] Scanning mods: $($i+1) / $totalMods" -ForegroundColor Magenta -NoNewline
    
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
        }
        
        # Only add to verified mods if it's not tampered or a cheat mod
        $modEntry.IsVerified = $true
        $verifiedMods.Add($modEntry)
        $allModsInfo.Add($modEntry)
        
        if ($modData.ExpectedSize -gt 0 -and $actualSize -ne $modData.ExpectedSize) {
               $sizeMismatchMods.Add($modEntry)
            if ([math]::Abs($sizeDiff) -gt 1024) { 
                $tamperedMods.Add($modEntry)
                # Remove from verified mods if tampered
                $null = $verifiedMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $file.Name })
            }
        }
    } elseif ($megabaseData = Fetch-Megabase -hash $hash) {
        $modEntry = [PSCustomObject]@{ 
            ModName = $megabaseData.name; FileName = $file.Name; Version = "Unknown"; ExpectedSize = 0; ExpectedSizeKB = 0
            ActualSize = $actualSize; ActualSizeKB = $actualSizeKB; SizeDiff = 0; SizeDiffKB = 0; DownloadSource = $zoneInfo.Source
            SourceURL = $zoneInfo.URL; IsModrinthDownload = $zoneInfo.IsModrinth; IsVerified = $true; MatchType = "Megabase"
            ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown"; PreferredLoader = $preferredLoader
            FilePath = $file.FullName; JarModId = $jarModInfo.ModId; JarName = $jarModInfo.Name; JarVersion = $jarModInfo.Version
            JarModLoader = $jarModInfo.ModLoader
        }
        
        $verifiedMods.Add($modEntry)
        $allModsInfo.Add($modEntry)
    } else {
        $unknownModEntry = [PSCustomObject]@{ 
            FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneInfo.URL; DownloadSource = $zoneInfo.Source
            IsModrinthDownload = $zoneInfo.IsModrinth; FileSize = $actualSize; FileSizeKB = $actualSizeKB; Hash = $hash
            ExpectedSize = 0; ExpectedSizeKB = 0; SizeDiff = 0; SizeDiffKB = 0; ModrinthUrl = ""; ModName = ""; MatchType = ""
            ExactMatch = $false; IsLatestVersion = $false; LoaderType = "Unknown"; PreferredLoader = $preferredLoader
            JarModId = $jarModInfo.ModId; JarName = $jarModInfo.Name; JarVersion = $jarModInfo.Version; JarModLoader = $jarModInfo.ModLoader
        }
        
       $unknownMods.Add($unknownModEntry)
       $allModsInfo.Add($unknownModEntry)
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
                
                # Move from unknown to verified if successfully identified
                if ($modrinthInfo.ExpectedSize -gt 0) {
                    $newVerifiedEntry = [PSCustomObject]@{ 
                        ModName = $modrinthInfo.Name; FileName = $mod.FileName; Version = $modrinthInfo.VersionNumber
                        ExpectedSize = $modrinthInfo.ExpectedSize; ExpectedSizeKB = $mod.ExpectedSizeKB; ActualSize = $mod.FileSize; ActualSizeKB = $mod.FileSizeKB
                        SizeDiff = $mod.SizeDiff; SizeDiffKB = $mod.SizeDiffKB; DownloadSource = $mod.DownloadSource; SourceURL = $mod.ZoneId
                        IsModrinthDownload = $mod.IsModrinthDownload; ModrinthUrl = $modrinthInfo.ModrinthUrl; IsVerified = $true; MatchType = $modrinthInfo.MatchType
                        ExactMatch = $modrinthInfo.ExactMatch; IsLatestVersion = $modrinthInfo.IsLatestVersion; LoaderType = $modrinthInfo.LoaderType
                        PreferredLoader = $mod.PreferredLoader; FilePath = $mod.FilePath; JarModId = $mod.JarModId; JarName = $mod.JarName
                        JarVersion = $mod.JarVersion; JarModLoader = $mod.JarModLoader
                    }
                    
                    $verifiedMods.Add($newVerifiedEntry)
                    $null = $unknownMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $mod.FileName })
                }
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
    
    Write-Host "`nScanning for cheat strings..." -ForegroundColor White
    
    foreach ($mod in $allModsInfo) {
        $counter++
        Write-Host "`r[$($spinner[$counter % $spinner.Length])] Scanning for cheat strings: $counter / $totalMods" -ForegroundColor Magenta -NoNewline
        
        # Check for single-letter class files
$singleLetterClassCount = 0
$totalClassCount = 0
$obfuscatedPathCount = 0

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($mod.FilePath)
    $classEntries = $zip.Entries | Where-Object { $_.FullName -match '\.class$' }

    foreach ($entry in $classEntries) {
        $totalClassCount++

        $className = [System.IO.Path]::GetFileNameWithoutExtension($entry.Name)
        if ($className.Length -le 2) {
            $singleLetterClassCount++
        }

        # Detect single-letter package chains like a/b/c/Class.class
        $pathWithoutClass = $entry.FullName -replace '\.class$',''
        $segments = $pathWithoutClass -split '/'

        $consecutiveSingle = 0
        $maxConsecutive = 0

        foreach ($segment in $segments) {
            if ($segment.Length -eq 1) {
                $consecutiveSingle++
                if ($consecutiveSingle -gt $maxConsecutive) {
                    $maxConsecutive = $consecutiveSingle
                }
            } else {
                $consecutiveSingle = 0
            }
        }

        if ($maxConsecutive -ge 3) {
            $obfuscatedPathCount++
        }
    }

    $zip.Dispose()
} catch {}

$obfPercent = 0
if ($totalClassCount -ge 10) {
    $obfPercent = [math]::Round(($obfuscatedPathCount / $totalClassCount) * 100)
}

if (
    $singleLetterClassCount -gt 15 -or
    ($totalClassCount -ge 10 -and $obfPercent -ge 25)
) {
    $reason = if ($obfPercent -ge 25) {
        "Multiple single-letter/obfuscation class patterns detected"
    } else {
        "Multiple single-letter/obfuscation class patterns detected"
    }

    $tamperedMods += [PSCustomObject]@{
        FileName = $mod.FileName
        ModName = $mod.ModName
        ActualSizeKB = $mod.FileSizeKB
        ExpectedSizeKB = $mod.ExpectedSizeKB
        SizeDiffKB = $mod.SizeDiffKB
        TamperReason = $reason
    }

    # Remove from verified mods
    $verifiedMods = $verifiedMods | Where-Object { $_.FileName -ne $mod.FileName }
}     
        if ($modStrings = Check-Strings $mod.FilePath) {
           $cheatMods.Add([PSCustomObject]@{
                FileName = $mod.FileName; StringsFound = $modStrings; FileSizeKB = $mod.FileSizeKB
                DownloadSource = $mod.DownloadSource; SourceURL = $mod.ZoneId; ExpectedSizeKB = $mod.ExpectedSizeKB
                SizeDiffKB = $mod.SizeDiffKB; IsVerifiedMod = ($mod.IsVerified -eq $true); ModName = $mod.ModName
                ModrinthUrl = $mod.ModrinthUrl; FilePath = $mod.FilePath
                HasSizeMismatch = ($mod.SizeDiffKB -ne 0 -and [math]::Abs($mod.SizeDiffKB) -gt 1)
                JarModId = $mod.JarModId; JarName = $mod.JarName; JarVersion = $mod.JarVersion
                MatchType = $mod.MatchType; ExactMatch = $mod.ExactMatch; IsLatestVersion = $mod.IsLatestVersion
                LoaderType = $mod.LoaderType
            })
            
            # Remove from verified mods if cheat detected
            $verifiedMods = $verifiedMods | Where-Object { $_.FileName -ne $mod.FileName }
        }
    }
} catch {
    Write-Host "`nError occurred while scanning: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
}

Write-Host "`nScanning complete!`n" -ForegroundColor Green

# ==================== DISALLOWED MODS DETECTOR ====================
# List of disallowed mods with their Modrinth slugs
$disallowedMods = @{
    "xeros-minimap" = @{
        Names = @("Xero's Minimap", "Xeros Minimap", "xeros-minimap", "XerosMinimap", "Xero's Minimap Mod")
    }
    "freecam" = @{
        Names = @("Freecam", "freecam", "FreeCam", "Free Cam")
    }
    "health-indicators" = @{
        Names = @("Health Indicators", "health indicators", "HealthIndicators", "Health Indicators Mod")
    }
    "clickcrystals" = @{
        Names = @("ClickCrystals", "clickcrystals", "ClickCrystals Mod")
    }
    "mousetweaks" = @{
        Names = @("Mouse Tweaks", "mousetweaks", "MouseTweaks")
    }
    "itemscroller" = @{
        Names = @("Item Scroller", "itemscroller", "ItemScroller")
    }
    "tweakeroo" = @{
        Names = @("Tweakeroo", "tweakeroo", "Tweakeroo")
    }
}

# Scan for disallowed mods
$disallowedModsFound = @()
$jarFiles = Get-ChildItem -Path $mods -Filter *.jar

foreach ($file in $jarFiles) {
    $fileName = $file.Name.ToLower()
    $modInfo = Get-Mod-Info-From-Jar -jarPath $file.FullName
    
    # Check each disallowed mod
    foreach ($modSlug in $disallowedMods.Keys) {
        $modData = $disallowedMods[$modSlug]
        $isDisallowed = $false
        
        # Check filename
        foreach ($name in $modData.Names) {
            if ($fileName -match [regex]::Escape($name.ToLower()) -or 
                $fileName -match [regex]::Escape($modSlug.ToLower()) -or
                $fileName -match [regex]::Escape(($name -replace ' ', '').ToLower())) {
                $isDisallowed = $true
                break
            }
        }
        
        # Check mod info from jar
        if (-not $isDisallowed) {
            if ($modInfo.ModId -and $modInfo.ModId.ToLower() -match $modSlug.ToLower()) {
                $isDisallowed = $true
            }
            elseif ($modInfo.Name -and $modInfo.Name.ToLower() -match $modSlug.ToLower()) {
                $isDisallowed = $true
            }
        }
        
        if ($isDisallowed) {
            $disallowedModsFound += [PSCustomObject]@{
                FileName = $file.Name
                ModName = $modData.Names[0]
            }
            break
        }
    }
}

# ==================== RESULTS SECTION ====================
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Verified Mods Section
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "VERIFIED MODS: $($verifiedMods.Count) ✓" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green

if ($verifiedMods.Count -gt 0) {
    foreach ($mod in $verifiedMods) {
        $isTampered = $tamperedMods.FileName -contains $mod.FileName
        $isCheatMod = $cheatMods.FileName -contains $mod.FileName
        
        if (-not $isTampered -and -not $isCheatMod) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$($mod.ModName) " -NoNewline -ForegroundColor White
            Write-Host "($($mod.FileName))" -ForegroundColor Green
            Write-Host "    Size: $($mod.ActualSizeKB) KB" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  No verified mods found" -ForegroundColor Gray
}
Write-Host ""

# Unknown Mods Section with Box - Yellow borders, White/Cyan text
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "UNKNOWN MODS: $($unknownMods.Count) ?" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

if ($unknownMods.Count -gt 0) {
    for ($i = 0; $i -lt $unknownMods.Count; $i++) {
        $mod = $unknownMods[$i]
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "  ║ " -NoNewline -ForegroundColor Yellow
        Write-Host "UNKNOWN MOD" -ForegroundColor Yellow
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "  ║ " -NoNewline -ForegroundColor Yellow
        Write-Host "File: $($mod.FileName)" -ForegroundColor White
        Write-Host "  ║ " -NoNewline -ForegroundColor Yellow
        Write-Host "Size: $($mod.FileSizeKB) KB" -ForegroundColor White
        if ($mod.ModName) {
            Write-Host "  ║ " -NoNewline -ForegroundColor Yellow
            Write-Host "Identified as: $($mod.ModName)" -ForegroundColor Cyan
        }
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Yellow
        if ($i -lt $unknownMods.Count - 1) {
            Write-Host ""
        }
    }
} else {
    Write-Host "  No unknown mods found" -ForegroundColor Gray
}
Write-Host ""

# Tampered Mods Section with Box - DarkYellow borders, White/Magenta/Red text
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow
Write-Host "TAMPERED MODS: $($tamperedMods.Count) ⚠" -ForegroundColor DarkYellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow

if ($tamperedMods.Count -gt 0) {
    for ($i = 0; $i -lt $tamperedMods.Count; $i++) {
        $mod = $tamperedMods[$i]
        $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor DarkYellow
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow
        Write-Host "TAMPERED MOD" -ForegroundColor DarkYellow
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor DarkYellow
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow
        Write-Host "File: $($mod.FileName)" -ForegroundColor White
        if ($mod.ModName) {
            Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow
            Write-Host "Mod: $($mod.ModName)" -ForegroundColor Magenta
        }
        if ($mod.TamperReason) {
            Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow
            Write-Host "Reason: $($mod.TamperReason)" -ForegroundColor Red
        }
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB)" -ForegroundColor Magenta
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor DarkYellow
        if ($i -lt $tamperedMods.Count - 1) {
            Write-Host ""
        }
    }
} else {
    Write-Host "  No tampered mods found" -ForegroundColor Gray
}
Write-Host ""

# Cheat Mods Section with Box - Red borders, White/Yellow/Magenta text
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
Write-Host "CHEAT MODS: $($cheatMods.Count) ⚠" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red

if ($cheatMods.Count -gt 0) {
    for ($i = 0; $i -lt $cheatMods.Count; $i++) {
        $mod = $cheatMods[$i]
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red
        Write-Host "CHEAT MOD DETECTED" -ForegroundColor Red
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red
        Write-Host "File: $($mod.FileName)" -ForegroundColor White
        
        if ($mod.ModName) {
            Write-Host "  ║ " -NoNewline -ForegroundColor Red
            Write-Host "Mod: $($mod.ModName)" -ForegroundColor White
        }
        
        # Show cheat strings as a list using • bullets
        if ($mod.StringsFound.Count -gt 0) {
            Write-Host "  ║ " -NoNewline -ForegroundColor Red
            Write-Host "Detected Cheat Strings:" -ForegroundColor Yellow
            $cheatList = @($mod.StringsFound) | Sort-Object
            foreach ($cheatString in $cheatList) {
                Write-Host "  ║   " -NoNewline -ForegroundColor Red
                Write-Host "• $cheatString" -ForegroundColor Magenta
            }
        }
        
        if ($mod.ExpectedSizeKB -gt 0) {
            $sign = if ($mod.SizeDiffKB -gt 0) { "+" } else { "" }
            if ($mod.SizeDiffKB -eq 0) {
                Write-Host "  ║ " -NoNewline -ForegroundColor Red
                Write-Host "Size matches Modrinth: $($mod.ExpectedSizeKB) KB ✓" -ForegroundColor White
            } else {
                Write-Host "  ║ " -NoNewline -ForegroundColor Red
                Write-Host "Size: $($mod.FileSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB)" -ForegroundColor White
                Write-Host "  ║ " -NoNewline -ForegroundColor Red
                Write-Host "Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor White
            }
        }
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
        if ($i -lt $cheatMods.Count - 1) {
            Write-Host ""
        }
    }
} else {
    Write-Host "  No cheat mods detected ✓" -ForegroundColor Green
}
Write-Host ""

# Disallowed Mods Section - Red borders, White text
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
Write-Host "DISALLOWED MODS: $($disallowedModsFound.Count) ⚠" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red

if ($disallowedModsFound.Count -gt 0) {
    for ($i = 0; $i -lt $disallowedModsFound.Count; $i++) {
        $mod = $disallowedModsFound[$i]
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red
        Write-Host "DISALLOWED MOD DETECTED" -ForegroundColor Red
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red
        Write-Host "File: $($mod.FileName)" -ForegroundColor White
        Write-Host "  ║ " -NoNewline -ForegroundColor Red
        Write-Host "Mod: $($mod.ModName)" -ForegroundColor White
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
        if ($i -lt $disallowedModsFound.Count - 1) {
            Write-Host ""
        }
    }
} else {
    Write-Host "  No disallowed mods detected ✓" -ForegroundColor Green
}
Write-Host ""

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Credits to Habibi Mod Analyzer" -ForegroundColor DarkGray
Write-Host "Special Thanks to Tonynoh For Helping me ❤️" -ForegroundColor White 
Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
