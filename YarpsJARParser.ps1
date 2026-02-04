Clear-Host

$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$xxstringsUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/xxstrings64.exe"

$pecmdPath = "$env:TEMP\PECmd.exe"
$xxstringsPath = "$env:TEMP\xxstrings64.exe"

# Download forensic tools
Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $xxstringsUrl -OutFile $xxstringsPath -ErrorAction SilentlyContinue

$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

# Function to detect deleted prefetch files (even from emptied Recycle Bin)
function Detect-DeletedPrefetch {
    Write-Host "`nDetecting deleted prefetch files..." -ForegroundColor Yellow
    $evidenceFound = $false
    
    $prefetchFolder = "C:\Windows\Prefetch"
    
    # METHOD 1: Check Event Logs for file deletions (persists after Recycle Bin empty)
    Write-Host "`n[1] Checking Event Logs for deletion events..." -ForegroundColor Gray
    try {
        # Security Event ID 4660: An object was deleted
        # We'll check multiple event logs
        $eventLogs = @('Security', 'System', 'Application')
        
        foreach ($log in $eventLogs) {
            try {
                $events = Get-WinEvent -LogName $log -MaxEvents 100 -ErrorAction SilentlyContinue | 
                    Where-Object { 
                        ($_.Id -eq 4660 -or $_.Id -eq 4656) -and  # File deletion events
                        $_.Message -match "Prefetch.*\.pf" -and
                        $_.TimeCreated -gt $logonTime
                    }
                
                if ($events.Count -gt 0) {
                    Write-Host "[!] Found deletion events in $log log:" -ForegroundColor Red
                    foreach ($event in $events | Select-Object -First 3) {
                        Write-Host "   Time: $($event.TimeCreated), ID: $($event.Id)" -ForegroundColor Yellow
                    }
                    $evidenceFound = $true
                    break
                }
            } catch {
                # Log might not exist or be inaccessible
            }
        }
        
        if (-not $evidenceFound) {
            Write-Host "No recent prefetch deletion events in logs" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Could not check event logs (admin may be required)" -ForegroundColor Gray
    }
    
    # METHOD 2: Check USN Journal for file deletions (persists even after Recycle Bin empty)
    Write-Host "`n[2] Checking for deletion records in USN Journal..." -ForegroundColor Gray
    try {
        # Check if USN Journal is enabled on C: drive
        $usnInfo = fsutil usn queryjournal C: 2>$null
        if ($usnInfo) {
            Write-Host "USN Journal is active on C: drive" -ForegroundColor Gray
            
            # Try to find recent .pf file deletions (this is a simple check)
            # Note: Full USN parsing requires more complex tools
            $usnData = fsutil usn readjournal C: 2>$null | Select-String "\.pf" | Select-String "DELETE"
            
            if ($usnData) {
                Write-Host "[!] Found .pf file deletion records in USN Journal" -ForegroundColor Red
                Write-Host "   (USN Journal keeps records even after Recycle Bin empty)" -ForegroundColor Yellow
                $evidenceFound = $true
            } else {
                Write-Host "No recent .pf deletions in USN Journal" -ForegroundColor Gray
            }
        } else {
            Write-Host "USN Journal not accessible or not enabled" -ForegroundColor Gray
        }
    } catch {
        Write-Host "USN Journal check failed (admin required)" -ForegroundColor Gray
    }
    
    # METHOD 3: Check Master File Table (MFT) residual entries
    Write-Host "`n[3] Checking for MFT residual evidence..." -ForegroundColor Gray
    try {
        # MFT keeps entries for deleted files until overwritten
        # We can check for files that should have prefetch but don't
        
        # Get all .exe files that have run recently from various sources
        $sources = @()
        
        # Check recent run commands from registry
        try {
            $recentCommands = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -ErrorAction SilentlyContinue
            if ($recentCommands) {
                $recentCommands.PSObject.Properties | Where-Object { 
                    $_.Name -notmatch '^PS' -and $_.Value -match "\.exe"
                } | ForEach-Object {
                    $exePath = $_.Value
                    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
                    $sources += $exeName
                }
            }
        } catch {}
        
        # Check running processes
        Get-Process -ErrorAction SilentlyContinue | 
            Where-Object { $_.ProcessName -match "java|javaw" } | 
            ForEach-Object {
                $sources += $_.ProcessName
            }
        
        # Check prefetch folder for missing files
        $existingPrefetch = Get-ChildItem -Path $prefetchFolder -Filter *.pf -ErrorAction SilentlyContinue | 
            ForEach-Object { $_.BaseName.Split('-')[0] }
        
        $missingFiles = $sources | Where-Object { $_ -notin $existingPrefetch -and $_ -ne $null }
        
        if ($missingFiles.Count -gt 0) {
            Write-Host "[!] Found programs that should have prefetch files but don't:" -ForegroundColor Red
            $missingFiles | Select-Object -Unique | ForEach-Object {
                Write-Host "   - $_" -ForegroundColor Yellow
            }
            $evidenceFound = $true
        } else {
            Write-Host "No obvious missing prefetch files" -ForegroundColor Gray
        }
    } catch {
        Write-Host "MFT check incomplete (limited without admin)" -ForegroundColor Gray
    }
    
    # METHOD 4: Check Volume Shadow Copies (if available)
    Write-Host "`n[4] Checking for Volume Shadow Copies..." -ForegroundColor Gray
    try {
        $vssAdmin = Get-Command vssadmin -ErrorAction SilentlyContinue
        if ($vssAdmin) {
            $shadows = vssadmin list shadows 2>$null
            if ($shadows -match "Shadow Copy Volume") {
                Write-Host "[*] Volume Shadow Copies exist" -ForegroundColor Gray
                Write-Host "   Deleted prefetch files MAY be recoverable from shadow copies" -ForegroundColor Yellow
                $evidenceFound = $true
            } else {
                Write-Host "No Volume Shadow Copies found" -ForegroundColor Gray
            }
        } else {
            Write-Host "vssadmin not available" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Shadow copy check failed" -ForegroundColor Gray
    }
    
    # METHOD 5: Check for evidence of prefetch clearing tools/scripts
    Write-Host "`n[5] Checking for prefetch clearing evidence..." -ForegroundColor Gray
    try {
        # Look for common prefetch clearing commands in recent history
        $prefetchClearingCommands = @(
            "del.*prefetch",
            "remove.*\.pf",
            "clear.*prefetch",
            "cmd.*/c.*del.*pf",
            "powershell.*prefetch"
        )
        
        # Check PowerShell history
        $psHistoryPath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        if (Test-Path $psHistoryPath) {
            $history = Get-Content $psHistoryPath -Tail 100 -ErrorAction SilentlyContinue
            foreach ($cmd in $prefetchClearingCommands) {
                $matches = $history | Select-String -Pattern $cmd
                if ($matches) {
                    Write-Host "[!] Found prefetch clearing commands in PowerShell history:" -ForegroundColor Red
                    $matches | ForEach-Object { Write-Host "   $_" -ForegroundColor Yellow }
                    $evidenceFound = $true
                    break
                }
            }
        }
        
        # Check cmd.exe history via registry
        try {
            $cmdHistory = Get-ItemProperty "HKCU:\Software\Microsoft\Command Processor" -Name "CompletionChar" -ErrorAction SilentlyContinue
            # Note: Full command history is harder to access without specialized tools
        } catch {}
        
        if (-not $evidenceFound) {
            Write-Host "No obvious prefetch clearing commands found" -ForegroundColor Gray
        }
    } catch {
        Write-Host "History check failed" -ForegroundColor Gray
    }
    
    # Summary
    Write-Host "`n----------------------------------------------"
    if ($evidenceFound) {
        Write-Host "[!] EVIDENCE OF DELETED PREFETCH FILES DETECTED!" -ForegroundColor Red
        Write-Host "Files may have been deleted and Recycle Bin emptied" -ForegroundColor Yellow
    } else {
        Write-Host "[✓] No clear evidence of deleted prefetch files" -ForegroundColor Green
        Write-Host "(Note: Advanced deletion may leave no traces)" -ForegroundColor Gray
    }
    Write-Host "----------------------------------------------"
    
    return $evidenceFound
}

# Run the detection
Detect-DeletedPrefetch

Write-Host "`n`nAnalyzing existing Java prefetch files..." -ForegroundColor Cyan

$prefetchFolder = "C:\Windows\Prefetch"
$files = Get-ChildItem -Path $prefetchFolder -Filter *.pf -ErrorAction SilentlyContinue

if (-not $files) {
    Write-Host "No prefetch files found!" -ForegroundColor Red
    exit
}

$filteredFiles = $files | Where-Object { 
    ($_.Name -match "java|javaw") -and ($_.LastWriteTime -gt $logonTime)
}

if ($filteredFiles.Count -gt 0) {
    Write-Host "Found $($filteredFiles.Count) Java prefetch files" -ForegroundColor Gray
    $filteredFiles | ForEach-Object { 
        Write-Host "`nAnalyzing: $($_.Name)" -ForegroundColor Cyan
        
        $prefetchFilePath = $_.FullName
        $pecmdOutput = & $pecmdPath -f $prefetchFilePath
        
        if (-not $pecmdOutput) {
            Write-Host "Failed to parse" -ForegroundColor Red
            return
        }
        
        $pecmdOutput | ForEach-Object {
            $line = $_
            if ($line -match '\\VOLUME{(.+?)}') {
                $line = $line -replace '\\VOLUME{(.+?)}', 'C:'
            }
            $line = $line -replace '^\d+: ', ''

            if ($line -match "\.jar") {
                Write-Host "Found JAR: $line" -ForegroundColor Gray
                
                if (Test-Path $line) {
                    try {
                        $firstBytes = Get-Content $line -Encoding Byte -TotalCount 4 -ErrorAction Stop
                        if ($firstBytes[0] -eq 0x50 -and $firstBytes[1] -eq 0x4B -and $firstBytes[2] -eq 0x03 -and $firstBytes[3] -eq 0x04) {
                            if ($line -notmatch "\.jar$") {
                                Write-Host "[!] Modified extension: $line" -ForegroundColor Red
                            } else {
                                Write-Host "[✓] Valid JAR" -ForegroundColor Green
                            }
                        }
                    } catch {}
                } else {
                    Write-Host "[?] File not found: $line" -ForegroundColor Yellow
                }
            }
        }
    }
} else {
    Write-Host "No Java prefetch files found" -ForegroundColor Gray
}

Write-Host "`n`nChecking DcomLaunch memory..." -ForegroundColor Cyan

$pidDcomLaunch = (Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -eq 'DcomLaunch' }).ProcessId

if (Test-Path $xxstringsPath) {
    $xxstringsOutput = & $xxstringsPath -p $pidDcomLaunch -raw | Select-String "-jar"
    
    if ($xxstringsOutput) {
        Write-Host "Found '-jar' in DcomLaunch:" -ForegroundColor Yellow
        $xxstringsOutput | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "No '-jar' found in DcomLaunch" -ForegroundColor Gray
    }
}

Write-Host "`nAnalysis complete!" -ForegroundColor Cyan
