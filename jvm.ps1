# Minecraft JVM Arguments Detector for PowerShell
# Save this as Detect-MinecraftJVM.ps1
# Run with: powershell -ExecutionPolicy Bypass -File Detect-MinecraftJVM.ps1

param(
    [switch]$Continuous = $false,
    [int]$Interval = 5,
    [switch]$JsonOutput = $false,
    [switch]$MonitorAllJava = $false
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-MinecraftProcesses {
    $minecraftProcesses = @()
    
    # Get all Java processes
    $processes = Get-Process java*, javaw* -ErrorAction SilentlyContinue
    
    foreach ($proc in $processes) {
        try {
            # Get command line using WMI (works in PowerShell 5.1)
            $wmiProcess = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
            
            if ($wmiProcess -and $wmiProcess.CommandLine) {
                $cmdLine = $wmiProcess.CommandLine
                
                # Check if it's a Minecraft-related process
                $isMinecraft = $false
                $lowerCmdLine = $cmdLine.ToLower()
                
                # Common Minecraft indicators
                if ($lowerCmdLine -match "minecraft" -or 
                    $lowerCmdLine -match "\.minecraft" -or 
                    $lowerCmdLine -match "net\.minecraft" -or
                    $lowerCmdLine -match "minecraftforge" -or
                    $lowerCmdLine -match "fabric" -or
                    $lowerCmdLine -match "optifine" -or
                    $cmdLine -match "\.jar" -or
                    $lowerCmdLine -match "mojang") {
                    $isMinecraft = $true
                }
                
                # Also check for specific Minecraft launcher processes
                $processName = $proc.ProcessName.ToLower()
                if ($processName -match "minecraft" -or $processName -match "tlauncher") {
                    $isMinecraft = $true
                }
                
                if ($isMinecraft -or $MonitorAllJava) {
                    # Get process owner
                    $owner = "Unknown"
                    try {
                        $ownerInfo = $wmiProcess.GetOwner()
                        if ($ownerInfo.Domain -and $ownerInfo.User) {
                            $owner = "$($ownerInfo.Domain)\$($ownerInfo.User)"
                        } elseif ($ownerInfo.User) {
                            $owner = $ownerInfo.User
                        }
                    } catch { }
                    
                    $processInfo = @{
                        PID = $proc.Id
                        Name = $proc.ProcessName
                        CommandLine = $cmdLine
                        User = $owner
                        StartTime = $proc.StartTime
                    }
                    
                    $minecraftProcesses += $processInfo
                }
            }
        } catch {
            # Silently continue if we can't access a process
            continue
        }
    }
    
    return $minecraftProcesses
}

function Extract-JVMArguments {
    param(
        [string]$CommandLine
    )
    
    $jvmArgs = @{
        Memory = @{}
        GarbageCollector = @()
        SystemProperties = @{}
        OtherArguments = @()
        MainClass = $null
        GameArguments = @()
        TotalMemory = 0
        FullCommand = $CommandLine
    }
    
    # Extract memory arguments
    if ($CommandLine -match '-Xmx(\d+[MG])') {
        $jvmArgs.Memory["Xmx"] = $matches[1]
        $value = $matches[1]
        $num = [int]($value -replace '[MG]', '')
        if ($value -match "G") {
            $jvmArgs.TotalMemory = $num * 1024
        } else {
            $jvmArgs.TotalMemory = $num
        }
    }
    
    if ($CommandLine -match '-Xms(\d+[MG])') {
        $jvmArgs.Memory["Xms"] = $matches[1]
    }
    
    if ($CommandLine -match '-Xmn(\d+[MG])') {
        $jvmArgs.Memory["Xmn"] = $matches[1]
    }
    
    # Extract garbage collector arguments
    $gcArgs = @("UseG1GC", "UseConcMarkSweepGC", "UseSerialGC", "UseParallelGC", 
                "UseZGC", "UseShenandoahGC", "UnlockExperimentalVMOptions")
    
    foreach ($gc in $gcArgs) {
        if ($CommandLine -match "-XX:\+$gc") {
            $jvmArgs.GarbageCollector += "-XX:+$gc"
        }
    }
    
    # Extract system properties (-D arguments) - YES, IT WILL DETECT YOUR ARGUMENT!
    # This will detect arguments like: -Dfabric.addMods=C:\Users\maste\Videos\kotlinfabric-jvm-1.04.jar
    if ($CommandLine -match '-D([^=\s]+)=([^\s]+)') {
        $matches = [regex]::Matches($CommandLine, '-D([^=\s]+)=([^\s]+)')
        foreach ($match in $matches) {
            $key = $match.Groups[1].Value
            $value = $match.Groups[2].Value
            $jvmArgs.SystemProperties[$key] = $value
        }
    }
    
    # Find main class/jar file
    if ($CommandLine -match '\s(\S+\.jar)(?:\s|$)') {
        $jvmArgs.MainClass = $matches[1]
        
        # Extract game arguments (everything after the jar)
        $jarIndex = $CommandLine.IndexOf($matches[1])
        if ($jarIndex -ne -1) {
            $afterJar = $CommandLine.Substring($jarIndex + $matches[1].Length).Trim()
            if ($afterJar) {
                # Split by spaces but keep quoted strings together
                $argMatches = [regex]::Matches($afterJar, '("[^"]*"|\S+)')
                foreach ($match in $argMatches) {
                    $jvmArgs.GameArguments += $match.Value
                }
            }
        }
    }
    
    # Extract other JVM arguments
    if ($CommandLine -match '(-(?:X|XX)[^\s]+)') {
        $matches = [regex]::Matches($CommandLine, '(-(?:X|XX)[^\s]+)')
        foreach ($match in $matches) {
            $arg = $match.Value
            # Skip already categorized arguments
            if (-not ($arg -match '^-X[mM]') -and 
                -not ($arg -match '^-XX:\+Use.*GC') -and
                -not ($arg -match '^-D')) {
                
                $jvmArgs.OtherArguments += $arg
            }
        }
    }
    
    return $jvmArgs
}

function Format-JVMOutput {
    param(
        [hashtable]$ProcessInfo,
        [hashtable]$JVMArgs
    )
    
    if ($JsonOutput) {
        $output = @{
            Process = $ProcessInfo
            JVMArguments = $JVMArgs
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        return $output | ConvertTo-Json -Depth 4
    }
    
    Write-ColorOutput "════════════════════════════════════════════════════════════════════" -Color Cyan
    Write-ColorOutput "MINECRAFT PROCESS DETECTED!" -Color Cyan
    Write-ColorOutput "════════════════════════════════════════════════════════════════════" -Color Cyan
    Write-Host "PID: $($ProcessInfo.PID)" -ForegroundColor White
    Write-Host "Process: $($ProcessInfo.Name)" -ForegroundColor White
    Write-Host "User: $($ProcessInfo.User)" -ForegroundColor White
    if ($ProcessInfo.StartTime) {
        Write-Host "Started: $($ProcessInfo.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    }
    Write-Host ""
    
    # Memory Settings
    if ($JVMArgs.Memory.Count -gt 0) {
        Write-ColorOutput "💾 MEMORY SETTINGS:" -Color Green
        if ($JVMArgs.Memory["Xmx"]) {
            Write-Host "  Maximum Heap (-Xmx): $($JVMArgs.Memory['Xmx'])" -ForegroundColor White
        }
        if ($JVMArgs.Memory["Xms"]) {
            Write-Host "  Initial Heap (-Xms): $($JVMArgs.Memory['Xms'])" -ForegroundColor White
        }
        if ($JVMArgs.Memory["Xmn"]) {
            Write-Host "  Young Generation (-Xmn): $($JVMArgs.Memory['Xmn'])" -ForegroundColor White
        }
    } else {
        Write-ColorOutput "💾 MEMORY SETTINGS: Using defaults (likely 2GB)" -Color Yellow
    }
    
    # Garbage Collector
    if ($JVMArgs.GarbageCollector.Count -gt 0) {
        Write-ColorOutput "`n🗑️  GARBAGE COLLECTOR:" -Color Green
        foreach ($gc in $JVMArgs.GarbageCollector) {
            Write-Host "  • $gc" -ForegroundColor White
        }
    }
    
    # System Properties - THIS WILL SHOW YOUR -D ARGUMENTS!
    if ($JVMArgs.SystemProperties.Count -gt 0) {
        Write-ColorOutput "`n⚙️  SYSTEM PROPERTIES (-D arguments):" -Color Green
        foreach ($key in $JVMArgs.SystemProperties.Keys) {
            Write-Host "  $($key):" -ForegroundColor Yellow -NoNewline
            Write-Host " $($JVMArgs.SystemProperties[$key])" -ForegroundColor White
        }
    }
    
    # Other Arguments
    if ($JVMArgs.OtherArguments.Count -gt 0) {
        Write-ColorOutput "`n🔧 OTHER JVM ARGUMENTS:" -Color Green
        foreach ($arg in $JVMArgs.OtherArguments) {
            Write-Host "  • $arg" -ForegroundColor White
        }
    }
    
    # Main Class
    if ($JVMArgs.MainClass) {
        Write-ColorOutput "`n🎮 MAIN CLASS/JAR:" -Color Green
        Write-Host "  $($JVMArgs.MainClass)" -ForegroundColor Magenta
    }
    
    # Show raw command line for debugging
    Write-ColorOutput "`n📝 RAW COMMAND LINE (first 200 chars):" -Color Gray
    if ($ProcessInfo.CommandLine.Length -gt 200) {
        Write-Host "  $($ProcessInfo.CommandLine.Substring(0, 200))..." -ForegroundColor DarkGray
    } else {
        Write-Host "  $($ProcessInfo.CommandLine)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

# Main execution
Clear-Host
Write-ColorOutput "================================================" -Color Cyan
Write-ColorOutput "   Minecraft JVM Arguments Detector" -Color Cyan
Write-ColorOutput "================================================" -Color Cyan
Write-Host "Version: 2.0 (Fixed for PowerShell 5.1)" -ForegroundColor Gray
Write-Host ""

if ($Continuous) {
    Write-ColorOutput "🔍 Continuous monitoring enabled (Interval: ${Interval}s)" -Color Yellow
    Write-ColorOutput "Press Ctrl+C to stop monitoring" -Color Gray
    Write-Host ""
    
    try {
        while ($true) {
            $processes = Get-MinecraftProcesses
            
            if ($processes.Count -gt 0) {
                foreach ($proc in $processes) {
                    $jvmArgs = Extract-JVMArguments -CommandLine $proc.CommandLine
                    Format-JVMOutput -ProcessInfo $proc -JVMArgs $jvmArgs
                }
            } else {
                Write-ColorOutput "[$(Get-Date -Format 'HH:mm:ss')] No Minecraft processes detected..." -Color Gray
            }
            
            Start-Sleep -Seconds $Interval
        }
    }
    catch {
        Write-ColorOutput "`nMonitoring stopped." -Color Yellow
    }
}
else {
    Write-ColorOutput "🔍 Scanning for Minecraft processes..." -Color Yellow
    $processes = Get-MinecraftProcesses
    
    if ($processes.Count -eq 0) {
        Write-ColorOutput "❌ No Minecraft processes found!" -Color Red
        Write-Host ""
        Write-ColorOutput "Troubleshooting steps:" -Color Yellow
        Write-Host "  1. Make sure Minecraft is running" -ForegroundColor Gray
        Write-Host "  2. Try running as Administrator" -ForegroundColor Gray
        Write-Host "  3. Run: .\Detect-MinecraftJVM.ps1 -MonitorAllJava" -ForegroundColor Gray
        Write-Host "  4. Run: .\Detect-MinecraftJVM.ps1 -Continuous" -ForegroundColor Gray
        Write-Host ""
        Write-ColorOutput "To manually check, run this command:" -Color Cyan
        Write-Host "  Get-Process java*, javaw* | Select-Object Id, ProcessName" -ForegroundColor White
    }
    else {
        Write-ColorOutput "✅ Found $($processes.Count) Minecraft process(es)" -Color Green
        Write-Host ""
        
        foreach ($proc in $processes) {
            $jvmArgs = Extract-JVMArguments -CommandLine $proc.CommandLine
            $jsonOutput = Format-JVMOutput -ProcessInfo $proc -JVMArgs $jvmArgs
            
            if ($JsonOutput) {
                $jsonOutput
            }
        }
    }
}
