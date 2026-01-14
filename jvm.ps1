# JVM Arguments Display Script
# Displays all JVM arguments from running javaw.exe processes

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Java Process JVM Arguments Display" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Find all javaw.exe processes
$javaProcesses = Get-Process -Name javaw -ErrorAction SilentlyContinue

if ($javaProcesses.Count -eq 0) {
    Write-Host "No javaw.exe processes found." -ForegroundColor Yellow
    Write-Host "Make sure Minecraft/Java application is running." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "Found $($javaProcesses.Count) Java process(es)" -ForegroundColor Green
Write-Host ""

foreach ($process in $javaProcesses) {
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "Process ID: $($process.Id)" -ForegroundColor White
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Get full command line
    $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
    
    if ($commandLine) {
        Write-Host "Full Command Line:" -ForegroundColor Yellow
        Write-Host $commandLine -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "JVM Arguments (parsed):" -ForegroundColor Cyan
        Write-Host ""
        
        # Split command line into arguments
        $args = $commandLine -split '\s+(?=-)' 
        
        foreach ($arg in $args) {
            $arg = $arg.Trim()
            
            # Highlight different types of JVM arguments
            if ($arg -match '^-D') {
                Write-Host "  $arg" -ForegroundColor Red
            }
            elseif ($arg -match '^-X') {
                Write-Host "  $arg" -ForegroundColor Green
            }
            elseif ($arg -match '^-javaagent') {
                Write-Host "  $arg" -ForegroundColor Magenta
            }
            elseif ($arg -match '^--add-opens' -or $arg -match '^--add-exports') {
                Write-Host "  $arg" -ForegroundColor DarkMagenta
            }
            elseif ($arg -match '^-') {
                Write-Host "  $arg" -ForegroundColor White
            }
        }
        
        Write-Host ""
    } else {
        Write-Host "Unable to retrieve command line arguments." -ForegroundColor Red
        Write-Host ""
    }
    
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ""
Write-Host "Color Legend:" -ForegroundColor Yellow
Write-Host "  Red    = -D arguments (system properties)" -ForegroundColor Red
Write-Host "  Green  = -X arguments (JVM flags)" -ForegroundColor Green
Write-Host "  Magenta = -javaagent (agent/mod loading)" -ForegroundColor Magenta
Write-Host "  Purple = --add-opens/exports (module access)" -ForegroundColor DarkMagenta
Write-Host ""

Read-Host "Press Enter to exit"
