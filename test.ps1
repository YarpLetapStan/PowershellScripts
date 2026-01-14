@echo off
setlocal enabledelayedexpansion

echo ================================================
echo Java Process JVM Arguments Finder
echo ================================================
echo.

REM Check if WMIC is available
where wmic >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: WMIC is not available on this system.
    echo Please use PowerShell version or install WMIC.
    goto :end
)

echo Searching for javaw.exe processes...
echo.

REM Find all javaw.exe processes
set found=0
for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq javaw.exe" /NH 2^>nul ^| find "javaw.exe"') do (
    set found=1
    set pid=%%i
    echo ------------------------------------------------
    echo Process ID: !pid!
    echo ------------------------------------------------
    
    REM Get command line arguments using WMIC
    for /f "tokens=*" %%c in ('wmic process where "ProcessId=!pid!" get CommandLine /format:list 2^>nul ^| findstr "CommandLine="') do (
        set cmdline=%%c
        set cmdline=!cmdline:CommandLine=!
        echo !cmdline!
    )
    echo.
)

if !found! equ 0 (
    echo No javaw.exe processes found.
)

:end
echo.
echo ================================================
pause
