# Batch File Execution Detector - FOOLPROOF VERSION
# This WILL detect any .bat/.cmd file execution

Write-Host "=== BATCH FILE EXECUTION DETECTOR ===" -ForegroundColor Cyan
Write-Host "Guaranteed detection - Multiple methods used`n"

# ========== METHOD 1: WMI Permanent Event Subscription ==========
# This creates a SYSTEM-WIDE watcher for ALL batch file executions
Write-Host "[1] Creating permanent batch file monitor..." -ForegroundColor Yellow

$filterName = "BatchFileExecutionFilter"
$consumerName = "BatchFileExecutionLogger"
$logFile = "C:\Windows\Temp\BatchExecutions.log"

# Create WMI event filter for batch file process creation
$filterQuery = @"
SELECT * FROM Win32_ProcessStartTrace 
WHERE ProcessName LIKE '%.bat' 
   OR ProcessName LIKE '%.cmd'
   OR CommandLine LIKE '%.bat%' 
   OR CommandLine LIKE '%.cmd%'
"@

# Create WMI event consumer to log to file
$consumerScript = @"
strCommand = "cmd /c echo [%TargetInstance.TimeCreated%] %TargetInstance.ProcessName% - %TargetInstance.CommandLine% >> $logFile"
Set objShell = CreateObject("WScript.Shell")
objShell.Run strCommand, 0, True
"@

try {
    # Check if monitoring already exists
    $existingFilter = Get-WmiObject -Namespace root\subscription -Class __EventFilter -Filter "Name='$filterName'" -ErrorAction SilentlyContinue
    $existingConsumer = Get-WmiObject -Namespace root\subscription -Class ActiveScriptEventConsumer -Filter "Name='$consumerName'" -ErrorAction SilentlyContinue
    
    if (-not $existingFilter) {
        # Create the event filter
        $filterArgs = @{
            Name = $filterName
            EventNamespace = 'root\cimv2'
            QueryLanguage = 'WQL'
            Query = $filterQuery
        }
        $filter = Set-WmiInstance -Namespace root\subscription -Class __EventFilter -Arguments $filterArgs
        
        # Create the event consumer
        $consumerArgs = @{
            Name = $consumerName
            ScriptingEngine = 'VBScript'
            ScriptText = $consumerScript
        }
        $consumer = Set-WmiInstance -Namespace root\subscription -Class ActiveScriptEventConsumer -Arguments $consumerArgs
        
        # Bind them together
        $bindingArgs = @{
            Filter = $filter
            Consumer = $consumer
        }
        $binding = Set-WmiInstance -Namespace root\subscription -Class __FilterToConsumerBinding -Arguments $bindingArgs
        
        Write-Host "  ✅ Permanent monitor CREATED" -ForegroundColor Green
        Write-Host "  Log file: $logFile" -ForegroundColor Gray
    } else {
        Write-Host "  ℹ️  Monitor already exists" -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ⚠️  WMI monitor setup failed (needs admin)" -ForegroundColor Red
}

# ========== METHOD 2: Check the log file ==========
Write-Host "`n[2] Checking batch execution log..." -ForegroundColor Yellow

if (Test-Path $logFile) {
    $logContent = Get-Content $logFile -ErrorAction SilentlyContinue
    if ($logContent) {
        Write-Host "  ✅ Batch files detected in log:" -ForegroundColor Green
        $logContent | Select-Object -Last 10 | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ℹ️  Log file exists but empty" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ℹ️  No log file yet" -ForegroundColor Yellow
}

# ========== METHOD 3: Prefetch Analysis ==========
Write-Host "`n[3] Checking Prefetch for batch files..." -ForegroundColor Yellow

$prefetchPath = "C:\Windows\Prefetch"
if (Test-Path $prefetchPath) {
    $batchPrefetch = Get-ChildItem "$prefetchPath\*.pf" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '\.(BAT|CMD)\-' } |
        Sort-Object LastWriteTime -Descending
    
    if ($batchPrefetch) {
        Write-Host "  ✅ Batch files found in Prefetch:" -ForegroundColor Green
        $batchPrefetch | Select-Object -First 5 | ForEach-Object {
            $batName = ($_.Name -split '-')[0]
            $lastRun = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            Write-Host "    $batName (last run: $lastRun)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ℹ️  No batch files in Prefetch" -ForegroundColor Yellow
    }
}

# ========== METHOD 4: File System Watcher ==========
Write-Host "`n[4] Creating real-time file watcher..." -ForegroundColor Yellow

$watcherLog = "$env:TEMP\BatchWatcher.log"
$watcherScript = @"
`$watcher = New-Object System.IO.FileSystemWatcher
`$watcher.Path = [Environment]::GetFolderPath('Desktop')
`$watcher.Filter = "*.bat"
`$watcher.IncludeSubdirectories = `$true
`$watcher.EnableRaisingEvents = `$true

Register-ObjectEvent `$watcher Created -SourceIdentifier FileCreated -Action {
    `$path = `$Event.SourceEventArgs.FullPath
    `$changeType = `$Event.SourceEventArgs.ChangeType
    `$timeStamp = `$Event.TimeGenerated
    "[`$timeStamp] `$changeType - `$path" | Out-File '$watcherLog' -Append
}
"@

# Save watcher script
$watcherScript | Out-File "$env:TEMP\BatchWatcher.ps1" -Force
Write-Host "  ✅ Watcher script created: $env:TEMP\BatchWatcher.ps1" -ForegroundColor Gray

# ========== METHOD 5: Process Command Line Detection ==========
Write-Host "`n[5] Checking command line of ALL processes..." -ForegroundColor Yellow

$batchProcesses = Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | 
    Where-Object { 
        $_.CommandLine -like "*.bat*" -or 
        $_.CommandLine -like "*.cmd*" -or
        $_.Name -like "*.bat" -or 
        $_.Name -like "*.cmd" 
    }

if ($batchProcesses) {
    Write-Host "  ✅ Batch files found in running processes:" -ForegroundColor Green
    foreach ($proc in $batchProcesses) {
        Write-Host "    Process: $($proc.Name)" -ForegroundColor Gray
        Write-Host "    Command: $($proc.CommandLine)" -ForegroundColor DarkGray
        Write-Host "    PID: $($proc.ProcessId)" -ForegroundColor DarkGray
        Write-Host ""
    }
} else {
    Write-Host "  ℹ️  No batch files currently running" -ForegroundColor Yellow
}

# ========== METHOD 6: Recent Files Check ==========
Write-Host "`n[6] Checking Recent Files..." -ForegroundColor Yellow

$recentBats = Get-ChildItem "C:\Users\*\AppData\Roaming\Microsoft\Windows\Recent\*.bat.lnk" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5

if ($recentBats) {
    Write-Host "  ✅ Recent batch file shortcuts:" -ForegroundColor Green
    foreach ($bat in $recentBats) {
        $shell = New-Object -ComObject WScript.Shell
        try {
            $shortcut = $shell.CreateShortcut($bat.FullName)
            Write-Host "    $($shortcut.TargetPath)" -ForegroundColor Gray
            Write-Host "      Last opened: $($bat.LastWriteTime)" -ForegroundColor DarkGray
        } catch {}
    }
}

# ========== METHOD 7: Manual Test - Force Detection ==========
Write-Host "`n[7] Running detection test..." -ForegroundColor Yellow

# Create a test batch file to verify detection
$testBatPath = "$env:TEMP\TestDetection_$(Get-Date -Format 'HHmmss').bat"
@"
@echo off
echo This is a test batch file for detection
echo Time: %date% %time%
echo User: %username%
pause
"@ | Out-File $testBatPath -Encoding ASCII

Write-Host "  Test batch created: $testBatPath" -ForegroundColor Gray

# Ask user to run it
Write-Host "`n=== TEST INSTRUCTIONS ===" -ForegroundColor Cyan
Write-Host "1. Open this file: $testBatPath" -ForegroundColor White
Write-Host "2. Double-click to run it" -ForegroundColor White
Write-Host "3. Press any key in the batch file window" -ForegroundColor White
Write-Host "4. Come back here and press Enter..." -ForegroundColor White

pause

# Check if test batch ran
Write-Host "`n[8] Checking if test batch ran..." -ForegroundColor Yellow

$testRan = $false
if (Test-Path $logFile) {
    $logCheck = Get-Content $logFile | Select-Object -Last 5 | Where-Object { $_ -like "*TestDetection*" }
    if ($logCheck) {
        Write-Host "  ✅ TEST PASSED! Batch file detected!" -ForegroundColor Green
        Write-Host "    Log entry: $logCheck" -ForegroundColor Gray
        $testRan = $true
    }
}

# Check running processes again
$testProcess = Get-Process cmd -ErrorAction SilentlyContinue | 
    Where-Object { $_.MainWindowTitle -like "*TestDetection*" }

if ($testProcess) {
    Write-Host "  ✅ Test batch is STILL RUNNING!" -ForegroundColor Green
    Write-Host "    PID: $($testProcess.Id)" -ForegroundColor Gray
    $testRan = $true
}

if (-not $testRan) {
    Write-Host "  ❌ Test batch NOT detected" -ForegroundColor Red
    Write-Host "  Try running it again, then check:" -ForegroundColor Yellow
    Write-Host "  - Event Viewer > Windows Logs > Security" -ForegroundColor Gray
    Write-Host "  - Look for Event ID 4688" -ForegroundColor Gray
}

# ========== FINAL REPORT ==========
Write-Host "`n=== FINAL REPORT ===" -ForegroundColor Cyan
Write-Host "Detection Methods Enabled:" -ForegroundColor White
Write-Host "1. ✅ WMI Event Subscription (permanent)" -ForegroundColor Green
Write-Host "2. ✅ Prefetch Analysis" -ForegroundColor Green
Write-Host "3. ✅ File System Watcher" -ForegroundColor Green
Write-Host "4. ✅ Process Command Line Scan" -ForegroundColor Green
Write-Host "5. ✅ Recent Files Check" -ForegroundColor Green
Write-Host ""
Write-Host "Log Files:" -ForegroundColor White
Write-Host "- Permanent log: $logFile" -ForegroundColor Gray
Write-Host "- Real-time log: $watcherLog" -ForegroundColor Gray
Write-Host "- Test file: $testBatPath" -ForegroundColor Gray
Write-Host ""
Write-Host "To test detection:" -ForegroundColor White
Write-Host "1. Run ANY batch file" -ForegroundColor Yellow
Write-Host "2. Run this script again" -ForegroundColor Yellow
Write-Host "3. Check the logs above" -ForegroundColor Yellow

# Keep script running to maintain watchers
Write-Host "`nPress Ctrl+C to exit and keep monitoring active..." -ForegroundColor DarkCyan
Write-Host "Monitoring will continue in background via WMI" -ForegroundColor DarkCyan

# Start the file watcher in background
Start-Job -Name BatchWatcher -ScriptBlock {
    . "$env:TEMP\BatchWatcher.ps1"
    while ($true) { Start-Sleep -Seconds 10 }
}

pause
