@echo off
echo.
echo ==========================================
echo    TouchPad Pro Server - Multiple Installers
echo ==========================================
echo.

cd /d "%~dp0"

echo [1/3] Preparing build...
if not exist "build\windows\x64\runner\Release\touchpad_pro_server.exe" (
    echo ERROR: Build not found. Running flutter build first...
    flutter build windows --release
    if errorlevel 1 (
        echo ERROR: Failed to build application
        pause
        exit /b 1
    )
)

echo [2/3] Creating installer directory...
rmdir /s /q installer_output 2>nul
mkdir installer_output

echo [3/3] Creating installers...

REM Try simple installer first (user directory, no admin rights)
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    echo Creating simple installer user directory, no admin required...
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "simple_installer.iss"
    if not errorlevel 1 (
        echo SUCCESS: Simple installer created!
    )
)

if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    echo Creating simple installer user directory, no admin required...
    "%ProgramFiles%\Inno Setup 6\ISCC.exe" "simple_installer.iss"
    if not errorlevel 1 (
        echo SUCCESS: Simple installer created!
    )
)

REM Try full installer (Program Files, admin rights)
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    echo Creating full installer Program Files, admin required...
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "touchpad_pro_installer.iss"
    if not errorlevel 1 (
        echo SUCCESS: Full installer created!
    )
)

if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    echo Creating full installer Program Files, admin required...
    "%ProgramFiles%\Inno Setup 6\ISCC.exe" "touchpad_pro_installer.iss"
    if not errorlevel 1 (
        echo SUCCESS: Full installer created!
    )
)

REM Create portable version as fallback
echo Creating portable ZIP package...
if not exist "dist" mkdir dist
xcopy /E /Y "build\windows\x64\runner\Release\*" "dist\"

powershell -Command "Compress-Archive -Path 'dist\*' -DestinationPath 'installer_output\TouchPadProServer_Portable.zip' -Force"
if not errorlevel 1 (
    echo SUCCESS: Portable ZIP package created!
    
    REM Create installation instructions
    echo TouchPad Pro Server - Portable Installation > installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo ========================================== >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo If the installer EXE files don't work, use this portable version: >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 1. Extract all files from TouchPadProServer_Portable.zip >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    to a folder of your choice (e.g. C:\TouchPadPro\) >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 2. Run touchpad_pro_server.exe to start the server >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 3. For desktop shortcut: Right-click touchpad_pro_server.exe and Create shortcut >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 4. For Windows startup: Press Win+R, type shell:startup, press Enter >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    Copy the shortcut to this folder and add --minimized to target >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo TROUBLESHOOTING: >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - If antivirus blocks the app, add it to exclusions >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - If Windows SmartScreen warns, click "More info" then "Run anyway" >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - Run as administrator if you have permission issues >> installer_output\INSTALLATION_INSTRUCTIONS.txt
)

echo.
echo Build completed!
echo.
echo Available installers/packages:
dir /b installer_output\
echo.
echo RECOMMENDATION:
echo - Try TouchPadProServer_Simple_Setup.exe first (no admin required)
echo - If that fails, try TouchPadProServer_Setup.exe (requires admin)
echo - If both fail, use TouchPadProServer_Portable.zip (manual installation)
echo.
pause
