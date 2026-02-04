Clear-Host

$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$xxstringsUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/xxstrings64.exe"

$pecmdPath = "$env:TEMP\PECmd.exe"
$xxstringsPath = "$env:TEMP\xxstrings64.exe"

# Download forensic tools
Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $xxstringsUrl -OutFile $xxstringsPath -ErrorAction SilentlyContinue

$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

# Function to detect deleted/renamed prefetch files
function Detect-TamperedPrefetch {
    param([DateTime]$sinceTime)
    
    Write-Host "`n[+] Checking for tampered prefetch files..." -ForegroundColor Cyan
    
    $prefetchFolder = "C:\Windows\Prefetch"
    $evidenceFound = $false
    
    # Method 1: Check for files that should exist based on recent activity
    # Get all prefetch files that existed before current analysis
    $knownPrefetchFiles = @()
    
    # Look for evidence in Windows Event Logs (if available)
    try {
        # Check Security logs for file deletion events (Event ID 4660)
        $deletionEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4660
            StartTime = $sinceTime
        } -MaxEvents 50 -ErrorAction SilentlyContinue | 
            Where-Object { $_.Properties[6].Value -like "*\Prefetch\*.pf" }
        
        if ($deletionEvents.Count -gt 0) {
            Write-Host "[!] Found prefetch file deletion events in Security logs:" -ForegroundColor Red
            $deletionEvents | ForEach-Object {
                $filePath = $_.Properties[6].Value
                $user = $_.Properties[1].Value
                $time = $_.TimeCreated
                Write-Host "    - $filePath deleted by $user at $time" -ForegroundColor Yellow
                $evidenceFound = $true
            }
        }
    } catch {
        # Event log not accessible or no events found
    }
    
    # Method 2: Check for abnormal prefetch file gaps
    $allPrefetchFiles = Get-ChildItem -Path $prefetchFolder -Filter *.pf -ErrorAction SilentlyContinue
    
    # Build expected naming pattern and check for missing sequence numbers
    $filePatterns = @{}
    $allPrefetchFiles | ForEach-Object {
        if ($_.Name -match '^(.+?)-([A-F0-9]{16})\.pf$') {
            $appName = $Matches[1]
            $hash = $Matches[2]
            if (-not $filePatterns.ContainsKey($appName)) {
                $filePatterns[$appName] = @()
            }
            $filePatterns[$appName] += $hash
        }
    }
    
    # Method 3: Check Registry for recent executions that should have prefetch entries
    try {
        # Recent execution from UserAssist registry keys
        $registryPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{F4E57C4B-2036-45F0-A9AB-443BCFE33D9F}\Count"
        )
        
        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                $regValues = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                if ($regValues) {
                    $regValues.PSObject.Properties | Where-Object {
                        $_.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider') -and
                        $_.Name -match '\.exe' -and
                        $_.Name -match 'java|javaw'
                    } | ForEach-Object {
                        $exeName = [System.Text.Encoding]::Unicode.GetString(
                            [System.Convert]::FromBase64String($_.Name.Split('\')[0])
                        ) -replace '[^\x20-\x7E]', '' -replace '^.{4}', ''
                        
                        if ($exeName -match 'javaw?\.exe$') {
                            $expectedPrefetch = "$prefetchFolder\$($exeName.Replace('.exe',''))-*.pf"
                            $matchingFiles = Get-ChildItem -Path $expectedPrefetch -ErrorAction SilentlyContinue
                            
                            if (-not $matchingFiles) {
                                Write-Host "[!] Missing prefetch for recently executed: $exeName" -ForegroundColor Red
                                Write-Host "    This executable was run but has no prefetch file" -ForegroundColor Yellow
                                $evidenceFound = $true
                            }
                        }
                    }
                }
            }
        }
    } catch {
        # Registry access failed
    }
    
    # Method 4: Check MFT (Master File Table) for deleted prefetch entries
    try {
        # Using Get-FileHash to check for recently modified hashes that don't match current files
        $hashesFilePath = "$env:TEMP\prefetch_hashes.txt"
        
        # Create baseline of current files
        $currentHashes = $allPrefetchFiles | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Hash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
                LastWrite = $_.LastWriteTime
            }
        }
        
        # Check for .pf files in Recycle Bin
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.NameSpace(0xA)  # 0xA is Recycle Bin
        
        $recycledFiles = @()
        for ($i = 0; $i -lt $recycleBin.Items().Count; $i++) {
            $item = $recycleBin.Items().Item($i)
            if ($item.Path -match '\\.pf$') {
                $recycledFiles += $item.Path
            }
        }
        
        if ($recycledFiles.Count -gt 0) {
            Write-Host "[!] Found prefetch files in Recycle Bin:" -ForegroundColor Red
            $recycledFiles | ForEach-Object {
                Write-Host "    - $_" -ForegroundColor Yellow
                $evidenceFound = $true
            }
        }
        
        # Check Volume Shadow Copies for deleted files (if admin)
        try {
            $vssList = vssadmin list shadows 2>$null | Select-String "Shadow Copy Volume"
            if ($vssList) {
                Write-Host "[*] Volume Shadow Copies available. Deleted files might be recoverable." -ForegroundColor Gray
            }
        } catch {}
        
    } catch {
        Write-Host "[*] MFT/Recycle Bin check requires elevated privileges" -ForegroundColor Gray
    }
    
    # Method 5: Check for renamed .pf files (files with wrong extension but prefetch signature)
    Write-Host "`n[*] Scanning for renamed prefetch files..." -ForegroundColor Gray
    
    # Check TEMP and common malware locations
    $suspiciousLocations = @(
        "$env:TEMP",
        "$env:APPDATA",
        "$env:LOCALAPPDATA",
        "C:\Windows\Temp"
    )
    
    foreach ($location in $suspiciousLocations) {
        if (Test-Path $location) {
            $potentialFiles = Get-ChildItem -Path $location -File -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { $_.Length -gt 1024 -and $_.Length -lt 10485760 }  # Reasonable prefetch size
            
            foreach ($file in $potentialFiles) {
                try {
                    $firstBytes = Get-Content $file.FullName -Encoding Byte -TotalCount 4 -ErrorAction Stop
                    # Prefetch files start with 'MAM' or 'SCCA'
                    if ($firstBytes[0] -eq 0x4D -and $firstBytes[1] -eq 0x41 -and $firstBytes[2] -eq 0x4D) {  # 'MAM'
                        Write-Host "[!] Found renamed prefetch file: $($file.FullName)" -ForegroundColor Red
                        Write-Host "    Original name might have been: $($file.Name).pf" -ForegroundColor Yellow
                        $evidenceFound = $true
                    }
                    elseif ($firstBytes[0] -eq 0x53 -and $firstBytes[1] -eq 0x43 -and $firstBytes[2] -eq 0x43 -and $firstBytes[3] -eq 0x41) {  # 'SCCA'
                        Write-Host "[!] Found renamed SCCA prefetch file: $($file.FullName)" -ForegroundColor Red
                        Write-Host "    Original name might have been: $($file.Name).pf" -ForegroundColor Yellow
                        $evidenceFound = $true
                    }
                } catch {}
            }
        }
    }
    
    if (-not $evidenceFound) {
        Write-Host "[✓] No obvious evidence of prefetch tampering found" -ForegroundColor Green
    }
    
    return $evidenceFound
}

# Run tampering detection
Detect-TamperedPrefetch -sinceTime $logonTime

# Original analysis continues...
Write-Host "`n" + "="*60
Write-Host "CONTINUING WITH STANDARD PREFETCH ANALYSIS..." -ForegroundColor Cyan
Write-Host "="*60 + "`n"

$prefetchFolder = "C:\Windows\Prefetch"
$files = Get-ChildItem -Path $prefetchFolder -Filter *.pf -ErrorAction SilentlyContinue

if (-not $files) {
    Write-Host "[!] No prefetch files found or access denied!" -ForegroundColor Red
    Write-Host "[*] This could indicate:" -ForegroundColor Yellow
    Write-Host "    1. Prefetch is disabled" -ForegroundColor Gray
    Write-Host "    2. Files were deleted" -ForegroundColor Gray
    Write-Host "    3. Lack of permissions" -ForegroundColor Gray
    Write-Host "    Consider checking: Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'" -ForegroundColor Gray
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

# Final summary
Write-Host "`n" + "="*60
Write-Host "ANALYSIS COMPLETE" -ForegroundColor Cyan
Write-Host "="*60
Write-Host "Recommendations:" -ForegroundColor Yellow
Write-Host "1. Check Event Viewer for suspicious activity" -ForegroundColor Gray
Write-Host "2. Consider running: 'sfc /scannow' for system integrity" -ForegroundColor Gray
Write-Host "3. Monitor prefetch folder for future anomalies" -ForegroundColor Gray
