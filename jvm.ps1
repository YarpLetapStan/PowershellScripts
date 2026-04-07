Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

$Script:ToolName = 'Rico ScreenShare Tool v3.0 (PowerShell Port)'
$Script:UserAgent = 'RicoSSGuide-PS/3.0'
$Script:ModrinthApi = 'https://api.modrinth.com/v2'
$Script:Desktop = [Environment]::GetFolderPath('Desktop')

$Script:CheatStrings = @(
    'WalksyOptimizer','ClickCrystal','Doomsday','Francium client','Luminaclient','WingClient',
    'Argon client','Prestige client','Scrim client','Grim client','Meteor client','Thunderhack Client',
    'Krypton Client','Gardenia client','Coffee Client','Lumina Client','Triggerbot Client','Wurst client module',
    'Ghost','Bleach Client','Asteria Client','Xenon client','Crypt Client','Bape Client','Impact Client',
    'Vape Client','Vape V4','Vape Lite','LiquidBounce','LiquidBounce NextGen','Aristois Client','Flux Client',
    'Future Client','Novoline Client','Pyro Client','Drip Client','Ares Client','Osiris Client','Rise Client',
    'Raven Client','Sigma Client','Minemora Client','Photon Client','Azura Client','Phobos Client','Wurst Client',
    'Huzuni Client','ForgeHax','KillAura','Kill Aura','MultiAura','Reach Modifier','Velocity','Anti Knockback',
    'No Knockback','Bhop','No Fall','Scaffold','FastPlace','ESP Module','Criticals','Backtrack','Freecam',
    'AutoTotem','AutoAnchor','CrystalAura','Autoarmor','TriggerBot','Aimassist','Sticky Aim','Ping spoof',
    'Auto crystal','Anchor Placer','AutoHitCrystal','AutoDoubleHand','AutoInventoryTotem','X-Ray','Fake Lag',
    'String Obfuscator','Bytecode Obfuscation','Reflection Injection','Runtime Injection','Anti Debug',
    'Screenshare Bypass','SS Bypass','Delete Evidence','Wipe Logs','Prefetch Cleaner','MFT Wipe',
    'DLL Injector','Auto Place Crystal','Auto Break Crystal','Surround Module','Burrow','AutoTrap',
    'Invoke-Expression','IEX ','Invoke-RestMethod','DownloadString','DownloadFile','Set-ExecutionPolicy',
    'ExecutionPolicy Bypass','EncodedCommand','FromBase64String','Net.WebClient','Invoke-WebRequest',
    'raw.githubusercontent','-WindowStyle Hidden','reg delete','Reflection.Assembly','System.Net.WebClient'
)

$Script:FlaggedNames = @(
    'wurst','meteor','liquidbounce','sigma','impact','aristois','flux','huzuni','nodus','skillclient',
    'scaffoldbot','killaura','xray','freecam','nofall','speedhack','aimbot','reachhack','antiafk',
    'autoclicker','blink','criticals','bhop','tracers','wallhack','forceop','nuker','highjump','longjump',
    'krypton','catlean','thunderhack','grandline','novaclient','luminaclient','wingclient','coffeeclient',
    'xenonclient','sallos','aperture','xerxes','syphlex'
)

$Script:SafeMods = @(
    'optifine','sodium','lithium','phosphor','fabric-api','fabricloader','forge','modmenu','iris','indium',
    'replaymod','xaerosminimap','xaerosworldmap','journeymap','jei','rei','appleskin','voicechat',
    'dynamiclights','continuity','entityculling','ferritecore','lazydfu','starlight','immediatelyfast','nvidium'
)

$Script:WatchedServices = @(
    [pscustomobject]@{ Name='SysMain'; Display='SysMain (Superfetch)'; Why='Prefetch history can help show recent launches' },
    [pscustomobject]@{ Name='PcaSvc'; Display='Program Compatibility Assistant'; Why='Tracks recent executables' },
    [pscustomobject]@{ Name='DPS'; Display='Diagnostic Policy Service'; Why='Supports diagnostic logging' },
    [pscustomobject]@{ Name='EventLog'; Display='Windows Event Log'; Why='Core audit trail' },
    [pscustomobject]@{ Name='Schedule'; Display='Task Scheduler'; Why='Used by many logging tasks' },
    [pscustomobject]@{ Name='Bam'; Display='Background Activity Moderator'; Why='Tracks background activity' },
    [pscustomobject]@{ Name='Appinfo'; Display='Application Information'; Why='Used for elevation events' },
    [pscustomobject]@{ Name='PlugPlay'; Display='Plug and Play'; Why='Tracks device connections' },
    [pscustomobject]@{ Name='WSearch'; Display='Windows Search'; Why='Recent file indexing' }
)

$Script:CleanDlls = @(
    'ntdll.dll','kernel32.dll','kernelbase.dll','user32.dll','gdi32.dll','gdi32full.dll','win32u.dll',
    'advapi32.dll','sechost.dll','rpcrt4.dll','combase.dll','ucrtbase.dll','msvcrt.dll','ole32.dll',
    'shell32.dll','shlwapi.dll','ws2_32.dll','crypt32.dll','cfgmgr32.dll','bcrypt.dll','cryptbase.dll',
    'msctf.dll','imm32.dll','uxtheme.dll','dwmapi.dll','wintypes.dll','comdlg32.dll','version.dll',
    'setupapi.dll','winmm.dll','psapi.dll','userenv.dll','iphlpapi.dll','dnsapi.dll','nsi.dll','mswsock.dll',
    'jvm.dll','java.dll','zip.dll','net.dll','nio.dll','awt.dll','fontmanager.dll','freetype.dll','jawt.dll',
    'opengl32.dll','glu32.dll','d3d9.dll','d3d11.dll','d3d12.dll','dxgi.dll','dxcore.dll','xinput1_4.dll',
    'dsound.dll','mmdevapi.dll','audioses.dll','lwjgl.dll','lwjgl64.dll','openal.dll','openal64.dll'
)

$Script:SuspiciousDllKeywords = @(
    'inject','hook','cheat','hack','bypass','crack','aimbot','triggerbot','autoclicker',
    'macro','ghost','loader','client','payload','sigma','crystal','meteor','wurst','impact',
    'autototem','killaura','scaffold','xray','esp','wallhack','speed'
)

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '=============================================' -ForegroundColor Magenta
    Write-Host " $Script:ToolName" -ForegroundColor Cyan
    Write-Host '=============================================' -ForegroundColor Magenta
    Write-Host ''
}

function Pause-Tool {
    Write-Host ''
    [void](Read-Host 'Press ENTER to continue')
}

function Get-FileSHA1 {
    param([Parameter(Mandatory)][string]$Path)
    try { return (Get-FileHash -Algorithm SHA1 -LiteralPath $Path).Hash.ToLowerInvariant() } catch { return $null }
}

function Invoke-ModrinthLookup {
    param([Parameter(Mandatory)][string]$Sha1)
    try {
        $body = @{ hashes = @($Sha1); algorithm = 'sha1' } | ConvertTo-Json -Depth 4
        $result = Invoke-RestMethod -Method Post -Uri "$Script:ModrinthApi/version_files" -Headers @{ 'User-Agent' = $Script:UserAgent } -ContentType 'application/json' -Body $body
        if ($result.PSObject.Properties.Name -contains $Sha1) {
            $ver = $result.$Sha1
            $project = Invoke-RestMethod -Method Get -Uri "$Script:ModrinthApi/project/$($ver.project_id)" -Headers @{ 'User-Agent' = $Script:UserAgent }
            return [pscustomobject]@{
                Found = $true
                Title = $project.title
                Slug = $project.slug
                Version = $ver.version_number
                Url = "https://modrinth.com/mod/$($project.slug)"
            }
        }
    } catch {}
    [pscustomobject]@{ Found = $false; Title=''; Slug=''; Version=''; Url='' }
}

function Get-ZipEntriesText {
    param([Parameter(Mandatory)][string]$JarPath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $parts = New-Object System.Collections.Generic.List[string]
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($JarPath)
        foreach ($entry in $zip.Entries) {
            if ($entry.Length -gt 5242880) { continue }
            if ($entry.FullName -notmatch '\.(class|txt|json|cfg|properties|toml)$') { continue }
            try {
                $stream = $entry.Open()
                $reader = New-Object System.IO.BinaryReader($stream)
                $bytes = $reader.ReadBytes([int]$entry.Length)
                $reader.Close(); $stream.Close()
                $parts.Add([System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($bytes))
            } catch {}
        }
        $zip.Dispose()
    } catch {}
    return ($parts -join "`n")
}

function Invoke-JarScan {
    param([Parameter(Mandatory)][string]$JarPath)

    $fileName = [IO.Path]::GetFileName($JarPath)
    $textBlob = Get-ZipEntriesText -JarPath $JarPath
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($term in $Script:CheatStrings) {
        if ($textBlob -and $textBlob.ToLowerInvariant().Contains($term.ToLowerInvariant())) {
            $hits.Add($term)
        }
    }

    $metaHits = New-Object System.Collections.Generic.List[string]
    $lowerName = $fileName.ToLowerInvariant()
    foreach ($flag in $Script:FlaggedNames) {
        if ($lowerName.Contains($flag)) {
            $metaHits.Add("Filename contains '$flag'")
            break
        }
    }

    $status = 'UNKNOWN'
    if ($hits.Count -gt 0 -or $metaHits.Count -gt 0) {
        $status = 'FLAGGED'
    } elseif ($Script:SafeMods | Where-Object { $lowerName.Contains($_) }) {
        $status = 'SAFE'
    }

    [pscustomobject]@{
        FileName = $fileName
        Path = $JarPath
        Status = $status
        StringHits = @($hits)
        MetaHits = @($metaHits)
    }
}

function Invoke-ModAnalyzer {
    Write-Banner
    Write-Host 'Mod Analyzer' -ForegroundColor Cyan
    Write-Host ''
    $folder = Read-Host 'Paste the path to the mods folder'
    $folder = $folder.Trim('"')
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        Write-Host 'Folder not found.' -ForegroundColor Red
        Pause-Tool
        return
    }

    $jars = Get-ChildItem -LiteralPath $folder -Filter *.jar -File
    if (-not $jars) {
        Write-Host 'No .jar files found.' -ForegroundColor Yellow
        Pause-Tool
        return
    }

    $results = foreach ($jar in $jars) {
        Write-Host "Scanning $($jar.Name)..." -ForegroundColor DarkGray
        $sha1 = Get-FileSHA1 -Path $jar.FullName
        $modrinth = if ($sha1) { Invoke-ModrinthLookup -Sha1 $sha1 } else { [pscustomobject]@{ Found = $false } }
        if ($modrinth.Found) {
            [pscustomobject]@{
                FileName = $jar.Name
                Path = $jar.FullName
                Status = 'ON MODRINTH'
                SizeKB = [int]($jar.Length / 1KB)
                SHA1 = $sha1
                Modrinth = $modrinth
                StringHits = @()
                MetaHits = @()
            }
        } else {
            $scan = Invoke-JarScan -JarPath $jar.FullName
            [pscustomobject]@{
                FileName = $jar.Name
                Path = $jar.FullName
                Status = $scan.Status
                SizeKB = [int]($jar.Length / 1KB)
                SHA1 = $sha1
                Modrinth = $modrinth
                StringHits = $scan.StringHits
                MetaHits = $scan.MetaHits
            }
        }
    }

    Write-Host ''
    $grouped = $results | Group-Object Status | Sort-Object Name
    foreach ($group in $grouped) {
        Write-Host ("{0,-12} {1,3}" -f $group.Name, $group.Count) -ForegroundColor Magenta
    }
    Write-Host ''

    foreach ($r in $results | Sort-Object @{Expression={switch ($_.Status) { 'FLAGGED' {0}; 'UNKNOWN' {1}; 'SAFE' {2}; 'ON MODRINTH' {3}; default {4}}}}, FileName) {
        $color = switch ($r.Status) { 'FLAGGED' {'Red'} 'SAFE' {'Green'} 'ON MODRINTH' {'Cyan'} default {'Yellow'} }
        Write-Host ("[{0}] {1} ({2} KB)" -f $r.Status, $r.FileName, $r.SizeKB) -ForegroundColor $color
        if ($r.Modrinth.Found) {
            Write-Host ("  Modrinth: {0} v{1}" -f $r.Modrinth.Title, $r.Modrinth.Version) -ForegroundColor Gray
            Write-Host ("  URL: {0}" -f $r.Modrinth.Url) -ForegroundColor Gray
        }
        foreach ($hit in ($r.StringHits | Select-Object -First 5)) {
            Write-Host ("  Hit: {0}" -f $hit) -ForegroundColor DarkYellow
        }
        foreach ($hit in $r.MetaHits) {
            Write-Host ("  Meta: {0}" -f $hit) -ForegroundColor DarkYellow
        }
        Write-Host ''
    }

    $report = Join-Path $Script:Desktop 'rico_mod_report.txt'
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('RICO SCREENSHARE TOOL v3.0 - MOD ANALYZER REPORT')
    $lines.Add(("Folder: {0}" -f $folder))
    $lines.Add(("Date:   {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    $lines.Add('')
    foreach ($r in $results) {
        $lines.Add(("[{0}] {1}" -f $r.Status, $r.FileName))
        $lines.Add(("  SHA1: {0}" -f $r.SHA1))
        if ($r.Modrinth.Found) { $lines.Add(("  Modrinth: {0} v{1}" -f $r.Modrinth.Title, $r.Modrinth.Version)) }
        foreach ($hit in $r.StringHits) { $lines.Add(("  Hit: {0}" -f $hit)) }
        foreach ($hit in $r.MetaHits) { $lines.Add(("  Meta: {0}" -f $hit)) }
        $lines.Add('')
    }
    $lines | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Host "Report saved to $report" -ForegroundColor Green
    Pause-Tool
}

function Invoke-ServiceChecker {
    Write-Banner
    Write-Host 'Service Checker' -ForegroundColor Cyan
    Write-Host ''
    $rows = foreach ($svc in $Script:WatchedServices) {
        $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            [pscustomobject]@{ Name=$svc.Name; Display=$svc.Display; Status='NOT FOUND'; Why=$svc.Why }
        } else {
            [pscustomobject]@{ Name=$svc.Name; Display=$svc.Display; Status=$service.Status.ToString().ToUpperInvariant(); Why=$svc.Why }
        }
    }

    foreach ($row in $rows) {
        $color = if ($row.Status -eq 'RUNNING') { 'Green' } else { 'Red' }
        Write-Host ("{0,-12} {1,-12} {2}" -f $row.Name, $row.Status, $row.Display) -ForegroundColor $color
        if ($row.Status -ne 'RUNNING') {
            Write-Host ("  {0}" -f $row.Why) -ForegroundColor DarkYellow
        }
    }

    $report = Join-Path $Script:Desktop 'rico_service_report.txt'
    $rows | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Host ''
    Write-Host "Report saved to $report" -ForegroundColor Green
    Pause-Tool
}

function Invoke-RecycleBinRecovery {
    Write-Banner
    Write-Host 'Recycle Bin Recovery' -ForegroundColor Cyan
    Write-Host ''
    $recoverDir = Join-Path $Script:Desktop 'Recovered_RecycleBin'
    New-Item -ItemType Directory -Force -Path $recoverDir | Out-Null
    $shell = New-Object -ComObject Shell.Application
    $bin = $shell.Namespace(10)
    if ($null -eq $bin) {
        Write-Host 'Recycle Bin is not accessible.' -ForegroundColor Red
        Pause-Tool
        return
    }

    $items = @($bin.Items())
    if ($items.Count -eq 0) {
        Write-Host 'Recycle Bin appears empty.' -ForegroundColor Green
        Pause-Tool
        return
    }

    $copied = 0
    foreach ($item in $items) {
        try {
            $target = Join-Path $recoverDir $item.Name
            if (Test-Path -LiteralPath $target) {
                $target = Join-Path $recoverDir (([IO.Path]::GetFileNameWithoutExtension($item.Name)) + '_' + (Get-Date -Format 'HHmmss') + [IO.Path]::GetExtension($item.Name))
            }
            Copy-Item -LiteralPath $item.Path -Destination $target -Force
            $copied++
        } catch {}
    }

    Write-Host "Recovered/copied $copied item(s) to $recoverDir" -ForegroundColor Green
    Pause-Tool
}

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination,
        [string]$Label = 'File'
    )
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -Headers @{ 'User-Agent' = $Script:UserAgent } -UseBasicParsing
        Write-Host "$Label saved to $Destination" -ForegroundColor Green
    } catch {
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-LuytenDownloader {
    Write-Banner
    $dest = Join-Path $Script:Desktop 'luyten.jar'
    Invoke-DownloadFile -Url 'https://github.com/deathmarine/Luyten/releases/download/v0.5.4/luyten-0.5.4.jar' -Destination $dest -Label 'Luyten'
    Pause-Tool
}

function Get-BootTime {
    try { return (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } catch { return (Get-Date).AddDays(-1) }
}

function Invoke-RecentFileScanner {
    Write-Banner
    Write-Host 'Recent File Scanner' -ForegroundColor Cyan
    Write-Host ''
    $boot = Get-BootTime
    $roots = @($env:USERPROFILE, $env:APPDATA, $env:LOCALAPPDATA, $env:TEMP) | Where-Object { $_ -and (Test-Path $_) }
    $items = foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.exe','.jar','.dll' -and $_.LastAccessTime -ge $boot } |
            Select-Object LastAccessTime, FullName, Extension
    }
    $items = $items | Sort-Object LastAccessTime -Descending | Select-Object -First 100
    if (-not $items) {
        Write-Host 'No recent .exe/.jar/.dll files found since boot.' -ForegroundColor Yellow
    } else {
        $items | Format-Table -AutoSize
    }
    Pause-Tool
}

function Invoke-ShellExecutionScanner {
    Write-Banner
    Write-Host 'Shell Execution Scanner' -ForegroundColor Cyan
    Write-Host ''
    $historyPath = Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
    $results = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $historyPath) {
        Get-Content -LiteralPath $historyPath -ErrorAction SilentlyContinue | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '\.(exe|jar|dll)($|\s|"|\')' -or $line -match 'invoke-expression|downloadstring|downloadfile|encodedcommand|frombase64string|invoke-webrequest|invoke-restmethod') {
                $results.Add($line)
            }
        }
    }
    try {
        $runMru = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU'
        foreach ($prop in $runMru.PSObject.Properties) {
            if ($prop.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider','MRUList') {
                $val = [string]$prop.Value
                if ($val -match '\.(exe|jar|dll)') { $results.Add($val) }
            }
        }
    } catch {}

    $unique = $results | Sort-Object -Unique
    if (-not $unique) {
        Write-Host 'Nothing found. History may be cleared.' -ForegroundColor Yellow
    } else {
        foreach ($item in $unique) { Write-Host $item }
    }

    $report = Join-Path $Script:Desktop ("shell_exec_report_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
    $unique | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Host ''
    Write-Host "Report saved to $report" -ForegroundColor Green
    Pause-Tool
}

function Invoke-PostJavawScanner {
    Write-Banner
    Write-Host 'Post-Javaw Scanner' -ForegroundColor Cyan
    Write-Host ''
    $javaw = Get-Process javaw -ErrorAction SilentlyContinue | Sort-Object StartTime | Select-Object -Last 1
    if (-not $javaw) {
        Write-Host 'javaw.exe is not running.' -ForegroundColor Yellow
        Pause-Tool
        return
    }
    $start = $javaw.StartTime
    Write-Host ("javaw.exe started at {0}" -f $start) -ForegroundColor Gray
    $recentDir = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
    $found = @()
    if (Test-Path -LiteralPath $recentDir) {
        $found = Get-ChildItem -LiteralPath $recentDir -Filter *.lnk -File |
            Where-Object { $_.LastWriteTime -ge $start -and $_.Name -match '\.(exe|jar|dll)\.lnk$' } |
            Select-Object LastWriteTime, Name
    }
    if (-not $found) {
        Write-Host 'No recent .exe/.jar/.dll shortcuts found after javaw launch.' -ForegroundColor Yellow
    } else {
        $found | Sort-Object LastWriteTime | Format-Table -AutoSize
    }
    Pause-Tool
}

function Invoke-WinPrefetchViewDownloader {
    Write-Banner
    $zipPath = Join-Path $Script:Desktop 'WinPrefetchView.zip'
    $destDir = Join-Path $Script:Desktop 'WinPrefetchView'
    Invoke-DownloadFile -Url 'https://www.nirsoft.net/utils/winprefetchview.zip' -Destination $zipPath -Label 'WinPrefetchView zip'
    if (Test-Path -LiteralPath $zipPath) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Expand-Archive -LiteralPath $zipPath -DestinationPath $destDir -Force
        Remove-Item -LiteralPath $zipPath -Force
        Write-Host "Extracted to $destDir" -ForegroundColor Green
    }
    Pause-Tool
}

function Invoke-JavawDllScanner {
    Write-Banner
    Write-Host 'Javaw DLL Scanner' -ForegroundColor Cyan
    Write-Host ''
    $javaw = Get-Process javaw -ErrorAction SilentlyContinue
    if (-not $javaw) {
        Write-Host 'javaw.exe is not running.' -ForegroundColor Yellow
        Pause-Tool
        return
    }

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($proc in $javaw) {
        try {
            foreach ($mod in $proc.Modules) {
                $name = $mod.ModuleName.ToLowerInvariant()
                if ($Script:CleanDlls -contains $name) { continue }
                $reason = $null
                foreach ($kw in $Script:SuspiciousDllKeywords) {
                    if ($name.Contains($kw)) { $reason = "keyword: $kw"; break }
                }
                if (-not $reason -and $mod.FileName -match '\\temp\\|\\downloads\\|\\desktop\\|\\public\\') {
                    $reason = 'loaded from unusual path'
                }
                $rows.Add([pscustomobject]@{ PID=$proc.Id; DLL=$mod.ModuleName; Path=$mod.FileName; Reason=($reason ?? 'unrecognised') })
            }
        } catch {}
    }

    if (-not $rows) {
        Write-Host 'No suspicious or unrecognised DLLs found.' -ForegroundColor Green
    } else {
        $rows | Sort-Object PID, DLL | Format-Table -AutoSize
    }

    $report = Join-Path $Script:Desktop ("javaw_dll_report_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
    $rows | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Host ''
    Write-Host "Report saved to $report" -ForegroundColor Green
    Pause-Tool
}

function Invoke-CmdInjectionScanner {
    Write-Banner
    Write-Host 'CMD/PS Injection Scanner' -ForegroundColor Cyan
    Write-Host ''
    $procs = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CommandLine
    $map = @{}
    foreach ($p in $procs) { $map[[int]$p.ProcessId] = $p }
    $javawPids = @($procs | Where-Object { $_.Name -ieq 'javaw.exe' } | Select-Object -ExpandProperty ProcessId)
    if (-not $javawPids) {
        Write-Host 'javaw.exe is not running.' -ForegroundColor Yellow
        Pause-Tool
        return
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($p in $procs) {
        $parent = $map[[int]$p.ParentProcessId]
        if ($null -ne $parent -and $parent.Name -match '^(cmd|powershell|pwsh)\.exe$' -and $p.Name -notmatch '^(cmd|powershell|pwsh|conhost|explorer|javaw|java)\.exe$') {
            $results.Add([pscustomobject]@{ Type='Shell Parent'; PID=$p.ProcessId; Name=$p.Name; Parent=$parent.Name; CommandLine=$p.CommandLine })
        }
        if ($javawPids -contains [int]$p.ParentProcessId -and $p.Name -notmatch '^(conhost|java|javaw)\.exe$') {
            $results.Add([pscustomobject]@{ Type='Child of javaw'; PID=$p.ProcessId; Name=$p.Name; Parent='javaw.exe'; CommandLine=$p.CommandLine })
        }
    }

    if (-not $results) {
        Write-Host 'No obvious shell-spawned or javaw-child processes detected.' -ForegroundColor Green
    } else {
        $results | Sort-Object Type, Name | Format-Table -AutoSize
    }

    $report = Join-Path $Script:Desktop ("cmd_injection_report_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
    $results | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Host ''
    Write-Host "Report saved to $report" -ForegroundColor Green
    Pause-Tool
}

function Invoke-EchoJournalDownloader {
    Write-Banner
    $dest = Join-Path $Script:Desktop 'EchoJournal.zip'
    Invoke-DownloadFile -Url 'https://echo.ac/downloads/EchoJournal.zip' -Destination $dest -Label 'EchoJournal archive'
    Pause-Tool
}

function Show-MainMenu {
    Write-Banner
    Write-Host '[1]  Mod Analyzer' -ForegroundColor Cyan
    Write-Host '[2]  Service Checker' -ForegroundColor Cyan
    Write-Host '[3]  Bin Recovery' -ForegroundColor Cyan
    Write-Host '[4]  Get Luyten' -ForegroundColor Cyan
    Write-Host '[5]  Recent Files' -ForegroundColor Cyan
    Write-Host '[6]  Shell Exec Scan' -ForegroundColor Cyan
    Write-Host '[7]  Post-Javaw Scan' -ForegroundColor Cyan
    Write-Host '[8]  WinPrefetchView' -ForegroundColor Cyan
    Write-Host '[9]  DLL Scanner' -ForegroundColor Cyan
    Write-Host '[10] CMD Inject Scan' -ForegroundColor Cyan
    Write-Host '[11] Get EchoJournal' -ForegroundColor Cyan
    Write-Host '[Q]  Quit' -ForegroundColor Cyan
    Write-Host ''
    return (Read-Host 'Choice').Trim().ToLowerInvariant()
}

while ($true) {
    switch (Show-MainMenu) {
        '1'  { Invoke-ModAnalyzer }
        '2'  { Invoke-ServiceChecker }
        '3'  { Invoke-RecycleBinRecovery }
        '4'  { Invoke-LuytenDownloader }
        '5'  { Invoke-RecentFileScanner }
        '6'  { Invoke-ShellExecutionScanner }
        '7'  { Invoke-PostJavawScanner }
        '8'  { Invoke-WinPrefetchViewDownloader }
        '9'  { Invoke-JavawDllScanner }
        '10' { Invoke-CmdInjectionScanner }
        '11' { Invoke-EchoJournalDownloader }
        'q'  { break }
        default {
            Write-Host 'Invalid choice.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
