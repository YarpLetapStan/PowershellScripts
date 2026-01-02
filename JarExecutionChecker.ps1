# System Informer JAR Execution Checker
# Automates memory string search for "-jar" in msmpeng.exe

Write-Host "=== JAR Execution Checker ===" -ForegroundColor Cyan
Write-Host ""

# Check if System Informer is installed
$siPaths = @(
    "C:\Program Files\SystemInformer\SystemInformer.exe",
    "C:\Program Files (x86)\SystemInformer\SystemInformer.exe",
    "$env:ProgramFiles\SystemInformer\SystemInformer.exe"
)

$siPath = $null
foreach ($path in $siPaths) {
    if (Test-Path $path) {
        $siPath = $path
        break
    }
}

if (-not $siPath) {
    Write-Host "ERROR: System Informer not found!" -ForegroundColor Red
    Write-Host "Please install System Informer first." -ForegroundColor Yellow
    pause
    Start-Process cmd.exe
    exit
}

# Find msmpeng.exe process
Write-Host "Looking for msmpeng.exe process..." -ForegroundColor Yellow
$msmpeng = Get-Process -Name "MsMpEng" -ErrorAction SilentlyContinue

if (-not $msmpeng) {
    Write-Host "ERROR: msmpeng.exe process not found!" -ForegroundColor Red
    Write-Host "Windows Defender may not be running." -ForegroundColor Yellow
    pause
    Start-Process cmd.exe
    exit
}

$pid = $msmpeng.Id
Write-Host "Found msmpeng.exe (PID: $pid)" -ForegroundColor Green
Write-Host ""

# Launch System Informer with specific process selected
Write-Host "Launching System Informer..." -ForegroundColor Yellow
Start-Process -FilePath $siPath -ArgumentList "-selectpid $pid"

Start-Sleep -Seconds 2

# Use UI automation to navigate
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient

Write-Host "Attempting to automate System Informer..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Note: If automation fails, manually:" -ForegroundColor Cyan
Write-Host "  1. Right-click MsMpEng.exe > Properties" -ForegroundColor White
Write-Host "  2. Go to Memory tab > Click 'Options' > Click 'Strings'" -ForegroundColor White
Write-Host "  3. Set minimum length: 5" -ForegroundColor White
Write-Host "  4. Check: Image, Mapped, Private, Extended Unicode, Detect Unicode" -ForegroundColor White
Write-Host "  5. Click OK, then search for: -jar" -ForegroundColor White
Write-Host ""

# Send keystrokes to automate (best effort)
Start-Sleep -Seconds 1
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")  # Open properties
Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait("^+m")      # Memory tab shortcut (if available)

Write-Host "Searching for JAR executions in memory..." -ForegroundColor Green
Write-Host ""
Write-Host "Results will appear in System Informer." -ForegroundColor Yellow
Write-Host "Look for lines containing '-jar' to see executed JAR files." -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to close this window and open a fresh CMD..." -ForegroundColor Cyan
pause > $null

# Open fresh CMD and close this one
Start-Process cmd.exe
exit
