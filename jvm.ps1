param(
    [switch]$Monitor = $false,
    [int]$CheckEvery = 3
)

# Clear screen and show header
Clear-Host
Write-Host "=== Minecraft JVM Argument Monitor ===" -ForegroundColor Cyan
Write-Host "Red flags: Custom JVM arguments from launcher" -ForegroundColor Red
Write-Host "Yellow flags: Memory allocation changes" -ForegroundColor Yellow
Write-Host "Green: Standard Minecraft" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

function Check-Minecraft {
    $processes = Get-Process java*, javaw* -ErrorAction SilentlyContinue
    
    foreach ($proc in $processes) {
        try {
            $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)"
            if ($wmi.CommandLine -match "minecraft|\.minecraft") {
                Analyze-Arguments $proc.Id $wmi.CommandLine
            }
        } catch { }
    }
}

function Analyze-Arguments {
    param($PID, $CommandLine)
    
    # Extract just the arguments part (after the .exe)
    $exeIndex = $CommandLine.IndexOf(".exe")
    if ($exeIndex -gt 0) {
        $argsOnly = $CommandLine.Substring($exeIndex + 5).Trim()
    } else {
        $argsOnly = $CommandLine
    }
    
    # Look for custom JVM args (RED FLAG)
    $hasCustomArgs = $false
    $customArgs = @()
    
    # Common normal Minecraft arguments
    $normalArgs = @(
        "-Dos\.name=.*",
        "-Dos\.version=.*", 
        "-Djava\.library\.path=.*natives.*",
        "-cp",
        "-Xmx[0-9]+G",
        "-Xms[0-9]+G",
        "-XX:HeapDumpPath=.*",
        "-Djava\.io\.tmpdir=.*",
        "-Duser\.language=.*",
        "-Duser\.country=.*"
    )
    
    # Split arguments
    $allArgs = @()
    $currentArg = ""
    $inQuotes = $false
    
    for ($i = 0; $i -lt $argsOnly.Length; $i++) {
        $char = $argsOnly[$i]
        
        if ($char -eq '"') {
            $inQuotes = -not $inQuotes
        }
        elseif ($char -eq ' ' -and -not $inQuotes) {
            if ($currentArg -ne "") {
                $allArgs += $currentArg
                $currentArg = ""
            }
        }
        else {
            $currentArg += $char
        }
    }
    
    if ($currentArg -ne "") {
        $allArgs += $currentArg
    }
    
    # Check each argument
    foreach ($arg in $allArgs) {
        $isNormal = $false
        
        # Check if it's a normal Minecraft argument
        foreach ($pattern in $normalArgs) {
            if ($arg -match $pattern) {
                $isNormal = $true
                break
            }
        }
        
        # Check for jar files (normal)
        if ($arg -match '\.jar$') {
            $isNormal = $true
        }
        
        # Check for standard GC args
        if ($arg -match '^-XX:\+Use(G1GC|ParallelGC|ConcMarkSweepGC)$') {
            $isNormal = $true
        }
        
        # If not normal, it's custom (RED FLAG)
        if (-not $isNormal -and $arg -match '^-') {
            $hasCustomArgs = $true
            $customArgs += $arg
        }
    }
    
    # Look for memory allocation (YELLOW FLAG)
    $hasMemoryChange = $false
    $memoryArgs = @()
    
    if ($argsOnly -match '-Xmx([0-9]+[MG])') {
        $alloc = $matches[1]
        $num = [int]($alloc -replace '[MG]', '')
        $unit = $alloc -replace '[0-9]', ''
        
        # Flag if > 8GB or < 2GB
        if (($unit -eq "G" -and $num -gt 8) -or 
            ($unit -eq "M" -and $num -gt 8192) -or
            ($unit -eq "G" -and $num -lt 2)) {
            $hasMemoryChange = $true
            $memoryArgs += "-Xmx$alloc"
        }
    }
    
    # Display results
    Write-Host "PID $PID : " -NoNewline -ForegroundColor White
    
    if ($hasCustomArgs) {
        Write-Host "[RED FLAG] Custom JVM arguments found!" -ForegroundColor Red
        foreach ($arg in $customArgs) {
            Write-Host "  → $arg" -ForegroundColor Red
        }
    }
    elseif ($hasMemoryChange) {
        Write-Host "[YELLOW FLAG] Unusual memory allocation" -ForegroundColor Yellow
        foreach ($arg in $memoryArgs) {
            Write-Host "  → $arg" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[OK] Standard Minecraft" -ForegroundColor Green
    }
    
    # Show what was in the JVM args box
    if ($hasCustomArgs -or $hasMemoryChange) {
        Write-Host "  Launcher JVM Args: $argsOnly" -ForegroundColor Gray
        Write-Host ""
    }
}

# Main loop
if ($Monitor) {
    while ($true) {
        Check-Minecraft
        Start-Sleep -Seconds $CheckEvery
    }
} else {
    Check-Minecraft
}
