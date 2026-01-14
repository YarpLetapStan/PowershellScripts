param(
    [switch]$Continuous = $false,
    [int]$Interval = 5
)

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Get-JavaProcesses {
    $processes = @()
    $javaProcs = Get-Process java*, javaw* -ErrorAction SilentlyContinue
    
    foreach ($proc in $javaProcs) {
        try {
            $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
            if ($wmi -and $wmi.CommandLine) {
                $cmd = $wmi.CommandLine
                $lowerCmd = $cmd.ToLower()
                
                $isMinecraft = $false
                if ($lowerCmd -match "minecraft" -or 
                    $lowerCmd -match "\.minecraft" -or 
                    $lowerCmd -match "net\.minecraft" -or
                    $lowerCmd -match "\.jar") {
                    $isMinecraft = $true
                }
                
                if ($isMinecraft) {
                    $processes += @{
                        PID = $proc.Id
                        Name = $proc.ProcessName
                        CommandLine = $cmd
                        StartTime = $proc.StartTime
                    }
                }
            }
        } catch { }
    }
    return $processes
}

function Extract-Args {
    param([string]$CommandLine)
    
    $args = @{
        Memory = @{}
        Properties = @{}
        GC = @()
        Other = @()
    }
    
    # Memory
    if ($CommandLine -match '-Xmx(\d+[MG])') {
        $args.Memory["Xmx"] = $matches[1]
    }
    if ($CommandLine -match '-Xms(\d+[MG])') {
        $args.Memory["Xms"] = $matches[1]
    }
    
    # System Properties (-D)
    $propMatches = [regex]::Matches($CommandLine, '-D([^=\s]+)=([^\s]+)')
    foreach ($match in $propMatches) {
        $args.Properties[$match.Groups[1].Value] = $match.Groups[2].Value
    }
    
    # GC Args
    $gcList = @("UseG1GC", "UseConcMarkSweepGC", "UseSerialGC", "UseParallelGC")
    foreach ($gc in $gcList) {
        if ($CommandLine -match "-XX:\+$gc") {
            $args.GC += "-XX:+$gc"
        }
    }
    
    # Other args
    if ($CommandLine -match '(-(?:X|XX)[^\s]+)') {
        $allMatches = [regex]::Matches($CommandLine, '(-(?:X|XX)[^\s]+)')
        foreach ($match in $allMatches) {
            $arg = $match.Value
            if (-not ($arg -match '^-X[mM]') -and 
                -not ($arg -match '^-XX:\+Use.*GC') -and
                -not ($arg -match '^-D')) {
                $args.Other += $arg
            }
        }
    }
    
    return $args
}

function Show-Output {
    param($Process, $Args)
    
    Write-Color "════════════════════════════════════════" Cyan
    Write-Color "MINECRAFT JVM DETECTED" Cyan
    Write-Color "════════════════════════════════════════" Cyan
    Write-Host "PID: $($Process.PID)" -ForegroundColor White
    Write-Host "Process: $($Process.Name)" -ForegroundColor White
    if ($Process.StartTime) {
        Write-Host "Started: $($Process.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Memory
    if ($Args.Memory.Count -gt 0) {
        Write-Color "💾 MEMORY:" Green
        if ($Args.Memory["Xmx"]) {
            Write-Host "  Max: $($Args.Memory['Xmx'])" -ForegroundColor White
        }
        if ($Args.Memory["Xms"]) {
            Write-Host "  Min: $($Args.Memory['Xms'])" -ForegroundColor White
        }
    }
    
    # Properties (-D)
    if ($Args.Properties.Count -gt 0) {
        Write-Color "`n⚙️  PROPERTIES (-D):" Green
        foreach ($key in $Args.Properties.Keys) {
            Write-Host "  $($key):" -ForegroundColor Yellow -NoNewline
            Write-Host " $($Args.Properties[$key])" -ForegroundColor White
        }
    }
    
    # GC
    if ($Args.GC.Count -gt 0) {
        Write-Color "`n🗑️  GARBAGE COLLECTOR:" Green
        foreach ($gc in $Args.GC) {
            Write-Host "  • $gc" -ForegroundColor White
        }
    }
    
    # Other
    if ($Args.Other.Count -gt 0) {
        Write-Color "`n🔧 OTHER ARGS:" Green
        foreach ($arg in $Args.Other) {
            Write-Host "  • $arg" -ForegroundColor White
        }
    }
    
    # Raw command (short)
    Write-Color "`n📝 COMMAND:" Gray
    $shortCmd = $Process.CommandLine
    if ($shortCmd.Length -gt 150) {
        $shortCmd = $shortCmd.Substring(0, 150) + "..."
    }
    Write-Host "  $shortCmd" -ForegroundColor DarkGray
    Write-Host ""
}

# Main
Clear-Host
Write-Color "Minecraft JVM Detector" Cyan
Write-Color "========================" Cyan
Write-Host ""

if ($Continuous) {
    Write-Color "🔍 Monitoring (${Interval}s intervals)" Yellow
    Write-Color "Press Ctrl+C to stop" Gray
    Write-Host ""
    
    while ($true) {
        $procs = Get-JavaProcesses
        if ($procs.Count -gt 0) {
            foreach ($proc in $procs) {
                $jvmArgs = Extract-Args -CommandLine $proc.CommandLine
                Show-Output -Process $proc -Args $jvmArgs
            }
        } else {
            Write-Color "[$(Get-Date -Format 'HH:mm:ss')] No processes" Gray
        }
        Start-Sleep -Seconds $Interval
    }
}
else {
    Write-Color "🔍 Scanning..." Yellow
    $procs = Get-JavaProcesses
    
    if ($procs.Count -eq 0) {
        Write-Color "❌ No Minecraft Java processes found" Red
        Write-Host ""
        Write-Color "Try:" Yellow
        Write-Host "  Run Minecraft first" -ForegroundColor Gray
        Write-Host "  Run as Administrator" -ForegroundColor Gray
        Write-Host "  Use -Continuous flag to monitor" -ForegroundColor Gray
    }
    else {
        Write-Color "✅ Found $($procs.Count) process(es)" Green
        Write-Host ""
        
        foreach ($proc in $procs) {
            $jvmArgs = Extract-Args -CommandLine $proc.CommandLine
            Show-Output -Process $proc -Args $jvmArgs
        }
    }
}
