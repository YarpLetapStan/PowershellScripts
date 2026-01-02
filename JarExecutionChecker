# YarpLetapStan JAR Execution Checker
# github.com/YarpLetapStan
# Checks for JAR files executed since last PC shutdown

# Open clean window
Start-Process powershell.exe -WindowStyle Normal -ArgumentList @"
-NoExit -Command "& {
    Clear-Host
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host '     YarpLetapStan JAR Execution Checker' -ForegroundColor Cyan
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'github.com/YarpLetapStan' -ForegroundColor Gray
    Write-Host ''
    
    # Get last shutdown time
    try {
        `$shutdown = Get-WinEvent -FilterHashtable @{LogName='System';ID=6006} -MaxEvents 1 -ErrorAction Stop
        Write-Host 'Last system shutdown: ' -NoNewline
        Write-Host `$shutdown.TimeCreated -ForegroundColor Yellow
    } catch {
        `$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Write-Host 'System uptime since: ' -NoNewline
        Write-Host `$uptime -ForegroundColor Yellow
    }
    
    Write-Host ''
    Write-Host 'Scanning for JAR execution since shutdown...' -ForegroundColor White
    Write-Host '--------------------------------------------' -ForegroundColor Gray
    
    # Check for JAR files executed since shutdown
    `$foundItems = @()
    
    # 1. Check running Java processes with JAR arguments
    `$javaProcs = Get-Process java, javaw -ErrorAction SilentlyContinue
    foreach (`$proc in `$javaProcs) {
        try {
            `$cmdLine = (Get-CimInstance Win32_Process -Filter \"ProcessId=`$(`$proc.Id)\").CommandLine
            if (`$cmdLine -match '\.jar') {
                `$foundItems += [PSCustomObject]@{
                    Type = 'Running Process'
                    PID = `$proc.Id
                    Process = `$proc.ProcessName
                    CommandLine = `$cmdLine
                    Started = `$proc.StartTime
                }
            }
        } catch {}
    }
    
    # 2. Check Prefetch files (recently executed)
    `$prefetchPath = \"`$env:SystemRoot\\Prefetch\"
    if (Test-Path `$prefetchPath) {
        `$lastShutdown = try { (Get-WinEvent -FilterHashtable @{LogName='System';ID=6006} -MaxEvents 1).TimeCreated } catch { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
        `$pfFiles = Get-ChildItem -Path `$prefetchPath -Filter \"*.pf\" -ErrorAction SilentlyContinue | 
            Where-Object { `$_.LastWriteTime -gt `$lastShutdown -and `$_.Name -match 'java|jar' }
        
        foreach (`$pf in `$pfFiles) {
            `$foundItems += [PSCustomObject]@{
                Type = 'Prefetch File'
                Name = `$pf.Name
                Path = `$pf.FullName
                LastRun = `$pf.LastWriteTime
            }
        }
    }
    
    # Display results
    if (`$foundItems.Count -gt 0) {
        Write-Host \"Found `$(`$foundItems.Count) evidence(s) of JAR execution:\" -ForegroundColor Yellow
        Write-Host ''
        
        # Group by type
        `$grouped = `$foundItems | Group-Object Type
        foreach (`$group in `$grouped) {
            Write-Host \"`$(`$group.Name):\" -ForegroundColor Cyan
            foreach (`$item in `$group.Group) {
                if (`$item.Type -eq 'Running Process') {
                    Write-Host \"  PID `$(`$item.PID) - Started: `$(`$item.Started)\" -ForegroundColor White
                    Write-Host \"  Command: `$(`$item.CommandLine)\" -ForegroundColor Gray
                } else {
                    Write-Host \"  `$(`$item.Name) - Last Run: `$(`$item.LastRun)\" -ForegroundColor White
                }
            }
            Write-Host ''
        }
    } else {
        Write-Host 'No evidence of JAR files executed since last shutdown.' -ForegroundColor Green
    }
    
    Write-Host '--------------------------------------------' -ForegroundColor Gray
    Write-Host 'Scan complete.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Press any key to exit...' -ForegroundColor Gray
    `$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}"
"@
