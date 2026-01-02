# Jar Execution Checker by YarpLetapStan
# Checks for JAR files executed since last PC shutdown
# github.com/YarpLetapStan

# Open clean window immediately
Start-Process powershell.exe -WindowStyle Normal -ArgumentList @"
-NoExit -Command "& {
    Clear-Host
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host '     Jar Execution Checker by YarpLetapStan' -ForegroundColor Cyan
    WriteHost '============================================' -ForegroundColor Cyan
    Write-Host ''
    
    # Get last shutdown time
    try {
        `$shutdown = Get-WinEvent -FilterHashtable @{LogName='System';ID=6006} -MaxEvents 1 -ErrorAction Stop
        Write-Host 'Last system shutdown: ' -NoNewline
        Write-Host `$shutdown.TimeCreated -ForegroundColor Yellow
    } catch {
        `$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Write-Host 'System up since: ' -NoNewline
        Write-Host `$uptime -ForegroundColor Yellow
    }
    
    Write-Host ''
    Write-Host 'Scanning for JAR files executed since shutdown...' -ForegroundColor White
    Write-Host '--------------------------------------------' -ForegroundColor Gray
    
    # Check for running JAR processes
    `$jarProcesses = @()
    Get-Process java, javaw -ErrorAction SilentlyContinue | ForEach-Object {
        `$cmdLine = (Get-CimInstance Win32_Process -Filter \"ProcessId=`$(`$_.Id)\").CommandLine
        if (`$cmdLine -match '\.jar') {
            `$jarProcesses += [PSCustomObject]@{
                Type = 'Running JAR'
                PID = `$_.Id
                Name = `$_.ProcessName
                Command = `$cmdLine
                StartTime = `$_.StartTime
            }
        }
    }
    
    # Check prefetch for recent JAR execution
    `$prefetchJars = @()
    `$prefetchPath = \"`$env:SystemRoot\\Prefetch\"
    if (Test-Path `$prefetchPath) {
        `$lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Get-ChildItem -Path `$prefetchPath -Filter \"*.pf\" -ErrorAction SilentlyContinue | 
            Where-Object { `$_.LastWriteTime -gt `$lastBoot } |
            ForEach-Object {
                if (`$_.Name -match 'java|javaw|jar') {
                    `$prefetchJars += [PSCustomObject]@{
                        Type = 'Prefetch'
                        Name = `$_.Name
                        LastRun = `$_.LastWriteTime
                        Path = `$_.FullName
                    }
                }
            }
    }
    
    # Combine results
    `$allResults = `$jarProcesses + `$prefetchJars
    
    # Display results
    if (`$allResults.Count -gt 0) {
        Write-Host \"`nFound `$(`$allResults.Count) evidence(s) of JAR execution:\" -ForegroundColor Yellow
        Write-Host ''
        
        # Show running processes
        if (`$jarProcesses.Count -gt 0) {
            Write-Host 'Currently Running JAR Processes:' -ForegroundColor Cyan
            foreach (`$proc in `$jarProcesses) {
                Write-Host \"  PID `$(`$proc.PID) (`$(`$proc.Name))\" -ForegroundColor White
                Write-Host \"    Started: `$(`$proc.StartTime)\" -ForegroundColor Gray
                Write-Host \"    Command: `$(`$proc.Command)\" -ForegroundColor Gray
                Write-Host ''
            }
        }
        
        # Show prefetch evidence
        if (`$prefetchJars.Count -gt 0) {
            Write-Host 'Prefetch Evidence (recent executions):' -ForegroundColor Cyan
            foreach (`$pf in `$prefetchJars) {
                Write-Host \"  `$(`$pf.Name)\" -ForegroundColor White
                Write-Host \"    Last Run: `$(`$pf.LastRun)\" -ForegroundColor Gray
                Write-Host ''
            }
        }
        
        # Summary
        Write-Host 'Summary:' -ForegroundColor Yellow
        Write-Host \"  Running JAR processes: `$(`$jarProcesses.Count)\" -ForegroundColor White
        Write-Host \"  Prefetch evidence: `$(`$prefetchJars.Count)\" -ForegroundColor White
        Write-Host \"  Total findings: `$(`$allResults.Count)\" -ForegroundColor White
        
    } else {
        Write-Host '`nNo evidence of JAR files executed since last shutdown.' -ForegroundColor Green
    }
    
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor Gray
    Write-Host 'github.com/YarpLetapStan' -ForegroundColor Gray
    Write-Host 'Script by YarpLetapStan' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Window closes in 30 seconds or press any key...' -ForegroundColor Cyan
    try {
        `$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,AllowCtrlC')
    } catch {
        Start-Sleep -Seconds 30
    }
}"
"@

# Exit the original window
Stop-Process -Id $PID
