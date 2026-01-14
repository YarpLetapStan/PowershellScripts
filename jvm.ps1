# Fabric AddMods Detector
# Detects if -Dfabric.addMods was used and displays the full command

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Fabric AddMods Detector" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Find all javaw.exe processes
$javaProcesses = Get-Process -Name javaw -ErrorAction SilentlyContinue

if ($javaProcesses.Count -eq 0) {
    Write-Host "No javaw.exe processes found." -ForegroundColor Yellow
    Write-Host "Make sure Minecraft is running." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "Scanning $($javaProcesses.Count) Java process(es)..." -ForegroundColor White
Write-Host ""

$foundFabricAddMods = $false

foreach ($process in $javaProcesses) {
    # Get full command line
    $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
    
    if ($commandLine -match '-Dfabric\.addMods') {
        $foundFabricAddMods = $true
        
        Write-Host "================================================" -ForegroundColor Red
        Write-Host "*** FABRIC ADDMODS DETECTED ***" -ForegroundColor Red
        Write-Host "================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Process ID: $($process.Id)" -ForegroundColor Yellow
        Write-Host ""
        
        # Extract the fabric.addMods argument
        if ($commandLine -match '-Dfabric\.addMods=([^\s]+)') {
            $fabricAddModsValue = $matches[1]
            Write-Host "Fabric AddMods Path:" -ForegroundColor Cyan
            Write-Host $fabricAddModsValue -ForegroundColor Red
            Write-Host ""
        }
        
        Write-Host "Full Command Line:" -ForegroundColor Cyan
        Write-Host $commandLine -ForegroundColor Gray
        Write-Host ""
        Write-Host "================================================" -ForegroundColor Red
        Write-Host ""
    }
}

if (-not $foundFabricAddMods) {
    Write-Host "[CLEAN] No -Dfabric.addMods detected in any Java process" -ForegroundColor Green
}

Write-Host ""
Read-Host "Press Enter to exit"
