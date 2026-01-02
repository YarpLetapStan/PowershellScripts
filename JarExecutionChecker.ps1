# JAR Injection Checker for Minecraft
# Created by YarpLetapStan
# Checks for JAR files injected into javaw.exe (Minecraft) since last system boot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   JAR Injection Checker v1.0" -ForegroundColor Cyan
Write-Host "   By YarpLetapStan" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get last boot time
$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
Write-Host "[INFO] System last booted: $bootTime`n" -ForegroundColor Yellow

# Initialize results array
$injectedJars = @()

# Check MsMpEng (Windows Defender) process memory for "-jar" strings
Write-Host "[SCANNING] Checking MsMpEng (Windows Defender) for JAR execution traces..." -ForegroundColor Green
$msmpengProcess = Get-Process -Name "MsMpEng" -ErrorAction SilentlyContinue
if ($msmpengProcess) {
    Write-Host "[INFO] Found MsMpEng process (PID: $($msmpengProcess.Id))" -ForegroundColor Cyan
    
    # Try to get command line history from Windows Defender logs
    try {
        $defenderLogs = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -MaxEvents 1000 -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match '-jar' -and $_.TimeCreated -gt $bootTime }
        
        foreach ($log in $defenderLogs) {
            # Extract JAR file paths from the message
            if ($log.Message -match '(?:java|javaw).*?-jar\s+([^\s]+\.jar)') {
                $jarPath = $matches[1]
                $injectedJars += [PSCustomObject]@{
                    Source = "Defender Log (MsMpEng)"
                    File = Split-Path -Leaf $jarPath
                    LastAccess = $log.TimeCreated
                    Path = $jarPath
                    EventID = $log.Id
                }
            }
        }
        
        if ($defenderLogs) {
            Write-Host "[DETECTED] Found $($defenderLogs.Count) Defender events with '-jar' flag" -ForegroundColor Yellow
        } else {
            Write-Host "[INFO] No '-jar' execution traces in Defender logs since boot" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "[WARN] Limited access to Defender logs (requires admin)" -ForegroundColor Yellow
    }
    
    # Check Windows Defender quarantine and detection history
    Write-Host "[SCANNING] Checking Defender detection history..." -ForegroundColor Green
    $defenderHistoryPath = "$env:ProgramData\Microsoft\Windows Defender\Scans\History"
    if (Test-Path $defenderHistoryPath) {
        $recentScans = Get-ChildItem -Path $defenderHistoryPath -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $bootTime }
        
        if ($recentScans) {
            Write-Host "[INFO] Found $($recentScans.Count) recent Defender scan artifacts" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "[WARN] MsMpEng process not found (Windows Defender may be disabled)" -ForegroundColor Yellow
}

# Check all processes for "-jar" in command line
Write-Host "[SCANNING] Checking all processes for '-jar' command line arguments..." -ForegroundColor Green
$allProcesses = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
foreach ($proc in $allProcesses) {
    if ($proc.CommandLine -match '-jar\s+([^\s]+\.jar)') {
        $jarPath = $matches[1]
        $creationDate = $proc.CreationDate
        if ($creationDate -gt $bootTime) {
            $injectedJars += [PSCustomObject]@{
                Source = "Active Process"
                ProcessName = $proc.Name
                ProcessID = $proc.ProcessId
                File = Split-Path -Leaf $jarPath
                LastAccess = $creationDate
                Path = $jarPath
                CommandLine = $proc.CommandLine
            }
        }
    }
}

# Check if Minecraft/Java is currently running
Write-Host "[SCANNING] Checking for active javaw.exe processes..." -ForegroundColor Green
$javawProcesses = Get-Process -Name "javaw", "java" -ErrorAction SilentlyContinue
if ($javawProcesses) {
    Write-Host "[DETECTED] Found $($javawProcesses.Count) Java process(es) running" -ForegroundColor Yellow
    foreach ($proc in $javawProcesses) {
        try {
            $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
            if ($commandLine -match '-jar\s+([^\s]+\.jar)') {
                $jarPath = $matches[1]
                $injectedJars += [PSCustomObject]@{
                    Source = "Java Process"
                    ProcessID = $proc.Id
                    StartTime = $proc.StartTime
                    File = Split-Path -Leaf $jarPath
                    Path = $jarPath
                    CommandLine = $commandLine
                }
            }
        } catch {
            Write-Host "[WARN] Could not read command line for PID $($proc.Id)" -ForegroundColor Yellow
        }
    }
}

# Check Prefetch for javaw executions
Write-Host "[SCANNING] Checking Prefetch data..." -ForegroundColor Green
$prefetchPath = "$env:SystemRoot\Prefetch"
if (Test-Path $prefetchPath) {
    $prefetchFiles = Get-ChildItem -Path $prefetchPath -Filter "JAVAW*.pf" -ErrorAction SilentlyContinue
    foreach ($file in $prefetchFiles) {
        if ($file.LastWriteTime -gt $bootTime) {
            $injectedJars += [PSCustomObject]@{
                Source = "Prefetch"
                File = $file.Name
                LastAccess = $file.LastWriteTime
                Path = $file.FullName
            }
        }
    }
}

# Check Minecraft directories for recently accessed JARs
Write-Host "[SCANNING] Checking Minecraft directories..." -ForegroundColor Green
$minecraftPaths = @(
    "$env:APPDATA\.minecraft\mods",
    "$env:APPDATA\.minecraft\libraries",
    "$env:APPDATA\.minecraft\versions",
    "$env:USERPROFILE\curseforge\minecraft\Install\mods",
    "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
)

foreach ($mcPath in $minecraftPaths) {
    if (Test-Path $mcPath) {
        $recentJars = Get-ChildItem -Path $mcPath -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastAccessTime -gt $bootTime }
        
        foreach ($jar in $recentJars) {
            $injectedJars += [PSCustomObject]@{
                Source = "Minecraft Directory"
                File = $jar.Name
                LastAccess = $jar.LastAccessTime
                Path = $jar.FullName
            }
        }
    }
}

# Check temp directories for injected JARs
Write-Host "[SCANNING] Checking temp directories for injected JARs..." -ForegroundColor Green
$tempPaths = @($env:TEMP, "$env:LOCALAPPDATA\Temp")
foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        $tempJars = Get-ChildItem -Path $tempPath -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastAccessTime -gt $bootTime }
        
        foreach ($jar in $tempJars) {
            $injectedJars += [PSCustomObject]@{
                Source = "Temp Directory"
                File = $jar.Name
                LastAccess = $jar.LastAccessTime
                Path = $jar.FullName
            }
        }
    }
}

# Check for common injection tools/launchers
Write-Host "[SCANNING] Checking for injection client launchers..." -ForegroundColor Green
$suspiciousPatterns = @("*client*.jar", "*inject*.jar", "*hack*.jar", "*cheat*.jar", "*ghost*.jar")
$searchPaths = @($env:USERPROFILE, $env:TEMP, "$env:APPDATA\.minecraft")

foreach ($searchPath in $searchPaths) {
    if (Test-Path $searchPath) {
        foreach ($pattern in $suspiciousPatterns) {
            $foundFiles = Get-ChildItem -Path $searchPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.LastAccessTime -gt $bootTime } |
                Select-Object -First 5
            
            foreach ($file in $foundFiles) {
                $injectedJars += [PSCustomObject]@{
                    Source = "Suspicious Pattern"
                    File = $file.Name
                    LastAccess = $file.LastAccessTime
                    Path = $file.FullName
                }
            }
        }
    }
}

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   RESULTS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($injectedJars.Count -eq 0) {
    Write-Host "[RESULT] No JAR injection activity detected since last boot." -ForegroundColor Green
} else {
    Write-Host "[RESULT] Found $($injectedJars.Count) JAR injection indicators:`n" -ForegroundColor Yellow
    
    # Group by source for better readability
    $groupedResults = $injectedJars | Group-Object Source
    foreach ($group in $groupedResults) {
        Write-Host "`n[$($group.Name)]" -ForegroundColor Magenta
        $group.Group | Format-Table File, LastAccess, Path -AutoSize
    }
    
    # Show command lines if available
    $withCommandLine = $injectedJars | Where-Object { $_.CommandLine }
    if ($withCommandLine) {
        Write-Host "`n[COMMAND LINES]" -ForegroundColor Magenta
        foreach ($item in $withCommandLine) {
            Write-Host "  File: $($item.File)" -ForegroundColor Yellow
            Write-Host "  CMD:  $($item.CommandLine)" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

Write-Host "`n[INFO] Scan complete. Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
