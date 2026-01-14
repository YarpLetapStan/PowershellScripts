# Minecraft JVM Custom Argument Detector
# Shows ONLY what was typed in the JVM Arguments box

param(
    [switch]$Monitor = $false,
    [int]$CheckEvery = 3
)

Clear-Host
Write-Host "=== Minecraft JVM Argument Detector ===" -ForegroundColor Cyan
Write-Host "Shows ONLY what players typed in the JVM Arguments box" -ForegroundColor White
Write-Host ""

function Get-MinecraftJVMArgs {
    $foundArgs = @()
    $allProcs = Get-Process -ErrorAction SilentlyContinue
    
    foreach ($proc in $allProcs) {
        if ($proc.ProcessName -match "java|javaw") {
            try {
                $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
                if ($wmi -and $wmi.CommandLine) {
                    $cmdLine = $wmi.CommandLine
                    
                    # Only check if it's Minecraft
                    if ($cmdLine -match "minecraft" -or $cmdLine -match "\.minecraft" -or 
                        $cmdLine -match "mojang" -or ($cmdLine -match "\.jar" -and $proc.ProcessName -eq "javaw")) {
                        
                        # Extract JUST the custom arguments
                        $customArgs = Extract-CustomArgs -CommandLine $cmdLine
                        
                        if ($customArgs -ne "") {
                            $foundArgs += @{
                                PID = $proc.Id
                                Process = $proc.ProcessName
                                CustomArguments = $customArgs
                                RawCommand = $cmdLine
                            }
                        }
                    }
                }
            } catch { }
        }
    }
    
    return $foundArgs
}

function Extract-CustomArgs {
    param([string]$CommandLine)
    
    # List of ALL standard Minecraft arguments (these are NOT from the JVM box)
    $standardArgs = @(
        # Standard JVM args from launcher
        '-Dos\.name=.*',
        '-Dos\.version=.*',
        '-Dsun\.arch\.data\.model=.*',
        '-Djava\.library\.path=.*',
        '-Dminecraft\.launcher\.brand=.*',
        '-Dminecraft\.launcher\.version=.*',
        '-Djava\.io\.tmpdir=.*',
        '-cp',
        '.*\.jar',  # Jar files
        '--width',
        '--height',
        '--fullscreen',
        
        # Standard memory args (default is Xmx2G)
        '-Xmx\d+G',
        '-Xms\d+G',
        '-Xss\d+M',
        
        # Standard GC args
        '-XX:\+UseG1GC',
        '-XX:\+UnlockExperimentalVMOptions',
        '-XX:\+DisableExplicitGC',
        '-XX:\+UseCompressedOops',
        
        # Game window args
        '--username',
        '--version',
        '--gameDir',
        '--assetsDir',
        '--assetIndex',
        '--uuid',
        '--accessToken',
        '--userType',
        '--versionType'
    )
    
    # Remove standard arguments to leave ONLY custom ones
    $customOnly = $CommandLine
    
    # First, extract the part after .exe
    if ($CommandLine -match '\.exe\s+(.*)$') {
        $allArgs = $matches[1]
        $customOnly = $allArgs
        
        # Remove each standard argument pattern
        foreach ($pattern in $standardArgs) {
            $customOnly = $customOnly -replace $pattern, ''
        }
        
        # Clean up extra spaces
        $customOnly = $customOnly -replace '\s+', ' '
        $customOnly = $customOnly.Trim()
    }
    
    return $customOnly
}

# Main check
function Run-Detector {
    $results = Get-MinecraftJVMArgs
    
    if ($results.Count -eq 0) {
        Write-Host "No Minecraft processes with custom JVM arguments found." -ForegroundColor Green
        Write-Host ""
        Write-Host "Note: This only shows what was typed in the 'JVM Arguments' box." -ForegroundColor Gray
        Write-Host "      Standard Minecraft arguments are filtered out." -ForegroundColor Gray
    }
    else {
        Write-Host "Found $($results.Count) Minecraft process(es) with custom JVM arguments:`n" -ForegroundColor Cyan
        
        foreach ($result in $results) {
            Write-Host "════════════════════════════════════════════" -ForegroundColor DarkGray
            Write-Host "PID: $($result.PID) | Process: $($result.Process)" -ForegroundColor White
            
            # Split the custom args to check each one
            $customArgs = $result.CustomArguments -split '\s+' | Where-Object { $_ -ne '' }
            
            if ($customArgs.Count -gt 0) {
                Write-Host ""
                Write-Host "🔴 WHAT THE PLAYER TYPED IN JVM ARGUMENTS BOX:" -ForegroundColor Red
                
                foreach ($arg in $customArgs) {
                    # Check what type of argument it is
                    if ($arg -match '^-D') {
                        Write-Host "  -D Argument: " -ForegroundColor Red -NoNewline
                        Write-Host $arg -ForegroundColor White
                    }
                    elseif ($arg -match '^-Xmx') {
                        Write-Host "  Memory Argument: " -ForegroundColor Yellow -NoNewline
                        Write-Host $arg -ForegroundColor White
                    }
                    else {
                        Write-Host "  Custom Argument: " -ForegroundColor Red -NoNewline
                        Write-Host $arg -ForegroundColor White
                    }
                }
                
                # Show summary
                Write-Host ""
                Write-Host "📊 Summary:" -ForegroundColor Cyan
                Write-Host "  • Custom -D arguments: $($customArgs | Where-Object { $_ -match '^-D' } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
                Write-Host "  • Memory arguments: $($customArgs | Where-Object { $_ -match '^-Xm' } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
                Write-Host "  • Other custom args: $($customArgs | Where-Object { $_ -match '^-' -and $_ -notmatch '^-D' -and $_ -notmatch '^-Xm' } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
            }
            else {
                Write-Host ""
                Write-Host "✅ No custom JVM arguments detected" -ForegroundColor Green
            }
            
            Write-Host ""
        }
    }
}

# Run
if ($Monitor) {
    Write-Host "Monitoring mode: Checking every $CheckEvery seconds" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray
    
    while ($true) {
        Run-Detector
        Start-Sleep -Seconds $CheckEvery
        Write-Host "---" -ForegroundColor DarkGray
    }
} else {
    Run-Detector
}
