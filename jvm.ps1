# Simple Batch File Execution Detector
# Checks if ANY .bat/.cmd file has been executed since system restart

Write-Host "=== Batch File Execution Check ===" -ForegroundColor Cyan
Write-Host "Checking if .bat/.cmd files have run since last restart..."
Write-Host ""

# Get system boot time
try {
    $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
} catch {
    $bootTime = (Get-WmiObject Win32_OperatingSystem).LastBootUpTime
}

Write-Host "System Boot Time: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Current Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Uptime: $([math]::Round((New-TimeSpan -Start $bootTime -End (Get-Date)).TotalHours, 2)) hours"
Write-Host ""

# Method 1: Check Windows Event Logs for batch file executions
Write-Host "Checking Windows Event Logs..." -ForegroundColor Yellow

$batDetected = $false
$firstBatExecution = $null

# Look for batch file executions since boot time
try {
    # Get process creation events since boot
    $events = Get-WinEvent -LogName 'Security' -FilterXPath "*[System[(EventID=4688) and TimeCreated[@SystemTime>='$($bootTime.ToString('s'))']]]" -ErrorAction SilentlyContinue
    
    if ($events) {
        foreach ($event in $events) {
            $processName = $event.Properties[5].Value
            
            # Check if it's a batch file (.bat or .cmd)
            if ($processName -like "*.bat" -or $processName -like "*.cmd") {
                $batDetected = $true
                if (!$firstBatExecution -or $event.TimeCreated -lt $firstBatExecution) {
                    $firstBatExecution = $event.TimeCreated
                }
                Write-Host "  ✓ Found: $processName" -ForegroundColor Green
                Write-Host "    Time: $($event.TimeCreated.ToString('HH:mm:ss'))" -ForegroundColor Gray
                Write-Host "    User: $($event.Properties[1].Value)" -ForegroundColor Gray
                Write-Host ""
            }
        }
    }
} catch {
    Write-Host "  Unable to access Security event logs" -ForegroundColor DarkYellow
    Write-Host "  Trying alternative method..." -ForegroundColor DarkYellow
}

# Method 2: Alternative - Check for running batch processes
if (!$batDetected) {
    Write-Host "Checking currently running processes..." -ForegroundColor Yellow
    
    # Get all processes that started after boot
    $allProcesses = Get-Process -ErrorAction SilentlyContinue | 
        Where-Object { $_.StartTime -gt $bootTime }
    
    foreach ($process in $allProcesses) {
        $processPath = $process.Path
        if ($processPath -and ($processPath -like "*.bat" -or $processPath -like "*.cmd")) {
            $batDetected = $true
            Write-Host "  ✓ Found running batch file: $processPath" -ForegroundColor Green
            Write-Host "    Started: $($process.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

# Method 3: Check Prefetch for batch files (if available)
if (!$batDetected) {
    $prefetchPath = "C:\Windows\Prefetch"
    if (Test-Path $prefetchPath) {
        Write-Host "Checking Prefetch files..." -ForegroundColor Yellow
        
        # Look for .bat/.cmd in prefetch filenames
        $prefetchFiles = Get-ChildItem "$prefetchPath\*.pf" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "\.(BAT|CMD)\-" } |
            Select-Object -First 5
            
        if ($prefetchFiles) {
            $batDetected = $true
            Write-Host "  ✓ Found in Prefetch:" -ForegroundColor Green
            foreach ($file in $prefetchFiles) {
                Write-Host "    $($file.Name)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
}

# Display final result
Write-Host "=== RESULT ===" -ForegroundColor Cyan
if ($batDetected) {
    Write-Host "❌ BATCH FILE WAS EXECUTED" -ForegroundColor Red -BackgroundColor Black
    Write-Host "First detected at: $($firstBatExecution.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
} else {
    Write-Host "✅ NO BATCH FILES EXECUTED" -ForegroundColor Green -BackgroundColor Black
    Write-Host "No .bat/.cmd files have run since restart" -ForegroundColor Green
}

Write-Host ""
Write-Host "Note: Detection depends on Windows logging settings" -ForegroundColor DarkGray
