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

# Check if Minecraft/Java is currently running
Write-Host "[SCANNING] Checking for active javaw.exe processes..." -ForegroundColor Green
$javawProcesses = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
if ($javawProcesses) {
    Write-Host "[DETECTED] Found $($javawProcesses.Count) javaw.exe process(es) running" -ForegroundColor Yellow
    foreach ($proc in $javawProcesses) {
        try {
            $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
            if ($commandLine -match '\.jar') {
                $injectedJars += [PSCustomObject]@{
                    Source = "Active Process"
                    ProcessID = $proc.Id
                    StartTime = $proc.StartTime
                    CommandLine = $commandLine
                }
            }
        } catch {
            Write-Host "[WARN] Could not read command line for PID $($proc.Id)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[INFO] No active javaw.exe processes detected" -ForegroundColor Cyan
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

# Check Windows Event Logs for javaw process creation
Write-Host "[SCANNING] Checking Event Logs for javaw activity..." -ForegroundColor Green
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Microsoft-Windows-Sysmon/Operational', 'Security', 'Application'
        StartTime = $bootTime
    } -ErrorAction SilentlyContinue | Where-Object {
        $_.Message -match 'javaw\.exe' -and $_.Message -match '\.jar'
    } | Select-Object -First 10
    
    foreach ($event in $events) {
        $injectedJars += [PSCustomObject]@{
            Source = "Event Log"
            File = "javaw.exe with JAR injection detected"
            LastAccess = $event.TimeCreated
            Path = "Event ID: $($event.Id)"
        }
    }
} catch {
    Write-Host "[WARN] Limited access to event logs (requires admin for full scan)" -ForegroundColor Yellow
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
    $injectedJars | Sort-Object LastAccess -Descending | Format-Table Source, File, LastAccess -AutoSize
    
    Write-Host "`n[DETAILS] Full paths:" -ForegroundColor Cyan
    $injectedJars | ForEach-Object {
        if ($_.Path) {
            Write-Host "  - $($_.Path)" -ForegroundColor Gray
        }
        if ($_.CommandLine) {
            Write-Host "  CMD: $($_.CommandLine)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n[INFO] Scan complete. Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
