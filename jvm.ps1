# BatFileMonitor.ps1
# Monitors and logs .bat file executions from system startup
# Tracks file name and original location even if moved after execution

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$env:ProgramData\BatFileMonitor\execution_log.csv",
    
    [Parameter(Mandatory=$false)]
    [switch]$Install,
    
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall,
    
    [Parameter(Mandatory=$false)]
    [switch]$ViewLogs
)

# Configuration
$script:MonitorFolder = "$env:ProgramData\BatFileMonitor"
$script:TaskName = "BatFileMonitor"

function Initialize-MonitoringEnvironment {
    # Create monitoring folder if it doesn't exist
    if (-not (Test-Path $script:MonitorFolder)) {
        New-Item -ItemType Directory -Path $script:MonitorFolder -Force | Out-Null
        Write-Host "[+] Created monitoring folder: $script:MonitorFolder" -ForegroundColor Green
    }
    
    # Create log file with headers if it doesn't exist
    if (-not (Test-Path $LogPath)) {
        $headers = "Timestamp,ProcessName,CommandLine,FilePath,FileHash,ExecutionUser,ParentProcess,BootTime"
        $headers | Out-File -FilePath $LogPath -Encoding UTF8
        Write-Host "[+] Created log file: $LogPath" -ForegroundColor Green
    }
}

function Get-SystemBootTime {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    return $os.LastBootUpTime
}

function Get-FileHashSafe {
    param([string]$FilePath)
    
    try {
        if (Test-Path $FilePath) {
            $hash = Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction SilentlyContinue
            return $hash.Hash
        }
    } catch {
        return "N/A"
    }
    return "N/A"
}

function Monitor-BatExecutions {
    Write-Host "[*] Starting .bat file execution monitoring..." -ForegroundColor Cyan
    
    $bootTime = Get-SystemBootTime
    $lastCheck = Get-Date
    
    while ($true) {
        try {
            # Query Windows Event Log for process creation events
            # Event ID 4688 (Process Creation) requires audit policy enabled
            $events = Get-WinEvent -FilterHashtable @{
                LogName = 'Security'
                ID = 4688
                StartTime = $lastCheck
            } -ErrorAction SilentlyContinue
            
            foreach ($event in $events) {
                $eventXml = [xml]$event.ToXml()
                $eventData = $eventXml.Event.EventData.Data
                
                $processName = ($eventData | Where-Object {$_.Name -eq 'NewProcessName'}).'#text'
                $commandLine = ($eventData | Where-Object {$_.Name -eq 'CommandLine'}).'#text'
                $creator = ($eventData | Where-Object {$_.Name -eq 'SubjectUserName'}).'#text'
                $parentProcess = ($eventData | Where-Object {$_.Name -eq 'ParentProcessName'}).'#text'
                
                # Check if it's a .bat file execution
                if ($commandLine -match '\.bat["\s]|\.bat$' -or $processName -match '\.bat$') {
                    # Extract .bat file path from command line
                    $batFilePath = if ($commandLine -match '"([^"]+\.bat)"') {
                        $matches[1]
                    } elseif ($commandLine -match '([^\s]+\.bat)') {
                        $matches[1]
                    } else {
                        $processName
                    }
                    
                    $fileHash = Get-FileHashSafe -FilePath $batFilePath
                    
                    $logEntry = [PSCustomObject]@{
                        Timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                        ProcessName = Split-Path $processName -Leaf
                        CommandLine = $commandLine
                        FilePath = $batFilePath
                        FileHash = $fileHash
                        ExecutionUser = $creator
                        ParentProcess = $parentProcess
                        BootTime = $bootTime.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    
                    # Append to log
                    $logEntry | Export-Csv -Path $LogPath -Append -NoTypeInformation -Encoding UTF8
                    
                    Write-Host "[!] BAT execution detected:" -ForegroundColor Yellow
                    Write-Host "    File: $batFilePath" -ForegroundColor White
                    Write-Host "    Time: $($event.TimeCreated)" -ForegroundColor White
                    Write-Host "    User: $creator" -ForegroundColor White
                    Write-Host "    Hash: $fileHash" -ForegroundColor White
                }
            }
            
            # Also check WMI event logs (alternative method)
            $wmiEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'Microsoft-Windows-PowerShell/Operational'
                StartTime = $lastCheck
            } -ErrorAction SilentlyContinue | Where-Object {
                $_.Message -match '\.bat'
            }
            
            foreach ($wmiEvent in $wmiEvents) {
                # Process WMI-based detections if needed
            }
            
            $lastCheck = Get-Date
            Start-Sleep -Seconds 5
            
        } catch {
            Write-Host "[!] Error in monitoring loop: $_" -ForegroundColor Red
            Start-Sleep -Seconds 10
        }
    }
}

function Install-MonitoringService {
    Write-Host "[*] Installing BAT File Monitor..." -ForegroundColor Cyan
    
    Initialize-MonitoringEnvironment
    
    # Enable Process Creation Auditing (required for Event ID 4688)
    Write-Host "[*] Enabling process creation auditing..." -ForegroundColor Cyan
    auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
    
    # Create scheduled task to run at startup
    $scriptPath = $PSCommandPath
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    
    $trigger = New-ScheduledTaskTrigger -AtStartup
    
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    # Register the scheduled task
    Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    
    Write-Host "[+] Monitoring service installed successfully!" -ForegroundColor Green
    Write-Host "[+] Log file location: $LogPath" -ForegroundColor Green
    Write-Host "[+] The monitor will start automatically on next boot." -ForegroundColor Green
    Write-Host "[*] To start monitoring now, run: Start-ScheduledTask -TaskName '$script:TaskName'" -ForegroundColor Yellow
}

function Uninstall-MonitoringService {
    Write-Host "[*] Uninstalling BAT File Monitor..." -ForegroundColor Cyan
    
    # Remove scheduled task
    $task = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false
        Write-Host "[+] Scheduled task removed." -ForegroundColor Green
    } else {
        Write-Host "[!] Scheduled task not found." -ForegroundColor Yellow
    }
    
    Write-Host "[*] Log files preserved at: $LogPath" -ForegroundColor Cyan
    Write-Host "[+] Uninstallation complete." -ForegroundColor Green
}

function Show-Logs {
    if (Test-Path $LogPath) {
        Write-Host "`n[*] BAT File Execution Log:" -ForegroundColor Cyan
        Write-Host "=" * 100 -ForegroundColor Gray
        
        $logs = Import-Csv -Path $LogPath
        
        if ($logs.Count -eq 0) {
            Write-Host "[!] No executions logged yet." -ForegroundColor Yellow
        } else {
            $logs | Format-Table -AutoSize -Property Timestamp, ProcessName, FilePath, ExecutionUser, FileHash
            Write-Host "`n[*] Total executions logged: $($logs.Count)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "[!] Log file not found: $LogPath" -ForegroundColor Red
    }
}

# Main execution logic
if ($Install) {
    Install-MonitoringService
} elseif ($Uninstall) {
    Uninstall-MonitoringService
} elseif ($ViewLogs) {
    Show-Logs
} else {
    # Running in monitoring mode (triggered by scheduled task)
    Initialize-MonitoringEnvironment
    Monitor-BatExecutions
}
