[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

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
Write-Host "YarpLetapStan's Mod Analyzer V8.0 - Join discord.gg/napvp".PadLeft(($lineWidth + 34) / 2) -ForegroundColor Cyan
Write-Host ("━" * $lineWidth) -ForegroundColor Cyan
Write-Host ""

# ══════════════════════════════════════════════════════════════════════════════
#  PEB READER - pulls the true working directory out of a running JVM
# ══════════════════════════════════════════════════════════════════════════════

if (-not ('ProcessHelper' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ProcessHelper
{
    [DllImport("ntdll.dll", SetLastError = true)]
    private static extern int NtQueryInformationProcess(IntPtr ProcessHandle, int ProcessInformationClass, IntPtr ProcessInformation, int ProcessInformationLength, out int ReturnLength);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, IntPtr lpBuffer, int dwSize, out int lpNumberOfBytesRead);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool IsWow64Process(IntPtr hProcess, out bool wow64Process);
    private const int PROCESS_QUERY_INFORMATION = 0x0400;
    private const int PROCESS_VM_READ = 0x0010;
    private static string ReadRemoteUnicodeString(IntPtr hProcess, IntPtr addr)
    {
        IntPtr ustrBuf = Marshal.AllocHGlobal(16);
        try
        {
            int br;
            if (!ReadProcessMemory(hProcess, addr, ustrBuf, 16, out br) || br != 16) return null;
            short length = Marshal.ReadInt16(ustrBuf, 0);
            if (length <= 0) return null;
            IntPtr bufPtr = Marshal.ReadIntPtr(ustrBuf, 8);
            if (bufPtr == IntPtr.Zero) return null;
            IntPtr strBuf = Marshal.AllocHGlobal(length);
            try
            {
                if (!ReadProcessMemory(hProcess, bufPtr, strBuf, length, out br) || br != length) return null;
                return Marshal.PtrToStringUni(strBuf, length / 2);
            }
            finally { Marshal.FreeHGlobal(strBuf); }
        }
        finally { Marshal.FreeHGlobal(ustrBuf); }
    }
    public static string GetCurrentDirectory(int pid)
    {
        IntPtr hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, false, pid);
        if (hProcess == IntPtr.Zero) return null;
        try
        {
            bool wow64;
            if (!IsWow64Process(hProcess, out wow64) || wow64) return null;
            IntPtr pbi = Marshal.AllocHGlobal(48);
            try
            {
                int retLen;
                if (NtQueryInformationProcess(hProcess, 0, pbi, 48, out retLen) != 0) return null;
                IntPtr pebAddr = Marshal.ReadIntPtr(pbi, 8);
                if (pebAddr == IntPtr.Zero) return null;
                IntPtr paramPtrBuf = Marshal.AllocHGlobal(8);
                try
                {
                    int br;
                    if (!ReadProcessMemory(hProcess, pebAddr + 0x20, paramPtrBuf, 8, out br) || br != 8) return null;
                    IntPtr procParams = Marshal.ReadIntPtr(paramPtrBuf);
                    if (procParams == IntPtr.Zero) return null;
                    return ReadRemoteUnicodeString(hProcess, procParams + 0x38);
                }
                finally { Marshal.FreeHGlobal(paramPtrBuf); }
            }
            finally { Marshal.FreeHGlobal(pbi); }
        }
        finally { CloseHandle(hProcess); }
    }
}
"@
}

function Get-ProcessCurrentDirectory([int]$processId) {
    try { return [ProcessHelper]::GetCurrentDirectory($processId) } catch { return $null }
}

function Get-LayoutBases([string]$path) {
    return @($path, (Join-Path $path ".minecraft"), (Join-Path $path "game"), (Join-Path $path "minecraft"))
}

function Resolve-ModsFolder([string]$cwd) {
    if (-not $cwd -or -not (Test-Path $cwd -ErrorAction SilentlyContinue)) { return $null }
    foreach ($base in (Get-LayoutBases $cwd)) {
        $p = Join-Path $base "mods"
        if (Test-Path $p -ErrorAction SilentlyContinue) { return (Get-Item -LiteralPath $p).FullName }
    }
    try {
        foreach ($entry in (Get-ChildItem -LiteralPath $cwd -Directory -ErrorAction SilentlyContinue)) {
            foreach ($base in (Get-LayoutBases $entry.FullName)) {
                $p = Join-Path $base "mods"
                if (Test-Path $p -ErrorAction SilentlyContinue) { return (Get-Item -LiteralPath $p).FullName }
            }
        }
    } catch {}
    return $null
}

function Get-KnownLauncherRoots {
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    $userProfile = $env:USERPROFILE
    $roots = [System.Collections.Generic.List[string]]::new()
    if ($appData) {
        $roots.Add("$appData\.minecraft")
        $roots.Add("$appData\ModrinthApp\profiles")
        $roots.Add("$appData\PrismLauncher\instances")
        $roots.Add("$appData\PolyMC\instances")
        $roots.Add("$appData\MultiMC\instances")
        $roots.Add("$appData\ATLauncher\instances")
        $roots.Add("$appData\.feather\profiles")
        $roots.Add("$appData\gdlauncher_next\instances")
        $roots.Add("$appData\.technic\modpacks")
    }
    if ($localAppData) {
        $roots.Add("$localAppData\.minecraft")
        $roots.Add("$localAppData\Packages")
    }
    if ($userProfile) {
        $roots.Add("$userProfile\curseforge\minecraft\Instances")
        $userProfile, "$userProfile\Documents" | ForEach-Object { $roots.Add("$_\curseforge\minecraft\Instances") }
        $roots.Add("$userProfile\.lunarclient")
        $roots.Add("$userProfile\AppData\Roaming\.minecraft")
        $roots.Add("$userProfile\Documents\PrismLauncher\instances")
    }
    return ($roots | Select-Object -Unique)
}

function Find-CandidateInstanceBases {
    $bases = New-Object System.Collections.Generic.List[string]
    foreach ($root in (Get-KnownLauncherRoots)) {
        if (-not (Test-Path $root -ErrorAction SilentlyContinue)) { continue }
        foreach ($b in (Get-LayoutBases $root)) { $bases.Add($b) }
        foreach ($entry in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
            foreach ($b in (Get-LayoutBases $entry.FullName)) { $bases.Add($b) }
        }
    }
    return $bases
}

function Find-LatestInstanceByLog {
    $bestBase = $null
    $bestTime = [datetime]::MinValue
    $checked = 0
    foreach ($base in (Find-CandidateInstanceBases)) {
        $logPath = Join-Path $base "logs\latest.log"
        if (-not (Test-Path $logPath -ErrorAction SilentlyContinue)) { continue }
        $checked++
        try {
            $t = (Get-Item -LiteralPath $logPath -ErrorAction Stop).LastWriteTime
            if ($t -gt $bestTime) { $bestTime = $t; $bestBase = $base }
        } catch {}
    }
    Write-Host "  [i] Checked $checked instance log(s) across all known launchers" -ForegroundColor DarkGray
    if ($bestBase) { Write-Host "  [i] Newest latest.log: $bestTime  ->  $bestBase" -ForegroundColor DarkGray }
    return $bestBase
}

# ══════════════════════════════════════════════════════════════════════════════
#  INSTANCE DISCOVERY - one entry per running Minecraft process
# ══════════════════════════════════════════════════════════════════════════════

function Get-MinecraftInstances {
    $found = New-Object System.Collections.Generic.List[object]

    $procs = @()
    $procs += @(Get-Process -Name javaw -ErrorAction SilentlyContinue)
    $procs += @(Get-Process -Name java  -ErrorAction SilentlyContinue)

    foreach ($proc in $procs) {
        $cmdLine = $null
        $cimCwd  = $null
        try {
            $info = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction Stop
            $cmdLine = $info.CommandLine
            $cimCwd  = $info.CurrentDirectory
        } catch {}

        $player = "Unknown"; $uuid = "N/A"; $version = $null
        if ($cmdLine) {
            if ($cmdLine -match '--username\s+(\S+)') { $player  = $matches[1] }
            if ($cmdLine -match '--uuid\s+(\S+)')     { $uuid    = $matches[1] }
            if ($cmdLine -match '--version\s+(\S+)')  { $version = $matches[1] }
        }

        $modsFolder = $null; $source = $null

        # 1. PEB read of the live process working directory (works on any launcher,
        #    any custom install location, as long as the JVM is 64-bit)
        $cwd = Get-ProcessCurrentDirectory $proc.Id
        if ($cwd) {
            $modsFolder = Resolve-ModsFolder $cwd
            if ($modsFolder) { $source = "Process CWD (PEB)" }
        }

        # 2. --gameDir on the command line (covers 32-bit JVMs the PEB read skips)
        if (-not $modsFolder -and $cmdLine) {
            $gameDir = $null
            if     ($cmdLine -match '--gameDir\s+"([^"]+)"') { $gameDir = $matches[1] }
            elseif ($cmdLine -match "--gameDir\s+'([^']+)'") { $gameDir = $matches[1] }
            elseif ($cmdLine -match '--gameDir\s+(\S+)')     { $gameDir = $matches[1] }
            if ($gameDir) {
                $modsFolder = Resolve-ModsFolder $gameDir
                if ($modsFolder) { $source = "--gameDir argument" }
            }
        }

        # 3. Win32_Process CurrentDirectory
        if (-not $modsFolder -and $cimCwd) {
            $modsFolder = Resolve-ModsFolder $cimCwd
            if ($modsFolder) { $source = "Win32_Process CWD" }
        }

        $looksLikeMinecraft = $modsFolder -or ($cmdLine -and $cmdLine -match '(?i)(minecraft|net\.fabricmc|cpw\.mods|fabric-loader|forge|net\.minecraft)')
        if (-not $looksLikeMinecraft) { continue }

        $uptime = $null
        try { $uptime = (Get-Date) - $proc.StartTime } catch {}

        $found.Add([PSCustomObject]@{
            ProcessId   = $proc.Id
            ProcessName = $proc.ProcessName
            Player      = $player
            UUID        = $uuid
            LaunchVer   = $version
            ModsFolder  = $modsFolder
            Source      = $source
            CommandLine = $cmdLine
            Uptime      = $uptime
        })
    }
    return $found
}

Write-Host ("━" * 111) -ForegroundColor Yellow
Write-Host "INSTANCE DETECTION" -ForegroundColor Yellow
Write-Host ("━" * 111) -ForegroundColor Yellow
Write-Host ""

$instances = @(Get-MinecraftInstances)

if ($instances.Count -eq 0) {
    Write-Host "  [!] No running Minecraft process found." -ForegroundColor Yellow
    Write-Host "  [i] Falling back to a scan of every known launcher's instance logs...`n" -ForegroundColor DarkGray
    $latestBase = Find-LatestInstanceByLog
    $fallbackMods = if ($latestBase) { Resolve-ModsFolder $latestBase } else { $null }
    if ($fallbackMods) {
        Write-Host "  [+] Using most recently played instance: $fallbackMods`n" -ForegroundColor Green
        $instances = @([PSCustomObject]@{
            ProcessId=$null; ProcessName="(not running)"; Player="Unknown"; UUID="N/A"; LaunchVer=$null
            ModsFolder=$fallbackMods; Source="Newest latest.log"; CommandLine=$null; Uptime=$null
        })
    }
}

# Any process we could not resolve a folder for: ask, but only for that one.
foreach ($inst in $instances) {
    if ($inst.ModsFolder) { continue }
    Write-Host "  [!] Could not auto-detect the mods folder for PID $($inst.ProcessId) (Player: $($inst.Player))" -ForegroundColor Yellow
    Write-Host "      Enter the path manually, or press Enter to skip this instance: " -NoNewline -ForegroundColor DarkGray
    $manual = Read-Host
    if ($manual -and (Test-Path $manual -PathType Container)) {
        $resolved = if ((Split-Path $manual -Leaf) -eq "mods") { (Get-Item -LiteralPath $manual).FullName } else { Resolve-ModsFolder $manual }
        if ($resolved) { $inst.ModsFolder = $resolved; $inst.Source = "Manual entry" }
    }
}

$instances = @($instances | Where-Object { $_.ModsFolder })

if ($instances.Count -eq 0) {
    Write-Host "`n  [!] No mods folder could be resolved. Nothing to scan." -ForegroundColor Red
    Write-Host "  [i] Make sure Minecraft is running, and re-run this as Administrator.`n" -ForegroundColor Yellow
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Two accounts can share one instance folder. Scan each folder once, report every
# player attached to it.
$scanGroups = @()
foreach ($grp in ($instances | Group-Object -Property ModsFolder)) {
    $scanGroups += [PSCustomObject]@{
        ModsFolder = $grp.Name
        Instances  = @($grp.Group)
        Source     = $grp.Group[0].Source
    }
}

Write-Host "  [+] Detected $($instances.Count) Minecraft process(es) across $($scanGroups.Count) instance folder(s)`n" -ForegroundColor Green
foreach ($g in $scanGroups) {
    Write-Host "  ┌─ Mods folder : $($g.ModsFolder)" -ForegroundColor Green
    Write-Host "  ├─ Found via   : $($g.Source)" -ForegroundColor DarkGreen
    foreach ($i in $g.Instances) {
        $up = if ($i.Uptime) { "$($i.Uptime.Hours)h $($i.Uptime.Minutes)m $($i.Uptime.Seconds)s" } else { "n/a" }
        Write-Host "  ├─ $($i.ProcessName) PID $($i.ProcessId) | Player: $($i.Player) | Uptime: $up" -ForegroundColor DarkGreen
    }
    Write-Host "  └─" -ForegroundColor Green
}
Write-Host ""

# ══════════════════════════════════════════════════════════════════════════════
#  JVM ARGUMENT INJECTION SCANNER
# ══════════════════════════════════════════════════════════════════════════════

$fabricPatterns = @{
    "fabric.addMods"='-Dfabric\.addMods='; "fabric.loadMods"='-Dfabric\.loadMods='; "fabric.classPathGroups"='-Dfabric\.classPathGroups='; "fabric.gameJarPath"='-Dfabric\.gameJarPath='; "fabric.skipMcProvider"='-Dfabric\.skipMcProvider='; "fabric.development"='-Dfabric\.development='; "fabric.allowUnsupportedVersion"='-Dfabric\.allowUnsupportedVersion='; "fabric.remapClasspathFile"='-Dfabric\.remapClasspathFile='; "fabric.skipIntermediary"='-Dfabric\.skipIntermediary='; "fabric.configDir"='-Dfabric\.configDir='; "fabric.loader.config"='-Dfabric\.loader\.config='; "fabric.log.level"='-Dfabric\.log\.level='; "fabric.debug.dumpClasspath"='-Dfabric\.debug\.dumpClasspath='; "fabric.log.config"='-Dfabric\.log\.config='; "fabric.dli.config"='-Dfabric\.dli\.config='; "fabric.mixin.configs"='-Dfabric\.mixin\.configs='; "fabric.mixin.hotSwap"='-Dfabric\.mixin\.hotSwap='; "fabric.mixin.debug.export"='-Dfabric\.mixin\.debug\.export='; "fabric.mixin.debug.verbose"='-Dfabric\.mixin\.debug\.verbose='; "fabric.gameVersion"='-Dfabric\.gameVersion='; "fabric.forceVersion"='-Dfabric\.forceVersion='; "fabric.autoDetectVersion"='-Dfabric\.autoDetectVersion='; "fabric.launcher.name"='-Dfabric\.launcher\.name='; "fabric.launcher.brand"='-Dfabric\.launcher\.brand='; "fabric.mods.toml.path"='-Dfabric\.mods\.toml\.path='; "fabric.customModList"='-Dfabric\.customModList='; "fabric.resolve.modFiles"='-Dfabric\.resolve\.modFiles='; "fabric.skipDependencyResolution"='-Dfabric\.skipDependencyResolution='; "fabric.loader.entrypoints"='-Dfabric\.loader\.entrypoints='; "fabric.language.providers"='-Dfabric\.language\.providers=';
    "forge.addMods"='-Dforge\.addMods='; "forge.mods"='-Dforge\.mods='; "fml.coreMods.load"='-Dfml\.coreMods\.load='; "forge.coreMods.dir"='-Dforge\.coreMods\.dir='; "forge.modDir"='-Dforge\.modDir='; "forge.modsDirectories"='-Dforge\.modsDirectories='; "fml.customModList"='-Dfml\.customModList='; "forge.disableModScan"='-Dforge\.disableModScan='; "forge.modList"='-Dforge\.modList='; "forge.forceVersion"='-Dforge\.forceVersion='; "forge.disableUpdateCheck"='-Dforge\.disableUpdateCheck='; "forge.logging.mojang.level"='-Dforge\.logging\.mojang\.level='; "forge.mixin.hotSwap"='-Dforge\.mixin\.hotSwap='; "forge.resourcePack"='-Dforge\.resourcePack='; "forge.defaultResourcePack"='-Dforge\.defaultResourcePack='; "forge.texturePacks"='-Dforge\.texturePacks='; "forge.assetIndex"='-Dforge\.assetIndex='; "forge.assetsDir"='-Dforge\.assetsDir=';
    "javaSecurityManager"='-Djava\.security\.manager='; "javaSecurityPolicy"='-Djava\.security\.policy='; "bootClasspath"='-Xbootclasspath'; "systemClassLoader"='-Djava\.system\.class\.loader='; "javaClassPath"='-Djava\.class\.path='; "cp"='-cp\s+["''][^"'';]*\.jar';
    "cheatClientBrand"='-D(client|launcher)\.brand=(Wurst|Aristois|Impact|Kilo|Future|Lambda|Rusher|Konas|Phobos|Salhack|ForgeHax|Mathax|Meteor|Async|Seppuku|Xatz|Wolfram|Huzuni|Jigsaw|Zamorozka|Moon|Rage|Exhibition|Virtue|Novoline|Rekt|Skid|Ares|Abyss|Thunder|Tenacity|Rise|Flux|Gamesense|Intent|Remix|Sight|Vape|Shield|Ghost|Crispy|Inertia)';
    "javaAgent"='-javaagent:'; "agentLib"='-agentlib:jdwp'; "agentPath"='-agentpath:';
    "optifine"='-Doptifine\.'; "shadersmod"='-Dshaders?\.'; "shaderPack"='-Dshader[sP]ack='; "cheatPattern"='-D(xray|fly|speed|killaura|reach|esp|wallhack|noclip|autoclick|aimbot|triggerbot|antiknockback|nofall|timer|step|fullbright|nightvision|cavefinder)\.'
}
$cheatClients = @('Wurst','Aristois','Impact','Kilo','Future','Lambda','Rusher','Konas','Phobos','Salhack','ForgeHax','Mathax','Meteor','Async','Seppuku','Xatz','Wolfram','Huzuni','Jigsaw','Zamorozka','Moon','Rage','Exhibition','Virtue','Novoline','Rekt','Skid','Ares','Abyss','Thunder','Tenacity','Rise','Flux','Gamesense','Intent','Remix','Sight','Vape','Shield','Ghost','Crispy','Inertia')
$legitAgents = @('jmxremote','yjp','jrebel','newrelic','jacoco','theseus')

function Invoke-JvmArgScan {
    param($Instance)

    $cmdLine = $Instance.CommandLine
    if (-not $cmdLine) {
        Write-Host "  └─ [!] Could not retrieve command line for PID $($Instance.ProcessId)" -ForegroundColor DarkYellow
        Write-Host "      [i] Run as Administrator for complete detection.`n" -ForegroundColor DarkYellow
        return $false
    }

    Write-Host "  ┌─ Process: PID $($Instance.ProcessId) | Player: $($Instance.Player)" -ForegroundColor Green
    if ($Instance.UUID -ne "N/A") { Write-Host "  ├─ UUID: $($Instance.UUID)" -ForegroundColor DarkGreen }

    if ($cmdLine -match '^"([^"]+)"') { $cmdLine = $cmdLine.Substring($matches[1].Length + 2).Trim() }

    $detectedPatterns = @(); $suspiciousArgs = @()
    foreach ($k in $fabricPatterns.Keys) {
        if ($k -eq "addOpens" -or $k -eq "addExports") { continue }
        if ($cmdLine -match $fabricPatterns[$k]) {
            if ($k -eq "javaAgent") {
                $agentHits = @()
                foreach ($m in [regex]::Matches($cmdLine, '-javaagent:([^\s"]+)')) {
                    $agentName = [System.IO.Path]::GetFileName($m.Groups[1].Value.Trim('"').Trim("'"))
                    $isLegit = $false
                    foreach ($la in $legitAgents) { if ($agentName -match $la) { $isLegit = $true; break } }
                    if (-not $isLegit) { $agentHits += $m.Value }
                }
                if ($agentHits.Count -eq 0) { continue }
                $suspiciousArgs += $agentHits
            }
            $detectedPatterns += $k
            $suspiciousArgs += ($cmdLine -split '\s+' | Where-Object { $_ -match $fabricPatterns[$k] })
        }
    }
    foreach ($cc in $cheatClients) {
        if ($cmdLine -match "(?i)\b$cc\b" -and $detectedPatterns -notcontains "CheatClient-$cc") { $detectedPatterns += "CheatClient-$cc" }
    }
    if ($cmdLine -match '(%3B|%26%26|%7C%7C|%7C|%60|%24|%3C|%3E)') { $detectedPatterns += "EncodedInjection" }

    if ($detectedPatterns.Count -gt 0) {
        Write-Host "  ├─ [X] JVM INJECTION DETECTED`n" -ForegroundColor Red
        Write-Host "  │  Detected JVM Arguments:" -ForegroundColor Yellow
        $suspiciousArgs | Select-Object -Unique | ForEach-Object { Write-Host "  │    • $_" -ForegroundColor Magenta }
        Write-Host "`n  │  Detected Pattern Categories:" -ForegroundColor Yellow
        $grouped = @{}
        foreach ($p in $detectedPatterns) {
            $t = if ($p -match "^(fabric|forge|javaSecurity|bootClasspath|systemClassLoader|javaClassPath|cp|cheatClient|javaAgent|agentLib|agentPath|optifine|shadersmod|shaderPack|cheatPattern|EncodedInjection)") { $matches[1] } else { "other" }
            if (-not $grouped[$t]) { $grouped[$t] = @() }
            $grouped[$t] += $p
        }
        $typeMap = @{ fabric="Fabric Injection"; forge="Forge Injection"; javaSecurity="Security Bypass"; bootClasspath="Classpath Manipulation"; systemClassLoader="Class Loader"; javaClassPath="Class Path"; cp="Classpath (-cp)"; cheatClient="Cheat Client"; javaAgent="JVM Agent"; agentLib="JDWP Debug Agent"; agentPath="Native Agent"; optifine="Optifine/Shaders"; shadersmod="Shader Mod"; shaderPack="Shader Pack"; cheatPattern="Cheat Pattern"; EncodedInjection="Encoded Injection"; other="Other" }
        foreach ($t in $grouped.Keys | Sort-Object) {
            Write-Host "  │    └─ $($typeMap[$t])" -ForegroundColor White
            $grouped[$t] | ForEach-Object { Write-Host "  │        • $($_ -replace 'CheatClient-','')" -ForegroundColor Red }
        }
        Write-Host "`n  └─ ! WARNING: Potential cheat client or mod injection detected!`n" -ForegroundColor Red
        return $true
    }

    Write-Host "  └─ [+] No JVM injection patterns detected`n" -ForegroundColor Green
    return $false
}

# ══════════════════════════════════════════════════════════════════════════════
#  MOD METADATA + MODRINTH LOOKUP
# ══════════════════════════════════════════════════════════════════════════════

$modrinthCache = @{}
$projectCache  = @{}
$fileHashCache = @{}
$minecraftVersion = $null

function Get-SHA1($p) {
    if ($fileHashCache.ContainsKey($p)) { return $fileHashCache[$p] }
    $h = (Get-FileHash -Path $p -Algorithm SHA1).Hash
    $fileHashCache[$p] = $h
    return $h
}

function Get-ZoneIdentifier($p) {
    try {
        $raw = Get-Content -Raw -Stream Zone.Identifier $p -ErrorAction SilentlyContinue
        if ($raw -match "HostUrl=(.+)") {
            $url = $matches[1]
            $src = switch -regex ($url) { "modrinth\.com"{"Modrinth"} "curseforge\.com"{"CurseForge"} "github\.com"{"GitHub"} "discord"{"Discord"} "mediafire\.com"{"MediaFire"} "dropbox\.com"{"Dropbox"} "drive\.google\.com"{"Google Drive"} "mega\.nz|mega\.co\.nz"{"MEGA"} "anydesk\.com"{"AnyDesk"} "doomsdayclient\.com"{"DoomsdayClient"} "prestigeclient\.vip"{"PrestigeClient"} "198macros\.com"{"198Macros"} "dqrkis\.xyz"{"Dqrkis"} default{"Other"} }
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
        $e = $zip.Entries | Where-Object { $_.FullName -eq 'META-INF/mods.toml' -or $_.FullName -eq 'META-INF/neoforge.mods.toml' } | Select-Object -First 1
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

function Get-Minecraft-Version-From-Mods($modsFolder, $Instance) {
    $mcVersions = @{}; $modsScanned = 0
    Write-Host "  [i] Analyzing mods for Minecraft version..." -ForegroundColor Cyan
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
        Write-Host "  [i] Detected Minecraft version: $($best.Key) (from $($best.Value) out of $modsScanned mods)" -ForegroundColor Cyan
        return $best.Key
    }
    if ($Instance -and $Instance.CommandLine) {
        foreach ($pat in @('versions[/\\](\d+\.\d+(?:\.\d+)?)[/\\]','-Dminecraft\.version=(\d+\.\d+(?:\.\d+)?)','-Dfabric\.gameVersion=(\d+\.\d+(?:\.\d+)?)','--version\s+(\d+\.\d+(?:\.\d+)?)')) {
            if ($Instance.CommandLine -match $pat) { Write-Host "  [i] Detected Minecraft version from process: $($matches[1])" -ForegroundColor Cyan; return $matches[1] }
        }
    }
    Write-Host "  [!] Could not auto-detect Minecraft version - version filtering will be skipped." -ForegroundColor DarkYellow
    return $null
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
function Get-ModrinthProject($id) {
    $key = [string]$id
    if ($projectCache.ContainsKey($key)) { return $projectCache[$key] }
    $p = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$id" -UseBasicParsing
    if ($p.id) { $projectCache[[string]$p.id] = $p }
    if ($p.slug) { $projectCache[[string]$p.slug] = $p }
    $projectCache[$key] = $p
    return $p
}

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
                         LoaderType=$(if ($resp.loaders -contains "fabric"){"Fabric"} elseif ($resp.loaders -contains "forge"){"Forge"} else{"Unknown"}) }
        }
    } catch {}
    $modrinthCache["hash:$hash"] = $result
    return $result
}

function Fetch-By-ProjectId($id, $version, $preferredLoader) {
    try {
        $proj = Get-ModrinthProject $id; $versions = Get-ModrinthVersions $id
        $matched = Find-Closest-Version $version $versions $preferredLoader $minecraftVersion
        if ($matched) { return Build-ModrinthResult $proj $matched $versions -matchType $(if ($matched.version_number -eq $version){"Exact Version"} else {"Closest Version"}) }
        $fallback = $versions | Where-Object { ($_.loaders -contains $preferredLoader.ToLower()) -and ((-not $minecraftVersion) -or ($_.game_versions -contains $minecraftVersion)) } | Select-Object -First 1
        if (-not $fallback) { $fallback = $versions[0] }
        if ($fallback) { return Build-ModrinthResult $proj $fallback $versions -matchType "Latest Version" }
    } catch {}
    return $null
}

function Fetch-Modrinth-By-ModId($modId, $version, $preferredLoader="Fabric") {
    $cacheKey = "modid:$modId|$version|$preferredLoader|$minecraftVersion"
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
    $cacheKey = "filename:$filename|$preferredLoader|$minecraftVersion"
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
            if ($matched) { $r = Build-ModrinthResult $proj $matched $versions -matchType $(if ($matched.version_number -eq $localVer){"Exact Version"} else{"Closest Version"}); $modrinthCache[$cacheKey] = $r; return $r }
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
    foreach ($file in $jarFiles) { $hashMap[(Get-SHA1 $file.FullName)] = $file }

    $pending = @($hashMap.Keys | Where-Object { -not $modrinthCache.ContainsKey("hash:$_") })
    if ($pending.Count -eq 0) { return $hashMap }

    try {
        $body = @{ hashes = $pending; algorithm = "sha1" } | ConvertTo-Json
        $raw = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_files" -Method POST -ContentType "application/json" -Body $body -UseBasicParsing

        $versionsByHash = @{}
        $projectIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($prop in $raw.PSObject.Properties) {
            $versionsByHash[$prop.Name] = $prop.Value
            if ($prop.Value.project_id) { [void]$projectIds.Add([string]$prop.Value.project_id) }
        }

        if ($projectIds.Count -gt 0) {
            try {
                $idsJson = '[' + ((@($projectIds) | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
                $projects = Invoke-RestMethod -Uri ("https://api.modrinth.com/v2/projects?ids=" + [uri]::EscapeDataString($idsJson)) -UseBasicParsing
                foreach ($p in $projects) {
                    if ($p.id) { $projectCache[[string]$p.id] = $p }
                    if ($p.slug) { $projectCache[[string]$p.slug] = $p }
                }
            } catch {}
        }

        foreach ($hash in $versionsByHash.Keys) {
            $ver = $versionsByHash[$hash]
            try {
                $proj = Get-ModrinthProject $ver.project_id
                $modrinthCache["hash:$hash"] = @{
                    Name=$proj.title; Slug=$proj.slug; ExpectedSize=$ver.files[0].size
                    VersionNumber=$ver.version_number; FileName=$ver.files[0].filename
                    ModrinthUrl="https://modrinth.com/mod/$($proj.slug)/version/$($ver.id)"
                    FoundByHash=$true; ExactMatch=$true; IsLatestVersion=$false; MatchType="Exact Hash"
                    LoaderType=$(if ($ver.loaders -contains "fabric"){"Fabric"} elseif ($ver.loaders -contains "forge"){"Forge"} else{"Unknown"})
                }
            } catch {}
        }
    } catch {
        Write-Host "  [!] Bulk lookup failed, falling back to individual lookups: $($_.Exception.Message)`n" -ForegroundColor DarkYellow
    }
    return $hashMap
}

# ══════════════════════════════════════════════════════════════════════════════
#  CHEAT STRING ENGINE
# ══════════════════════════════════════════════════════════════════════════════

$cheatStrings = @(
    "isObsidianOrBedrock","isValidCrystalPosition","processAnchorPvP","isValidAnchorPosition","speedPotSlot","strengthPotSlot","preventSwordBlockBreaking","preventSwordBlockAttack",
    "Sw1tch","D3l4y","M1n","Pl4ce","T0t3m","Sl0t","Expl0de","Aut0",
    "Cry5t4l","C11ckGu1","obsPos","crystalslot","findKnockbackSword","attackRegisteredThisClick","freecam","pushOutOfBlocks",
    "onPushOutOfBlocks","MAX_ESPERA_TICKS","posCristal","modifyDecrementAmount","preventSwordFromBlockAttack","preventSwordFromBlockBreaking","shouldBlockBlockHit","lwfh",
    "Donut","setBlockBreakingCooldown","getBlockBreakingCooldown","setItemUseCooldown","onBlockBreaking","invokeDoAttack","invokeDoItemUse","setSelectedSlot",
    "getSelectedSlot","swapBackToOriginalSlot","blockBreakingCooldown","invokeOnMouseButton","onSwapLastAttackedTicksReset","getVisualAttackCooldownProgressPerTick","getHandSwingDuration","onBeginRenderTick",
    "PlayerMoveC2SPacketAccessor","redirectSelectedSlot","hookCancelBlockBreaking","EndCrystalItemMixin","arrayOfString","lvstrng","dqrkis","StringObfuscator",
    "POT_CHEATS","onShouldRenderBlockOutline","predictCrystals","noOffhandTotem","getNearByCrystals","slotExplode","needToPlaceRails","findTotemSlot",
    "activateOnRightClick","crystalPlaceClock","isDeadBodyNearby","CrystalTwiceClock","mainHandStack","attackInAir","attackOnJump","onDestruct",
    "getGlowstoneChance","isAutoCharge","getPlaceChance","getSwitchDelay","getGlowstoneDelay","getExplodeDelay","getExplodeSlotIndex","getPlaceDelayTicks",
    "getBreakDelayTicks","getBreakChance","isSpawnersEnabled","isShulkersEnabled","onModuleDisabled","switchToBestTool","switchToBestWeapon","isLootProtect",
    "getMinHunger","isTracersEnabled","getSelectedBlocks","isChestsEnabled","4ctivat K3y","D4m4ge T1ck","Sw1tch D3lay","Ch4rg3 D3l4y",
    "inventoryToMenuSlot","throwPearl","isLeftHoldOnly","Automatically switches to sword when hitting with totem","Failed to switch to mace after axe!","Breaking shield with axe...","TrilliumSolutions","CwskKkUfHQYB",
    "HgsCDQ49KkUfHQYB","DhsnbQ0LDg0MDA","OhYHBQcOHw","EgQKDiUqRR8WChk","KjoFWRcEAx0M","Hx0GAVkcChwdDA","HSw7RQQIAQQ","BR0sFBcOGg4a",
    "Oh0yWR0MCA","pedroisgay","krloader","K3yAHC","Aut0 H1t Cryst4l M4cr0","D0ubl3 4nch0r","Aut0H1tCyst4l","Pr3Ch3ck",
    "Expl0d3 D3l4y","T0t3m Sl0t","Ch4rge D3l4y","M1ss Ch4nce","Expl0de Sl0t","Expl0d3 Sl0t","N0 Dglwst0ne","Clk Sim",
    "P34rl C4tch3r","4ctiv4tK3y","d4m4geT1ck","sw1tchD3lay","ch4rg3D3l4y","expl0d3D3l4y","t0t3mSl0t","simulateClicks",
    "Aut0 XP","Thr0w3 XP f4st","W1nd Ch4rg3","P34rl","4c7 K3y"
)

$cheatStringSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in $cheatStrings) { [void]$cheatStringSet.Add($s) }

$strongNames = @(
    "AutoCrystal","AutoHitCrystal","CrystalAura","CrystalMacro","AutoCrystalPlaceClock",
    "DontPlaceCrystal","DontBreakCrystal","CanPlaceCrystalServer","KanPlaceKrystalServer",
    "EsperandoCristal","BuscarCristal",
    "clickSimulation","switchDelay","switchChance","placeChance","glowstoneDelay","glowstoneChance","explodeDelay","explodeChance",
    "explodeSlot","antiWeakness","damageTick","breakChance","breakDelay","stopOnCrystal","processCrystal","swapToWeapon",
    "AutoAnchor","DoubleAnchor","SafeAnchor","AirAnchor","AnchorMacro","AnchorAura",
    "AnchorTweaks","AnchorAction",
    "AutoTotem","HoverTotem","InventoryTotem","LegitTotem","LegitReTotem","ForceTotem",
    "OffhandTotem","TotemSwitch","ReOffhandTotem",
    "AutoPot","AutoPotRefill","AutoNethPot","AutoArmor","AutoDoubleHand","AutoClicker",
    "AutoFirework","AutoEat","AutoMine","AutoWeb","AntiWeb","WebMacro",
    "AutoMace","MaceSwap","SpearSwap","StunSlam","Macro198","AutoDtap",
    "AimAssist","TriggerBot","SilentAim","AimLock","KillAura","ClickAura","MultiAura",
    "LegitAura","BowAimbot","ShieldDisabler","ShieldBreaker","AxeSpam",
    "FakeLag","PingSpoof","FakeInv","FakePunch","PackSpoof","AntiKnockback",
    "ElytraSwap","KeyPearl","LootYeeter","AutoBreach","FastPlace","JumpReset","PopSwitch",
    "SprintReset","ChestSteal","BaseFinder","StashFinder","SelfDestruct",
    "WalksyOptimizer","WalskyOptimizer","WalksyCrystalOptimizerMod",
    "AuthBypass","LicenseCheckMixin","ObfuscatedAuth","GrimBypass","GrimDisabler",
    "GrimVelocity","VulcanBypass","MatrixBypass","WatchdogBypass","IntaveBypass",
    "VerusDisabler","AACBypass",
    "DqrkisClient","NovaClient","DoomsdayClient","PrestigeClient","VapeClient","VapeLite",
    "LiquidBounce","MeteorClient","RusherHack","ImpactClient","FutureClient",
    "CatleanClient","AsteriaClient","XenonClient","GypsyClient",
    "Aut0Cryst3l","Aut0Cryst4l","Aut0H1tCryst3l","Aut0H1tCryst4l","Anch0rMacr0",
    "Anch0rM4cr0","4nch0rM4cr0","D0uble4nch0r","D0ubl3Anch0r","S4feAnch0r","S4fe4nch0r",
    "Aut0T0t3m","H0verT0t3m","L3g1tR3t0t3m","Aut0D0ubl3H4nd","Aut0Stun"
)

$strongNeedleMap = @{}
foreach ($name in $strongNames) {
    $k = ($name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
    if ($k.Length -ge 5 -and -not $strongNeedleMap.ContainsKey($k)) { $strongNeedleMap[$k] = $name }
}
$strongKeysByLen = @($strongNeedleMap.Keys | Sort-Object -Property Length -Descending)

$fwLabelMap = @{}
foreach ($s in $cheatStrings) {
    if ($s -notmatch '[a-zA-Z]') { continue }
    $k = ($s -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
    if ($k.Length -ge 5 -and -not $fwLabelMap.ContainsKey($k) -and -not $strongNeedleMap.ContainsKey($k)) { $fwLabelMap[$k] = $s }
}
$fwLabelKeysByLen = @($fwLabelMap.Keys | Sort-Object -Property Length -Descending)

$scanSource = @'
using System;
using System.Collections.Generic;
using System.Text;

public static class YarpScan
{
    public static string[] ExactNeedles = new string[0];
    public static string[] StrongKeys = new string[0];
    public static string[] StrongNames = new string[0];
    public static string[] ObfNeedles = new string[0];
    public static string[] ObfNames = new string[0];

    public static string Normalize(string text)
    {
        StringBuilder sb = new StringBuilder(text.Length);
        bool boundary = true;
        for (int i = 0; i < text.Length; i++)
        {
            char c = text[i];
            int code = (int)c;
            if (code >= 0xFF01 && code <= 0xFF5E) { c = (char)(code - 0xFEE0); }
            else if (code == 0x3000) { c = ' '; }
            if (c == ' ' || c == '\t' || c == '.' || c == '-' || c == '_') { continue; }
            if (c >= 'A' && c <= 'Z') { sb.Append((char)(c + 32)); boundary = false; }
            else if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) { sb.Append(c); boundary = false; }
            else { if (!boundary) { sb.Append('\n'); boundary = true; } }
        }
        return sb.ToString();
    }

    public static List<string> Scan(string content, List<string> fwRuns, List<string> obfHits)
    {
        List<string> found = new List<string>();
        for (int i = 0; i < ExactNeedles.Length; i++)
        {
            if (content.IndexOf(ExactNeedles[i], StringComparison.OrdinalIgnoreCase) >= 0) { found.Add(ExactNeedles[i]); }
        }
        for (int i = 0; i < ObfNeedles.Length; i++)
        {
            if (!obfHits.Contains(ObfNames[i]) && content.IndexOf(ObfNeedles[i], StringComparison.Ordinal) >= 0) { obfHits.Add(ObfNames[i]); }
        }
        string norm = Normalize(content);
        for (int i = 0; i < StrongKeys.Length; i++)
        {
            if (norm.IndexOf(StrongKeys[i], StringComparison.Ordinal) >= 0) { found.Add(StrongNames[i]); }
        }
        int runStart = -1; int runEndFw = -1; int fwCount = 0;
        for (int i = 0; i < content.Length; i++)
        {
            char c = content[i];
            int code = (int)c;
            bool isFw = (code >= 0xFF01 && code <= 0xFF5E) || code == 0x3000;
            if (isFw)
            {
                if (runStart < 0) { runStart = i; fwCount = 0; }
                runEndFw = i; fwCount++;
            }
            else if (runStart >= 0 && i == runEndFw + 1 && (c == ' ' || c == '.' || c == '-' || c == '_'))
            {
            }
            else
            {
                if (runStart >= 0 && fwCount >= 2) { fwRuns.Add(content.Substring(runStart, runEndFw - runStart + 1)); }
                runStart = -1; runEndFw = -1; fwCount = 0;
            }
        }
        if (runStart >= 0 && fwCount >= 2) { fwRuns.Add(content.Substring(runStart, runEndFw - runStart + 1)); }
        return found;
    }
}
'@
if (-not ("YarpScan" -as [type])) { Add-Type -TypeDefinition $scanSource }

$obfSignatures = @(
    @{Sig="dev/skidfuscator";       Name="Skidfuscator"},
    @{Sig="skidfuscator.dev";       Name="Skidfuscator"},
    @{Sig="Skidfuscator";           Name="Skidfuscator"},
    @{Sig="dev/paramorphism";       Name="Paramorphism"},
    @{Sig="paramorphism-";          Name="Paramorphism"},
    @{Sig="Paramorphism";           Name="Paramorphism"},
    @{Sig="me/itzsomebody/radon";   Name="Radon"},
    @{Sig="ItzSomebody/Radon";      Name="Radon"},
    @{Sig="Radon Obfuscator";       Name="Radon"},
    @{Sig="dev/sim0n/caesium";      Name="Caesium"},
    @{Sig="sim0n/Caesium";          Name="Caesium"},
    @{Sig="Caesium Obfuscator";     Name="Caesium"},
    @{Sig="vimasig/Bozar";          Name="Bozar"},
    @{Sig="com/bozar";              Name="Bozar"},
    @{Sig="Bozar Obfuscator";       Name="Bozar"},
    @{Sig="branchlock.dev";         Name="Branchlock"},
    @{Sig="Branchlock";             Name="Branchlock"},
    @{Sig="com/binscure";           Name="Binscure"},
    @{Sig="Binscure";               Name="Binscure"},
    @{Sig="superblaubeere27";       Name="SuperBlaubeere27"},
    @{Sig="superblaubeere";         Name="SuperBlaubeere27"},
    @{Sig="Qprotect";               Name="Qprotect"},
    @{Sig="QProtect";               Name="Qprotect"},
    @{Sig="ZKMFLOW";                Name="Zelix KlassMaster"},
    @{Sig="ZelixKlassMaster";       Name="Zelix KlassMaster"},
    @{Sig="com/zelix";              Name="Zelix KlassMaster"},
    @{Sig="StringerJavaObfuscator"; Name="Stringer"},
    @{Sig="com/licel/stringer";     Name="Stringer"},
    @{Sig="jnic.obf";               Name="JNIC"},
    @{Sig="jnic-obfuscator";        Name="JNIC"},
    @{Sig="ScutiObf";               Name="Scuti"},
    @{Sig="scuti.obf";              Name="Scuti"},
    @{Sig="SmokeObf";               Name="Smoke"},
    @{Sig="smoke.obf";              Name="Smoke"}
)

[YarpScan]::ExactNeedles = [string[]]@($cheatStringSet)
[YarpScan]::StrongKeys   = [string[]]$strongKeysByLen
[YarpScan]::StrongNames  = [string[]]@($strongKeysByLen | ForEach-Object { $strongNeedleMap[$_] })
[YarpScan]::ObfNeedles   = [string[]]@($obfSignatures | ForEach-Object { $_.Sig })
[YarpScan]::ObfNames     = [string[]]@($obfSignatures | ForEach-Object { $_.Name })

function Resolve-FullwidthRuns {
    param($Runs)
    $resolved = [System.Collections.Generic.HashSet[string]]::new()
    $unknown  = @{}

    foreach ($run in $Runs) {
        $norm = ([YarpScan]::Normalize($run)) -replace "`n",''
        if ($norm.Length -lt 3) { continue }

        $hit = $null
        foreach ($k in $strongKeysByLen) { if ($norm.Contains($k)) { $hit = $strongNeedleMap[$k]; break } }
        if (-not $hit) {
            foreach ($k in $fwLabelKeysByLen) { if ($norm.Contains($k)) { $hit = $fwLabelMap[$k]; break } }
        }
        if ($hit) { [void]$resolved.Add($hit); continue }
        if ($norm.Length -ge 6 -and -not $unknown.ContainsKey($norm)) { $unknown[$norm] = $run }
    }

    $final = [System.Collections.Generic.HashSet[string]]::new()
    $keys  = @($unknown.Keys)
    foreach ($k in $keys) {
        $redundant = $false
        foreach ($other in $keys) {
            if ($k.Length -lt $other.Length -and $other.Contains($k)) { $redundant = $true; break }
        }
        if (-not $redundant) { [void]$final.Add($unknown[$k]) }
    }

    return @{ Resolved = $resolved; Unknown = $final }
}

function Check-Strings($filePath) {
    $found   = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $fwRuns  = [System.Collections.Generic.List[string]]::new()
    $obfHits = [System.Collections.Generic.List[string]]::new()

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($filePath)
        foreach ($entry in ($zip.Entries | Where-Object { $_.Name -match '\.(class|json|jar)$' })) {
            if ($entry.Name -like "*.jar") {
                try {
                    $ms = New-Object System.IO.MemoryStream; $entry.Open().CopyTo($ms); $ms.Position=0
                    $nz = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
                    foreach ($ne in ($nz.Entries | Where-Object { $_.Name -match '\.(class|json)$' })) {
                        try {
                            $r = New-Object System.IO.StreamReader($ne.Open(), [System.Text.Encoding]::UTF8)
                            foreach ($h in [YarpScan]::Scan($r.ReadToEnd(), $fwRuns, $obfHits)) { [void]$found.Add($h) }
                            $r.Close()
                        } catch {}
                    }
                    $nz.Dispose()
                } catch {}
                continue
            }
            try {
                $r = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
                foreach ($h in [YarpScan]::Scan($r.ReadToEnd(), $fwRuns, $obfHits)) { [void]$found.Add($h) }
                $r.Close()
            } catch {}
        }
        $zip.Dispose()
    } catch {}

    $fw = Resolve-FullwidthRuns $fwRuns
    foreach ($r in $fw.Resolved) { [void]$found.Add($r) }

    return @{ Strings = $found; Fullwidth = $fw.Unknown; Obfuscators = $obfHits }
}

# ══════════════════════════════════════════════════════════════════════════════
#  DISALLOWED MOD LIST
# ══════════════════════════════════════════════════════════════════════════════

$disallowedMods = @{
    "xeros-minimap"=@{Names=@("Xero's Minimap","Xeros Minimap","xeros-minimap","XerosMinimap","Xero's Minimap Mod")}
    "freecam"=@{Names=@("Freecam","freecam","FreeCam","Free Cam")}
    "health-indicators"=@{Names=@("Health Indicators","health indicators","HealthIndicators","Health Indicators Mod")}
    "clickcrystals"=@{Names=@("ClickCrystals","clickcrystals","ClickCrystals Mod","Click Crystals")}
    "mousetweaks"=@{Names=@("Mouse Tweaks","mousetweaks","MouseTweaks")}
    "itemscroller"=@{Names=@("Item Scroller","itemscroller","ItemScroller")}
    "tweakeroo"=@{Names=@("Tweakeroo","tweakeroo")}
    "kinds-crystal-optimizer"=@{Names=@("Kind's Crystal Optimizer","Kinds Crystal Optimizer","Kind Crystal Optimizer","KindsCrystalOptimizer","KindCrystalOptimizer")}
    "g1ax-crystal-optimizer"=@{Names=@("G1ax Crystal Optimizer","G1axCrystalOptimizer","G1ax")}
    "shikarus-crystal-optimizer"=@{Names=@("Shikaru's Crystal Optimizer","Shikarus Crystal Optimizer","ShikaruCrystalOptimizer","ShikarusCrystalOptimizer")}
    "hcscr"=@{Names=@("HCsCR","HCs Crystal Optimizer")}
    "hazel-crystal-optimizer"=@{Names=@("Hazel Crystal Optimizer","HazelCrystalOptimizer","Hazel Crystal Optimizer - HCO")}
    "psychodreams-crystal-optimizer"=@{Names=@("Psychodreams CrystalOptimizer","Psychodreams Crystal Optimizer","PsychodreamsCrystalOptimizer")}
    "walksys-crystal-optimizer"=@{Names=@("Walksy's Crystal Optimizer","Walksys Crystal Optimizer","WalksyCrystalOptimizer","Walksy Crystal Optimizer")}
    "no-delay-optimizer"=@{Names=@("No delay Optimizer","NoDelayOptimizer","No Delay Optimizer","nodelayoptimizer")}
    "safe-crystals"=@{Names=@("Safe Crystals","safecrystals","SafeCrystals","safe crystals")}
    "nocrystalrefresh"=@{Names=@("NoCrystalRefresh","No Crystal Refresh","nocrystalrefresh")}
    "psychodreams-antirefreshcrystal"=@{Names=@("Psychodreams Antirefreshcrystal","PsychodreamsAntirefreshcrystal","AntiRefreshCrystal","Anti Refresh Crystal")}
    "crystal-macro"=@{Names=@("Crystal Macro Mod","Crystal Macro","CrystalMacro","crystalmacro")}
    "auto-crystal-switcher"=@{Names=@("Auto Crystal Switcher","AutoCrystalSwitcher","autocrystalswitcher")}
    "kinds-anchor-optimizer"=@{Names=@("Kind's Anchor Optimizer","Kinds Anchor Optimizer","KindsAnchorOptimizer","KindAnchorOptimizer")}
    "tenites-anchor-optimizer"=@{Names=@("Tenite's anchor optimizer","Tenites anchor optimizer","TenitesAnchorOptimizer","TeniteAnchorOptimizer")}
    "vixsls-anchor-optimizer"=@{Names=@("Vixsl's Anchor Optimizer","Vixsls Anchor Optimizer","VixslAnchorOptimizer","VixslsAnchorOptimizer")}
    "diolez-anchor-optimizer"=@{Names=@("DiolezAnchorOptimizer","Diolez Anchor Optimizer","diolezanchoroptimizer")}
    "dokkos-hotbar-optimizer"=@{Names=@("Dokko's hotbar optimizer","Dokkos hotbar optimizer","DokkosHotbarOptimizer","DokkoHotbarOptimizer")}
    "bobs-hotbar-optimizer"=@{Names=@("bob's hotbar optimizer","bobs hotbar optimizer","BobsHotbarOptimizer","BobHotbarOptimizer")}
    "gloryis-keyboard-optimizer"=@{Names=@("Gloryi's Keyboard Optimizer","Gloryis Keyboard Optimizer","GloryiKeyboardOptimizer","GloryisKeyboardOptimizer")}
    "jellos-pvp-optimizer"=@{Names=@("Jello's pvp optimizer","Jellos pvp optimizer","JellosPvpOptimizer","JelloPvpOptimizer")}
    "pvp-optimizer"=@{Names=@("PVP Optimizer","pvpoptimizer","PVPOptimizer","pvp optimizer")}
    "lunartweaks"=@{Names=@("LunarTweaks","Lunar Tweaks","lunartweaks")}
    "no-shield-delay"=@{Names=@("No Shield Delay","NoShieldDelay","noshielddelay")}
    "no-mining-cooldown"=@{Names=@("No Mining Cooldown","NoMiningCooldown","nominingcooldown")}
    "no-jump-delay"=@{Names=@("No Jump Delay Enhanced","No Jump Delay","NoJumpDelay","NoJumpDelayEnhanced")}
    "lwfh-airplace"=@{Names=@("lwfh Airplace","lwfh","Airplace")}
    "autototem-catchall"=@{Names=@("AutoTotem","Auto Totem","autototem","auto-totem")}
    "d-hand"=@{Names=@("D-hand mod","D-hand","DHand","Double Hand Mod")}
}

# ══════════════════════════════════════════════════════════════════════════════
#  MAIN SCAN - runs once per instance folder
# ══════════════════════════════════════════════════════════════════════════════

function Invoke-ModScan {
    param([string]$ModsFolder, $Instance)

    $script:minecraftVersion = Get-Minecraft-Version-From-Mods $ModsFolder $Instance
    if ($script:minecraftVersion) { Write-Host "  [i] Using Minecraft version: $($script:minecraftVersion) for filtering`n" -ForegroundColor Green } else { Write-Host "" }

    $verifiedMods = [System.Collections.Generic.List[object]]::new()
    $unknownMods  = [System.Collections.Generic.List[object]]::new()
    $cheatMods    = [System.Collections.Generic.List[object]]::new()
    $tamperedMods = [System.Collections.Generic.List[object]]::new()
    $allModsInfo  = [System.Collections.Generic.List[object]]::new()

    $jarFiles = @(Get-ChildItem -Path $ModsFolder -Filter *.jar -ErrorAction SilentlyContinue)
    $spinner = @("|","/","-","\"); $totalMods = $jarFiles.Count

    if ($totalMods -eq 0) {
        Write-Host "  [!] No .jar files in this mods folder.`n" -ForegroundColor Yellow
        return [PSCustomObject]@{ Verified=$verifiedMods; Unknown=$unknownMods; Tampered=$tamperedMods; Cheat=$cheatMods
                                  Disallowed=@(); AllCheatStrings=@(); AllFullwidth=@(); ModsFolder=$ModsFolder; Total=0 }
    }

    $null = Invoke-BulkHashLookup $jarFiles

    Write-Host "  [i] Scanning $totalMods mods..." -ForegroundColor White
    for ($i = 0; $i -lt $jarFiles.Count; $i++) {
        $file = $jarFiles[$i]
        Write-Host "`r  [$($spinner[$i % 4])] Scanning mods: $($i+1) / $totalMods    " -ForegroundColor Magenta -NoNewline
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
            ExpectedSizeKB=$(if($md.ExpectedSize -gt 0){[math]::Round($md.ExpectedSize/1KB,2)} else {0})
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
                $entry | Add-Member -NotePropertyName TamperReasons -NotePropertyValue @("File size does not match the Modrinth release ($($md.MatchType))") -Force
                $tamperedMods.Add($entry)
                $fn = $file.Name
                $null = $verifiedMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $fn }.GetNewClosure())
            }
        } elseif ($mb = Fetch-Megabase $hash) {
            $entry.ModName = $mb.name; $entry.IsVerified = $true
            $verifiedMods.Add($entry); $allModsInfo.Add($entry)
        } else {
            $unknownMods.Add($entry); $allModsInfo.Add($entry)
        }
    }
    Write-Host ""

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
            $fn = $mod.FileName
            $null = $unknownMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $fn }.GetNewClosure())
            $i--
        }
    }

    $counter = 0
    Write-Host "  [i] Scanning for cheat strings..." -ForegroundColor White

    foreach ($mod in $allModsInfo) {
        $counter++
        Write-Host "`r  [$($spinner[$counter % 4])] Scanning for cheat strings: $counter / $totalMods    " -ForegroundColor Magenta -NoNewline

        $s1=0; $s2=0; $tc=0; $obf=0; $num=0; $uni=0; $nov=0; $gib=0; $spkg=0; $conf=0
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
                if ($cn -match '^[Il1O0]+$' -or $cn -match '^_+$') { $conf++ }
                if ($cn.Length -ge 3 -and $cn -match '^[a-zA-Z]+$') {
                    $v = ($cn.ToCharArray() | Where-Object { $_ -match '[aeiouAEIOU]' }).Count
                    if ($v -eq 0) { $nov++ }
                    if ($cn -match '[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{3,}' -and ($v/$cn.Length) -lt 0.3) { $gib++ }
                }
                if ($segs.Count -ge 2) {
                    foreach ($seg in $segs[0..($segs.Count-2)]) { if ($seg.Length -eq 1) { $spkg++ } }
                    $cons=0; $maxC=0
                    foreach ($seg in $segs[0..($segs.Count-2)]) { if ($seg.Length -eq 1){$cons++;if($cons -gt $maxC){$maxC=$cons}} else {$cons=0} }
                    if ($maxC -ge 3) { $obf++ }
                }
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
        $cfp=[math]::Round($(if($tc -ge 5){$conf/$tc*100} else {0}))

        $scan = Check-Strings $mod.FilePath

        $obfReasons = @()
        if ($s1p -ge 15 -and $tc -ge 5)   { $obfReasons += "Single-letter class names ($s1p%)" }
        if ($s2p -ge 20 -and $tc -ge 5)   { $obfReasons += "Two-letter class names ($s2p%)" }
        if ($np -ge 20 -and $tc -ge 5)    { $obfReasons += "Numeric class names ($np%)" }
        if ($up -ge 10 -and $tc -ge 5)    { $obfReasons += "Unicode class names ($up%)" }
        if ($nvp -ge 8 -and $tc -ge 5)    { $obfReasons += "No-vowel class names ($nvp%)" }
        if ($gp -ge 15 -and $tc -ge 100)  { $obfReasons += "Gibberish class names ($gp%)" }
        if ($spkg -ge 50 -and $tc -ge 10) { $obfReasons += "Single-char package paths ($spkg segments)" }
        if ($op -ge 25 -and $tc -ge 10)   { $obfReasons += "Obfuscated package structure ($op%)" }
        if ($cfp -ge 3 -and $tc -ge 5)    { $obfReasons += "Confusion-char class names Il1O0 ($cfp%)" }
        if ($scan.Obfuscators.Count -gt 0 -and $mod.MatchType -ne "Exact Hash") {
            $obfReasons = @("Known cheat obfuscator: $($scan.Obfuscators -join ', ')") + $obfReasons
        }

        $fn = $mod.FileName

        if ($obfReasons.Count -gt 0) {
            $tamperedMods.Add([PSCustomObject]@{ FileName=$mod.FileName; ModName=$mod.ModName; ActualSizeKB=$mod.ActualSizeKB; ExpectedSizeKB=$mod.ExpectedSizeKB; SizeDiffKB=$mod.SizeDiffKB; TamperReasons=$obfReasons })
            $null = $verifiedMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $fn }.GetNewClosure())
        }

        if ($scan.Strings.Count -gt 0 -or $scan.Fullwidth.Count -gt 0) {
            $cheatMods.Add([PSCustomObject]@{ FileName=$mod.FileName; StringsFound=$scan.Strings; FullwidthFound=$scan.Fullwidth; FileSizeKB=$mod.ActualSizeKB; DownloadSource=$mod.DownloadSource; SourceURL=$mod.ZoneId; ExpectedSizeKB=$mod.ExpectedSizeKB; SizeDiffKB=$mod.SizeDiffKB; IsVerifiedMod=$mod.IsVerified; ModName=$mod.ModName; ModrinthUrl=$mod.ModrinthUrl; FilePath=$mod.FilePath; HasSizeMismatch=($mod.SizeDiffKB -ne 0 -and [math]::Abs($mod.SizeDiffKB) -gt 1); JarModId=$mod.JarModId; JarName=$mod.JarName; JarVersion=$mod.JarVersion; MatchType=$mod.MatchType; ExactMatch=$mod.ExactMatch; IsLatestVersion=$mod.IsLatestVersion; LoaderType=$mod.LoaderType })
            $null = $verifiedMods.RemoveAll([Predicate[object]]{ param($x) $x.FileName -eq $fn }.GetNewClosure())
        }
    }
    Write-Host ""

    # Disallowed check reuses metadata already parsed above - no second pass over the jars
    $disallowedFound = @()
    foreach ($mod in $allModsInfo) {
        $fnL = $mod.FileName.ToLower()
        $jid = if ($mod.JarModId) { $mod.JarModId.ToLower() } else { "" }
        $jnm = if ($mod.JarName)  { $mod.JarName.ToLower() }  else { "" }
        foreach ($slug in $disallowedMods.Keys) {
            $md2 = $disallowedMods[$slug]; $hit = $false
            $slugL = $slug.ToLower(); $slugNoDash = $slugL -replace '-',''
            foreach ($name in $md2.Names) {
                $nameL = $name.ToLower(); $nameNoSpace = ($name -replace ' ','').ToLower()
                if ($fnL -match [regex]::Escape($nameL) -or $fnL -match [regex]::Escape($nameNoSpace) -or $fnL -match [regex]::Escape($slugL) -or $fnL -match [regex]::Escape($slugNoDash)) { $hit=$true; break }
                if ($jid -and ($jid -match [regex]::Escape($nameNoSpace) -or $jid -match [regex]::Escape($slugNoDash) -or $jid -match [regex]::Escape($slugL))) { $hit=$true; break }
                if ($jnm -and ($jnm -match [regex]::Escape($nameL) -or $jnm -match [regex]::Escape($nameNoSpace) -or $jnm -match [regex]::Escape($slugL))) { $hit=$true; break }
            }
            if ($hit) { $disallowedFound += [PSCustomObject]@{ FileName=$mod.FileName; ModName=$md2.Names[0] }; break }
        }
    }

    $allCheatStrings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $allFullwidth = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($mod in $cheatMods) {
        foreach ($s in $mod.StringsFound) { [void]$allCheatStrings.Add($s) }
        if ($mod.FullwidthFound) { foreach ($f in $mod.FullwidthFound) { [void]$allFullwidth.Add($f) } }
    }

    return [PSCustomObject]@{
        Verified=$verifiedMods; Unknown=$unknownMods; Tampered=$tamperedMods; Cheat=$cheatMods
        Disallowed=$disallowedFound; AllCheatStrings=$allCheatStrings; AllFullwidth=$allFullwidth
        ModsFolder=$ModsFolder; Total=$totalMods; MinecraftVersion=$script:minecraftVersion
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  REPORTING
# ══════════════════════════════════════════════════════════════════════════════

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

function Write-ScanReport {
    param($Result, $Group)

    $possibleFalseFlags = @("ViaFabricPlus","Simple Voice Chat")

    Write-Sep Green; Write-Host "VERIFIED MODS: $($Result.Verified.Count) [OK]" -ForegroundColor Green; Write-Sep Green
    if ($Result.Verified.Count -gt 0) {
        foreach ($mod in $Result.Verified) {
            Write-Host "  + " -NoNewline -ForegroundColor Green; Write-Host "$($mod.ModName) " -NoNewline -ForegroundColor White; Write-Host "($($mod.FileName))" -ForegroundColor Green
            Write-Host "    Size: $($mod.ActualSizeKB) KB" -ForegroundColor Green
        }
    } else { Write-Host "  No verified mods found" -ForegroundColor Gray }
    Write-Host ""

    Write-Sep Yellow; Write-Host "UNKNOWN MODS: $($Result.Unknown.Count) ?" -ForegroundColor Yellow; Write-Sep Yellow
    if ($Result.Unknown.Count -gt 0) {
        foreach ($mod in $Result.Unknown) {
            Write-Card @(@{text="UNKNOWN MOD";color="Yellow"}, "File: $($mod.FileName)", "Size: $($mod.FileSizeKB) KB", "Source: $($mod.DownloadSource)") Yellow
        }
    } else { Write-Host "  No unknown mods found" -ForegroundColor Gray }
    Write-Host ""

    Write-Sep DarkYellow; Write-Host "TAMPERED MODS: $($Result.Tampered.Count) !" -ForegroundColor DarkYellow; Write-Sep DarkYellow
    if ($Result.Tampered.Count -gt 0) {
        foreach ($mod in $Result.Tampered) {
            $sign = if ($mod.SizeDiffKB -gt 0) {"+"} else {""}
            Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor DarkYellow
            Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "TAMPERED MOD" -ForegroundColor DarkYellow
            Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor DarkYellow
            Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "File: $($mod.FileName)" -ForegroundColor White
            if ($mod.ModName) { Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Mod: $($mod.ModName)" -ForegroundColor Magenta }
            if ($mod.TamperReasons -and @($mod.TamperReasons).Count -gt 0) {
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Detected Issues:" -ForegroundColor Yellow
                foreach ($reason in @($mod.TamperReasons)) {
                    Write-Host "  ║   " -NoNewline -ForegroundColor DarkYellow; Write-Host "• $reason" -ForegroundColor Red
                }
            }
            if ($mod.ExpectedSizeKB -gt 0) {
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Size: $($mod.ActualSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB)" -ForegroundColor Magenta
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Red
            } else {
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkYellow; Write-Host "Size: $($mod.ActualSizeKB) KB (no Modrinth match to compare)" -ForegroundColor Magenta
            }
            Write-Host "  ╚══════════════════════════════════════════`n" -ForegroundColor DarkYellow
        }
    } else { Write-Host "  No tampered mods found" -ForegroundColor Gray }
    Write-Host ""

    Write-Sep Red; Write-Host "CHEAT MODS: $($Result.Cheat.Count) !" -ForegroundColor Red; Write-Sep Red
    if ($Result.Cheat.Count -gt 0) {
        $dqrkisStrings = @("CwskKkUfHQYB","HgsCDQ49KkUfHQYB","DhsnbQ0LDg0MDA","OhYHBQcOHw","EgQKDiUqRR8WChk","KjoFWRcEAx0M","Hx0GAVkcChwdDA","HSw7RQQIAQQ","BR0sFBcOGg4a","Oh0yWR0MCA")
        foreach ($mod in $Result.Cheat) {
            Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
            Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "CHEAT MOD DETECTED" -ForegroundColor Red
            Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor Red
            Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "File: $($mod.FileName)" -ForegroundColor White
            if ($mod.ModName) { Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Mod: $($mod.ModName)" -ForegroundColor White }
            if ($possibleFalseFlags -contains $mod.ModName) {
                Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "! May be a false flag - $($mod.ModName) is a known legit mod that contains these strings" -ForegroundColor DarkYellow
            }
            if (($mod.StringsFound | Where-Object { $dqrkisStrings -contains $_ }).Count -gt 0) { Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Reason: Dqrkis Client Strings" -ForegroundColor Red }
            if ($mod.StringsFound.Count -gt 0) {
                Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Detected Cheat Strings:" -ForegroundColor Yellow
                @($mod.StringsFound) | Sort-Object | ForEach-Object { Write-Host "  ║   " -NoNewline -ForegroundColor Red; Write-Host "• $_" -ForegroundColor Magenta }
            }
            if ($mod.FullwidthFound -and $mod.FullwidthFound.Count -gt 0) {
                Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Unknown Fullwidth Strings:" -ForegroundColor Yellow
                @($mod.FullwidthFound) | Sort-Object | ForEach-Object { Write-Host "  ║   " -NoNewline -ForegroundColor Red; Write-Host "• $_" -ForegroundColor Magenta }
            }
            if ($mod.ExpectedSizeKB -gt 0) {
                $sign = if ($mod.SizeDiffKB -gt 0){"+"} else {""}
                Write-Host "  ║ " -NoNewline -ForegroundColor Red
                if ($mod.SizeDiffKB -eq 0) { Write-Host "Size matches Modrinth: $($mod.ExpectedSizeKB) KB [OK]" -ForegroundColor White }
                else {
                    Write-Host "Size: $($mod.FileSizeKB) KB (Expected: $($mod.ExpectedSizeKB) KB) | " -NoNewline -ForegroundColor White
                    Write-Host "Difference: $sign$($mod.SizeDiffKB) KB" -ForegroundColor Red
                }
            }
            Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
            Write-Host ""
        }
    } else { Write-Host "  No cheat mods detected [OK]" -ForegroundColor Green }
    Write-Host ""

    Write-Sep Red; Write-Host "DISALLOWED MODS: $(@($Result.Disallowed).Count) !" -ForegroundColor Red; Write-Sep Red
    if (@($Result.Disallowed).Count -gt 0) {
        foreach ($mod in $Result.Disallowed) { Write-Card @(@{text="DISALLOWED MOD DETECTED";color="Red"}, "File: $($mod.FileName)", "Mod: $($mod.ModName)") Red }
    } else { Write-Host "  No disallowed mods detected [OK]" -ForegroundColor Green }
    Write-Host ""

    $verColor   = if ($Result.Verified.Count -gt 0)         { "Green" }  else { "DarkGray" }
    $unkColor   = if ($Result.Unknown.Count -gt 0)          { "Yellow" } else { "DarkGray" }
    $tampColor  = if ($Result.Tampered.Count -gt 0)         { "Red" }    else { "DarkGray" }
    $cheatColor = if ($Result.Cheat.Count -gt 0)            { "Red" }    else { "DarkGray" }
    $disColor   = if (@($Result.Disallowed).Count -gt 0)    { "Red" }    else { "DarkGray" }

    foreach ($inst in $Group.Instances) {
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Player     " -NoNewline -ForegroundColor White; Write-Host $inst.Player -ForegroundColor White
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "UUID       " -NoNewline -ForegroundColor White; Write-Host $inst.UUID -ForegroundColor White
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "PID        " -NoNewline -ForegroundColor White; Write-Host $inst.ProcessId -ForegroundColor White
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Mods       " -NoNewline -ForegroundColor White; Write-Host $Result.ModsFolder -ForegroundColor DarkGray
        Write-Host "  ╠══════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Verified   " -NoNewline -ForegroundColor White; Write-Host $Result.Verified.Count        -ForegroundColor $verColor
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Unknown    " -NoNewline -ForegroundColor White; Write-Host $Result.Unknown.Count         -ForegroundColor $unkColor
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Tampered   " -NoNewline -ForegroundColor White; Write-Host $Result.Tampered.Count        -ForegroundColor $tampColor
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Cheat      " -NoNewline -ForegroundColor White; Write-Host $Result.Cheat.Count           -ForegroundColor $cheatColor
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Disallowed " -NoNewline -ForegroundColor White; Write-Host @($Result.Disallowed).Count   -ForegroundColor $disColor
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGray; Write-Host "Join discord.gg/napvp" -ForegroundColor Blue
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host ""
    }

    if ($Result.AllCheatStrings.Count -gt 0) {
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Cheat Strings Detected In Instance:" -ForegroundColor Red
        $Result.AllCheatStrings | Sort-Object | ForEach-Object {
            Write-Host "  ║   " -NoNewline -ForegroundColor Red; Write-Host "• " -NoNewline -ForegroundColor Magenta; Write-Host $_ -ForegroundColor Magenta
        }
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
    }

    if ($Result.AllFullwidth.Count -gt 0) {
        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║ " -NoNewline -ForegroundColor Red; Write-Host "Unknown Fullwidth Strings In Instance:" -ForegroundColor Red
        $Result.AllFullwidth | Sort-Object | ForEach-Object {
            Write-Host "  ║   " -NoNewline -ForegroundColor Red; Write-Host "• " -NoNewline -ForegroundColor Magenta; Write-Host $_ -ForegroundColor Magenta
        }
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  RUN - one full pass per detected instance folder
# ══════════════════════════════════════════════════════════════════════════════

$allResults = @()
$idx = 0

foreach ($group in $scanGroups) {
    $idx++
    $players = ($group.Instances | ForEach-Object { $_.Player }) -join ", "

    Write-Host ""
    Write-Host ("═" * 111) -ForegroundColor Cyan
    Write-Host "  INSTANCE $idx OF $($scanGroups.Count)   |   Player(s): $players" -ForegroundColor Cyan
    Write-Host "  $($group.ModsFolder)" -ForegroundColor DarkCyan
    Write-Host ("═" * 111) -ForegroundColor Cyan
    Write-Host ""

    Write-Sep Yellow; Write-Host "JVM ARGUMENTS INJECTION SCANNER" -ForegroundColor Yellow; Write-Sep Yellow
    Write-Host ""
    $anyInjection = $false
    foreach ($inst in $group.Instances) {
        if ($inst.ProcessId) { if (Invoke-JvmArgScan $inst) { $anyInjection = $true } }
    }
    if (-not $anyInjection) { Write-Host "  [+] CLEAN: No JVM argument injections detected for this instance`n" -ForegroundColor Green }

    $result = Invoke-ModScan -ModsFolder $group.ModsFolder -Instance $group.Instances[0]

    Write-Host ""
    Write-Host ("━" * 50) -ForegroundColor Cyan
    Write-Host "  SCAN COMPLETE - INSTANCE $idx" -ForegroundColor Cyan
    Write-Host ("━" * 50) -ForegroundColor Cyan
    Write-Host ""

    Write-ScanReport -Result $result -Group $group
    $allResults += [PSCustomObject]@{ Group=$group; Result=$result }
}

# ══════════════════════════════════════════════════════════════════════════════
#  GRAND TOTAL (only when more than one instance was scanned)
# ══════════════════════════════════════════════════════════════════════════════

if ($allResults.Count -gt 1) {
    Write-Host ("═" * 111) -ForegroundColor Cyan
    Write-Host "  ALL INSTANCES - COMBINED SUMMARY" -ForegroundColor Cyan
    Write-Host ("═" * 111) -ForegroundColor Cyan
    Write-Host ""
    foreach ($r in $allResults) {
        $players = ($r.Group.Instances | ForEach-Object { "$($_.Player) (PID $($_.ProcessId))" }) -join ", "
        $flags = @()
        if ($r.Result.Cheat.Count -gt 0)          { $flags += "$($r.Result.Cheat.Count) cheat" }
        if (@($r.Result.Disallowed).Count -gt 0)  { $flags += "$(@($r.Result.Disallowed).Count) disallowed" }
        if ($r.Result.Tampered.Count -gt 0)       { $flags += "$($r.Result.Tampered.Count) tampered" }
        if ($r.Result.Unknown.Count -gt 0)        { $flags += "$($r.Result.Unknown.Count) unknown" }
        $verdict = if ($flags.Count -eq 0) { "CLEAN" } else { $flags -join " | " }
        $col     = if ($flags.Count -eq 0) { "Green" } elseif ($r.Result.Cheat.Count -gt 0 -or @($r.Result.Disallowed).Count -gt 0) { "Red" } else { "Yellow" }

        Write-Host "  ╔══════════════════════════════════════════" -ForegroundColor $col
        Write-Host "  ║ " -NoNewline -ForegroundColor $col; Write-Host $players -ForegroundColor White
        Write-Host "  ║ " -NoNewline -ForegroundColor $col; Write-Host $r.Result.ModsFolder -ForegroundColor DarkGray
        Write-Host "  ║ " -NoNewline -ForegroundColor $col; Write-Host "$($r.Result.Total) mods scanned  ->  $verdict" -ForegroundColor $col
        Write-Host "  ╚══════════════════════════════════════════" -ForegroundColor $col
        Write-Host ""
    }
}

Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host "  Credits to Habibi Mod Analyzer and Tonynoh" -ForegroundColor DarkGray
Write-Host "  Join discord.gg/napvp" -ForegroundColor Blue
Write-Host ("━" * 50) -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
