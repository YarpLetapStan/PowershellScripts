[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Host "Made by YarpLetapStan`nDm YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan
Write-Host @"
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
"@ -ForegroundColor Blue

$lineWidth = 100
Write-Host "YarpLetapStan's Mod Analyzer V6.1".PadLeft(($lineWidth + 34) / 2) -ForegroundColor Cyan
Write-Host ("━" * $lineWidth) -ForegroundColor Cyan
Write-Host ""

Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray
$mods = Read-Host "PATH"
Write-Host

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host "Using default path: $mods`n" -ForegroundColor White
}
if (-not (Test-Path $mods -PathType Container)) { Write-Host "Invalid Path!" -ForegroundColor Red; exit 1 }

$process = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $process) { $process = Get-Process java -ErrorAction SilentlyContinue }
if ($process) {
    try {
        $elapsed = (Get-Date) - $process.StartTime
        Write-Host "Minecraft Uptime: $($process.Name) PID $($process.Id) started at $($process.StartTime) and running for $($elapsed.Hours)h $($elapsed.Minutes)m $($elapsed.Seconds)s`n" -ForegroundColor Cyan
    } catch {}
}

$sep = "━" * 111
Write-Host $sep -ForegroundColor Yellow
Write-Host "JVM ARGUMENTS INJECTION SCANNER" -ForegroundColor Yellow
Write-Host $sep -ForegroundColor Yellow
Write-Host ""

$javaProcesses = Get-Process -Name javaw -ErrorAction SilentlyContinue
if ($javaProcesses.Count -eq 0) {
    Write-Host "  [!] No javaw.exe processes found" -ForegroundColor Yellow
    Write-Host "  [i] Make sure Minecraft is running`n" -ForegroundColor Yellow
} else {
    Write-Host "  [i] Scanning $($javaProcesses.Count) Java process(es)...`n" -ForegroundColor White
    $foundInjection = $false

    $fabricPatterns = @{
        "fabric.addMods"="'-Dfabric\.addMods='"; "fabric.loadMods"='-Dfabric\.loadMods='; "fabric.classPathGroups"='-Dfabric\.classPathGroups='; "fabric.gameJarPath"='-Dfabric\.gameJarPath='; "fabric.skipMcProvider"='-Dfabric\.skipMcProvider='; "fabric.development"='-Dfabric\.development='; "fabric.allowUnsupportedVersion"='-Dfabric\.allowUnsupportedVersion='; "fabric.remapClasspathFile"='-Dfabric\.remapClasspathFile='; "fabric.skipIntermediary"='-Dfabric\.skipIntermediary='; "fabric.configDir"='-Dfabric\.configDir='; "fabric.loader.config"='-Dfabric\.loader\.config='; "fabric.log.level"='-Dfabric\.log\.level='; "fabric.debug.dumpClasspath"='-Dfabric\.debug\.dumpClasspath='; "fabric.log.config"='-Dfabric\.log\.config='; "fabric.dli.config"='-Dfabric\.dli\.config='; "fabric.mixin.configs"='-Dfabric\.mixin\.configs='; "fabric.mixin.hotSwap"='-Dfabric\.mixin\.hotSwap='; "fabric.mixin.debug.export"='-Dfabric\.mixin\.debug\.export='; "fabric.mixin.debug.verbose"='-Dfabric\.mixin\.debug\.verbose='; "fabric.gameVersion"='-Dfabric\.gameVersion='; "fabric.forceVersion"='-Dfabric\.forceVersion='; "fabric.autoDetectVersion"='-Dfabric\.autoDetectVersion='; "fabric.launcher.name"='-Dfabric\.launcher\.name='; "fabric.launcher.brand"='-Dfabric\.launcher\.brand='; "fabric.mods.toml.path"='-Dfabric\.mods\.toml\.path='; "fabric.customModList"='-Dfabric\.customModList='; "fabric.resolve.modFiles"='-Dfabric\.resolve\.modFiles='; "fabric.skipDependencyResolution"='-Dfabric\.skipDependencyResolution='; "fabric.loader.entrypoints"='-Dfabric\.loader\.entrypoints='; "fabric.language.providers"='-Dfabric\.language\.providers=';
        "forge.addMods"='-Dforge\.addMods='; "forge.mods"='-Dforge\.mods='; "fml.coreMods.load"='-Dfml\.coreMods\.load='; "forge.coreMods.dir"='-Dforge\.coreMods\.dir='; "forge.modDir"='-Dforge\.modDir='; "forge.modsDirectories"='-Dforge\.modsDirectories='; "fml.customModList"='-Dfml\.customModList='; "forge.disableModScan"='-Dforge\.disableModScan='; "forge.modList"='-Dforge\.modList='; "forge.forceVersion"='-Dforge\.forceVersion='; "forge.disableUpdateCheck"='-Dforge\.disableUpdateCheck='; "forge.logging.mojang.level"='-Dforge\.logging\.mojang\.level='; "forge.mixin.hotSwap"='-Dforge\.mixin\.hotSwap='; "forge.resourcePack"='-Dforge\.resourcePack='; "forge.defaultResourcePack"='-Dforge\.defaultResourcePack='; "forge.texturePacks"='-Dforge\.texturePacks='; "forge.assetIndex"='-Dforge\.assetIndex='; "forge.assetsDir"='-Dforge\.assetsDir=';
        "javaSecurityManager"='-Djava\.security\.manager='; "javaSecurityPolicy"='-Djava\.security\.policy='; "bootClasspath"='-Xbootclasspath'; "systemClassLoader"='-Djava\.system\.class\.loader='; "javaClassPath"='-Djava\.class\.path='; "cp"='-cp\s+["''][^"'';]*\.jar';
        "cheatClientBrand"='-D(client|launcher)\.brand=(Wurst|Aristois|Impact|Kilo|Future|Lambda|Rusher|Konas|Phobos|Salhack|ForgeHax|Mathax|Meteor|Async|Seppuku|Xatz|Wolfram|Huzuni|Jigsaw|Zamorozka|Moon|Rage|Exhibition|Virtue|Novoline|Rekt|Skid|Ares|Abyss|Thunder|Tenacity|Rise|Flux|Gamesense|Intent|Remix|Sight|Vape|Shield|Ghost|Crispy|Inertia)';
        "optifine"='-Doptifine\.'; "shadersmod"='-Dshaders?\.'; "shaderPack"='-Dshader[sP]ack='; "cheatPattern"='-D(xray|fly|speed|killaura|reach|esp|wallhack|noclip|autoclick|aimbot|triggerbot|antiknockback|nofall|timer|step|fullbright|nightvision|cavefinder)\.'
    }
    $cheatClients = @('Wurst','Aristois','Impact','Kilo','Future','Lambda','Rusher','Konas','Phobos','Salhack','ForgeHax','Mathax','Meteor','Async','Seppuku','Xatz','Wolfram','Huzuni','Jigsaw','Zamorozka','Moon','Rage','Exhibition','Virtue','Novoline','Rekt','Skid','Ares','Abyss','Thunder','Tenacity','Rise','Flux','Gamesense','Intent','Remix','Sight','Vape','Shield','Ghost','Crispy','Inertia')

    foreach ($proc in $javaProcesses) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction Stop).CommandLine
            if (-not $cmdLine) { continue }

            $playerName = if ($cmdLine -match '--username\s+(\S+)') { $matches[1] } else { "Unknown" }
            $playerUUID = if ($cmdLine -match '--uuid\s+(\S+)') { $matches[1] } else { $null }

            Write-Host "  ┌─ Process: PID $($proc.Id) | Player: $playerName" -ForegroundColor Green
            if ($playerUUID) { Write-Host "  ├─ UUID: $playerUUID" -ForegroundColor DarkGray }

            if ($cmdLine -match '^"([^"]+)"') { $cmdLine = $cmdLine.Substring($matches[1].Length + 2).Trim() }

            $detectedPatterns = @(); $suspiciousArgs = @()
            foreach ($k in $fabricPatterns.Keys) {
                if ($k -eq "addOpens" -or $k -eq "addExports") { continue }
                if ($cmdLine -match $fabricPatterns[$k]) {
                    $detectedPatterns += $k
                    $suspiciousArgs += ($cmdLine -split '\s+' | Where-Object { $_ -match $fabricPatterns[$k] })
                }
            }
            foreach ($cc in $cheatClients) {
                if ($cmdLine -match "(?i)\b$cc\b" -and $detectedPatterns -notcontains "CheatClient-$cc") { $detectedPatterns += "CheatClient-$cc" }
            }
            if ($cmdLine -match '(%3B|%26%26|%7C%7C|%7C|%60|%24|%3C|%3E)') { $detectedPatterns += "EncodedInjection" }

            if ($detectedPatterns.Count -gt 0) {
                $foundInjection = $true
                Write-Host "  ├─ [✗] JVM INJECTION DETECTED`n" -ForegroundColor Red
                Write-Host "  │  Detected JVM Arguments:" -ForegroundColor Yellow
                $suspiciousArgs | Select-Object -Unique | ForEach-Object { Write-Host "  │    • $_" -ForegroundColor Magenta }
                Write-Host "`n  │  Detected Pattern Categories:" -ForegroundColor Yellow
                $grouped = @{}
                foreach ($p in $detectedPatterns) {
                    $t = if ($p -match "^(fabric|forge|javaSecurity|bootClasspath|systemClassLoader|javaClassPath|cp|cheatClient|optifine|shadersmod|shaderPack|cheatPattern|EncodedInjection)") { $matches[1] } else { "other" }
                    if (-not $grouped[$t]) { $grouped[$t] = @() }
                    $grouped[$t] += $p
                }
                $typeMap = @{ fabric="Fabric Injection"; forge="Forge Injection"; javaSecurity="Security Bypass"; bootClasspath="Classpath Manipulation"; systemClassLoader="Class Loader"; javaClassPath="Class Path"; cp="Classpath (-cp)"; cheatClient="Cheat Client"; optifine="Optifine/Shaders"; shadersmod="Shader Mod"; shaderPack="Shader Pack"; cheatPattern="Cheat Pattern"; EncodedInjection="Encoded Injection"; other="Other" }
                foreach ($t in $grouped.Keys | Sort-Object) {
                    Write-Host "  │    └─ $($typeMap[$t])" -ForegroundColor White
                    $grouped[$t] | ForEach-Object { Write-Host "  │        • $($_ -replace 'CheatClient-','')" -ForegroundColor Red }
                }
                Write-Host "`n  └─ ⚠ WARNING: Potential cheat client or mod injection detected!`n" -ForegroundColor Red
            } else {
                Write-Host "  └─ [✓] No JVM injection patterns detected`n" -ForegroundColor Green
            }
        } catch {
            Write-Host "  └─ [!] Warning: Could not retrieve command line for PID $($proc.Id)" -ForegroundColor DarkYellow
            Write-Host "      [i] Run as Administrator for complete detection.`n" -ForegroundColor DarkYellow
        }
    }
    if (-not $foundInjection) { Write-Host "  [✓] CLEAN: No JVM argument injections detected in any Java process" -ForegroundColor Green }
    Write-Host ""
}

function Get-Minecraft-Version-From-Mods($modsFolder) {
    $mcVersions = @{}; $modsScanned = 0
    Write-Host "Analyzing mods for Minecraft version..." -ForegroundColor Cyan
    foreach ($file in (Get-ChildItem -Path $modsFolder -Filter *.jar)) {
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
            $fmj = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1
            if ($fmj) {
                $r = New-Object System.IO.StreamReader($fmj.Open()); $fd = $r.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue; $r.Close()
                if ($fd.depends.minecraft) {
                    $s = $fd.depends.minecraft
                    $ver = if ($s -match '>=\s*(\d+\.\d+(?:\.\d+)?).*<=\s*(\d+\.\d+(?:\.\d+)?)') { $matches[2] }
                          elseif ($s -match '[><=~\^]+\s*(\d+\.\d+(?:\.\d+)?)') { $matches[1] }
                          elseif ($s -match '^(\d+\.\d+(?:\.\d+)?)$') { $matches[1] }
                          elseif ($s -match '(\d+\.\d+(?:\.\d+)?)') { $matches[1] }
                    if ($ver -match '^\d+\.\d+(?:\.\d+)?$') { if (-not $mcVersions[$ver]) { $mcVersions[$ver]=0 }; $mcVersions[$ver]++; $modsScanned++ }
                }
            }
            $mtoml = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' } | Select-Object -First 1
            if ($mtoml) {
                $r = New-Object System.IO.StreamReader($mtoml.Open()); $tc = $r.ReadToEnd(); $r.Close()
                if ($tc -match 'modId\s*=\s*"minecraft"[\s\S]{0,200}versionRange\s*=\s*"([^"]+)"') {
                    $vr = $matches[1]
                    $ver = if ($vr -match '\[(\d+\.\d+(?:\.\d+)?),') { $matches[1] }
                           elseif ($vr -match '\[(\d+\.\d+(?:\.\d+)?)\]') { $matches[1] }
                           elseif ($vr -match '(\d+\.\d+(?:\.\d+)?)') { $matches[1] }
                    if ($ver) { if (-not $mcVersions[$ver]) { $mcVersions[$ver]=0 }; $mcVersions[$ver]++; $modsScanned++ }
                }
            }
            $zip.Dispose()
        } catch { continue }
    }
    if ($mcVersions.Count -gt 0) {
        $best = $mcVersions.GetEnumerator() | Sort-Object -Property @{E={$_.Value};D=$true},@{E={$_.Key};D=$true} | Select-Object -First 1
        Write-Host "Detected Minecraft version: $($best.Key) (from $($best.Value) out of $modsScanned mods)" -ForegroundColor Cyan
        return $best.Key
    }
    if ($process) {
        try {
            $cl = (Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            foreach ($pat in @('versions[/\\](\d+\.\d+(?:\.\d+)?)[/\\]','-Dminecraft\.version=(\d+\.\d+(?:\.\d+)?)','-Dfabric\.gameVersion=(\d+\.\d+(?:\.\d+)?)','--version\s+(\d+\.\d+(?:\.\d+)?)')) {
                if ($cl -match $pat) { Write-Host "Detected Minecraft version from process: $($matches[1])" -ForegroundColor Cyan; return $matches[1] }
            }
        } catch { Write-Host "Warning: Could not read process command line" -ForegroundColor DarkYellow }
    }
    Write-Host "Could not auto-detect Minecraft version from mods." -ForegroundColor Yellow
    $v = Read-Host "Enter your Minecraft version (e.g., 1.21, 1.20.1) or press Enter to skip"
    return if ($v -eq '') { $null } else { $v }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
if ($minecraftVersion = Get-Minecraft-Version-From-Mods -modsFolder $mods) { Write-Host "Using Minecraft version: $minecraftVersion for filtering`n" -ForegroundColor Green }

function Get-SHA1($p) { return (Get-FileHash -Path $p -Algorithm SHA1).Hash }

function Get-ZoneIdentifier($p) {
    try {
        $raw = Get-Content -Raw -Stream Zone.Identifier $p -ErrorAction SilentlyContinue
        if ($raw -match "HostUrl=(.+)") {
            $url = $matches[1]
            $src = switch -regex ($url) { "modrinth\.com"{"Modrinth"} "curseforge\.com"{"CurseForge"} "github\.com"{"GitHub"} "discord"{"Discord"} default{"Other"} }
            return @{ Source=$src; URL=$url; IsModrinth=$url -match "modrinth\.com" }
        }
    } catch {}
    return @{ Source="Unknown"; URL=""; IsModrinth=$false }
}

function Get-Mod-Info-From-Jar($jarPath) {
    $mi = @{ ModId=""; Name=""; Version=""; Authors=@(); ModLoader="" }
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        $e = $zip.Entries | Where-Object { $_.Name -eq 'fabric.mod.json' } | Select-Object -First 1
        if ($e) {
            $r = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8); $fd = $r.ReadToEnd() | ConvertFrom-Json; $r.Close()
            $mi.ModId=$fd.id; $mi.Name=$fd.name; $mi.Version=$fd.version; $mi.ModLoader="Fabric"
            $zip.Dispose(); return $mi
        }
        $e = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' } | Select-Object -First 1
        if ($e) {
            $r = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8); $tc = $r.ReadToEnd(); $r.Close()
            if ($tc -match 'modId\s*=\s*"([^"]+)"') { $mi.ModId=$matches[1] }
            if ($tc -match 'displayName\s*=\s*"([^"]+)"') { $mi.Name=$matches[1] }
            if ($tc -match 'version\s*=\s*"([^"]+)"') { $mi.Version=$matches[1] }
            $mi.ModLoader="Forge/NeoForge"; $zip.Dispose(); return $mi
        }
        $e = $zip.Entries | Where-Object { $_.Name -match '\.mixins\.json$' } | Select-Object -First 1
        if ($e) {
            $r = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8); $mx = $r.ReadToEnd() | ConvertFrom-Json -ErrorAction SilentlyContinue; $r.Close()
            if ($mx.package -and -not $mi.ModId) { $pp = $mx.package -split '\.'; if ($pp.Count -ge 2) { $mi.ModId=$pp[-2] } }
        }
        $e = $zip.Entries | Where-Object { $_.Name -eq 'MANIFEST.MF' } | Select-Object -First 1
        if ($e) {
            $r = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8); $mc2 = $r.ReadToEnd(); $r.Close()
            foreach ($line in ($mc2 -split "`n")) {
                if ($line -match 'Implementation-Title:\s*(.+)' -and -not $mi.Name) { $mi.Name=$matches[1].Trim() }
                if ($line -match 'Implementation-Version:\s*(.+)' -and -not $mi.Version) { $mi.Version=$matches[1].Trim() }
            }
        }
        $zip.Dispose()
    } catch {}
    return $mi
}

function Find-Closest-Version($localVersion, $availableVersions, $preferredLoader="Fabric", $minecraftVersion) {
    if (-not $localVersion -or -not $availableVersions) { return $null }
    $fv = $availableVersions | Where-Object { ($_.loaders -contains $preferredLoader.ToLower()) -and ((-not $minecraftVersion) -or ($_.game_versions -contains $minecraftVersion)) }
    if (-not $fv) { $fv = $availableVersions | Where-Object { $_.game_versions -contains $minecraftVersion } }
    if (-not $fv) { $fv = $availableVersions | Where-Object { $_.loaders -contains $preferredLoader.ToLower() } }
    if (-not $fv) { $fv = $availableVersions }
    $exact = $fv | Where-Object { $_.version_number -eq $localVersion } | Select-Object -First 1
    if ($exact) { return $exact }
    try {
        if ($localVersion -match '(\d+)\.(\d+)\.(\d+)') {
            $ma=[int]$matches[1]; $mi2=[int]$matches[2]; $pa=[int]$matches[3]
            $best=$null; $bestD=[double]::MaxValue
            foreach ($v in $fv) {
                if ($v.version_number -match '(\d+)\.(\d+)\.(\d+)') {
                    $d=[math]::Sqrt([math]::Pow($ma-[int]$matches[1],2)*100+[math]::Pow($mi2-[int]$matches[2],2)*10+[math]::Pow($pa-[int]$matches[3],2))
                    if ($d -lt $bestD) { $bestD=$d; $best=$v }
                }
            }
            if ($best -and $bestD -lt 10) { return $best }
        }
        if ($localVersion -match '(\d+)\.(\d+)') {
            $ma=[int]$matches[1]; $mi2=[int]$matches[2]
            $best=$null; $bestD=[double]::MaxValue
            foreach ($v in $fv) {
                if ($v.version_number -match '(\d+)\.(\d+)') {
                    $d=[math]::Sqrt([math]::Pow($ma-[int]$matches[1],2)*10+[math]::Pow($mi2-[int]$matches[2],2))
                    if ($d -lt $bestD) { $bestD=$d; $best=$v }
                }
            }
            if ($best -and $bestD -lt 5) { return $best }
        }
    } catch {}
    return $fv | Where-Object { $_.version_number -match [regex]::Escape($localVersion) } | Select-Object -First 1
}

function Build-ModrinthResult($proj, $ver, $versions, $byHash=$false, $matchType="") {
    $file = $ver.files[0]
    $loader = if ($ver.loaders -contains "fabric") {"Fabric"} elseif ($ver.loaders -contains "forge") {"Forge"} else {$ver.loaders[0]}
    return @{ Name=$proj.title; Slug=$proj.slug; ExpectedSize=$file.size; VersionNumber=$ver.version_number; FileName=$file.filename
              ModrinthUrl="https://modrinth.com/mod/$($proj.slug)/version/$($ver.id)"; FoundByHash=$byHash
              ExactMatch=($byHash -or $matchType -eq "Exact Version" -or $matchType -eq "Exact Filename")
              IsLatestVersion=($versions[0].id -eq $ver.id); MatchType=$matchType; LoaderType=$loader }
}

function Get-ModrinthVersions($id) { return Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$id/version" -UseBasicParsing }
function Get-ModrinthProject($id) { return Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$id" -UseBasicParsing }

$modrinthCache = @{}

function Fetch-Modrinth-By-Hash($hash) {
    if ($modrinthCache.ContainsKey("hash:$hash")) { return $modrinthCache["hash:$hash"] }
    $result = @{ Name=""; Slug=""; ExpectedSize=0; VersionNumber=""; FileName=""; FoundByHash=$false; ExactMatch=$false; IsLatestVersion=$false; MatchType="No Match"; LoaderType="Unknown" }
    try {
        $resp = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -UseBasicParsing
        if ($resp.project_id) {
            $proj = Get-ModrinthProject $resp.project_id
            $result = @{ Name=$proj.title; Slug=$proj.slug; ExpectedSize=$resp.files[0].size; VersionNumber=$resp.version_number
                         FileName=$resp.files[0].filename; ModrinthUrl="https://modrinth.com/mod/$($proj.slug)/version/$($resp.id)"
                         FoundByHash=$true; ExactMatch=$true; IsLatestVersion=$false; MatchType="Exact Hash"
                         LoaderType=if ($resp.loaders -contains "fabric"){"Fabric"} elseif ($resp.loaders -contains "forge"){"Forge"} else{"Unknown"} }
        }
    } catch {}
    $modrinthCache["hash:$hash"] = $result
    return $result
}

function Fetch-By-ProjectId($id, $version, $preferredLoader) {
    try {
        $proj = Get-ModrinthProject $id; $versions = Get-ModrinthVersions $id
        $matched = Find-Closest-Version $version $versions $preferredLoader $minecraftVersion
        if ($matched) { return Build-ModrinthResult $proj $matched $versions -matchType (if ($matched.version_number -eq $version){"Exact Version"} else {"Closest Version"}) }
        $fallback = $versions | Where-Object { ($_.loaders -contains $preferredLoader.ToLower()) -and ((-not $minecraftVersion) -or ($_.game_versions -contains $minecraftVersion)) } | Select-Object -First 1
        if (-not $fallback) { $fallback = $versions[0] }
        if ($fallback) { return Build-ModrinthResult $proj $fallback $versions -matchType "Latest Version" }
    } catch {}
    return $null
}

function Fetch-Modrinth-By-ModId($modId, $version, $preferredLoader="Fabric") {
    $cacheKey = "modid:$modId|$version|$preferredLoader"
    if ($modrinthCache.ContainsKey($cacheKey)) { return $modrinthCache[$cacheKey] }
    $result = Fetch-By-ProjectId $modId $version $preferredLoader
    if ($result) { $modrinthCache[$cacheKey] = $result; return $result }
    try {
        $search = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/search?query=`"$modId`"&facets=`"[[`"project_type:mod`"]]`"&limit=5" -UseBasicParsing
        if ($search.hits.Count -gt 0) {
            $best = $search.hits | Sort-Object { if ($_.slug -eq $modId){100} elseif ($_.title -eq $modId){80} elseif ($_.title -match $modId){50} else{0} } -Descending | Select-Object -First 1
            if ($best) { $r = Fetch-By-ProjectId $best.project_id $version $preferredLoader; if ($r) { $modrinthCache[$cacheKey] = $r; return $r } }
        }
    } catch {}
    $empty = @{ Name=""; Slug=""; ExpectedSize=0; VersionNumber=""; FileName=""; FoundByHash=$false; ExactMatch=$false; IsLatestVersion=$false; MatchType="No Match"; LoaderType="Unknown" }
    $modrinthCache[$cacheKey] = $empty
    return $empty
}

function Fetch-Modrinth-By-Filename($filename, $preferredLoader="Fabric") {
    $cacheKey = "filename:$filename|$preferredLoader"
    if ($modrinthCache.ContainsKey($cacheKey)) { return $modrinthCache[$cacheKey] }
    $clean = $filename -replace '\.temp\.jar$|\.tmp\.jar$|_1\.jar$','.jar'
    $base = [System.IO.Path]::GetFileNameWithoutExtension($clean)
    if ($filename -match '(?i)fabric') { $preferredLoader="Fabric" } elseif ($filename -match '(?i)forge') { $preferredLoader="Forge" }
    $localVer = ""; $baseName = $base
    if ($base -match '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$') { $localVer=$matches[1]; $baseName=$base -replace '[-_](v?[\d\.]+(?:-[a-zA-Z0-9]+)?)$','' }
    $baseName = $baseName -replace '(?i)-fabric$|-forge$',''

    foreach ($slug in @($baseName.ToLower(), $base.ToLower())) {
        try {
            $proj = Get-ModrinthProject $slug; $versions = Get-ModrinthVersions $slug
            $exactFile = $versions | ForEach-Object { $v=$_; $_.files | Where-Object { $_.filename -eq $clean -or $_.filename -eq $filename } | ForEach-Object { @{ver=$v;file=$_} } } | Select-Object -First 1
            if ($exactFile) { $r = Build-ModrinthResult $proj $exactFile.ver $versions -matchType "Exact Filename"; $modrinthCache[$cacheKey] = $r; return $r }
            $matched = Find-Closest-Version $localVer $versions $preferredLoader $minecraftVersion
            if ($matched) { $r = Build-ModrinthResult $proj $matched $versions -matchType (if ($matched.version_number -eq $localVer){"Exact Version"} else{"Closest Version"}); $modrinthCache[$cacheKey] = $r; return $r }
            $fallback = $versions | Where-Object { ($_.loaders -contains $preferredLoader.ToLower()) -and ((-not $minecraftVersion) -or ($_.game_versions -contains $minecraftVersion)) } | Select-Object -First 1
            if (-not $fallback) { $fallback = $versions[0] }
            if ($fallback) { $r = Build-ModrinthResult $proj $fallback $versions -matchType "Latest Version"; $modrinthCache[$cacheKey] = $r; return $r }
        } catch { continue }
    }
    try {
        $search = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/search?query=`"$baseName`"&facets=`"[[`"project_type:mod`"]]`"&limit=5" -UseBasicParsing
        if ($search.hits.Count -gt 0) {
            $hit = $search.hits[0]; $versions = Get-ModrinthVersions $hit.project_id
            $exactFile = $versions | ForEach-Object { $v=$_; $_.files | Where-Object { $_.filename -eq $clean -or $_.filename -eq $filename } | ForEach-Object { @{ver=$v;file=$_} } } | Select-Object -First 1
            if ($exactFile) { $r = Build-ModrinthResult $hit $exactFile.ver $versions -matchType "Exact Filename"; $modrinthCache[$cacheKey] = $r; return $r }
            if ($versions.Count -gt 0) { $r = Build-ModrinthResult $hit $versions[0] $versions -matchType "Latest Version"; $modrinthCache[$cacheKey] = $r; return $r }
        }
    } catch {}
    $empty = @{ Name=""; Slug=""; ExpectedSize=0; VersionNumber=""; FileName=""; FoundByHash=$false; ExactMatch=$false; IsLatestVersion=$false; MatchType="No Match"; LoaderType="Unknown" }
    $modrinthCache[$cacheKey] = $empty
    return $empty
}

function Fetch-Megabase($hash) {
    try { $r = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -UseBasicParsing; if (-not $r.error) { return $r.data } } catch {}
    return $null
}

function Invoke-BulkHashLookup($jarFiles) {
    $hashMap = @{}
    foreach ($file in $jarFiles) {
        $hash = Get-SHA1 $file.FullName
        $hashMap[$hash] = $file
    }

    $bulkResults = @{}
    try {
        $body = @{ hashes = @($hashMap.Keys); algorithm = "sha1" } | ConvertTo-Json
        $raw = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_files" -Method POST -ContentType "application/json" -Body $body -UseBasicParsing
        foreach ($prop in $raw.PSObject.Properties) {
            $hash = $prop.Name
            $ver  = $prop.Value
            $bulkResults[$hash] = $ver
            try {
                $proj = Get-ModrinthProject $ver.project_id
                $modrinthCache["hash:$hash"] = @{
                    Name=$proj.title; Slug=$proj.slug; ExpectedSize=$ver.files[0].size
                    VersionNumber=$ver.version_number; FileName=$ver.files[0].filename
                    ModrinthUrl="https://modrinth.com/mod/$($proj.slug)/version/$($ver.id)"
                    FoundByHash=$true; ExactMatch=$true; IsLatestVersion=$false; MatchType="Exact Hash"
                    LoaderType=if ($ver.loaders -contains "fabric"){"Fabric"} elseif ($ver.loaders -contains "forge"){"Forge"} else{"Unknown"}
                }
            } catch {}
        }

    } catch {
        Write-Host "Bulk lookup failed, falling back to individual lookups: $($_.Exception.Message)`n" -ForegroundColor DarkYellow
    }
    return $hashMap
}

$cheatStrings = @(
    "clickSimulation","switchDelay","switchChance","placeChance","glowstoneDelay","glowstoneChance","explodeDelay","explodeChance","explodeSlot","antiWeakness","damageTick","breakChance","breakDelay",
    "stopOnCrystal","processCrystal","swapToWeapon","isObsidianOrBedrock","isValidCrystalPosition","processAnchorPvP","isValidAnchorPosition",
    "AutoCrystal","autocrystal","auto crystal","AutoHitCrystal","autohitcrystal","dontPlaceCrystal","dontBreakCrystal","canPlaceCrystalServer","autoCrystalPlaceClock",
    "AutoAnchor","autoanchor","auto anchor","DoubleAnchor","safe anchor","safeanchor","anchortweaks","anchor macro",
    "AutoTotem","autototem","auto totem","InventoryTotem","inventorytotem","HoverTotem","hover totem","legittotem",
    "AutoPot","autopot","auto pot","speedPotSlot","strengthPotSlot",
    "AutoArmor","autoarmor","auto armor","preventSwordBlockBreaking","preventSwordBlockAttack",
    "AutoDoubleHand","autodoublehand","auto double hand","AutoClicker",
    "AimAssist","aimassist","aim assist","triggerbot","trigger bot","Sw1tch","D3l4y","M1n","Pl4ce","D3l4y","M1n",
    "T0t3m","Sl0t","Expl0de","Sl0t","Aut0","Cry5t4l","C11ckGu1","obsPos","crystalslot",
    "shieldbreaker","shield breaker","axespam","axe spam",
    "findKnockbackSword","attackRegisteredThisClick",
    "FakeLag","pingspoof","ping spoof","freecam","Freecam","FakeInv",
    "pushOutOfBlocks","onPushOutOfBlocks","MAX_ESPERA_TICKS","esperandoCristal","posCristal","buscarCristal","kanPlaceKrystalServer",
    "modifyDecrementAmount","preventSwordFromBlockAttack","preventSwordFromBlockBreaking","shouldBlockBlockHit","lwfh",
    "webmacro","web macro","JumpReset","Donut",
    "setBlockBreakingCooldown","getBlockBreakingCooldown","setItemUseCooldown",
    "onBlockBreaking","invokeDoAttack","invokeDoItemUse",
    "setSelectedSlot","getSelectedSlot","swapBackToOriginalSlot",
    "blockBreakingCooldown","invokeOnMouseButton",
    "onSwapLastAttackedTicksReset","getVisualAttackCooldownProgressPerTick",
    "getHandSwingDuration","onBeginRenderTick",
    "PlayerMoveC2SPacketAccessor","redirectSelectedSlot","hookCancelBlockBreaking",
    "EndCrystalItemMixin","endcrystalitemmixin","WalksyCrystalOptimizerMod",
    "arrayOfString","lvstrng","dqrkis","StringObfuscator","POT_CHEATS",
    "onShouldRenderBlockOutline","predictCrystals","noOffhandTotem","getNearByCrystals",
    "slotExplode","needToPlaceRails","findTotemSlot","activateOnRightClick",
    "crystalPlaceClock","isDeadBodyNearby","CrystalTwiceClock",
    "mainHandStack","attackInAir","attackOnJump","onDestruct",
    "getGlowstoneChance","isAutoCharge","getPlaceChance","getSwitchDelay",
    "getGlowstoneDelay","getExplodeDelay","getExplodeSlotIndex",
    "getPlaceDelayTicks","getBreakDelayTicks","getBreakChance",
    "isSpawnersEnabled","isShulkersEnabled","onModuleDisabled",
    "switchToBestTool","switchToBestWeapon",
    "isLootProtect","getMinHunger","isTracersEnabled",
    "getSelectedBlocks","isChestsEnabled","4ctivat K3y","D4m4ge T1ck","Sw1tch D3lay","Ch4rg3 D3l4y",
    "inventoryToMenuSlot","throwPearl","isLeftHoldOnly",
    "Automatically switches to sword when hitting with totem",
    "Failed to switch to mace after axe!","Breaking shield with axe...","TrilliumSolutions",
    "selfdestruct","self destruct","CwskKkUfHQYB","HgsCDQ49KkUfHQYB","DhsnbQ0LDg0MDA","OhYHBQcOHw","EgQKDiUqRR8WChk",
    "KjoFWRcEAx0M","Hx0GAVkcChwdDA","HSw7RQQIAQQ","BR0sFBcOGg4a","Oh0yWR0MCA",
    "ＡｕｔｏＣｒｙｓｔａｌ","Ａｕｔｏ Ｃｒｙｓｔａｌ","ＡｕｔｏＨｉｔＣｒｙｓｔａｌ","Ａ．ｕｔｏ Ｃｒｙｓｔａｌ","Ａ．ｕｔｏＣｒｙｓｔａｌＬＶ２","Ａ．ｕｔｏ Ｈｉｔ Ｃｒｙｓｔａｌ",
    "ＡｕｔｏＡｎｃｈｏｒ","Ａｕｔｏ Ａｎｃｈｏｒ","ＤｏｕｂｌｅＡｎｃｈｏｒ","Ｄｏｕｂｌｅ Ａｎｃｈｏｒ","ＳａｆｅＡｎｃｈｏｒ","Ｓａｆｅ Ａｎｃｈｏｒ",
    "Ａｎｃｈｏｒ Ｍａｃｒｏ","Ａ．ｎｃｈｏｒ Ｍａｃｒｏ","Ａ．ｎｃｈｏｒ Ｍａｃｒｏ Ｖ２","Ｄ．ｏｕｂｌｅ Ａｎｃｈｏｒ","Ｓ．ａｆｅＡｎｃｈｏｒ",
    "ＡｕｔｏＴｏｔｅｍ","Ａｕｔｏ Ｔｏｔｅｍ","Ａｕｔｏ Ｔｏｔｅｍ Ｈｉｔ","Ａ．ｕｔｏ Ｔｏｔｅｍ Ｈｉｔ","ＨｏｖｅｒＴｏｔｅｍ","Ｈｏｖｅｒ Ｔｏｔｅｍ",
    "ＩｎｖｅｎｔｏｒｙＴｏｔｅｍ","Ｈ．ｏｖｅｒ Ｔｏｔｅｍ","Ａ．ｕｔｏ Ｉｎｖｅｎｔｏｒｙ Ｔｏｔｅｍ","Ｆ．ｏｒｃｅ Ｔｏｔｅｍ","Ｔ．ｏｔｅｍ Ｆｉｒｓｔ",
    "Ｔ．ｏｔｅｍ Ｏｆｆｈａｎｄ","Ｔ．ｏｔｅｍ Ｓｌｏｔ","Ｈ．ｏｖｅｒ","Ｗ．ｏｒｋ Ｗｉｔｈ Ｔｏｔｅｍ","ＡｕｔｏＤｏｕｂｌｅＨａｎｄ","Ａｕｔｏ Ｄｏｕｂｌｅ Ｈａｎｄ","Ａ．ｕｔｏ Ｄｏｕｂｌｅ Ｈａｎｄ",
    "Ａ．ｃｔｉｖａｔｅ Ｋｅｙ","Ｗ．ｈｉｌｅ Ｕｓｅ","Ｓ．ｔｏｐ ｏｎ Ｋｉｌｌ","Ｃ．ｌｉｃｋ Ｓｉｍｕｌａｔｉｏｎ","Ｓ．ｗｉｔｃｈ Ｄｅｌａｙ",
    "Ｓ．ｗｔｃｈ Ｃｈａｎｃｅ","Ｐ．ｌａｃｅ Ｃｈａｎｃｅ","Ｇ．ｌｏｗｓｔｏｎｅ Ｄｅｌａｙ","Ｇ．ｌｏｗｓｔｏｎｅ Ｃｈａｎｃｅ","Ｅ．ｘｐｌｏｄｅ Ｄｅｌａｙ",
    "Ｅ．ｘｐｌｏｄｅ Ｃｈａｎｃｅ","Ｅ．ｘｐｌｏｄｅ Ｓｌｏｔ","Ｏ．ｎｌｙ Ｏｗｎ","Ｏ．ｎｌｙ Ｃｈａｒｇｅ","Ｒ．ａｎｄｏｍ Ｇｌｏｗｓｔｏｎｅ",
    "pedroisgay","krloader",
    "Aut0Cryst3l","Aut0 Cryst3l","Aut0H1tCryst3l","Aut0 H1t Cryst3l","K3yAHC",
    "Aut0 H1t Cryst4l M4cr0","Anch0r Macr0","Anch0r M4cr0","D0uble4nch0r","D0ubl3 4nch0r",
    "S4fe4nch0r","S4fe Anch0r","4nch0r M4cr0",
    "Aut0 T0t3m","L3g1t R3t0t3m","Aut0 D0ubl3 H4nd","Aut0H1tCyst4l","Aut0 Stun","Pr3Ch3ck",
    "Expl0d3 D3l4y","T0t3m Sl0t","Ch4rge D3l4y","M1ss Ch4nce","Expl0de Sl0t","Expl0d3 Sl0t",
    "N0 Dglwst0ne","Clk Sim","P34rl C4tch3r",
    "4ctiv4tK3y","d4m4geT1ck","sw1tchD3lay","ch4rg3D3l4y","expl0d3D3l4y","t0t3mSl0t",
    "simulateClicks","Aut0 XP","Thr0w3 XP f4st","W1nd Ch4rg3","P34rl","4c7 K3y"
)

$cheatStringSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in $cheatStrings) { [void]$cheatStringSet.Add($s) }

function Check-Strings($filePath) {
    $found = [System.Collections.Generic.HashSet[string]]::new()
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($filePath)
        foreach ($entry in ($zip.Entries | Where-Object { $_.Name -match '\.(class|json|jar)$' })) {
            if ($entry.Name -like "*.jar") {
                try {
                    $ms = New-Object System.IO.MemoryStream; $entry.Open().CopyTo($ms); $ms.Position=0
                    $nz = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
                    foreach ($ne in ($nz.Entries | Where-Object { $_.Name -match '\.(class|json)$' })) {
                        $r = New-Object System.IO.StreamReader($ne.Open(), [System.Text.Encoding]::UTF8)
                        $nc = $r.ReadToEnd(); $r.Close()
                        foreach ($s in $cheatStringSet) {
                            if ($nc.IndexOf($s, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { [void]$found.Add($s) }
                        }
                    }
                } catch {}
                continue
            }
            try {
                $r = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
                $ec = $r.ReadToEnd(); $r.Close()
                foreach ($s in $cheatStringSet) {
                    if ($ec.IndexOf($s, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { [void]$found.Add($s) }
                }
            } catch {}
        }
        $zip.Dispose()
    } catch {}
    return $found
}

$verifiedMods = [System.Collections.Generic.List[object]]::new()
$unknownMods  = [System.Collections.Generic.List[object]]::new()
$cheatMods    = [System.Collections.Generic.List[object]]::new()
$tamperedMods = [System.Collections.Generic.List[object]]::new()
$allModsInfo  = [System.Collections.Generic.List[object]]::new()
$jarFiles = Get-ChildItem -Path $mods -Filter *.jar
$spinner = @("|","/","-","\"); $totalMods = $jarFiles.Count

$hashMap = Invoke-BulkHashLookup $jarFiles

Write-Host "Scanning $totalMods mods..." -ForegroundColor White
for ($i = 0; $i -lt $jarFiles.Count; $i++) {
    $file = $jarFiles[$i]
    Write-Host "`r[$($spinner[$i % 4])] Scanning mods: $($i+1) / $totalMods" -ForegroundColor Magenta -NoNewline
    $hash = Get-SHA1 $file.FullName
    $actualSize = $file.Length; $actualSizeKB = [math]::Round($actualSize/1KB, 2)
    $zone = Get-ZoneIdentifier $file.FullName
    $jarInfo = Get-Mod-Info-From-Jar $file.FullName
    $loader = if ($file.Name -match '(?i)fabric'){"Fabric"} elseif ($file.Name -match '(?i)forge'){"Forge"} elseif ($jarInfo.ModLoader -eq "Fabric"){"Fabric"} elseif ($jarInfo.ModLoader -eq "Forge/NeoForge"){"Forge"} else {"Fabric"}

    $md = Fetch-Modrinth-By-Hash $hash
    if (-not $md.Name -and $jarInfo.ModId) { $md = Fetch-Modrinth-By-ModId $jarInfo.ModId $jarInfo.Version $loader }
    if (-not $md.Name) { $md = Fetch-Modrinth-By-Filename $file.Name $loader }

    $entry = [PSCustomObject]@{
        ModName=$md.Name; FileName=$file.Name; Version=$md.VersionNumber; ExpectedSize=$md.ExpectedSize
        ExpectedSizeKB=if($md.ExpectedSize -gt 0){[math]::Round($md.ExpectedSize/1KB,2)} else {0}
        ActualSize=$actualSize; ActualSizeKB=$actualSizeKB; SizeDiff=($actualSize - $md.ExpectedSize)
        SizeDiffKB=[math]::Round(($actualSize - $md.ExpectedSize)/1KB,2); DownloadSource=$zone.Source; SourceURL=$zone.URL
        IsModrinthDownload=$zone.IsModrinth; ModrinthUrl=$md.ModrinthUrl; IsVerified=($md.Name -ne "")
        MatchType=$md.MatchType; ExactMatch=$md.ExactMatch; IsLatestVersion=$md.IsLatestVersion; LoaderType=$md.LoaderType
        PreferredLoader=$loader; FilePath=$file.FullName; FileSizeKB=$actualSizeKB
        JarModId=$jarInfo.ModId; JarName=$jarInfo.Name; JarVersion=$jarInfo.Version; JarModLoader=$jarInfo.ModLoader
        ZoneId=$zone.URL; FileSize=$actualSize; Hash=$hash
    }

    if ($md.Name) {
        $verifiedMods.Add($entry); $allModsInfo.Add($entry)
        if ($md.ExpectedSize -gt 0 -and $actualSize -ne $md.ExpectedSize -and [math]::Abs($actualSize - $md.ExpectedSize) -gt 1024) {
            $tamperedMods.Add($entry)
            $null = $verifiedMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $file.Name })
        }
    } elseif ($mb = Fetch-Megabase $hash) {
        $entry.ModName = $mb.name; $entry.IsVerified = $true
        $verifiedMods.Add($entry); $allModsInfo.Add($entry)
    } else {
        $unknownMods.Add($entry); $allModsInfo.Add($entry)
    }
}

for ($i = 0; $i -lt $unknownMods.Count; $i++) {
    $mod = $unknownMods[$i]
    $mr = if ($mod.JarModId) { Fetch-Modrinth-By-ModId $mod.JarModId $mod.JarVersion $mod.PreferredLoader } else { $null }
    if (-not $mr -or -not $mr.Name) { $mr = Fetch-Modrinth-By-Filename $mod.FileName $mod.PreferredLoader }
    if ($mr -and $mr.Name -and $mr.ExpectedSize -gt 0) {
        $mod.ModName=$mr.Name; $mod.ExpectedSize=$mr.ExpectedSize; $mod.ExpectedSizeKB=[math]::Round($mr.ExpectedSize/1KB,2)
        $mod.SizeDiff=$mod.FileSize-$mr.ExpectedSize; $mod.SizeDiffKB=[math]::Round(($mod.FileSize-$mr.ExpectedSize)/1KB,2)
        $mod.ModrinthUrl=$mr.ModrinthUrl; $mod.MatchType=$mr.MatchType; $mod.ExactMatch=$mr.ExactMatch
        $mod.IsLatestVersion=$mr.IsLatestVersion; $mod.LoaderType=$mr.LoaderType
        $newEntry = $mod.PSObject.Copy(); $newEntry.IsVerified=$true; $newEntry.Version=$mr.VersionNumber
        $verifiedMods.Add($newEntry)
        $null = $unknownMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $mod.FileName })
    }
}

$counter = 0
$tempDir = Join-Path $env:TEMP "yarpletapstanmodanalyzer"
try {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    $null = New-Item -ItemType Directory -Path $tempDir -Force
    Write-Host "`nScanning for cheat strings..." -ForegroundColor White

    foreach ($mod in $allModsInfo) {
        $counter++
        Write-Host "`r[$($spinner[$counter % 4])] Scanning for cheat strings: $counter / $totalMods" -ForegroundColor Magenta -NoNewline

        $s1=0; $s2=0; $tc=0; $obf=0; $num=0; $uni=0; $nov=0; $gib=0; $spkg=0
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($mod.FilePath)
            foreach ($entry in ($zip.Entries | Where-Object { $_.FullName -match '\.class$' })) {
                $tc++
                $cn = [System.IO.Path]::GetFileNameWithoutExtension($entry.Name)
                $segs = ($entry.FullName -replace '\.class$','') -split '/'
                if ($cn -match '^[a-zA-Z]$')    { $s1++ }
                if ($cn -match '^[a-zA-Z]{2}$') { $s2++ }
                if ($cn -match '^\d+$')          { $num++ }
                if ($cn -match '[^\x00-\x7F]')   { $uni++ }
                if ($cn.Length -ge 3 -and $cn -match '^[a-zA-Z]+$') {
                    $v = ($cn.ToCharArray() | Where-Object { $_ -match '[aeiouAEIOU]' }).Count
                    if ($v -eq 0) { $nov++ }
                    if ($cn -match '[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{3,}' -and ($v/$cn.Length) -lt 0.3) { $gib++ }
                }
                foreach ($seg in $segs[0..($segs.Count-2)]) { if ($seg.Length -eq 1) { $spkg++ } }
                $cons=0; $maxC=0
                foreach ($seg in $segs[0..($segs.Count-2)]) { if ($seg.Length -eq 1){$cons++;if($cons -gt $maxC){$maxC=$cons}} else {$cons=0} }
                if ($maxC -ge 3) { $obf++ }
            }
            $zip.Dispose()
        } catch {}

        $s1p=[math]::Round($(if($tc -ge 5){$s1/$tc*100} else {0}))
        $s2p=[math]::Round($(if($tc -ge 5){$s2/$tc*100} else {0}))
        $np=[math]::Round($(if($tc -ge 5){$num/$tc*100} else {0}))
        $up=[math]::Round($(if($tc -ge 5){$uni/$tc*100} else {0}))
        $nvp=[math]::Round($(if($tc -ge 5){$nov/$tc*100} else {0}))
        $gp=[math]::Round($(if($tc -ge 5){$gib/$tc*100} else {0}))
        $op=[math]::Round($(if($tc -ge 10){$obf/$tc*100} else {0}))

        if (($s1p -ge 15 -and $tc -ge 5) -or ($s2p -ge 20 -and $tc -ge 5) -or ($np -ge 20 -and $tc -ge 5) -or
            ($up -ge 10 -and $tc -ge 5) -or ($nvp -ge 8 -and $tc -ge 5) -or ($gp -ge 15 -and $tc -ge 100) -or
            ($spkg -ge 50 -and $tc -ge 10) -or ($op -ge 25 -and $tc -ge 10)) {
            $tamperedMods.Add([PSCustomObject]@{ FileName=$mod.FileName; ModName=$mod.ModName; ActualSizeKB=$mod.ActualSizeKB; ExpectedSizeKB=$mod.ExpectedSizeKB; SizeDiffKB=$mod.SizeDiffKB; TamperReason="Obfuscation patterns detected" })
            $verifiedMods = $verifiedMods | Where-Object { $_.FileName -ne $mod.FileName }
        }

        $strings = Check-Strings $mod.FilePath
        if ($strings.Count -gt 0) {
            $cheatMods.Add([PSCustomObject]@{ FileName=$mod.FileName; StringsFound=$strings; FileSizeKB=$mod.ActualSizeKB; DownloadSource=$mod.DownloadSource; SourceURL=$mod.ZoneId; ExpectedSizeKB=$mod.ExpectedSizeKB; SizeDiffKB=$mod.SizeDiffKB; IsVerifiedMod=$mod.IsVerified; ModName=$mod.ModName; ModrinthUrl=$mod.ModrinthUrl; FilePath=$mod.FilePath; HasSizeMismatch=($mod.SizeDiffKB -ne 0 -and [math]::Abs($mod.SizeDiffKB) -gt 1); JarModId=$mod.JarModId; JarName=$mod.JarName; JarVersion=$mod.JarVersion; MatchType=$mod.MatchType; ExactMatch=$mod.ExactMatch; IsLatestVersion=$mod.IsLatestVersion; LoaderType=$mod.LoaderType })
            $verifiedMods = $verifiedMods | Where-Object { $_.FileName -ne $mod.FileName }
        }
    }
} catch { Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
} finally { if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue } }

Write-Host "`nScanning complete!`n" -ForegroundColor Green

$disallowedMods = @{
    "xeros-minimap"=@{Names=@("Xero's Minimap","Xeros Minimap","xeros-minimap","XerosMinimap","Xero's Minimap Mod")}
    "freecam"=@{Names=@("Freecam","freecam","FreeCam","Free Cam")}
    "health-indicators"=@{Names=@("Health Indicators","health indicators","HealthIndicators","Health Indicators Mod")}
    "clickcrystals"=@{Names=@("ClickCrystals","clickcrystals","ClickCrystals Mod")}
    "mousetweaks"=@{Names=@("Mouse Tweaks","mousetweaks","MouseTweaks")}
    "itemscroller"=@{Names=@("Item Scroller","itemscroller","ItemScroller")}
    "tweakeroo"=@{Names=@("Tweakeroo","tweakeroo")}
}

$disallowedFound = @()
foreach ($file in (Get-ChildItem -Path $mods -Filter *.jar)) {
    $fn = $file.Name.ToLower(); $ji = Get-Mod-Info-From-Jar $file.FullName
    foreach ($slug in $disallowedMods.Keys) {
        $md2 = $disallowedMods[$slug]; $hit = $false
        foreach ($name in $md2.Names) {
            if ($fn -match [regex]::Escape($name.ToLower()) -or $fn -match [regex]::Escape($slug.ToLower()) -or $fn -match [regex]::Escape(($name -replace ' ','').ToLower())) { $hit=$true; break }
        }
        if (-not $hit -and $ji.ModId -and $ji.ModId.ToLower() -match $slug.ToLower()) { $hit=$true }
        if (-not $hit -and $ji.Name -and $ji.Name.ToLower() -match $slug.ToLower()) { $hit=$true }
        if ($hit) { $disallowedFound += [PSCustomObject]@{ FileName=$file.Name; ModName=$md2.Names[0] }; break }
    }
}

function Write-Sep($color="Cyan") { Write-Host ("━"*111) -ForegroundColor $color }
function Write-Card($lines, $color) {
    Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor $color
    foreach ($l in $lines) {
        Write-Host "  ║ " -NoNewline -ForegroundColor $color
        if ($l -is [hashtable]) { Write-Host $l.text -ForegroundColor $l.color }
        else { Write-Host $l -ForegroundColor White }
    }
    Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor $color
    Write-Host ""
}

$summaryPlayers = @()
foreach ($proc in (Get-Process -Name javaw -ErrorAction SilentlyContinue)) {
    try {
        $cl = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction Stop).CommandLine
        if (-not $cl) { continue }
        $pName = if ($cl -match '--username\s+(\S+)') { $matches[1] } else { "Unknown" }
        $pUUID = if ($cl -match '--uuid\s+(\S+)') { $matches[1] } else { "N/A" }
        $summaryPlayers += [PSCustomObject]@{ Name=$pName; UUID=$pUUID }
    } catch {}
}

$allCheatStrings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($mod in $cheatMods) { foreach ($s in $mod.StringsFound) { [void]$allCheatStrings.Add($s) } }

Write-Sep Green; Write-Host "VERIFIED MODS: $($verifiedMods.Count) ✓" -ForegroundColor Green; Write-Sep Green
if ($verifiedMods.Count -gt 0) {
    foreach ($mod in $verifiedMods) {
        if (($tamperedMods | Where-Object { $_.FileName -eq $mod.FileName }).Count -eq 0 -and ($cheatMods | Where-Object { $_.FileName -eq $mod.FileName }).Count -eq 0) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green; Write-Host "$($mod.ModName) " -NoNewline -ForegroundColor White; Write-Host "($($mod.FileName))" -ForegroundColor Green
            Write-Host "    Size: $($mod.ActualSizeKB) KB" -ForegroundColor Green
        }
    }
} else { Write-Host "  No verified mods found" -ForegroundColor Gray }
Write-Host ""

Write-Sep Yellow; Write-Host "UNKNOWN MODS: $($unknownMods.Count) ?" -ForegroundColor Yellow; Write-Sep Yellow
if ($unknownMods.Count -gt 0) {
    foreach ($mod in $unknownMods) {
        Write-Card @(@{text="UNKNOWN MOD";color="Yellow"}, "File: $($mod.FileName)", "Size: $($mod.FileSizeKB) KB") Yellow
        if ($mod.ModName) { Write-Host "  ║ " -NoNewline -ForegroundColor Yellow; Write-Host "Identified as: $($mod.ModName)" -ForegroundColor Cyan }
    }
} else { Write-Host "  No unknown mods found" -ForegroundColor Gray }
Write-Host ""

Write-Sep DarkYellow; Write-Host "TAMPERED MODS: $($tamperedMods.Count) ⚠" -ForegroundColor DarkYellow; Write-Sep DarkYellow
if ($tamperedMods.Count -gt 0) {
    foreach ($mod in $tamperedMods) {
        $sign = if ($mod.SizeDiffKB -gt 0) {"+"} else {""}
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor DarkYellow
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "TAMPERED MOD" -ForegroundColor DarkYellow
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor DarkYellow
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "File: $($mod.FileName)" -ForegroundColor White
        if ($mod.ModName) { Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Mod: $($mod.ModName)" -ForegroundColor Magenta }
        if ($mod.TamperReason) { Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Reason: $($mod.TamperReason)" -ForegroundColor Red }
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB)" -ForegroundColor Magenta
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════`n" -ForegroundColor DarkYellow
    }
} else { Write-Host "  No tampered mods found" -ForegroundColor Gray }
Write-Host ""

Write-Sep Red; Write-Host "CHEAT MODS: $($cheatMods.Count) ⚠" -ForegroundColor Red; Write-Sep Red
if ($cheatMods.Count -gt 0) {
    foreach ($mod in $cheatMods) {
        $dqrkisStrings = @("CwskKkUfHQYB","HgsCDQ49KkUfHQYB","DhsnbQ0LDg0MDA","OhYHBQcOHw","EgQKDiUqRR8WChk","KjoFWRcEAx0M","Hx0GAVkcChwdDA","HSw7RQQIAQQ","BR0sFBcOGg4a","Oh0yWR0MCA")
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "CHEAT MOD DETECTED" -ForegroundColor Red
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "File: $($mod.FileName)" -ForegroundColor White
        if ($mod.ModName) { Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Mod: $($mod.ModName)" -ForegroundColor White }
        if (($mod.StringsFound | Where-Object { $dqrkisStrings -contains $_ }).Count -gt 0) { Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Reason: Dqrkis Client Strings" -ForegroundColor Red }
        Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Detected Cheat Strings:" -ForegroundColor Yellow
        @($mod.StringsFound) | Sort-Object | ForEach-Object { Write-Host "  ║   " -NoNewline -ForegroundColor Red; Write-Host "• $_" -ForegroundColor Magenta }
        if ($mod.ExpectedSizeKB -gt 0) {
            $sign = if ($mod.SizeDiffKB -gt 0){"+"} else {""}
            Write-Host "  ║ " -NoNewline -ForegroundColor Red
            if ($mod.SizeDiffKB -eq 0) { Write-Host "Size matches Modrinth: $($mod.ExpectedSizeKB) KB ✓" -ForegroundColor White }
            else {
                Write-Host "Size: $($mod.FileSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB) | " -NoNewline -ForegroundColor White
                Write-Host "Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Red
            }
        }
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
    }
} else { Write-Host "  No cheat mods detected ✓" -ForegroundColor Green }
Write-Host ""

Write-Sep Red; Write-Host "DISALLOWED MODS: $($disallowedFound.Count) ⚠" -ForegroundColor Red; Write-Sep Red
if ($disallowedFound.Count -gt 0) {
    foreach ($mod in $disallowedFound) { Write-Card @(@{text="DISALLOWED MOD DETECTED";color="Red"}, "File: $($mod.FileName)", "Mod: $($mod.ModName)") Red }
} else { Write-Host "  No disallowed mods detected ✓" -ForegroundColor Green }
Write-Host ""

$verColor   = if ($verifiedMods.Count -gt 0)    { "Green" }  else { "DarkGray" }
$unkColor   = if ($unknownMods.Count -gt 0)     { "Yellow" } else { "DarkGray" }
$tampColor  = if ($tamperedMods.Count -gt 0)    { "Red" }    else { "DarkGray" }
$cheatColor = if ($cheatMods.Count -gt 0)       { "Red" }    else { "DarkGray" }
$disColor   = if ($disallowedFound.Count -gt 0)  { "Red" }   else { "DarkGray" }

Write-Host ""
Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host "  SCAN COMPLETE" -ForegroundColor Cyan
Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host ""

if ($summaryPlayers.Count -gt 0) {
    foreach ($p in $summaryPlayers) {
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Player     " -NoNewline -ForegroundColor White; Write-Host $p.Name -ForegroundColor White
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "UUID       " -NoNewline -ForegroundColor White; Write-Host $p.UUID -ForegroundColor White
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Verified   " -NoNewline -ForegroundColor White; Write-Host $verifiedMods.Count   -ForegroundColor $(if($verifiedMods.Count -eq 0){"DarkGray"} else {$verColor})
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Unknown    " -NoNewline -ForegroundColor White; Write-Host $unknownMods.Count    -ForegroundColor $(if($unknownMods.Count -eq 0){"DarkGray"} else {$unkColor})
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Tampered   " -NoNewline -ForegroundColor White; Write-Host $tamperedMods.Count   -ForegroundColor $(if($tamperedMods.Count -eq 0){"DarkGray"} else {$tampColor})
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Cheat      " -NoNewline -ForegroundColor White; Write-Host $cheatMods.Count      -ForegroundColor $(if($cheatMods.Count -eq 0){"DarkGray"} else {$cheatColor})
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Disallowed " -NoNewline -ForegroundColor White; Write-Host $disallowedFound.Count -ForegroundColor $(if($disallowedFound.Count -eq 0){"DarkGray"} else {$disColor})
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host ""
    }
} else {
    Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Player     " -NoNewline -ForegroundColor White; Write-Host "No Minecraft process detected" -ForegroundColor DarkGray
    Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Verified   " -NoNewline -ForegroundColor White; Write-Host $verifiedMods.Count   -ForegroundColor $(if($verifiedMods.Count -eq 0){"DarkGray"} else {$verColor})
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Unknown    " -NoNewline -ForegroundColor White; Write-Host $unknownMods.Count    -ForegroundColor $(if($unknownMods.Count -eq 0){"DarkGray"} else {$unkColor})
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Tampered   " -NoNewline -ForegroundColor White; Write-Host $tamperedMods.Count   -ForegroundColor $(if($tamperedMods.Count -eq 0){"DarkGray"} else {$tampColor})
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Cheat      " -NoNewline -ForegroundColor White; Write-Host $cheatMods.Count      -ForegroundColor $(if($cheatMods.Count -eq 0){"DarkGray"} else {$cheatColor})
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Disallowed " -NoNewline -ForegroundColor White; Write-Host $disallowedFound.Count -ForegroundColor $(if($disallowedFound.Count -eq 0){"DarkGray"} else {$disColor})
    Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}

if ($allCheatStrings.Count -gt 0) {
    Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Cheat Strings Detected:" -ForegroundColor Red
    $allCheatStrings | Sort-Object | ForEach-Object {
        Write-Host "  ║   " -NoNewline -ForegroundColor Red; Write-Host "• " -NoNewline -ForegroundColor Magenta; Write-Host $_ -ForegroundColor Magenta
    }
    Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
}

if ($disallowedFound.Count -gt 0) {
    Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Disallowed Mods Detected:" -ForegroundColor Red
    foreach ($mod in $disallowedFound) {
        Write-Host "  ║   " -NoNewline -ForegroundColor Red; Write-Host "• " -NoNewline -ForegroundColor Magenta; Write-Host $mod.ModName -ForegroundColor Magenta
    }
    Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
}

Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host "  Credits to Habibi Mod Analyzer" -ForegroundColor DarkGray
Write-Host "  Special Thanks to Tonynoh For Helping me ❤️" -ForegroundColor DarkGrey
Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
