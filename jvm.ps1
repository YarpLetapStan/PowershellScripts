# Minecraft JVM Box Argument Detector
# Shows EXACTLY what was typed in the "JVM Arguments" box

param(
    [switch]$Monitor = $false,
    [int]$CheckEvery = 5
)

Clear-Host
Write-Host "=== Minecraft JVM Box Detector ===" -ForegroundColor Cyan
Write-Host "Shows ONLY what was typed in the 'JVM Arguments' box" -ForegroundColor White
Write-Host ""

# These are the EXACT default arguments Minecraft launcher uses
# Anything NOT in this list came from the JVM Arguments box
$defaultMinecraftArgs = @(
    # EXACT memory defaults
    '-Xmx2G',
    '-Xss1M',
    
    # EXACT garbage collector defaults
    '-XX:+UnlockExperimentalVMOptions',
    '-XX:+UseG1GC',
    '-XX:MaxGCPauseMillis=100',
    '-XX:+DisableExplicitGC',
    '-XX:TargetSurvivorRatio=90',
    '-XX:G1NewSizePercent=50',
    '-XX:G1MaxNewSizePercent=80',
    '-XX:InitiatingHeapOccupancyPercent=10',
    '-XX:G1MixedGCLiveThresholdPercent=50',
    '-XX:+AggressiveOpts',
    '-XX:+AlwaysPreTouch',
    '-XX:+UseLargePagesInMetaspace',
    '-XX:+UseCompressedOops',
    '-XX:+UseCompressedClassPointers',
    '-XX:+UseStringDeduplication',
    '-XX:+OptimizeStringConcat',
    '-XX:+UseFastAccessorMethods',
    '-XX:+UseNUMA',
    '-XX:+UseBiasedLocking',
    
    # EXACT system property defaults
    '-Dos.name=Windows 10',
    '-Dos.version=',
    '-Dsun.arch.data.model=64',
    '-Djava.library.path=',
    '-Dminecraft.launcher.brand=minecraft-launcher',
    '-Dminecraft.launcher.version=',
    '-Djava.io.tmpdir=',
    '-Duser.language=en',
    '-Duser.country=US',
    '-Dfile.encoding=UTF-8'
)

function Get-JVMBoxArguments {
    $results = @()
    
    # Look for Java processes
    $javaProcs = Get-Process java*, javaw* -ErrorAction SilentlyContinue
    
    foreach ($proc in $javaProcs) {
        try {
            # Get the full command line
            $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
            if ($wmi -and $wmi.CommandLine) {
                $cmdLine = $wmi.CommandLine
                
                # Only check Minecraft processes
                if ($cmdLine -match "minecraft" -or $cmdLine -match "\.minecraft") {
                    # Get JUST what's in the JVM box
                    $boxArgs = Extract-BoxArguments -CommandLine $cmdLine
                    
                    if ($boxArgs -ne "") {
                        $results += @{
                            PID = $proc.Id
                            BoxArguments = $boxArgs
                        }
                    }
                }
            }
        } catch { }
    }
    
    return $results
}

function Extract-BoxArguments {
    param([string]$CommandLine)
    
    # Extract everything after .exe
    if ($CommandLine -match '\.exe\s+(.*)$') {
        $allArgs = $matches[1]
        
        # Split into individual arguments
        $argList = Split-Arguments -ArgsString $allArgs
        
        # Filter out EXACT default arguments
        $customArgs = @()
        
        foreach ($arg in $argList) {
            $isDefault = $false
            
            # Check if it matches any default argument pattern
            foreach ($default in $defaultMinecraftArgs) {
                # Remove version numbers and paths from defaults for matching
                $cleanDefault = $default -replace '=.*$', '='
                $cleanArg = $arg -replace '=.*$', '='
                
                if ($cleanArg -eq $cleanDefault) {
                    $isDefault = $true
                    break
                }
                
                # Special case for -Dos.version and similar
                if ($default -match '^-[^-].*=$' -and $arg.StartsWith($default)) {
                    $isDefault = $true
                    break
                }
            }
            
            # Also filter out jar files and game arguments
            if ($arg -match '\.jar$' -or 
                $arg -match '^--' -or 
                $arg -match '^net\.minecraft' -or
                $arg -eq "-cp") {
                $isDefault = $true
            }
            
            # Also filter out standard memory if exactly 2G
            if ($arg -eq "-Xmx2G" -or $arg -eq "-Xms1G") {
                $isDefault = $true
            }
            
            if (-not $isDefault) {
                $customArgs += $arg
            }
        }
        
        # Return only custom arguments
        return ($customArgs -join " ")
    }
    
    return ""
}

function Split-Arguments {
    param([string]$ArgsString)
    
    $argsList = @()
    $current = ""
    $inQuotes = $false
    
    for ($i = 0; $i -lt $ArgsString.Length; $i++) {
        $char = $ArgsString[$i]
        
        if ($char -eq '"') {
            $inQuotes = -not $inQuotes
            $current += $char
        }
        elseif ($char -eq ' ' -and -not $inQuotes) {
            if ($current -ne "") {
                $argsList += $current
                $current = ""
            }
        }
        else {
            $current += $char
        }
    }
    
    if ($current -ne "") {
        $argsList += $current
    }
    
    return $argsList
}

# Main function
function Check-For-Custom-Args {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Checking for custom JVM arguments..." -ForegroundColor Gray
    
    $results = Get-JVMBoxArguments
    
    if ($results.Count -eq 0) {
        Write-Host "✅ No custom JVM arguments found in any Minecraft process." -ForegroundColor Green
        Write-Host "   (Only using default launcher settings)" -ForegroundColor Gray
    }
    else {
        foreach ($result in $results) {
            Write-Host ""
            Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "🚨 CUSTOM JVM ARGUMENTS DETECTED!" -ForegroundColor Red
            Write-Host "PID: $($result.PID)" -ForegroundColor White
            
            # Split the box arguments
            $boxArgs = $result.BoxArguments -split '\s+' | Where-Object { $_ -ne '' }
            
            if ($boxArgs.Count -gt 0) {
                Write-Host ""
                Write-Host "🔴 What was typed in the JVM Arguments box:" -ForegroundColor Red
                Write-Host ""
                
                foreach ($arg in $boxArgs) {
                    # Show just the argument
                    Write-Host "  $arg" -ForegroundColor Red
                }
                
                Write-Host ""
                Write-Host "📋 Total custom arguments: $($boxArgs.Count)" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host ""
}

# Run
if ($Monitor) {
    Write-Host "🔍 Monitoring mode (every $CheckEvery seconds)" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
    Write-Host ""
    
    try {
        while ($true) {
            Check-For-Custom-Args
            Start-Sleep -Seconds $CheckEvery
        }
    }
    catch {
        Write-Host "`nStopped monitoring." -ForegroundColor Gray
    }
}
else {
    Check-For-Custom-Args
}
