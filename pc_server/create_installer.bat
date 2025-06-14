@echo off
echo.
echo ==========================================
echo    TouchPad Pro Server - Build Installer
echo ==========================================
echo.

cd /d "%~dp0"

echo [1/4] Preparing distribution...
if not exist "build\windows\x64\runner\Release\touchpad_pro_server.exe" (
    echo ERROR: Build not found. Running flutter build first...
    flutter build windows --release
    if errorlevel 1 (
        echo ERROR: Failed to build application
        pause
        exit /b 1
    )
)

echo [2/4] Creating distribution folder...
rmdir /s /q dist 2>nul
mkdir dist
xcopy /E /Y "build\windows\x64\runner\Release\*" "dist\"
if exist "assets" xcopy /E /Y "assets" "dist\assets\"
if exist "app_icon.png" copy "app_icon.png" "dist\"
if exist "README.md" copy "README.md" "dist\"

echo [3/4] Creating installer package...
rmdir /s /q installer_output 2>nul
mkdir installer_output

REM Try different methods to create installer
set "INSTALLER_CREATED=false"

REM Method 1: Check for Inno Setup
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    echo Using Inno Setup to create installer...
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "touchpad_pro_installer.iss"
    if not errorlevel 1 (
        echo SUCCESS: Inno Setup installer created!
        set "INSTALLER_CREATED=true"
        goto :success
    )
)

if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    echo Using Inno Setup to create installer...
    "%ProgramFiles%\Inno Setup 6\ISCC.exe" "touchpad_pro_installer.iss"
    if not errorlevel 1 (
        echo SUCCESS: Inno Setup installer created!
        set "INSTALLER_CREATED=true"
        goto :success
    )
)

REM Method 2: Try WinRAR SFX
if exist "%ProgramFiles%\WinRAR\WinRAR.exe" (
    echo Using WinRAR to create self-extracting installer...
    echo ;The comment below contains SFX script commands > dist\config.txt
    echo Path=%%ProgramFiles%%\TouchPad Pro Server >> dist\config.txt
    echo Setup=touchpad_pro_server.exe >> dist\config.txt
    echo Silent=0 >> dist\config.txt
    echo Overwrite=1 >> dist\config.txt
    echo Title=TouchPad Pro Server v1.0.0 >> dist\config.txt
    echo Text >> dist\config.txt
    echo { >> dist\config.txt
    echo TouchPad Pro Server Installation >> dist\config.txt
    echo. >> dist\config.txt
    echo This will install TouchPad Pro Server to your computer. >> dist\config.txt
    echo The server allows you to control your PC mouse using your mobile device. >> dist\config.txt
    echo. >> dist\config.txt
    echo Click Install to continue. >> dist\config.txt
    echo } >> dist\config.txt
    
    "%ProgramFiles%\WinRAR\WinRAR.exe" a -sfx -z"dist\config.txt" "installer_output\TouchPadProServer_Setup.exe" "dist\*"
    if not errorlevel 1 (
        del "dist\config.txt"
        echo SUCCESS: WinRAR self-extracting installer created!
        set "INSTALLER_CREATED=true"
        goto :success
    )
)

if exist "%ProgramFiles(x86)%\WinRAR\WinRAR.exe" (
    echo Using WinRAR to create self-extracting installer...
    echo ;The comment below contains SFX script commands > dist\config.txt
    echo Path=%%ProgramFiles%%\TouchPad Pro Server >> dist\config.txt
    echo Setup=touchpad_pro_server.exe >> dist\config.txt
    echo Silent=0 >> dist\config.txt
    echo Overwrite=1 >> dist\config.txt
    echo Title=TouchPad Pro Server v1.0.0 >> dist\config.txt
    echo Text >> dist\config.txt
    echo { >> dist\config.txt
    echo TouchPad Pro Server Installation >> dist\config.txt
    echo. >> dist\config.txt
    echo This will install TouchPad Pro Server to your computer. >> dist\config.txt
    echo The server allows you to control your PC mouse using your mobile device. >> dist\config.txt
    echo. >> dist\config.txt
    echo Click Install to continue. >> dist\config.txt
    echo } >> dist\config.txt
    
    "%ProgramFiles(x86)%\WinRAR\WinRAR.exe" a -sfx -z"dist\config.txt" "installer_output\TouchPadProServer_Setup.exe" "dist\*"
    if not errorlevel 1 (
        del "dist\config.txt"
        echo SUCCESS: WinRAR self-extracting installer created!
        set "INSTALLER_CREATED=true"
        goto :success
    )
)

REM Method 3: Create ZIP package as fallback
echo Creating portable ZIP package...
powershell -Command "Compress-Archive -Path 'dist\*' -DestinationPath 'installer_output\TouchPadProServer_Portable.zip' -Force"
if not errorlevel 1 (
    echo SUCCESS: Portable ZIP package created!
    set "INSTALLER_CREATED=true"
    
    REM Create installation instructions
    echo TouchPad Pro Server - Portable Installation > installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo ========================================== >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 1. Extract all files from TouchPadProServer_Portable.zip >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    to a folder of your choice (e.g. C:\Program Files\TouchPad Pro Server\) >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 2. Run touchpad_pro_server.exe to start the server >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 3. Optional: Create a desktop shortcut >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    - Right-click on touchpad_pro_server.exe >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    - Select Create shortcut >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    - Move the shortcut to your desktop >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo 4. Optional: Start with Windows >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    - Press Win+R, type shell:startup, press Enter >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    - Copy the touchpad_pro_server.exe shortcut to this folder >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo    - Add --minimized to the shortcut target for silent startup >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo. >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo Features: >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - Professional wireless mouse/touchpad control >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - System tray integration >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - Auto-discovery of mobile devices >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - Secure device connection management >> installer_output\INSTALLATION_INSTRUCTIONS.txt
    echo - Beautiful modern UI >> installer_output\INSTALLATION_INSTRUCTIONS.txt
)

:success
echo.
echo [4/4] Build completed!
echo.
if "%INSTALLER_CREATED%"=="true" (
    echo SUCCESS: TouchPad Pro Server installer/package created!
    echo.
    echo Distribution files: dist\
    echo Installer/Package:  installer_output\
    echo.
    echo Files created:
    dir /b installer_output\
    echo.
    echo You can now distribute these files to users.
) else (
    echo WARNING: Could not create installer package.
    echo The distribution files are available in the 'dist' folder.
    echo You can manually ZIP these files for distribution.
)
echo.
pause
