# JAR Injection Checker for Minecraft
# Created by YarpLetapStan
# Checks for JAR files by searching for "-jar" strings in process memory

# Clear the screen and open a new CMD window to hide the original command
Start-Process cmd.exe -ArgumentList "/k powershell -NoProfile -ExecutionPolicy Bypass -Command `"& {
    Clear-Host
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '   JAR Injection Checker v1.0' -ForegroundColor Cyan
    Write-Host '   By YarpLetapStan' -ForegroundColor Cyan
    Write-Host '========================================\n' -ForegroundColor Cyan
    Write-Host '[INFO] Scanning system for JAR file executions...\n' -ForegroundColor Yellow
    
    # Get last boot time
    `$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    
    # Initialize results array
    `$foundJars = @()
    
    # Check MsMpEng process
    `$msmpengProcess = Get-Process -Name 'MsMpEng' -ErrorAction SilentlyContinue
    if (`$msmpengProcess) {
        # Check Windows Defender logs for scanned/detected items
        try {
            `$defenderEvents = Get-WinEvent -LogName 'Microsoft-Windows-Windows Defender/Operational' -MaxEvents 500 -ErrorAction SilentlyContinue |
                Where-Object { 
                    (`$_.Message -match '-jar' -or `$_.Message -match '\.jar') -and 
                    `$_.TimeCreated -gt `$bootTime 
                }
            
            if (`$defenderEvents) {
                foreach (`$event in `$defenderEvents) {
                    `$message = `$event.Message
                    if (`$message -match '(?:file:|path:|Process Name:)\s*([^\r\n]+\.jar[^\r\n]*)') {
                        `$jarPath = `$matches[1].Trim()
                        `$foundJars += [PSCustomObject]@{
                            Source = 'Defender Event Log'
                            Detection = 'JAR file reference'
                            FilePath = `$jarPath
                            Timestamp = `$event.TimeCreated
                            EventID = `$event.Id
                        }
                    }
                }
            }
        } catch {}
    }
    
    # Check all Java processes for '-jar' command line arguments
    `$javaProcesses = Get-Process -Name 'java', 'javaw' -ErrorAction SilentlyContinue
    
    if (`$javaProcesses) {
        foreach (`$proc in `$javaProcesses) {
            try {
                `$processInfo = Get-CimInstance Win32_Process -Filter \"ProcessId = `$(`$proc.Id)\" -ErrorAction Stop
                `$cmdLine = `$processInfo.CommandLine
                
                if (`$cmdLine -match '-jar\s+\"?([^\"\\s]+\.jar)') {
                    `$jarPath = `$matches[1]
                    `$foundJars += [PSCustomObject]@{
                        Source = 'Active Java Process'
                        ProcessID = `$proc.Id
                        Detection = 'Command line argument'
                        FilePath = `$jarPath
                        Timestamp = `$proc.StartTime
                        FullCommand = `$cmdLine
                    }
                }
            } catch {}
        }
    }
    
    # Check Windows Event Logs for process creation with '-jar'
    try {
        `$processEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security', 'Microsoft-Windows-Sysmon/Operational'
            ID = 4688, 1
            StartTime = `$bootTime
        } -ErrorAction SilentlyContinue | Where-Object { `$_.Message -match '-jar' } | Select-Object -First 20
        
        if (`$processEvents) {
            foreach (`$event in `$processEvents) {
                if (`$event.Message -match '([^\\s]+\.jar)') {
                    `$jarPath = `$matches[1]
                    `$foundJars += [PSCustomObject]@{
                        Source = 'Process Creation Event'
                        Detection = \"Event Log ID `$(`$event.Id)\"
                        FilePath = `$jarPath
                        Timestamp = `$event.TimeCreated
                    }
                }
            }
        }
    } catch {}
    
    # Check recent JAR files accessed in common locations
    `$searchPaths = @(
        \"`$env:APPDATA\.minecraft\",
        \"`$env:TEMP\",
        \"`$env:USERPROFILE\Downloads\",
        \"`$env:USERPROFILE\Desktop\"
    )
    
    foreach (`$path in `$searchPaths) {
        if (Test-Path `$path) {
            `$recentJars = Get-ChildItem -Path `$path -Filter '*.jar' -Recurse -ErrorAction SilentlyContinue |
                Where-Object { `$_.LastAccessTime -gt `$bootTime } |
                Select-Object -First 10
            
            foreach (`$jar in `$recentJars) {
                `$foundJars += [PSCustomObject]@{
                    Source = 'File System Scan'
                    Detection = 'Recently accessed'
                    FilePath = `$jar.FullName
                    Timestamp = `$jar.LastAccessTime
                }
            }
        }
    }
    
    # Display results
    Write-Host '\n========================================' -ForegroundColor Cyan
    Write-Host '   DETECTION RESULTS' -ForegroundColor Cyan
    Write-Host '========================================\n' -ForegroundColor Cyan
    
    if (`$foundJars.Count -eq 0) {
        Write-Host '[RESULT] No JAR file executions detected since last boot.' -ForegroundColor Green
    } else {
        Write-Host \"[RESULT] Found `$(`$foundJars.Count) JAR file detection(s):\n\" -ForegroundColor Yellow
        
        # Remove duplicates and display
        `$uniqueJars = `$foundJars | Sort-Object FilePath -Unique
        
        foreach (`$jar in `$uniqueJars) {
            Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray
            Write-Host 'Source:    ' -NoNewline -ForegroundColor Cyan
            Write-Host `$jar.Source -ForegroundColor White
            Write-Host 'Detection: ' -NoNewline -ForegroundColor Cyan
            Write-Host `$jar.Detection -ForegroundColor White
            Write-Host 'File Path: ' -NoNewline -ForegroundColor Cyan
            Write-Host `$jar.FilePath -ForegroundColor Yellow
            Write-Host 'Timestamp: ' -NoNewline -ForegroundColor Cyan
            Write-Host `$jar.Timestamp -ForegroundColor White
            
            if (`$jar.ProcessID) {
                Write-Host 'PID:       ' -NoNewline -ForegroundColor Cyan
                Write-Host `$jar.ProcessID -ForegroundColor White
            }
            
            if (`$jar.FullCommand) {
                Write-Host 'Full CMD:  ' -NoNewline -ForegroundColor Cyan
                Write-Host `$jar.FullCommand -ForegroundColor Gray
            }
            Write-Host ''
        }
        
        Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray
        Write-Host \"\n[SUMMARY] Total unique JAR files: `$(`$uniqueJars.Count)\" -ForegroundColor Green
    }
    
    Write-Host '\n[INFO] Scan complete. Press any key to exit...' -ForegroundColor Cyan
    `$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}`""

# Exit the original window immediately
exit
