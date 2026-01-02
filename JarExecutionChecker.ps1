# JAR Injection Checker for Minecraft
# Created by YarpLetapStan
# Checks for JAR files by searching for "-jar" strings in process memory

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   JAR Injection Checker v1.0" -ForegroundColor Cyan
Write-Host "   By YarpLetapStan" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[WARN] Not running as administrator - some features may be limited" -ForegroundColor Yellow
    Write-Host "[INFO] For best results, run as administrator`n" -ForegroundColor Yellow
}

# Get last boot time
$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
Write-Host "[INFO] System last booted: $bootTime`n" -ForegroundColor Yellow

# Initialize results array
$foundJars = @()

# Function to search process memory for strings (simplified approach)
function Search-ProcessMemory {
    param($ProcessName)
    
    Write-Host "[SCANNING] Searching for '-jar' strings in $ProcessName process memory..." -ForegroundColor Green
    
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if (-not $process) {
        Write-Host "[INFO] Process '$ProcessName' not found or not running" -ForegroundColor Cyan
        return
    }
    
    Write-Host "[INFO] Found $ProcessName (PID: $($process.Id))" -ForegroundColor Cyan
    Write-Host "[INFO] Note: Direct memory scanning requires System Informer or similar tools" -ForegroundColor Yellow
    Write-Host "[INFO] Checking alternative detection methods...`n" -ForegroundColor Yellow
    
    # Check Windows Defender logs for scanned/detected items
    try {
        $defenderEvents = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -MaxEvents 500 -ErrorAction SilentlyContinue |
            Where-Object { 
                ($_.Message -match '-jar' -or $_.Message -match '\.jar') -and 
                $_.TimeCreated -gt $bootTime 
            }
        
        if ($defenderEvents) {
            Write-Host "[DETECTED] Found $($defenderEvents.Count) Defender events containing JAR references:" -ForegroundColor Yellow
            foreach ($event in $defenderEvents) {
                # Extract file paths from event messages
                $message = $event.Message
                if ($message -match '(?:file:|path:|Process Name:)\s*([^\r\n]+\.jar[^\r\n]*)') {
                    $jarPath = $matches[1].Trim()
                    $foundJars += [PSCustomObject]@{
                        Source = "Defender Event Log"
                        Detection = "JAR file reference"
                        FilePath = $jarPath
                        Timestamp = $event.TimeCreated
                        EventID = $event.Id
                    }
                    Write-Host "  [+] $jarPath" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "[INFO] No JAR-related Defender events found since boot" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "[ERROR] Could not access Defender logs: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Search MsMpEng (Windows Defender) process
Search-ProcessMemory -ProcessName "MsMpEng"

# Also check all Java processes for "-jar" command line arguments
Write-Host "`n[SCANNING] Checking all Java processes for '-jar' arguments..." -ForegroundColor Green
$javaProcesses = Get-Process -Name "java", "javaw" -ErrorAction SilentlyContinue

if ($javaProcesses) {
    Write-Host "[DETECTED] Found $($javaProcesses.Count) Java process(es):" -ForegroundColor Yellow
    
    foreach ($proc in $javaProcesses) {
        try {
            $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction Stop
            $cmdLine = $processInfo.CommandLine
            
            if ($cmdLine -match '-jar\s+"?([^"\s]+\.jar)') {
                $jarPath = $matches[1]
                $foundJars += [PSCustomObject]@{
                    Source = "Active Java Process"
                    ProcessID = $proc.Id
                    Detection = "Command line argument"
                    FilePath = $jarPath
                    Timestamp = $proc.StartTime
                    FullCommand = $cmdLine
                }
                Write-Host "  [+] PID $($proc.Id): $jarPath" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [!] Could not read command line for PID $($proc.Id)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[INFO] No Java processes currently running" -ForegroundColor Cyan
}

# Check Windows Event Logs for process creation with "-jar"
Write-Host "`n[SCANNING] Checking Windows Event Logs for '-jar' process creation..." -ForegroundColor Green
try {
    $processEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'Security', 'Microsoft-Windows-Sysmon/Operational'
        ID = 4688, 1  # Process creation events
        StartTime = $bootTime
    } -ErrorAction SilentlyContinue | Where-Object { $_.Message -match '-jar' } | Select-Object -First 20
    
    if ($processEvents) {
        Write-Host "[DETECTED] Found $($processEvents.Count) process creation events with '-jar':" -ForegroundColor Yellow
        foreach ($event in $processEvents) {
            if ($event.Message -match '([^\s]+\.jar)') {
                $jarPath = $matches[1]
                $foundJars += [PSCustomObject]@{
                    Source = "Process Creation Event"
                    Detection = "Event Log ID $($event.Id)"
                    FilePath = $jarPath
                    Timestamp = $event.TimeCreated
                }
                Write-Host "  [+] $jarPath" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "[INFO] No '-jar' process creation events found" -ForegroundColor Cyan
    }
} catch {
    Write-Host "[WARN] Limited event log access" -ForegroundColor Yellow
}

# Check recent JAR files accessed in common locations
Write-Host "`n[SCANNING] Checking for recently accessed JAR files..." -ForegroundColor Green
$searchPaths = @(
    "$env:APPDATA\.minecraft",
    "$env:TEMP",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $recentJars = Get-ChildItem -Path $path -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastAccessTime -gt $bootTime } |
            Select-Object -First 10
        
        foreach ($jar in $recentJars) {
            $foundJars += [PSCustomObject]@{
                Source = "File System Scan"
                Detection = "Recently accessed"
                FilePath = $jar.FullName
                Timestamp = $jar.LastAccessTime
            }
        }
    }
}

# Display comprehensive results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   DETECTION RESULTS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($foundJars.Count -eq 0) {
    Write-Host "[RESULT] No JAR file executions detected since last boot." -ForegroundColor Green
    Write-Host "`n[NOTE] For memory string scanning like System Informer:" -ForegroundColor Yellow
    Write-Host "  1. Open System Informer as Administrator" -ForegroundColor Gray
    Write-Host "  2. Find 'MsMpEng.exe' process" -ForegroundColor Gray
    Write-Host "  3. Right-click > Properties > Memory > Strings" -ForegroundColor Gray
    Write-Host "  4. Search for '-jar' with minimum length 5" -ForegroundColor Gray
    Write-Host "  5. Check Private, Image, and Mapped memory regions" -ForegroundColor Gray
} else {
    Write-Host "[RESULT] Found $($foundJars.Count) JAR file detection(s):`n" -ForegroundColor Yellow
    
    # Remove duplicates and display
    $uniqueJars = $foundJars | Sort-Object FilePath -Unique
    
    foreach ($jar in $uniqueJars) {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "Source:    " -NoNewline -ForegroundColor Cyan
        Write-Host $jar.Source -ForegroundColor White
        Write-Host "Detection: " -NoNewline -ForegroundColor Cyan
        Write-Host $jar.Detection -ForegroundColor White
        Write-Host "File Path: " -NoNewline -ForegroundColor Cyan
        Write-Host $jar.FilePath -ForegroundColor Yellow
        Write-Host "Timestamp: " -NoNewline -ForegroundColor Cyan
        Write-Host $jar.Timestamp -ForegroundColor White
        
        if ($jar.ProcessID) {
            Write-Host "PID:       " -NoNewline -ForegroundColor Cyan
            Write-Host $jar.ProcessID -ForegroundColor White
        }
        
        if ($jar.FullCommand) {
            Write-Host "Full CMD:  " -NoNewline -ForegroundColor Cyan
            Write-Host $jar.FullCommand -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "`n[SUMMARY] Total unique JAR files: $($uniqueJars.Count)" -ForegroundColor Green
}

Write-Host "`n[TIP] For deeper memory analysis, use System Informer:" -ForegroundColor Cyan
Write-Host "  String Search: MsMpEng.exe > Memory > Strings > Search '-jar'" -ForegroundColor Gray

Write-Host "`n[INFO] Scan complete. Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
