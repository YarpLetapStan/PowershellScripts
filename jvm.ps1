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
        SuspiciousArgs = @()  # For flagged arguments
    }
    
    # Extract ALL JVM arguments with their values
    # Pattern: -Something or -Dkey=value
    $argMatches = [regex]::Matches($CommandLine, '(-\S+)(?:\s+([^\s-][^\s]*))?')
    
    foreach ($match in $argMatches) {
        $argName = $match.Groups[1].Value
        $argValue = $match.Groups[2].Value
        
        # Skip the .jar file (main class)
        if ($argName -match '\.jar$') { continue }
        
        # CATEGORIZE AND FLAG SUSPICIOUS ARGUMENTS
        
        # 1. MEMORY ARGUMENTS (-Xmx, -Xms, etc.)
        if ($argName -match '^-Xmx') {
            $args.Memory["Xmx"] = $argValue
        }
        elseif ($argName -match '^-Xms') {
            $args.Memory["Xms"] = $argValue
        }
        elseif ($argName -match '^-Xmn') {
            $args.Memory["Xmn"] = $argValue
        }
        elseif ($argName -match '^-Xss') {
            $args.Memory["Xss"] = $argValue
        }
        
        # 2. SYSTEM PROPERTIES (-D arguments) - FLAG SUSPICIOUS ONES
        elseif ($argName -match '^-D') {
            # Extract key=value from -D
            if ($argName -match '^-D([^=]+)=(.*)') {
                $key = $matches[1]
                $value = $matches[2]
                $args.Properties[$key] = $value
                
                # FLAG suspicious -D arguments
                if ($value -match '\.so$' -or $value -match '\.dll$' -or $value -match '\.exe$') {
                    $args.SuspiciousArgs += @{
                        Argument = $argName
                        Value = $value
                        Reason = "Loads native library: $value"
                    }
                }
                elseif ($key -match 'java\.library\.path' -and $value -match '\.\./') {
                    $args.SuspiciousArgs += @{
                        Argument = $argName
                        Value = $value
                        Reason = "Uses parent directory (../) in library path"
                    }
                }
                elseif ($value -match 'http://' -or $value -match 'https://') {
                    $args.SuspiciousArgs += @{
                        Argument = $argName
                        Value = $value
                        Reason = "Contains URL (potential remote loading)"
                    }
                }
            }
        }
        
        # 3. SUSPICIOUS ARGUMENTS TO FLAG
        elseif ($argName -match '^-Xbootclasspath') {
            $args.SuspiciousArgs += @{
                Argument = $argName
                Value = $argValue
                Reason = "Modifies boot classpath (can load malicious classes)"
            }
        }
        elseif ($argName -match '^-javaagent') {
            $args.SuspiciousArgs += @{
                Argument = $argName
                Value = $argValue
                Reason = "Java agent instrumentation (can modify runtime)"
            }
        }
        elseif ($argName -match '^-Xrunjdwp' -or $argName -match '^-agentlib:jdwp') {
            $args.SuspiciousArgs += @{
                Argument = $argName
                Value = $argValue
                Reason = "Java Debug Wire Protocol (debugger attachment)"
            }
        }
        
        # 4. GC ARGUMENTS
        elseif ($argName -match '^-XX:\+Use') {
            $args.GC += $argName
        }
        
        # 5. OTHER ARGUMENTS
        elseif ($argName -match '^-') {
            $args.Other += $argName
            if ($argValue) {
                $args.Other += $argValue
            }
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
    
    # SUSPICIOUS JVM ARGUMENTS (RED FLAGS) - MOST IMPORTANT!
    if ($Args.SuspiciousArgs.Count -gt 0) {
        Write-Color "🚨 SUSPICIOUS JVM ARGUMENTS DETECTED!" Red
        Write-Color "══════════════════════════════════════════════════════════" Red
        
        foreach ($suspArg in $Args.SuspiciousArgs) {
            Write-Host "  🔴 ARGUMENT: " -ForegroundColor Red -NoNewline
            Write-Host "$($suspArg.Argument)" -ForegroundColor White
            Write-Host "     Value: " -ForegroundColor Yellow -NoNewline
            Write-Host "$($suspArg.Value)" -ForegroundColor White
            Write-Host "     Reason: " -ForegroundColor Red -NoNewline
            Write-Host "$($suspArg.Reason)" -ForegroundColor White
            Write-Host ""
        }
        Write-Host ""
    }
    
    # Memory
    if ($Args.Memory.Count -gt 0) {
        Write-Color "💾 MEMORY SETTINGS:" Green
        foreach ($key in $Args.Memory.Keys) {
            Write-Host "  $($key): $($Args.Memory[$key])" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # System Properties (-D) - Show all
    if ($Args.Properties.Count -gt 0) {
        Write-Color "⚙️  SYSTEM PROPERTIES (-D):" Green
        foreach ($key in $Args.Properties.Keys) {
            $isSuspicious = $Args.SuspiciousArgs | Where-Object { $_.Argument -match $key }
            if ($isSuspicious) {
                Write-Host "  ⚠️  $($key): " -ForegroundColor Yellow -NoNewline
            } else {
                Write-Host "  $($key): " -ForegroundColor Yellow -NoNewline
            }
            Write-Host "$($Args.Properties[$key])" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # GC
    if ($Args.GC.Count -gt 0) {
        Write-Color "🗑️  GARBAGE COLLECTOR:" Green
        foreach ($gc in $Args.GC) {
            Write-Host "  • $gc" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Other arguments
    if ($Args.Other.Count -gt 0) {
        Write-Color "🔧 OTHER ARGUMENTS:" Green
        foreach ($arg in $Args.Other) {
            Write-Host "  • $arg" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Security assessment based on suspicious args
    Write-Color "🔒 SECURITY ASSESSMENT:" Cyan
    
    if ($Args.SuspiciousArgs.Count -gt 0) {
        Write-Color "  ❌ HIGH RISK - Suspicious JVM arguments detected" Red
        Write-Host "  Suspicious arguments found: $($Args.SuspiciousArgs.Count)" -ForegroundColor Red
        Write-Host "  Review the red flagged arguments above!" -ForegroundColor Red
    } else {
        Write-Color "  ✅ LOW RISK - No suspicious JVM arguments" Green
    }
    
    # Show full command for reference
    Write-Color "`n📝 FULL COMMAND:" Gray
    Write-Host "  $($Process.CommandLine)" -ForegroundColor DarkGray
    Write-Host ""
}

# Main
Clear-Host
Write-Color "Java JVM Argument Analyzer" Cyan
Write-Color "====================================" Cyan
Write-Color "Flags suspicious JVM arguments in RED" Yellow
Write-Host "Detects: -D, -Xbootclasspath, library paths, etc." -ForegroundColor Gray
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
