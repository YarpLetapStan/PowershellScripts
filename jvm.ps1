# Batch File Execution Detector with Permanent Logging
# Logs bat file names and locations even if files are moved/deleted

Write-Host "=== Batch File Execution Tracker ===" -ForegroundColor Cyan
Write-Host ""

# Create a dedicated log file in AppData (survives reboots)
$logFile = "$env:APPDATA\BatExecutionLog.json"
$log = @()

# Load existing log if it exists
if (Test-Path $logFile) {
    $log = Get-Content $logFile | ConvertFrom-Json
}

# Get system boot time
$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
if (!$bootTime) {
    $bootTime = (Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
}

Write-Host "System Boot Time: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Current Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# Method 1: Check Windows Event Logs (MOST RELIABLE for past executions)
Write-Host "Scanning Event Logs for batch executions..." -ForegroundColor Yellow

$newDetections = @()
try {
    # Get ALL process creation events since boot
    $events = Get-WinEvent -LogName 'Security' -FilterXPath "*[System[(EventID=4688) and TimeCreated[@SystemTime>='$($bootTime.ToString('s'))']]]" -ErrorAction SilentlyContinue
    
    if ($events) {
        foreach ($event in $events) {
            $processName = $event.Properties[5].Value
            $commandLine = $event.Properties[8].Value
            $user = $event.Properties[1].Value
            $time = $event.TimeCreated
            
            # Check if it's a batch file
            if ($processName -like "*.bat" -or $processName -like "*.cmd" -or 
                $commandLine -like "*.bat*" -or $commandLine -like "*.cmd*") {
                
                # Extract filename from path
                $batFileName = [System.IO.Path]::GetFileName($processName)
                if (!$batFileName -and $commandLine) {
                    # Try to extract from command line
                    $batFileName = ($commandLine -split ' ')[0]
                    if ($batFileName -like "*\*") {
                        $batFileName = [System.IO.Path]::GetFileName($batFileName)
                    }
                }
                
                # Create detection record
                $detection = [PSCustomObject]@{
                    FileName = $batFileName
                    OriginalPath = $processName
                    CommandLine = $commandLine
                    ExecutionTime = $time.ToString('yyyy-MM-dd HH:mm:ss')
                    User = $user
                    DetectedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    BootSession = $bootTime.ToString('yyyyMMddHHmmss')
                }
                
                # Check if this is already logged
                $alreadyLogged = $log | Where-Object { 
                    $_.FileName -eq $detection.FileName -and 
                    $_.ExecutionTime -eq $detection.ExecutionTime
                }
                
                if (!$alreadyLogged) {
                    $newDetections += $detection
                    Write-Host "  🔍 NEW: $batFileName" -ForegroundColor Green
                    Write-Host "     Path: $processName" -ForegroundColor Gray
                    Write-Host "     Time: $time" -ForegroundColor Gray
                    Write-Host "     User: $user" -ForegroundColor Gray
                }
            }
        }
    }
} catch {
    Write-Host "  Note: Event log access limited" -ForegroundColor DarkYellow
}

# Method 2: Check running batch processes RIGHT NOW
Write-Host "`nChecking currently running batch files..." -ForegroundColor Yellow

$runningBats = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like "*.bat" -or $_.Path -like "*.cmd" -or
    $_.ProcessName -eq "cmd" -and $_.MainWindowTitle -like "*.bat*"
}

if ($runningBats) {
    foreach ($proc in $runningBats) {
        $detection = [PSCustomObject]@{
            FileName = if ($proc.Path) { [System.IO.Path]::GetFileName($proc.Path) } else { "Unknown" }
            OriginalPath = $proc.Path
            CommandLine = ""
            ExecutionTime = $proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
            User = $proc.StartInfo.UserName
            DetectedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            BootSession = $bootTime.ToString('yyyyMMddHHmmss')
        }
        
        $alreadyLogged = $log | Where-Object { 
            $_.FileName -eq $detection.FileName -and 
            $_.ExecutionTime -eq $detection.ExecutionTime
        }
        
        if (!$alreadyLogged) {
            $newDetections += $detection
            Write-Host "  ⚡ RUNNING: $($detection.FileName)" -ForegroundColor Red
            Write-Host "     Path: $($proc.Path)" -ForegroundColor Gray
            Write-Host "     PID: $($proc.Id)" -ForegroundColor Gray
            Write-Host "     Started: $($proc.StartTime)" -ForegroundColor Gray
        }
    }
}

# Method 3: Check command history from all users' consoles
Write-Host "`nChecking command history..." -ForegroundColor Yellow

# Look in common history locations
$historyLocations = @(
    "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt",
    "$env:USERPROFILE\.bash_history",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*"
)

foreach ($historyPath in $historyLocations) {
    if (Test-Path $historyPath) {
        try {
            $historyContent = Get-Content $historyPath -Tail 100 -ErrorAction SilentlyContinue
            $batCommands = $historyContent | Where-Object { $_ -like "*.bat*" -or $_ -like "*.cmd*" }
            
            if ($batCommands) {
                foreach ($cmd in $batCommands | Select-Object -First 3) {
                    Write-Host "  📜 Found in history: $($cmd.Substring(0, [Math]::Min(50, $cmd.Length)))..." -ForegroundColor Cyan
                }
            }
        } catch {}
    }
}

# Save new detections to log file
if ($newDetections.Count -gt 0) {
    $log += $newDetections
    $log | ConvertTo-Json | Set-Content $logFile
    Write-Host "`n✅ Logged $($newDetections.Count) new batch file execution(s)" -ForegroundColor Green
} else {
    Write-Host "`nℹ️  No new batch file executions detected" -ForegroundColor Yellow
}

# Display ALL logged batch file executions from current boot session
$currentSessionLog = $log | Where-Object { $_.BootSession -eq $bootTime.ToString('yyyyMMddHHmmss') }

Write-Host "`n=== ALL BATCH EXECUTIONS THIS SESSION ===" -ForegroundColor Cyan
if ($currentSessionLog) {
    foreach ($entry in $currentSessionLog) {
        Write-Host "`n📄 File: $($entry.FileName)" -ForegroundColor Yellow
        Write-Host "   Original Location: $($entry.OriginalPath)" -ForegroundColor Gray
        Write-Host "   Executed: $($entry.ExecutionTime)" -ForegroundColor Gray
        Write-Host "   By User: $($entry.User)" -ForegroundColor Gray
        Write-Host "   Detected: $($entry.DetectedAt)" -ForegroundColor Gray
    }
} else {
    Write-Host "No batch files logged for this session" -ForegroundColor DarkGray
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total batch files executed since boot: $($currentSessionLog.Count)" -ForegroundColor White
Write-Host "Log file location: $logFile" -ForegroundColor Gray
Write-Host "Log survives reboots: YES" -ForegroundColor Green

# Quick check for YOUR specific batch file
$yourBatFile = "execution-tracker.bat"  # Change this to your batch filename
$foundYours = $currentSessionLog | Where-Object { $_.FileName -like "*$yourBatFile*" }

if ($foundYours) {
    Write-Host "`n🎯 YOUR FILE '$yourBatFile' WAS EXECUTED!" -ForegroundColor Red -BackgroundColor Black
    foreach ($exec in $foundYours) {
        Write-Host "   At: $($exec.ExecutionTime)" -ForegroundColor Yellow
        Write-Host "   From: $($exec.OriginalPath)" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n✅ Your batch file '$yourBatFile' was NOT executed" -ForegroundColor Green
}

Write-Host "`nTip: Run this script again to see new detections" -ForegroundColor DarkGray
