Clear-Host

$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$xxstringsUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/xxstrings64.exe"

$pecmdPath = "$env:TEMP\PECmd.exe"
$xxstringsPath = "$env:TEMP\xxstrings64.exe"

# Download forensic tools
Write-Host "[*] Downloading forensic tools..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath -ErrorAction Stop
    Write-Host "[✓] Downloaded PECmd.exe" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to download PECmd.exe: $_" -ForegroundColor Red
}

try {
    Invoke-WebRequest -Uri $xxstringsUrl -OutFile $xxstringsPath -ErrorAction Stop
    Write-Host "[✓] Downloaded xxstrings64.exe" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to download xxstrings64.exe: $_" -ForegroundColor Red
}

$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
Write-Host "[*] System last boot: $logonTime" -ForegroundColor Gray

# Function to detect deleted/renamed prefetch files (even with emptied Recycle Bin)
function Detect-TamperedPrefetch {
    param([DateTime]$sinceTime)
    
    Write-Host "`n[+] Checking for tampered prefetch files..." -ForegroundColor Cyan
    $evidenceFound = $false
    
    $prefetchFolder = "C:\Windows\Prefetch"
    
    # METHOD 1: Check if prefetch is disabled or cleared
    Write-Host "`n[1] Checking Prefetch Registry Settings..." -ForegroundColor Gray
    try {
        $prefetchValue = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -ErrorAction SilentlyContinue
        if ($prefetchValue.EnablePrefetcher -eq 0) {
            Write-Host "[!] PREFETCH IS DISABLED IN REGISTRY!" -ForegroundColor Red
            Write-Host "    HKLM:\...\PrefetchParameters\EnablePrefetcher = 0" -ForegroundColor Yellow
            $evidenceFound = $true
        } elseif ($prefetchValue.EnablePrefetcher) {
            Write-Host "[✓] Prefetch is enabled (Value: $($prefetchValue.EnablePrefetcher))" -ForegroundColor Green
        }
    } catch {
        Write-Host "[*] Could not check prefetch registry settings" -ForegroundColor Gray
    }
    
    # METHOD 2: Check Event Logs for file deletions (works even if Recycle Bin emptied)
    Write-Host "`n[2] Checking Event Logs for prefetch deletions..." -ForegroundColor Gray
    try {
        $hasSecurityLog = $false
        try {
            $logTest = Get-WinEvent -ListLog Security -ErrorAction SilentlyContinue
            if ($logTest) { $hasSecurityLog = $true }
        } catch {}
        
        if ($hasSecurityLog) {
            $filter = @{
                LogName = 'Security'
                StartTime = $sinceTime.AddDays(-1)
            }
            
            $deletionEvents = Get-WinEvent -FilterHashtable $filter -MaxEvents 50 -ErrorAction SilentlyContinue | 
                Where-Object { 
                    $_.Id -eq 4660 -and 
                    $_.Properties[6].Value -like "*\Prefetch\*.pf" 
                }
            
            if ($deletionEvents.Count -gt 0) {
                Write-Host "[!] Found prefetch file deletion events:" -ForegroundColor Red
                foreach ($event in $deletionEvents | Select-Object -First 3) {
                    $filePath = $event.Properties[6].Value
                    $user = $event.Properties[1].Value
                    $time = $event.TimeCreated.ToString("HH:mm:ss")
                    Write-Host "    - $([System.IO.Path]::GetFileName($filePath)) at $time by $user" -ForegroundColor Yellow
                }
                if ($deletionEvents.Count -gt 3) {
                    Write-Host "    ... and $($deletionEvents.Count - 3) more events" -ForegroundColor Yellow
                }
                $evidenceFound = $true
            } else {
                Write-Host "[✓] No recent prefetch deletion events found" -ForegroundColor Green
            }
        } else {
            Write-Host "[*] Security event log not accessible" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[*] Event log check failed" -ForegroundColor Gray
    }
    
    # METHOD 3: Quick USN Journal check with timeout (won't hang)
    Write-Host "`n[3] Checking USN Journal for deleted file records..." -ForegroundColor Gray
    try {
        $usnCheckScript = {
            $usnResult = @()
            try {
                $tempFile = [System.IO.Path]::GetTempFileName()
                
                $process = Start-Process -FilePath "fsutil.exe" `
                    -ArgumentList "usn", "readjournal", "C:" `
                    -NoNewWindow `
                    -RedirectStandardOutput $tempFile `
                    -PassThru `
                    -WindowStyle Hidden
                
                $process | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
                
                if (-not $process.HasExited) {
                    $process.Kill()
                    return @("TIMEOUT")
                }
                
                if (Test-Path $tempFile) {
                    $content = Get-Content $tempFile -ErrorAction SilentlyContinue
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    
                    $usnResult = $content | Where-Object { 
                        $_ -match "\.pf" -and $_ -match "DELETE|CLOSE.*DELETE" 
                    } | Select-Object -First 5
                }
            } catch {
                # If any error, just return empty
            }
            return $usnResult
        }
        
        $job = Start-Job -ScriptBlock $usnCheckScript
        $usnResult = $job | Wait-Job -Timeout 7 | Receive-Job
        $job | Remove-Job -Force
        
        if ($usnResult -contains "TIMEOUT") {
            Write-Host "[*] USN Journal check timed out (normal on large drives)" -ForegroundColor Gray
        } elseif ($usnResult -and $usnResult.Count -gt 0) {
            Write-Host "[!] Found references to deleted .pf files in USN Journal:" -ForegroundColor Red
            foreach ($entry in $usnResult | Select-Object -First 3) {
                if ($entry -match "[^\\]+\\.pf") {
                    $fileName = $matches[0]
                    Write-Host "    - $fileName" -ForegroundColor Yellow
                } else {
                    Write-Host "    - $($entry.Substring(0, [Math]::Min(50, $entry.Length)))..." -ForegroundColor Yellow
                }
            }
            $evidenceFound = $true
        } else {
            Write-Host "[✓] No recent .pf deletions found in USN Journal" -ForegroundColor Green
        }
    } catch {
        Write-Host "[*] USN Journal query requires elevated privileges" -ForegroundColor Gray
    }
    
    # METHOD 4: Check for running processes without prefetch files
    Write-Host "`n[4] Checking for missing prefetch files..." -ForegroundColor Gray
    try {
        $runningJava = Get-Process -ErrorAction SilentlyContinue | 
            Where-Object { $_.ProcessName -match "^javaw?$" } | 
            Select-Object -First 5
        
        if ($runningJava.Count -gt 0) {
            Write-Host "[*] Found $($runningJava.Count) running Java process(es)" -ForegroundColor Gray
            
            foreach ($proc in $runningJava) {
                $prefetchFiles = Get-ChildItem -Path $prefetchFolder -Filter "*$($proc.ProcessName)*" -ErrorAction SilentlyContinue
                
                if (-not $prefetchFiles -or $prefetchFiles.Count -eq 0) {
                    Write-Host "[!] Running '$($proc.ProcessName)' (PID: $($proc.Id)) has no prefetch!" -ForegroundColor Red
                    
                    try {
                        $procPath = $proc.Path
                        if ($procPath) {
                            Write-Host "    Path: $procPath" -ForegroundColor Yellow
                        }
                    } catch {}
                    
                    $evidenceFound = $true
                } else {
                    Write-Host "[✓] '$($proc.ProcessName)' has prefetch file(s)" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "[*] No Java processes currently running" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[*] Could not check running processes" -ForegroundColor Gray
    }
    
    # METHOD 5: Statistical analysis of prefetch folder
    Write-Host "`n[5] Analyzing prefetch folder contents..." -ForegroundColor Gray
    try {
        $prefetchFiles = Get-ChildItem -Path $prefetchFolder -Filter *.pf -ErrorAction SilentlyContinue
        
        if ($prefetchFiles) {
            $fileCount = $prefetchFiles.Count
            Write-Host "    - Total prefetch files: $fileCount" -ForegroundColor Gray
            
            $javaPrefetch = $prefetchFiles | Where-Object { $_.Name -match "java|JAVA" }
            if ($javaPrefetch.Count -gt 0) {
                Write-Host "    - Java-related prefetch files: $($javaPrefetch.Count)" -ForegroundColor Gray
                foreach ($file in $javaPrefetch | Select-Object -First 3) {
                    Write-Host "      > $($file.Name) (Last: $($file.LastWriteTime.ToString('MM/dd HH:mm')))" -ForegroundColor Gray
                }
            }
            
            if ($fileCount -lt 15) {
                Write-Host "[!] Very few prefetch files ($fileCount) - may have been cleared!" -ForegroundColor Red
                Write-Host "    Normal Windows systems typically have 50-500+ prefetch files" -ForegroundColor Yellow
                $evidenceFound = $true
            }
            
            $recentFiles = $prefetchFiles | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) }
            if ($recentFiles.Count -gt 0) {
                Write-Host "    - Files modified in last hour: $($recentFiles.Count)" -ForegroundColor Gray
            }
        } else {
            Write-Host "[!] No prefetch files found at all!" -ForegroundColor Red
            Write-Host "    This is highly suspicious on a normal Windows system" -ForegroundColor Yellow
            $evidenceFound = $true
        }
    } catch {
        Write-Host "[*] Could not analyze prefetch folder" -ForegroundColor Gray
    }
    
    # METHOD 6: Quick scan for renamed prefetch files
    Write-Host "`n[6] Scanning for renamed prefetch files..." -ForegroundColor Gray
    try {
        $tempFolder = $env:TEMP
        if (Test-Path $tempFolder) {
            $recentFiles = Get-ChildItem -Path $tempFolder -File -ErrorAction SilentlyContinue | 
                Where-Object { 
                    $_.Length -gt 50000 -and $_.Length -lt 5000000 -and
                    $_.LastWriteTime -gt (Get-Date).AddDays(-1) 
                } | 
                Select-Object -First 10
            
            $suspiciousCount = 0
            foreach ($file in $recentFiles) {
                try {
                    $stream = [System.IO.File]::OpenRead($file.FullName)
                    $bytes = New-Object byte[] 8
                    $bytesRead = $stream.Read($bytes, 0, 8)
                    $stream.Close()
                    
                    if ($bytesRead -ge 4) {
                        $hexSignature = [System.BitConverter]::ToString($bytes[0..3])
                        
                        if ($hexSignature -match "^4D-41-4D" -or $hexSignature -match "^53-43-43-41") {
                            $suspiciousCount++
                            Write-Host "[!] Found potential renamed prefetch: $($file.Name)" -ForegroundColor Red
                            Write-Host "    Location: $($file.DirectoryName)" -ForegroundColor Yellow
                            $evidenceFound = $true
                            
                            if ($suspiciousCount -ge 3) {
                                Write-Host "    ... and more possible renamed files" -ForegroundColor Yellow
                                break
                            }
                        }
                    }
                } catch {
                    # File might be locked, skip
                }
            }
            
            if ($suspiciousCount -eq 0) {
                Write-Host "[✓] No renamed prefetch files found in TEMP" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "[*] Could not scan for renamed files" -ForegroundColor Gray
    }
    
    # Summary
    Write-Host "`n" + "="*60
    if ($evidenceFound) {
        Write-Host "[!] SUSPICIOUS ACTIVITY DETECTED!" -ForegroundColor Red
        Write-Host "    Possible prefetch tampering or deletion" -ForegroundColor Yellow
    } else {
        Write-Host "[✓] No obvious evidence of prefetch tampering" -ForegroundColor Green
    }
    Write-Host "="*60
    
    return $evidenceFound
}

# Run the detection
Detect-TamperedPrefetch -sinceTime $logonTime

# CONTINUE WITH ORIGINAL SCRIPT
Write-Host "`n" + "="*60
Write-Host "CONTINUING WITH STANDARD PREFETCH ANALYSIS..." -ForegroundColor Cyan
Write-Host "="*60 + "`n"

$prefetchFolder = "C:\Windows\Prefetch"
$files = Get-ChildItem -Path $prefetchFolder -Filter *.pf -ErrorAction SilentlyContinue

if (-not $files) {
    Write-Host "[!] CRITICAL: No prefetch files found!" -ForegroundColor Red
    exit 1
}

$filteredFiles = $files | Where-Object { 
    ($_.Name -match "java|javaw") -and ($_.LastWriteTime -gt $logonTime)
}

if ($filteredFiles.Count -gt 0) {
    Write-Host "PF files found after logon time.." -ForegroundColor Gray
    $filteredFiles | ForEach-Object { 
        Write-Host " "
        Write-Host $_.FullName -ForegroundColor DarkCyan
        
        # Check if file is accessible (not locked or corrupted)
        try {
            $testStream = [System.IO.File]::Open($_.FullName, 'Open', 'Read', 'None')
            $testStream.Close()
        } catch {
            Write-Host "[!] Warning: Prefetch file may be corrupted or locked: $($_.FullName)" -ForegroundColor Red
        }
        
        $prefetchFilePath = $_.FullName
        $pecmdOutput = & $pecmdPath -f $prefetchFilePath 2>$null
        
        if ($LASTEXITCODE -ne 0 -or -not $pecmdOutput) {
            Write-Host "[!] Failed to parse prefetch file (might be corrupted)" -ForegroundColor Red
            return
        }
        
        $filteredImports = $pecmdOutput

        if ($filteredImports.Count -gt 0) {
            Write-Host "Imports found:" -ForegroundColor DarkYellow
            $filteredImports | ForEach-Object {
                $line = $_
                if ($line -match '\\VOLUME{(.+?)}') {
                    $line = $line -replace '\\VOLUME{(.+?)}', 'C:'
                }
                $line = $line -replace '^\d+: ', ''

                try {
                    if ((Get-Content $line -First 1 -ErrorAction SilentlyContinue) -match 'PK\x03\x04') {
                        if ($line -notmatch "\.jar$") {
                            Write-Host "File .jar modified extension: $line " -ForegroundColor DarkRed
                        } else {
                            Write-Host "Valid .jar file: $line" -ForegroundColor DarkGreen
                        }
                    }
                } catch {
                    if ($line -match "\.jar$") {
                        Write-Host "File .jar deleted maybe: $line" -ForegroundColor DarkYellow
                    }
                }

                if ($line -match "\.jar$" -and !(Test-Path $line)) {
                    Write-Host "File .jar deleted maybe: $line" -ForegroundColor DarkYellow
                }
            }
        } else {
            Write-Host "No imports found for the file $($_.Name)." -ForegroundColor Red
        }
    }
} else {
    Write-Host "No PF files containing 'java' or 'javaw' and modified after logon time were found." -ForegroundColor Red
}

Write-Output " "
Write-Host "Searching for DcomLaunch PID..." -ForegroundColor Gray

$pidDcomLaunch = (Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -eq 'DcomLaunch' }).ProcessId
Write-Host "[*] DcomLaunch PID: $pidDcomLaunch" -ForegroundColor Gray

if (Test-Path $xxstringsPath) {
    $xxstringsOutput = & $xxstringsPath -p $pidDcomLaunch -raw 2>$null | findstr /C:"-jar"
    
    if ($xxstringsOutput) {
        Write-Host "Strings found in DcomLaunch process memory containing '-jar':" -ForegroundColor DarkYellow

        $xxstringsOutput | ForEach-Object {
            Write-Host $_ -ForegroundColor Gray

            # Try to extract a .jar path after the -jar argument
            if ($_ -match '-jar\s+"?([^"\s]+\.jar)"?') {
                $jarPath = $Matches[1]

                # Replace \VOLUME{} if present
                if ($jarPath -match '\\VOLUME{[^}]+}') {
                    $jarPath = $jarPath -replace '\\VOLUME{[^}]+}', 'C:'
                }

                Write-Host "`nProcessing JAR file: $jarPath" -ForegroundColor Cyan

                try {
                    $firstByte = Get-Content $jarPath -Encoding Byte -TotalCount 4 -ErrorAction Stop
                    if ($firstByte[0] -eq 0x50 -and $firstByte[1] -eq 0x4B -and $firstByte[2] -eq 0x03 -and $firstByte[3] -eq 0x04) {
                        Write-Host "Valid .jar file in memory string: $jarPath" -ForegroundColor DarkGreen
                    } else {
                        Write-Host "Invalid .jar file (wrong magic): $jarPath" -ForegroundColor DarkRed
                    }
                } catch {
                    Write-Host "File not found or inaccessible: $jarPath" -ForegroundColor DarkYellow
                }
            } else {
                Write-Host "Could not extract .jar path from string: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No strings containing '-jar' were found in DcomLaunch process memory." -ForegroundColor Red
    }
} else {
    Write-Host "[!] xxstrings64.exe not found, skipping memory analysis" -ForegroundColor Red
}

# Final summary
Write-Host "`n" + "="*60
Write-Host "ANALYSIS COMPLETE" -ForegroundColor Cyan
Write-Host "="*60
Write-Host "Summary of findings:" -ForegroundColor Yellow
Write-Host "1. Prefetch tampering detection completed" -ForegroundColor Gray
Write-Host "2. Java prefetch files analyzed: $($filteredFiles.Count)" -ForegroundColor Gray
Write-Host "3. DcomLaunch memory analyzed for JAR execution" -ForegroundColor Gray
Write-Host "`nRecommendations:" -ForegroundColor Yellow
Write-Host "- Check suspicious JAR files in antivirus" -ForegroundColor Gray
Write-Host "- Monitor for unusual Java processes" -ForegroundColor Gray
Write-Host "- Consider full system scan with anti-malware tools" -ForegroundColor Gray
