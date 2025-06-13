@echo off
echo Building TouchPad Pro Server for Windows...
echo.

cd /d "%~dp0"

echo [1/3] Installing dependencies...
flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo [2/3] Building Windows release...
flutter build windows --release
if errorlevel 1 (
    echo ERROR: Failed to build Windows application
    pause
    exit /b 1
)

echo.
echo [3/3] Copying assets and creating distribution folder...
mkdir dist 2>nul
xcopy /E /Y build\windows\x64\runner\Release\* dist\
if errorlevel 1 (
    echo ERROR: Failed to copy build files
    pause
    exit /b 1
)

echo.
echo ✓ Build completed successfully!
echo.
echo Distribution files are in the 'dist' folder:
echo   - TouchPad Pro Server.exe (main application)
echo   - data\ (required application data)
echo   - All required DLLs and dependencies
echo.
echo You can now distribute the entire 'dist' folder to users.
echo.
pause
