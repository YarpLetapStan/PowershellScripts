Clear-Host

$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$xxstringsUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/xxstrings64.exe"

$pecmdPath = "$env:TEMP\PECmd.exe"
$xxstringsPath = "$env:TEMP\xxstrings64.exe"

# Download forensic tools
Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $xxstringsUrl -OutFile $xxstringsPath -ErrorAction SilentlyContinue

$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

# Function to detect deleted/renamed prefetch files (even with emptied Recycle Bin)
function Detect-TamperedPrefetch {
    param([DateTime]$sinceTime)
    
    Write-Host "`n[+] Checking for tampered prefetch files..." -ForegroundColor Cyan
    $evidenceFound = $false
    
    $prefetchFolder = "C:\Windows\Prefetch"
    
    # METHOD 1: Check if prefetch is disabled or cleared
    $prefetchEnabled = $true
    try {
        $prefetchValue = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -ErrorAction SilentlyContinue
        if ($prefetchValue.EnablePrefetcher -eq 0) {
            Write-Host "[!] PREFETCH IS DISABLED IN REGISTRY!" -ForegroundColor Red
            Write-Host "    HKLM:\...\PrefetchParameters\EnablePrefetcher = 0" -ForegroundColor Yellow
            $evidenceFound = $true
            $prefetchEnabled = $false
        }
    } catch {
        Write-Host "[*] Could not check prefetch registry settings (admin required)" -ForegroundColor Gray
    }
    
    # METHOD 2: Check Event Logs for file deletions (works even if Recycle Bin emptied)
    Write-Host "`n[*] Checking Event Logs for prefetch deletions..." -ForegroundColor Gray
    try {
        # Event ID 4660: File deleted
        $deletionEvents = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4660) and TimeCreated[@SystemTime>='$($sinceTime.ToString('yyyy-MM-ddTHH:mm:ss'))']]]" -ErrorAction SilentlyContinue -MaxEvents 100 | 
            Where-Object { $_.Properties[6].Value -like "*\Prefetch\*.pf" }
        
        if ($deletionEvents.Count -gt 0) {
            Write-Host "[!] Found prefetch file deletion events (Event ID 4660):" -ForegroundColor Red
            foreach ($event in $deletionEvents) {
                $filePath = $event.Properties[6].Value
                $user = $event.Properties[1].Value
                $time = $event.TimeCreated
                Write-Host "    - $filePath deleted by $user at $time" -ForegroundColor Yellow
            }
            $evidenceFound = $true
        } else {
            Write-Host "[✓] No recent prefetch deletion events found in Security logs" -ForegroundColor Green
        }
    } catch {
        Write-Host "[*] Could not access Security event logs (admin required)" -ForegroundColor Gray
    }
    
    # METHOD 3: Check for evidence in USN Journal (if admin)
    Write-Host "`n[*] Checking USN Journal for deleted file records..." -ForegroundColor Gray
    try {
        # Use fsutil to query USN Journal (requires admin)
        $usnData = fsutil usn readjournal C: 2>$null | Select-String "\.pf" | Select-String "DELETE"
        
        if ($usnData) {
            Write-Host "[!] Found references to deleted .pf files in USN Journal:" -ForegroundColor Red
            $usnData | Select-Object -First 5 | ForEach-Object {
                Write-Host "    - $_" -ForegroundColor Yellow
            }
            if ($usnData.Count -gt 5) {
                Write-Host "    ... and $($usnData.Count - 5) more entries" -ForegroundColor Yellow
            }
            $evidenceFound = $true
        } else {
            Write-Host "[*] No recent .pf deletions found in USN Journal" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[*] USN Journal query requires elevated privileges" -ForegroundColor Gray
    }
    
    # METHOD 4: Indirect detection - check for missing prefetch files that SHOULD exist
    Write-Host "`n[*] Checking for missing prefetch files via indirect evidence..." -ForegroundColor Gray
    
    # Get currently running processes that would normally create prefetch
    $runningJavaProcesses = Get-Process | Where-Object { $_.ProcessName -match "java(w?)" } | Select-Object -First 10
    
    if ($runningJavaProcesses.Count -gt 0) {
        Write-Host "[*] Currently running Java processes found:" -ForegroundColor Gray
        foreach ($proc in $runningJavaProcesses) {
            $exeName = $proc.ProcessName
            $expectedPrefetch = "$exeName.exe"
            
            # Check if prefetch file exists for this running process
            $prefetchFiles = Get-ChildItem -Path $prefetchFolder -Filter "*$exeName*" -ErrorAction SilentlyContinue
            
            if (-not $prefetchFiles) {
                Write-Host "[!] Running process '$exeName' has no prefetch file!" -ForegroundColor Red
                Write-Host "    Process ID: $($proc.Id), Path: $(try { $proc.Path } catch { 'Unknown' })" -ForegroundColor Yellow
                $evidenceFound = $true
            }
        }
    }
    
    # METHOD 5: Check for renamed prefetch files by scanning for prefetch signatures
    Write-Host "`n[*] Scanning for renamed prefetch files (checking file signatures)..." -ForegroundColor Gray
    
    # Common locations where malware might hide renamed prefetch files
    $scanLocations = @(
        "$env:TEMP",
        "$env:APPDATA",
        "$env:LOCALAPPDATA\Temp",
        "C:\Windows\Temp"
    )
    
    $filesChecked = 0
    foreach ($location in $scanLocations) {
        if (Test-Path $location) {
            # Get files that might be prefetch based on size (prefetch files are typically 10KB-10MB)
            $potentialFiles = Get-ChildItem -Path $location -File -ErrorAction SilentlyContinue | 
                Where-Object { $_.Length -gt 10240 -and $_.Length -lt 10485760 } | 
                Select-Object -First 20
            
            foreach ($file in $potentialFiles) {
                $filesChecked++
                try {
                    # Read first 4 bytes to check for prefetch signature
                    $stream = [System.IO.File]::OpenRead($file.FullName)
                    $bytes = New-Object byte[] 4
                    $bytesRead = $stream.Read($bytes, 0, 4)
                    $stream.Close()
                    
                    if ($bytesRead -eq 4) {
                        # Check for 'MAM' (4D 41 4D) or 'SCCA' (53 43 43 41) signature
                        if (($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x41 -and $bytes[2] -eq 0x4D) -or
                            ($bytes[0] -eq 0x53 -and $bytes[1] -eq 0x43 -and $bytes[2] -eq 0x43 -and $bytes[3] -eq 0x41)) {
                            
                            Write-Host "[!] Found renamed prefetch file: $($file.FullName)" -ForegroundColor Red
                            Write-Host "    Size: $([math]::Round($file.Length/1KB,2)) KB, Modified: $($file.LastWriteTime)" -ForegroundColor Yellow
                            Write-Host "    Signature: $([System.BitConverter]::ToString($bytes))" -ForegroundColor Yellow
                            $evidenceFound = $true
                        }
                    }
                } catch {
                    # File might be locked or inaccessible
                }
            }
        }
    }
    
    Write-Host "[*] Scanned $filesChecked files for prefetch signatures" -ForegroundColor Gray
    
    # METHOD 6: Check Volume Shadow Copies (if available and admin)
    Write-Host "`n[*] Checking for Volume Shadow Copies..." -ForegroundColor Gray
    try {
        # Quick check without hanging
        $vssProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c vssadmin list shadows 2>&1" -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\vss_check.txt"
        Start-Sleep -Seconds 2
        
        if (Test-Path "$env:TEMP\vss_check.txt") {
            $vssContent = Get-Content "$env:TEMP\vss_check.txt" -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\vss_check.txt" -ErrorAction SilentlyContinue
            
            if ($vssContent -match "Shadow Copy Volume") {
                Write-Host "[*] Volume Shadow Copies available" -ForegroundColor Gray
                Write-Host "    Deleted prefetch files might be recoverable using:" -ForegroundColor Gray
                Write-Host "    - Forensic tools like FTK Imager or Autopsy" -ForegroundColor Gray
                Write-Host "    - vssadmin or diskshadow commands" -ForegroundColor Gray
            } else {
                Write-Host "[*] No accessible Volume Shadow Copies found" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "[*] Volume Shadow Copy check requires admin privileges" -ForegroundColor Gray
    }
    
    # METHOD 7: Check for suspicious empty prefetch folder or very few files
    $prefetchFiles = Get-ChildItem -Path $prefetchFolder -Filter *.pf -ErrorAction SilentlyContinue
    if ($prefetchFiles) {
        $fileCount = $prefetchFiles.Count
        Write-Host "`n[*] Prefetch folder analysis:" -ForegroundColor Gray
        Write-Host "    - Total prefetch files: $fileCount" -ForegroundColor Gray
        
        # Typical Windows system has dozens to hundreds of prefetch files
        if ($fileCount -lt 20 -and $prefetchEnabled) {
            Write-Host "[!] Very few prefetch files ($fileCount) - may have been cleared!" -ForegroundColor Red
            $evidenceFound = $true
        }
        
        # Check oldest and newest files
        $oldestFile = $prefetchFiles | Sort-Object LastWriteTime | Select-Object -First 1
        $newestFile = $prefetchFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        Write-Host "    - Oldest file: $($oldestFile.Name) ($($oldestFile.LastWriteTime))" -ForegroundColor Gray
        Write-Host "    - Newest file: $($newestFile.Name) ($($newestFile.LastWriteTime))" -ForegroundColor Gray
        
        # If all files are very recent, might indicate a purge
        $hoursSinceOldest = (Get-Date) - $oldestFile.LastWriteTime
        if ($hoursSinceOldest.TotalHours -lt 24 -and $fileCount -gt 30) {
            Write-Host "[!] All prefetch files are less than 24 hours old - possible recent purge!" -ForegroundColor Red
            $evidenceFound = $true
        }
    } else {
        Write-Host "[!] No prefetch files found at all!" -ForegroundColor Red
        Write-Host "    This is highly suspicious on a normal Windows system" -ForegroundColor Yellow
        $evidenceFound = $true
    }
    
    # Summary
    Write-Host "`n" + "="*60
    if ($evidenceFound) {
        Write-Host "[!] EVIDENCE OF PREFETCH TAMPERING DETECTED!" -ForegroundColor Red
        Write-Host "    Deleted files may still be recoverable via:" -ForegroundColor Yellow
        Write-Host "    1. Forensic file carving tools" -ForegroundColor Gray
        Write-Host "    2. Volume Shadow Copies (if available)" -ForegroundColor Gray
        Write-Host "    3. MFT analysis with specialized tools" -ForegroundColor Gray
    } else {
        Write-Host "[✓] No obvious evidence of prefetch tampering detected" -ForegroundColor Green
        Write-Host "    Note: Advanced deletion methods may still leave no traces" -ForegroundColor Gray
    }
    Write-Host "="*60
    
    return $evidenceFound
}

# Run the detection
Detect-TamperedPrefetch -sinceTime $logonTime

# Continue with original analysis...
# [Rest of your original script here...]
