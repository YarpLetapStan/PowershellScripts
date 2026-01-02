# JAR Execution Checker
# Created by YarpLetapStan
# Checks for JAR files executed since last system boot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   JAR Execution Checker v1.0" -ForegroundColor Cyan
Write-Host "   By YarpLetapStan" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get last boot time
$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
Write-Host "[INFO] System last booted: $bootTime`n" -ForegroundColor Yellow

# Initialize results array
$executedJars = @()

# Check Prefetch for JAR executions
Write-Host "[SCANNING] Checking Prefetch data..." -ForegroundColor Green
$prefetchPath = "$env:SystemRoot\Prefetch"
if (Test-Path $prefetchPath) {
    $prefetchFiles = Get-ChildItem -Path $prefetchPath -Filter "JAVA*.pf" -ErrorAction SilentlyContinue
    foreach ($file in $prefetchFiles) {
        if ($file.LastWriteTime -gt $bootTime) {
            $executedJars += [PSCustomObject]@{
                Source = "Prefetch"
                File = $file.Name
                LastAccess = $file.LastWriteTime
                Path = $file.FullName
            }
        }
    }
}

# Check Recent Items
Write-Host "[SCANNING] Checking Recent Items..." -ForegroundColor Green
$recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
if (Test-Path $recentPath) {
    $recentJars = Get-ChildItem -Path $recentPath -Filter "*.jar.lnk" -ErrorAction SilentlyContinue
    foreach ($file in $recentJars) {
        if ($file.LastWriteTime -gt $bootTime) {
            $executedJars += [PSCustomObject]@{
                Source = "Recent Items"
                File = $file.Name -replace '.lnk$', ''
                LastAccess = $file.LastWriteTime
                Path = $file.FullName
            }
        }
    }
}

# Check Windows Event Logs for process creation
Write-Host "[SCANNING] Checking Event Logs..." -ForegroundColor Green
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Microsoft-Windows-Sysmon/Operational', 'Security'
        ID = 1, 4688
        StartTime = $bootTime
    } -ErrorAction SilentlyContinue | Where-Object {
        $_.Message -match '\.jar' -or $_.Message -match 'java.*\.jar'
    }
    
    foreach ($event in $events) {
        $executedJars += [PSCustomObject]@{
            Source = "Event Log"
            File = "JAR execution detected"
            LastAccess = $event.TimeCreated
            Path = "Event ID: $($event.Id)"
        }
    }
} catch {
    Write-Host "[WARN] Limited access to event logs (requires admin)" -ForegroundColor Yellow
}

# Check common temp directories
Write-Host "[SCANNING] Checking temp directories..." -ForegroundColor Green
$tempPaths = @($env:TEMP, "$env:LOCALAPPDATA\Temp", "$env:SystemRoot\Temp")
foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        $tempJars = Get-ChildItem -Path $tempPath -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastAccessTime -gt $bootTime }
        
        foreach ($jar in $tempJars) {
            $executedJars += [PSCustomObject]@{
                Source = "Temp Directory"
                File = $jar.Name
                LastAccess = $jar.LastAccessTime
                Path = $jar.FullName
            }
        }
    }
}

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   RESULTS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($executedJars.Count -eq 0) {
    Write-Host "[RESULT] No JAR file executions detected since last boot." -ForegroundColor Green
} else {
    Write-Host "[RESULT] Found $($executedJars.Count) JAR-related activity:`n" -ForegroundColor Yellow
    $executedJars | Sort-Object LastAccess -Descending | Format-Table -AutoSize
}

Write-Host "`n[INFO] Scan complete. Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
