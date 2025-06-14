@echo off
echo.
echo ==========================================
echo    TouchPad Pro Server - Easy Installer
echo ==========================================
echo.

cd /d "%~dp0"

REM Check if build exists
if not exist "build\windows\x64\runner\Release\touchpad_pro_server.exe" (
    echo ERROR: Application build not found.
    echo Please run: flutter build windows --release
    echo.
    pause
    exit /b 1
)

echo Starting PowerShell installer...
echo.
echo NOTE: If Windows asks about execution policy, choose "Y" to allow.
echo       This is safe - you can review the installer.ps1 file first.
echo.

REM Try to run PowerShell installer with appropriate execution policy
powershell.exe -ExecutionPolicy Bypass -File "installer.ps1"

if errorlevel 1 (
    echo.
    echo Installation may have failed or been cancelled.
    echo.
    echo ALTERNATIVE OPTIONS:
    echo 1. Run the installer manually as administrator:
    echo    Right-click this file and select "Run as administrator"
    echo.
    echo 2. Use the portable version:
    echo    Extract installer_output\TouchPadProServer_Portable.zip
    echo    and run touchpad_pro_server.exe directly
    echo.
    echo 3. Manual PowerShell installation:
    echo    PowerShell -ExecutionPolicy Bypass -File installer.ps1
    echo.
)

pause
