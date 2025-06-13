@echo off
echo Setting up TouchPad Pro Mobile Client...
echo.

cd /d "%~dp0"

echo [1/4] Installing Flutter dependencies...
flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo [2/4] Checking Flutter doctor...
flutter doctor
echo.

echo [3/4] Building debug APK for testing...
flutter build apk --debug
if errorlevel 1 (
    echo ERROR: Failed to build debug APK
    pause
    exit /b 1
)

echo.
echo [4/4] Building release APK...
flutter build apk --release
if errorlevel 1 (
    echo ERROR: Failed to build release APK
    pause
    exit /b 1
)

echo.
echo ✓ Setup completed successfully!
echo.
echo Build outputs:
echo   - Debug APK: build\app\outputs\flutter-apk\app-debug.apk
echo   - Release APK: build\app\outputs\flutter-apk\app-release.apk
echo.
echo To run on connected device: flutter run
echo To install APK on device: adb install build\app\outputs\flutter-apk\app-release.apk
echo.
pause
