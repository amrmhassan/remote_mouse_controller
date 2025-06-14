#!/usr/bin/env pwsh
# TouchPad Pro Server - Build Installer Script
# This script creates a single installable EXE using multiple methods

param(
    [string]$Method = "auto"  # auto, portable, winrar, 7zip
)

Write-Host "🚀 TouchPad Pro Server - Build Installer" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Set locations
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir = "$ProjectRoot\build\windows\x64\runner\Release"
$DistDir = "$ProjectRoot\dist"
$InstallerDir = "$ProjectRoot\installer_output"

# Create directories
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallerDir | Out-Null

Write-Host "📂 Preparing distribution files..." -ForegroundColor Yellow

# Copy all required files to dist directory
if (Test-Path $BuildDir) {
    Copy-Item "$BuildDir\*" -Destination $DistDir -Recurse -Force
    Write-Host "✓ Copied build files" -ForegroundColor Green
} else {
    Write-Host "❌ Build directory not found. Please run 'flutter build windows --release' first." -ForegroundColor Red
    exit 1
}

# Copy assets
if (Test-Path "$ProjectRoot\assets") {
    Copy-Item "$ProjectRoot\assets" -Destination $DistDir -Recurse -Force
    Write-Host "✓ Copied assets" -ForegroundColor Green
}

# Copy icon
if (Test-Path "$ProjectRoot\app_icon.png") {
    Copy-Item "$ProjectRoot\app_icon.png" -Destination $DistDir -Force
    Write-Host "✓ Copied icon" -ForegroundColor Green
}

# Copy README
if (Test-Path "$ProjectRoot\README.md") {
    Copy-Item "$ProjectRoot\README.md" -Destination $DistDir -Force
    Write-Host "✓ Copied documentation" -ForegroundColor Green
}

Write-Host ""

# Method 1: Try Inno Setup
if ($Method -eq "auto" -or $Method -eq "inno") {
    Write-Host "🔧 Attempting to create installer with Inno Setup..." -ForegroundColor Yellow
    
    $InnoCompiler = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($InnoCompiler) {
        try {
            & $InnoCompiler "$ProjectRoot\touchpad_pro_installer.iss"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Inno Setup installer created successfully!" -ForegroundColor Green
                Write-Host "📦 Installer location: $InstallerDir\TouchPadProServer_Setup.exe" -ForegroundColor Cyan
                exit 0
            }
        } catch {
            Write-Host "⚠️  Inno Setup compilation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  Inno Setup not found. Trying alternative methods..." -ForegroundColor Yellow
    }
}

# Method 2: Self-extracting archive with WinRAR
if ($Method -eq "auto" -or $Method -eq "winrar") {
    Write-Host "🔧 Attempting to create self-extracting archive with WinRAR..." -ForegroundColor Yellow
    
    $WinRar = @(
        "${env:ProgramFiles}\WinRAR\WinRAR.exe",
        "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($WinRar) {
        try {            $SfxConfig = @"
;The comment below contains SFX script commands
Path=%ProgramFiles%\TouchPad Pro Server
Setup=touchpad_pro_server.exe
Silent=0
Overwrite=1
Title=TouchPad Pro Server v1.0.0
Text
{
TouchPad Pro Server Installation

This will install TouchPad Pro Server to your computer.
The server allows you to control your PC mouse using your mobile device.

Click Install to continue.
}
"@
            $SfxConfig | Out-File -FilePath "$DistDir\config.txt" -Encoding ASCII
            
            & $WinRar "a" "-sfx" "-z$DistDir\config.txt" "$InstallerDir\TouchPadProServer_Setup.exe" "$DistDir\*"
            
            if ($LASTEXITCODE -eq 0) {
                Remove-Item "$DistDir\config.txt" -Force
                Write-Host "✅ WinRAR self-extracting installer created successfully!" -ForegroundColor Green
                Write-Host "📦 Installer location: $InstallerDir\TouchPadProServer_Setup.exe" -ForegroundColor Cyan
                exit 0
            }
        } catch {
            Write-Host "⚠️  WinRAR creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  WinRAR not found. Trying 7-Zip..." -ForegroundColor Yellow
    }
}

# Method 3: Self-extracting archive with 7-Zip
if ($Method -eq "auto" -or $Method -eq "7zip") {
    Write-Host "🔧 Attempting to create self-extracting archive with 7-Zip..." -ForegroundColor Yellow
    
    $SevenZip = @(
        "${env:ProgramFiles}\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($SevenZip) {
        try {
            # Create 7z archive first
            & $SevenZip "a" "-t7z" "$InstallerDir\TouchPadProServer.7z" "$DistDir\*"
              # Create config for SFX
            $SfxConfig = @"
;!@Install@!UTF-8!
Title=TouchPad Pro Server v1.0.0
BeginPrompt=Do you want to install TouchPad Pro Server?
RunProgram=touchpad_pro_server.exe
Directory=%ProgramFiles%\TouchPad Pro Server
;!@InstallEnd@!
"@
            $SfxConfig | Out-File -FilePath "$InstallerDir\config.txt" -Encoding UTF8
            
            # Get 7z SFX module
            $SfxModule = "${env:ProgramFiles}\7-Zip\7zS.sfx"
            if (-not (Test-Path $SfxModule)) {
                $SfxModule = "${env:ProgramFiles(x86)}\7-Zip\7zS.sfx"
            }
            
            if (Test-Path $SfxModule) {
                # Combine SFX module + config + archive
                $TempFiles = @($SfxModule, "$InstallerDir\config.txt", "$InstallerDir\TouchPadProServer.7z")
                $Output = "$InstallerDir\TouchPadProServer_Setup.exe"
                
                $OutputFile = [System.IO.File]::Create($Output)
                foreach ($file in $TempFiles) {
                    $InputFile = [System.IO.File]::OpenRead($file)
                    $InputFile.CopyTo($OutputFile)
                    $InputFile.Close()
                }
                $OutputFile.Close()
                
                # Cleanup
                Remove-Item "$InstallerDir\config.txt" -Force
                Remove-Item "$InstallerDir\TouchPadProServer.7z" -Force
                
                Write-Host "✅ 7-Zip self-extracting installer created successfully!" -ForegroundColor Green
                Write-Host "📦 Installer location: $InstallerDir\TouchPadProServer_Setup.exe" -ForegroundColor Cyan
                exit 0
            }
        } catch {
            Write-Host "⚠️  7-Zip creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  7-Zip not found. Creating portable package..." -ForegroundColor Yellow
    }
}

# Method 4: Portable ZIP package
Write-Host "📦 Creating portable ZIP package..." -ForegroundColor Yellow

try {
    $ZipPath = "$InstallerDir\TouchPadProServer_Portable.zip"
    
    # Create ZIP using PowerShell 5.0+ built-in compression
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Compress-Archive -Path "$DistDir\*" -DestinationPath $ZipPath -Force
    } else {
        # Fallback for older PowerShell versions
        Add-Type -Assembly "System.IO.Compression.FileSystem"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($DistDir, $ZipPath)
    }
    
    Write-Host "✅ Portable ZIP package created successfully!" -ForegroundColor Green
    Write-Host "📦 Package location: $ZipPath" -ForegroundColor Cyan
      # Create installation instructions
    $Instructions = @"
TouchPad Pro Server - Portable Installation
==========================================

1. Extract all files from this ZIP to a folder of your choice
   (e.g., C:\Program Files\TouchPad Pro Server\)

2. Run touchpad_pro_server.exe to start the server

3. (Optional) Create a desktop shortcut:
   - Right-click on touchpad_pro_server.exe
   - Select Create shortcut
   - Move the shortcut to your desktop

4. (Optional) Start with Windows:
   - Press Win+R, type shell:startup, press Enter
   - Copy the touchpad_pro_server.exe shortcut to this folder
   - Add --minimized to the shortcut target for silent startup

Features:
- Professional wireless mouse/touchpad control
- System tray integration
- Auto-discovery of mobile devices
- Secure device connection management
- Beautiful modern UI

For support, visit: https://github.com/touchpadpro
"@
    
    $Instructions | Out-File -FilePath "$InstallerDir\INSTALLATION_INSTRUCTIONS.txt" -Encoding UTF8
    Write-Host "📋 Installation instructions created: $InstallerDir\INSTALLATION_INSTRUCTIONS.txt" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Failed to create portable package: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Build completed successfully!" -ForegroundColor Green
Write-Host "📁 Distribution files: $DistDir" -ForegroundColor Cyan
Write-Host "📦 Installer/Package: $InstallerDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now distribute the installer or portable package to users." -ForegroundColor White
