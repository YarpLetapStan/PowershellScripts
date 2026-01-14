# Save this as: check_jvm.ps1
# Run in CMD: powershell -ExecutionPolicy Bypass -File check_jvm.ps1

Clear-Host
Write-Host "=== Minecraft JVM Argument Checker ===" -ForegroundColor Cyan
Write-Host "Checking for custom JVM arguments..." -ForegroundColor White
Write-Host ""

$foundMinecraft = $false

# Check all javaw processes (Minecraft usually uses javaw)
$processes = Get-Process javaw* -ErrorAction SilentlyContinue

if ($processes.Count -eq 0) {
    Write-Host "No Minecraft processes found!" -ForegroundColor Yellow
    Write-Host "Make sure Minecraft is running." -ForegroundColor Gray
    exit
}

foreach ($proc in $processes) {
    try {
        # Get the full command line
        $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
        
        if ($wmi -and $wmi.CommandLine) {
            $cmdLine = $wmi.CommandLine
            
            # Check if it's Minecraft
            if ($cmdLine -match "minecraft" -or $cmdLine -match "\.minecraft" -or $cmdLine -match "mojang") {
                $foundMinecraft = $true
                
                Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "Minecraft Process Found!" -ForegroundColor Green
                Write-Host "PID: $($proc.Id)" -ForegroundColor White
                Write-Host ""
                
                # Extract just the arguments (after .exe)
                if ($cmdLine -match '\.exe\s+"(.*)"$' -or $cmdLine -match '\.exe\s+(.*)$') {
                    $allArgs = $matches[1]
                    
                    Write-Host "📋 All JVM Arguments:" -ForegroundColor Yellow
                    Write-Host "----------------------" -ForegroundColor DarkGray
                    
                    # Split into individual arguments
                    $argsArray = $allArgs -split '\s+(?=(?:[^"]*"[^"]*")*[^"]*$)' | Where-Object { $_ -ne '' }
                    
                    $customArgs = @()
                    
                    foreach ($arg in $argsArray) {
                        # Skip .jar files and main class
                        if ($arg -match '\.jar$' -or $arg -match '^net\.minecraft' -or $arg -eq "-cp") {
                            Write-Host "  [Standard] $arg" -ForegroundColor Gray
                        }
                        # Check for custom -D arguments (RED FLAG)
                        elseif ($arg -match '^-D') {
                            # These are standard Minecraft -D args, ignore them
                            $standardDArgs = @('os\.', 'sun\.', 'java\.', 'minecraft\.', 'user\.', 'file\.encoding')
                            $isStandard = $false
                            
                            foreach ($std in $standardDArgs) {
                                if ($arg -match "^-D$std") {
                                    $isStandard = $true
                                    break
                                }
                            }
                            
                            if (-not $isStandard) {
                                Write-Host "  🔴 [Custom] $arg" -ForegroundColor Red
                                $customArgs += $arg
                            } else {
                                Write-Host "  [System] $arg" -ForegroundColor DarkGray
                            }
                        }
                        # Check for memory arguments (YELLOW FLAG if not default)
                        elseif ($arg -match '^-Xmx') {
                            if ($arg -ne "-Xmx2G") {
                                Write-Host "  🟡 [Memory] $arg" -ForegroundColor Yellow
                                $customArgs += $arg
                            } else {
                                Write-Host "  [Memory] $arg (default)" -ForegroundColor Gray
                            }
                        }
                        # Other arguments
                        elseif ($arg -match '^-') {
                            Write-Host "  [Other] $arg" -ForegroundColor Cyan
                        }
                        else {
                            Write-Host "  $arg" -ForegroundColor Gray
                        }
                    }
                    
                    # Show summary
                    if ($customArgs.Count -gt 0) {
                        Write-Host "`n🚨 CUSTOM JVM ARGUMENTS DETECTED!" -ForegroundColor Red
                        Write-Host "These were typed in the JVM Arguments box:" -ForegroundColor Red
                        
                        foreach ($custom in $customArgs) {
                            Write-Host "  → $custom" -ForegroundColor Red
                        }
                        
                        Write-Host "`n⚠️  Player added custom JVM arguments!" -ForegroundColor Red
                    } else {
                        Write-Host "`n✅ No custom JVM arguments found." -ForegroundColor Green
                        Write-Host "Player is using default launcher settings." -ForegroundColor Gray
                    }
                    
                    Write-Host ""
                }
            }
        }
    }
    catch {
        # Skip processes we can't access
        continue
    }
}

if (-not $foundMinecraft) {
    Write-Host "No Minecraft Java processes found!" -ForegroundColor Yellow
    Write-Host "Note: Only checks javaw processes (standard Minecraft)." -ForegroundColor Gray
}
