@echo off
echo.
echo ==========================================
echo    TouchPad Pro Server - Package Creator
echo ==========================================
echo.

cd /d "%~dp0"

echo [1/4] Checking build...
if not exist "build\windows\x64\runner\Release\touchpad_pro_server.exe" (
    echo Build not found. Creating release build...
    flutter build windows --release
    if errorlevel 1 (
        echo ERROR: Failed to build application
        pause
        exit /b 1
    )
)

echo [2/4] Creating package directory...
rmdir /s /q package 2>nul
mkdir package
mkdir package\installers
mkdir package\portable

echo [3/4] Copying files...

REM Copy portable version
xcopy /E /Y "build\windows\x64\runner\Release\*" "package\portable\"

REM Copy installer scripts
copy "installer.ps1" "package\installers\"
copy "easy_install.bat" "package\installers\"
copy "build\windows\x64\runner\Release\*" "package\installers\build\windows\x64\runner\Release\" /E /Y
mkdir "package\installers\build\windows\x64\runner\Release" 2>nul

REM Create README for the package
echo TouchPad Pro Server v1.0.0 > package\README.txt
echo ================================= >> package\README.txt
echo. >> package\README.txt
echo This package contains multiple installation options: >> package\README.txt
echo. >> package\README.txt
echo OPTION 1 - Easy Installation: >> package\README.txt
echo   1. Go to the 'installers' folder >> package\README.txt
echo   2. Run 'easy_install.bat' >> package\README.txt
echo   3. Follow the prompts >> package\README.txt
echo. >> package\README.txt
echo OPTION 2 - Portable Version: >> package\README.txt
echo   1. Go to the 'portable' folder >> package\README.txt
echo   2. Run 'touchpad_pro_server.exe' directly >> package\README.txt
echo   3. No installation required! >> package\README.txt
echo. >> package\README.txt
echo TROUBLESHOOTING: >> package\README.txt
echo - If installer fails: Use portable version >> package\README.txt
echo - If Windows blocks: Add to antivirus exclusions >> package\README.txt
echo - If permission denied: Run as administrator >> package\README.txt
echo - If SmartScreen warns: Click "More info" then "Run anyway" >> package\README.txt
echo. >> package\README.txt
echo FEATURES: >> package\README.txt
echo - Control your PC mouse/touchpad wirelessly from mobile >> package\README.txt
echo - Professional UI with system tray integration >> package\README.txt
echo - Auto-discovery of mobile devices on same network >> package\README.txt
echo - Secure connection management >> package\README.txt
echo - Supports gestures, scrolling, and precision control >> package\README.txt
echo. >> package\README.txt
echo MOBILE APP: >> package\README.txt
echo - Install the APK on your Android device >> package\README.txt
echo - Connect to the same WiFi network as your PC >> package\README.txt
echo - The app will automatically find your PC >> package\README.txt

echo [4/4] Creating final package...
powershell -Command "Compress-Archive -Path 'package\*' -DestinationPath 'TouchPadProServer_Complete_Package.zip' -Force"

if not errorlevel 1 (
    echo.
    echo SUCCESS: Complete package created!
    echo.
    echo File: TouchPadProServer_Complete_Package.zip
    echo Size: 
    dir TouchPadProServer_Complete_Package.zip | find ".zip"
    echo.
    echo This package contains:
    echo - Easy installer (recommended)
    echo - Portable version (no installation)
    echo - Complete documentation
    echo.
    echo You can now distribute TouchPadProServer_Complete_Package.zip
    echo Recipients can choose their preferred installation method.
) else (
    echo ERROR: Failed to create package
)

echo.
pause
