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
    
    # Try multiple methods to get Java processes
    try {
        # Method 1: WMI (works on older systems)
        $processes = Get-WmiObject Win32_Process -Filter "Name LIKE '%java%' OR Name LIKE '%javaw%'" | 
                     Select-Object ProcessId, Name, CommandLine, CreationDate, @{Name="User"; Expression={$_.GetOwner().User}}
    }
    catch {
        # Method 2: Get-Process with detailed properties
        $processes = Get-Process java*, javaw* -ErrorAction SilentlyContinue | 
                     Select-Object Id, ProcessName, 
                     @{Name="CommandLine"; Expression={
                        try {
                            (Get-WmiObject Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
                        }
                        catch { $null }
                     }},
                     StartTime,
                     @{Name="User"; Expression={$_.GetOwner().User}}
    }
    
    foreach ($proc in $processes) {
        $cmdLine = $proc.CommandLine
        if ($cmdLine -and $cmdLine -ne "") {
            # Check if it's a Minecraft-related process
            $isMinecraft = $false
            $lowerCmdLine = $cmdLine.ToLower()
            
            # Common Minecraft indicators
            $minecraftIndicators = @(
                "minecraft",
                ".minecraft",
                "net.minecraft",
                "minecraftforge",
                "fabric",
                "optifine",
                "lunar",
                "badlion",
                "feather",
                "versions/",
                "libraries/com/mojang",
                "mojang",
                "minecraft launcher"
            )
            
            foreach ($indicator in $minecraftIndicators) {
                if ($lowerCmdLine -match [regex]::Escape($indicator)) {
                    $isMinecraft = $true
                    break
                }
            }
            
            # Also check for Java process running jar files (common for custom launchers)
            if (-not $isMinecraft -and ($MonitorAllJava -or $cmdLine -match "\.jar")) {
                $isMinecraft = $true
            }
            
            if ($isMinecraft) {
                $processInfo = @{
                    PID = $proc.ProcessId ?? $proc.Id
                    Name = $proc.Name ?? $proc.ProcessName
                    CommandLine = $cmdLine
                    User = $proc.User ?? "Unknown"
                    StartTime = if ($proc.CreationDate) { 
                        [Management.ManagementDateTimeConverter]::ToDateTime($proc.CreationDate) 
                    } elseif ($proc.StartTime) { 
                        $proc.StartTime 
                    } else { 
                        Get-Date 
                    }
                }
                $minecraftProcesses += $processInfo
            }
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
    
    # Split command line into arguments (handles quotes properly)
    $argList = @()
    $currentArg = ""
    $inQuotes = $false
    
    for ($i = 0; $i -lt $CommandLine.Length; $i++) {
        $char = $CommandLine[$i]
        
        if ($char -eq '"') {
            $inQuotes = -not $inQuotes
        }
        elseif ($char -eq ' ' -and -not $inQuotes) {
            if ($currentArg -ne "") {
                $argList += $currentArg
                $currentArg = ""
            }
        }
        else {
            $currentArg += $char
        }
    }
    
    if ($currentArg -ne "") {
        $argList += $currentArg
    }
    
    # Extract memory arguments
    $memoryPatterns = @{
        "Xmx" = '-Xmx(\d+[MG])'
        "Xms" = '-Xms(\d+[MG])'
        "Xmn" = '-Xmn(\d+[MG])'
        "Xss" = '-Xss(\d+[kMG])'
        "XX:MaxMetaspaceSize" = '-XX:MaxMetaspaceSize=(\d+[MG])'
        "XX:MetaspaceSize" = '-XX:MetaspaceSize=(\d+[MG])'
    }
    
    foreach ($pattern in $memoryPatterns.GetEnumerator()) {
        if ($CommandLine -match $pattern.Value) {
            $value = $matches[1]
            $jvmArgs.Memory[$pattern.Key] = $value
            
            # Calculate total memory in MB
            if ($pattern.Key -eq "Xmx") {
                $num = [int]($value -replace '[MG]', '')
                if ($value -match "G") {
                    $jvmArgs.TotalMemory = $num * 1024
                } else {
                    $jvmArgs.TotalMemory = $num
                }
            }
        }
    }
    
    # Extract garbage collector arguments
    $gcArgs = @(
        "-XX:+UseG1GC",
        "-XX:+UseConcMarkSweepGC", 
        "-XX:+UseSerialGC",
        "-XX:+UseParallelGC",
        "-XX:+UseZGC",
        "-XX:+UseShenandoahGC",
        "-XX:+UnlockExperimentalVMOptions"
    )
    
    foreach ($gcArg in $gcArgs) {
        if ($CommandLine -match [regex]::Escape($gcArg)) {
            $jvmArgs.GarbageCollector += $gcArg
        }
    }
    
    # Extract GC tuning arguments
    $gcTuningPatterns = @(
        '-XX:MaxGCPauseMillis=(\d+)',
        '-XX:G1HeapRegionSize=(\d+[MG])',
        '-XX:ParallelGCThreads=(\d+)',
        '-XX:ConcGCThreads=(\d+)'
    )
    
    foreach ($pattern in $gcTuningPatterns) {
        if ($CommandLine -match $pattern) {
            $jvmArgs.GarbageCollector += $matches[0]
        }
    }
    
    # Extract system properties (-D arguments)
    if ($CommandLine -match '-D([^=\s]+)=([^\s]+)') {
        $matches = [regex]::Matches($CommandLine, '-D([^=\s]+)=([^\s]+)')
        foreach ($match in $matches) {
            $jvmArgs.SystemProperties[$match.Groups[1].Value] = $match.Groups[2].Value
        }
    }
    
    # Find main class/jar file
    for ($i = 0; $i -lt $argList.Count; $i++) {
        $arg = $argList[$i]
        
        # Look for .jar files that aren't options
        if ($arg -match '\.jar$' -and -not $arg.StartsWith('-')) {
            $jvmArgs.MainClass = $arg
            
            # Game arguments are typically everything after the jar
            if ($i + 1 -lt $argList.Count) {
                $jvmArgs.GameArguments = $argList[($i + 1)..($argList.Count - 1)]
            }
            break
        }
    }
    
    # Extract other JVM arguments
    $otherArgsPattern = '(-(?:X|XX)[^\s]+)(?=\s|$)'
    if ($CommandLine -match $otherArgsPattern) {
        $matches = [regex]::Matches($CommandLine, $otherArgsPattern)
        foreach ($match in $matches) {
            $arg = $match.Value
            # Skip already categorized arguments
            if (-not ($arg -match '^-X[mM]') -and 
                -not ($arg -match '^-XX:\+Use.*GC') -and
                -not ($arg -match '^-D') -and
                -not ($jvmArgs.GarbageCollector -contains $arg) -and
                -not ($jvmArgs.Memory.Keys | ForEach-Object { "-$_" -replace ':', ':' } -contains $arg.Replace('=', ''))) {
                
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
    
    $output = @"
════════════════════════════════════════════════════════════════════
MINECRAFT PROCESS DETECTED!
════════════════════════════════════════════════════════════════════
PID: $($ProcessInfo.PID)
Process: $($ProcessInfo.Name)
User: $($ProcessInfo.User)
Started: $($ProcessInfo.StartTime.ToString("yyyy-MM-dd HH:mm:ss"))

"@
    
    Write-ColorOutput $output -Color Cyan
    
    # Memory Settings
    if ($JVMArgs.Memory.Count -gt 0) {
        Write-ColorOutput "💾 MEMORY SETTINGS:" -Color Green
        foreach ($key in $JVMArgs.Memory.Keys) {
            Write-Host "  $($key.PadRight(20)): $($JVMArgs.Memory[$key])" -ForegroundColor White
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
    
    # System Properties
    if ($JVMArgs.SystemProperties.Count -gt 0) {
        Write-ColorOutput "`n⚙️  SYSTEM PROPERTIES:" -Color Green
        foreach ($key in $JVMArgs.SystemProperties.Keys) {
            Write-Host "  $($key.PadRight(30)): $($JVMArgs.SystemProperties[$key])" -ForegroundColor White
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
    
    # Summary
    Write-ColorOutput "`n📊 SUMMARY:" -Color Cyan
    Write-Host "  Total Memory Allocated: " -NoNewline -ForegroundColor Yellow
    if ($JVMArgs.TotalMemory -gt 0) {
        Write-Host "$($JVMArgs.TotalMemory)MB" -ForegroundColor Green
    } else {
        Write-Host "Unknown (Check -Xmx argument)" -ForegroundColor Yellow
    }
    
    Write-Host "  Total JVM Arguments: " -NoNewline -ForegroundColor Yellow
    $totalArgs = $JVMArgs.Memory.Count + $JVMArgs.GarbageCollector.Count + 
                 $JVMArgs.SystemProperties.Count + $JVMArgs.OtherArguments.Count
    Write-Host "$totalArgs detected" -ForegroundColor Green
    
    # Detect common performance issues
    Write-ColorOutput "`n⚠️  PERFORMANCE CHECK:" -Color Yellow
    
    if ($JVMArgs.TotalMemory -gt 8192) {
        Write-Host "  ❌ Too much RAM allocated (>8GB)" -ForegroundColor Red
        Write-Host "    Recommendation: Use 4-8GB for optimal performance" -ForegroundColor Gray
    }
    elseif ($JVMArgs.TotalMemory -lt 2048) {
        Write-Host "  ⚠️  Low RAM allocation (<2GB)" -ForegroundColor Yellow
        Write-Host "    Recommendation: Increase to at least 4GB for modern Minecraft" -ForegroundColor Gray
    }
    else {
        Write-Host "  ✅ RAM allocation is reasonable" -ForegroundColor Green
    }
    
    if (-not ($JVMArgs.GarbageCollector -contains "-XX:+UseG1GC")) {
        Write-Host "  ⚠️  Not using G1GC (recommended for Minecraft)" -ForegroundColor Yellow
    }
    
    return $null
}

# Main execution
Clear-Host
Write-ColorOutput "================================================" -Color Cyan
Write-ColorOutput "   Minecraft JVM Arguments Detector" -Color Cyan
Write-ColorOutput "================================================" -Color Cyan
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
        Write-ColorOutput "Make sure:" -Color Yellow
        Write-Host "  1. Minecraft is running" -ForegroundColor Gray
        Write-Host "  2. Run as Administrator if you have permission issues" -ForegroundColor Gray
        Write-Host "  3. Try: .\Detect-MinecraftJVM.ps1 -MonitorAllJava" -ForegroundColor Gray
        Write-Host "  4. Try: .\Detect-MinecraftJVM.ps1 -Continuous" -ForegroundColor Gray
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
