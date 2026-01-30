# Batch File Execution Detection Script
# GitHub URL: https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/refs/heads/main/BatchExecutionDetector.ps1

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "    BAT Execution Detection Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Create a unique marker file in Temp directory
$markerFile = "$env:TEMP\bat_execution_marker.txt"
$globalMarker = "$env:TEMP\global_bat_execution_marker.txt"

# Get system boot time (more accurate method)
try {
    $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
} catch {
    $bootTime = (Get-WmiObject Win32_OperatingSystem).LastBootUpTime
}

Write-Host "System Information:" -ForegroundColor Green
Write-Host "-------------------" -ForegroundColor Green
Write-Host "Current Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "System Boot Time: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Uptime: $([math]::Round((New-TimeSpan -Start $bootTime -End (Get-Date)).TotalHours, 2)) hours"
Write-Host ""

# Check if this script has run since boot
$scriptHasRun = $false
$firstRunTime = $null

if (Test-Path $markerFile) {
    $markerContent = Get-Content $markerFile
    $firstRunTime = $markerContent | Select-Object -First 1
    $scriptHasRun = $true
}

# Check for ANY batch file execution since boot
$anyBatExecuted = $false
$firstBatExecution = $null

if (Test-Path $globalMarker) {
    $globalContent = Get-Content $globalMarker
    $markerBootTime = $globalContent | Select-Object -Index 0
    $firstBatExecution = $globalContent | Select-Object -Index 1
    
    # Check if marker was created after last boot
    if ($markerBootTime -and $bootTime -lt $firstBatExecution) {
        $anyBatExecuted = $true
    }
}

# Display results
Write-Host "Execution Detection Results:" -ForegroundColor Yellow
Write-Host "---------------------------" -ForegroundColor Yellow

if ($scriptHasRun) {
    Write-Host "[THIS SCRIPT] " -NoNewline -ForegroundColor Red
    Write-Host "Has been executed since last restart"
    Write-Host "  First execution: $firstRunTime"
} else {
    Write-Host "[THIS SCRIPT] " -NoNewline -ForegroundColor Green
    Write-Host "First execution since restart"
    # Create marker for this script
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File -FilePath $markerFile
}

Write-Host ""

if ($anyBatExecuted) {
    Write-Host "[ANY BATCH FILE] " -NoNewline -ForegroundColor Red
    Write-Host "A batch file has been executed since restart"
    Write-Host "  First batch execution: $firstBatExecution"
} else {
    Write-Host "[ANY BATCH FILE] " -NoNewline -ForegroundColor Green
    Write-Host "No batch files executed since restart"
    # Create global marker if this is the first batch execution
    if (-not $scriptHasRun) {
        @($bootTime.ToString('yyyy-MM-dd HH:mm:ss'), (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) | Out-File -FilePath $globalMarker
    }
}

Write-Host ""

# Show recent batch file executions (last 24 hours)
Write-Host "Recent Batch File Executions (Last 24h):" -ForegroundColor Magenta
Write-Host "----------------------------------------" -ForegroundColor Magenta

# Check Windows event logs for batch file executions
try {
    $startTime = (Get-Date).AddHours(-24)
    
    # Method 1: Check Process Creation events (Windows 10/11)
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 4688
        StartTime = $startTime
    } -MaxEvents 20 -ErrorAction SilentlyContinue | Where-Object {
        $_.Properties[5].Value -like "*.bat" -or 
        $_.Properties[5].Value -like "*cmd.exe" -or
        $_.Properties[0].Value -like "*cmd.exe"
    }
    
    if ($events) {
        foreach ($event in $events | Select-Object -First 5) {
            $time = $event.TimeCreated.ToString('HH:mm:ss')
            $process = $event.Properties[5].Value
            $user = $event.Properties[1].Value
            Write-Host "  $time - $process (User: $user)" -ForegroundColor Gray
        }
    } else {
        # Method 2: Alternative detection
        $processEvents = Get-Process -Name "cmd" -ErrorAction SilentlyContinue | 
            Where-Object { $_.StartTime -gt $startTime }
        
        if ($processEvents) {
            foreach ($proc in $processEvents | Select-Object -First 3) {
                Write-Host "  $($proc.StartTime.ToString('HH:mm:ss')) - cmd.exe (PID: $($proc.Id))" -ForegroundColor Gray
            }
        } else {
            Write-Host "  No batch executions detected in event logs" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  Event log access restricted or unavailable" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Marker Files:" -ForegroundColor Cyan
Write-Host "-------------" -ForegroundColor Cyan
Write-Host "Script Marker: $markerFile"
Write-Host "Global Marker: $globalMarker"

Write-Host ""
Write-Host "Cleanup Commands:" -ForegroundColor DarkYellow
Write-Host "rm '$markerFile'" -ForegroundColor Gray
Write-Host "rm '$globalMarker'" -ForegroundColor Gray

Write-Host ""
# Self-cleanup option (optional - uncomment if you want auto-cleanup)
# if ((Read-Host "Cleanup markers? (y/n)") -eq 'y') {
#     Remove-Item $markerFile -ErrorAction SilentlyContinue
#     Remove-Item $globalMarker -ErrorAction SilentlyContinue
#     Write-Host "Markers cleaned up!" -ForegroundColor Green
# }

Write-Host "Done!" -ForegroundColor Green
