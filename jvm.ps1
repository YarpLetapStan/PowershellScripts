# Minecraft JVM Argument Monitor
# Save as: minecraft_jvm.ps1
# Run: powershell -ExecutionPolicy Bypass -File minecraft_jvm.ps1

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
Write-Host ""

function Find-MinecraftProcesses {
    $minecraftProcs = @()
    $allProcs = Get-Process -ErrorAction SilentlyContinue
    
    foreach ($proc in $allProcs) {
        # Check for Java processes
        if ($proc.ProcessName -match "java|javaw") {
            try {
                # Get command line
                $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
                if ($wmi -and $wmi.CommandLine) {
                    $cmdLine = $wmi.CommandLine
                    
                    # Check if it's Minecraft (simple check)
                    $isMinecraft = $false
                    
                    # Check for common Minecraft indicators
                    if ($cmdLine -match "minecraft" -or 
                        $cmdLine -match "\.minecraft" -or 
                        $cmdLine -match "mojang" -or
                        ($cmdLine -match "\.jar" -and $proc.ProcessName -eq "javaw")) {
                        $isMinecraft = $true
                    }
                    
                    if ($isMinecraft) {
                        $minecraftProcs += @{
                            Id = $proc.Id
                            Name = $proc.ProcessName
                            CommandLine = $cmdLine
                        }
                    }
                }
            } catch {
                # Skip processes we can't access
            }
        }
    }
    
    return $minecraftProcs
}

function Show-JVMArgs {
    param($CommandLine)
    
    Write-Host "Full command line:" -ForegroundColor Gray
    Write-Host "  $CommandLine" -ForegroundColor DarkGray
    Write-Host ""
    
    # Extract arguments (everything after .exe)
    if ($CommandLine -match '\.exe\s+(.*)$') {
        $argsPart = $matches[1]
        Write-Host "JVM Arguments detected:" -ForegroundColor Gray
        
        # Split into individual arguments
        $argsArray = @()
        $current = ""
        $inQuotes = $false
        
        for ($i = 0; $i -lt $argsPart.Length; $i++) {
            $char = $argsPart[$i]
            
            if ($char -eq '"') {
                $inQuotes = -not $inQuotes
                $current += $char
            }
            elseif ($char -eq ' ' -and -not $inQuotes) {
                if ($current -ne "") {
                    $argsArray += $current
                    $current = ""
                }
            }
            else {
                $current += $char
            }
        }
        
        if ($current -ne "") {
            $argsArray += $current
        }
        
        # Show all arguments
        foreach ($arg in $argsArray) {
            Write-Host "  • $arg" -ForegroundColor White
        }
        
        return $argsPart
    }
    
    return ""
}

function Check-Arguments {
    param($Process)
    
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Process: $($Process.Name) (PID: $($Process.Id))" -ForegroundColor White
    
    $jvmArgs = Show-JVMArgs -CommandLine $Process.CommandLine
    
    # Check for custom JVM arguments (RED FLAG)
    $hasRedFlag = $false
    
    # Check for -D arguments that aren't standard
    if ($jvmArgs -match '-D([^=\s]+)=([^\s]+)') {
        $matches = [regex]::Matches($jvmArgs, '-D([^=\s]+)=([^\s]+)')
        foreach ($match in $matches) {
            $key = $match.Groups[1].Value
            
            # List of standard Minecraft -D arguments
            $standardDArgs = @(
                "os.name", "os.version", "java.library.path", 
                "java.io.tmpdir", "user.language", "user.country",
                "sun.java.command", "jna.nosys"
            )
            
            # Check if this is a non-standard -D argument
            $isStandard = $false
            foreach ($std in $standardDArgs) {
                if ($key -eq $std -or $key.StartsWith("$std.")) {
                    $isStandard = $true
                    break
                }
            }
            
            if (-not $isStandard) {
                $hasRedFlag = $true
                Write-Host "`n[RED FLAG] Custom JVM argument found!" -ForegroundColor Red
                Write-Host "  -D$key=$(($match.Groups[2].Value).Substring(0, [Math]::Min(50, $match.Groups[2].Value.Length)))" -ForegroundColor Red
            }
        }
    }
    
    # Check for unusual memory allocation (YELLOW FLAG)
    $hasYellowFlag = $false
    if ($jvmArgs -match '-Xmx(\d+)([MG])') {
        $amount = [int]$matches[1]
        $unit = $matches[2]
        
        if ($unit -eq "G") {
            $mb = $amount * 1024
        } else {
            $mb = $amount
        }
        
        # Flag if > 8GB or < 2GB
        if ($mb -gt 8192 -or $mb -lt 2048) {
            $hasYellowFlag = $true
            Write-Host "`n[YELLOW FLAG] Unusual memory allocation!" -ForegroundColor Yellow
            Write-Host "  -Xmx$amount$unit ($mb MB)" -ForegroundColor Yellow
        }
    }
    
    # Show status
    if ($hasRedFlag) {
        Write-Host "`n❌ RED FLAG DETECTED!" -ForegroundColor Red
        Write-Host "   Custom JVM arguments found in launcher" -ForegroundColor Red
    }
    elseif ($hasYellowFlag) {
        Write-Host "`n⚠️  YELLOW FLAG DETECTED!" -ForegroundColor Yellow
        Write-Host "   Unusual memory allocation detected" -ForegroundColor Yellow
    }
    else {
        Write-Host "`n✅ STANDARD MINECRAFT" -ForegroundColor Green
        Write-Host "   No custom JVM arguments found" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Main function
function Run-Check {
    $procs = Find-MinecraftProcesses
    
    if ($procs.Count -eq 0) {
        Write-Host "No Minecraft Java processes found!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Make sure:" -ForegroundColor Gray
        Write-Host "1. Minecraft is running" -ForegroundColor Gray
        Write-Host "2. Try running as Administrator" -ForegroundColor Gray
        Write-Host "3. The game needs to be started from the launcher" -ForegroundColor Gray
    }
    else {
        Write-Host "Found $($procs.Count) Minecraft process(es):`n" -ForegroundColor Cyan
        
        foreach ($proc in $procs) {
            Check-Arguments -Process $proc
        }
    }
}

# Run the check
if ($Monitor) {
    Write-Host "Monitoring mode (checking every $CheckEvery seconds)" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray
    
    while ($true) {
        Run-Check
        Start-Sleep -Seconds $CheckEvery
    }
} else {
    Run-Check
}
