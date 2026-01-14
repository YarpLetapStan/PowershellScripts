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
                $processes += @{
                    PID = $proc.Id
                    Name = $proc.ProcessName
                    CommandLine = $cmd
                    StartTime = $proc.StartTime
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
        ExecutedCommands = @()
    }
    
    # Extract commands executed via -e, -exec, or similar
    # Look for command execution patterns
    if ($CommandLine -match '-e\s+"([^"]+)"' -or $CommandLine -match '-e\s+([^\s]+)') {
        $args.ExecutedCommands += $matches[1]
    }
    
    if ($CommandLine -match '-exec\s+"([^"]+)"' -or $CommandLine -match '-exec\s+([^\s]+)') {
        $args.ExecutedCommands += $matches[1]
    }
    
    if ($CommandLine -match '-c\s+"([^"]+)"' -or $CommandLine -match '-c\s+([^\s]+)') {
        $args.ExecutedCommands += $matches[1]
    }
    
    # Look for suspicious execution patterns
    $suspiciousPatterns = @(
        'Runtime\.getRuntime\(\)\.exec',
        'ProcessBuilder',
        'powershell',
        'cmd\.exe',
        'bash',
        'sh',
        'wget',
        'curl',
        'certutil',
        'bitsadmin',
        'mshta',
        'rundll32',
        'regsvr32'
    )
    
    foreach ($pattern in $suspiciousPatterns) {
        if ($CommandLine -match $pattern -and -not ($CommandLine -match "powershell.*-Command.*Get-Process")) {
            $args.ExecutedCommands += "Pattern detected: $pattern"
        }
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
    
    return $args
}

function Show-Output {
    param($Process, $Args)
    
    Write-Color "══════════════════════════════════════════════════════════" Cyan
    Write-Color "JAVA PROCESS DETECTED" Cyan
    Write-Color "══════════════════════════════════════════════════════════" Cyan
    Write-Host "PID: $($Process.PID)" -ForegroundColor White
    Write-Host "Process: $($Process.Name)" -ForegroundColor White
    if ($Process.StartTime) {
        Write-Host "Started: $($Process.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Check if this looks like Minecraft
    $isMinecraft = $Process.CommandLine -match "minecraft" -or 
                   $Process.CommandLine -match "\.minecraft" -or 
                   $Process.CommandLine -match "net\.minecraft" -or
                   ($Process.CommandLine -match "\.jar" -and $Process.Name -match "javaw")
    
    if ($isMinecraft) {
        Write-Color "🎮 This appears to be Minecraft" Green
    } else {
        Write-Color "⚠️  This may not be Minecraft" Yellow
    }
    Write-Host ""
    
    # EXECUTED COMMANDS (RED FLAG) - MOST IMPORTANT SECTION!
    if ($Args.ExecutedCommands.Count -gt 0) {
        Write-Color "🚨 EXECUTED COMMANDS DETECTED!" Red
        Write-Color "════════════════════════════════════════" Red
        foreach ($cmd in $Args.ExecutedCommands) {
            Write-Host "  • $cmd" -ForegroundColor Red
        }
        Write-Host ""
        Write-Color "⚠️  WARNING: This process may be executing system commands!" Red
        Write-Host ""
    } else {
        Write-Color "✅ No suspicious commands detected" Green
        Write-Host ""
    }
    
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
    
    # Raw command
    Write-Color "`n📝 FULL COMMAND:" Gray
    Write-Host "  $($Process.CommandLine)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Security assessment
    Write-Color "🔒 SECURITY ASSESSMENT:" Cyan
    $isSuspicious = $Args.ExecutedCommands.Count -gt 0
    
    if ($isSuspicious) {
        Write-Color "  ❌ HIGH RISK - Command execution detected" Red
        Write-Host "  Consider terminating this process!" -ForegroundColor Red
    } else {
        Write-Color "  ✅ LOW RISK - No command execution" Green
    }
    Write-Host ""
}

# Main
Clear-Host
Write-Color "Java Process Analyzer with Command Detection" Cyan
Write-Color "==============================================" Cyan
Write-Color "Detects executed commands and flags them in RED" Yellow
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
            Write-Color "[$(Get-Date -Format 'HH:mm:ss')] No Java processes" Gray
        }
        Start-Sleep -Seconds $Interval
    }
}
else {
    Write-Color "🔍 Scanning for Java processes..." Yellow
    $procs = Get-JavaProcesses
    
    if ($procs.Count -eq 0) {
        Write-Color "❌ No Java processes found" Red
        Write-Host ""
        Write-Color "Note:" Yellow
        Write-Host "  Make sure Java/Minecraft is running" -ForegroundColor Gray
        Write-Host "  Try running as Administrator" -ForegroundColor Gray
    }
    else {
        Write-Color "✅ Found $($procs.Count) Java process(es)" Green
        Write-Host ""
        
        foreach ($proc in $procs) {
            $jvmArgs = Extract-Args -CommandLine $proc.CommandLine
            Show-Output -Process $proc -Args $jvmArgs
        }
    }
}
