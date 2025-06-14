# TouchPad Pro Server - PowerShell Installer
# This script creates a self-extracting installer that handles permission issues

param(
    [string]$InstallPath = "",
    [switch]$NoDesktopIcon,
    [switch]$NoStartup,
    [switch]$Silent
)

$AppName = "TouchPad Pro Server"
$AppVersion = "1.0.0"
$ExeName = "touchpad_pro_server.exe"

# Function to show progress
function Show-Progress {
    param([string]$Activity, [string]$Status, [int]$PercentComplete)
    if (-not $Silent) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    }
}

# Function to test if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to choose installation directory
function Choose-InstallDirectory {
    if ($InstallPath -ne "") {
        return $InstallPath
    }
    
    # Suggest different paths based on admin privileges
    if (Test-Administrator) {
        $defaultPath = "$env:ProgramFiles\$AppName"
    } else {
        $defaultPath = "$env:LOCALAPPDATA\$AppName"
    }
    
    if ($Silent) {
        return $defaultPath
    }
    
    Write-Host "`n$AppName Installation" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Default installation directory: $defaultPath"
    Write-Host ""
    $response = Read-Host "Press Enter to use default, or type a new path"
    
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $defaultPath
    } else {
        return $response
    }
}

# Main installation function
function Install-TouchPadPro {
    try {
        if (-not $Silent) {
            Clear-Host
            Write-Host "$AppName Installer v$AppVersion" -ForegroundColor Green
            Write-Host "=======================================" -ForegroundColor Green
            Write-Host ""
        }
        
        # Step 1: Choose installation directory
        Show-Progress "Installation" "Choosing installation directory..." 10
        $installDir = Choose-InstallDirectory
        
        # Step 2: Create directory
        Show-Progress "Installation" "Creating installation directory..." 20
        if (-not (Test-Path $installDir)) {
            try {
                New-Item -ItemType Directory -Path $installDir -Force | Out-Null
                Write-Host "Created directory: $installDir" -ForegroundColor Green
            } catch {
                throw "Failed to create directory: $installDir. Error: $($_.Exception.Message)"
            }
        }
        
        # Step 3: Check if source files exist
        Show-Progress "Installation" "Checking source files..." 30
        $sourceDir = Join-Path $PSScriptRoot "build\windows\x64\runner\Release"
        $exePath = Join-Path $sourceDir $ExeName
        
        if (-not (Test-Path $exePath)) {
            throw "Application executable not found: $exePath"
        }
        
        # Step 4: Copy files
        Show-Progress "Installation" "Copying application files..." 40
        try {
            # Copy main executable
            Copy-Item $exePath $installDir -Force
            
            # Copy DLLs
            $dlls = @("flutter_windows.dll", "screen_retriever_plugin.dll", "system_tray_plugin.dll", "window_manager_plugin.dll")
            foreach ($dll in $dlls) {
                $dllPath = Join-Path $sourceDir $dll
                if (Test-Path $dllPath) {
                    Copy-Item $dllPath $installDir -Force
                }
            }
            
            # Copy data folder
            $dataSource = Join-Path $sourceDir "data"
            $dataTarget = Join-Path $installDir "data"
            if (Test-Path $dataSource) {
                Copy-Item $dataSource $dataTarget -Recurse -Force
            }
            
            Write-Host "Files copied successfully" -ForegroundColor Green
        } catch {
            throw "Failed to copy files: $($_.Exception.Message)"
        }
        
        # Step 5: Create desktop shortcut
        Show-Progress "Installation" "Creating shortcuts..." 60
        if (-not $NoDesktopIcon) {
            try {
                $WshShell = New-Object -comObject WScript.Shell
                $desktopPath = [System.Environment]::GetFolderPath('Desktop')
                $shortcutPath = Join-Path $desktopPath "$AppName.lnk"
                $shortcut = $WshShell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = Join-Path $installDir $ExeName
                $shortcut.WorkingDirectory = $installDir
                $shortcut.Description = "$AppName - Wireless mouse/touchpad control"
                $shortcut.Save()
                Write-Host "Desktop shortcut created" -ForegroundColor Green
            } catch {
                Write-Warning "Could not create desktop shortcut: $($_.Exception.Message)"
            }
        }
        
        # Step 6: Add to startup (optional)
        Show-Progress "Installation" "Configuring startup options..." 80
        if (-not $NoStartup) {
            if (-not $Silent) {
                $startupResponse = Read-Host "Add to Windows startup? (y/N)"
                if ($startupResponse -eq "y" -or $startupResponse -eq "Y") {
                    try {
                        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                        $targetPath = "`"$(Join-Path $installDir $ExeName)`" --minimized"
                        Set-ItemProperty -Path $regPath -Name $AppName -Value $targetPath
                        Write-Host "Added to Windows startup" -ForegroundColor Green
                    } catch {
                        Write-Warning "Could not add to startup: $($_.Exception.Message)"
                    }
                }
            }
        }
        
        # Step 7: Create uninstaller
        Show-Progress "Installation" "Creating uninstaller..." 90
        $uninstallerContent = @"
# TouchPad Pro Server Uninstaller
`$installDir = "$installDir"
`$appName = "$AppName"

Write-Host "Uninstalling `$appName..." -ForegroundColor Yellow

# Stop the application if running
Get-Process -Name "touchpad_pro_server" -ErrorAction SilentlyContinue | Stop-Process -Force

# Remove from startup
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name `$appName -ErrorAction SilentlyContinue

# Remove desktop shortcut
`$desktopPath = [System.Environment]::GetFolderPath('Desktop')
`$shortcutPath = Join-Path `$desktopPath "`$appName.lnk"
if (Test-Path `$shortcutPath) {
    Remove-Item `$shortcutPath -Force
}

# Remove installation directory
if (Test-Path `$installDir) {
    Remove-Item `$installDir -Recurse -Force
    Write-Host "Application uninstalled successfully" -ForegroundColor Green
} else {
    Write-Host "Installation directory not found" -ForegroundColor Yellow
}

Read-Host "Press Enter to close"
"@
        
        $uninstallerPath = Join-Path $installDir "uninstall.ps1"
        $uninstallerContent | Out-File -FilePath $uninstallerPath -Encoding UTF8
        
        # Step 8: Installation complete
        Show-Progress "Installation" "Installation complete!" 100
        Start-Sleep 1
        
        if (-not $Silent) {
            Clear-Host
            Write-Host "$AppName Installation Complete!" -ForegroundColor Green
            Write-Host "======================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Installation directory: $installDir" -ForegroundColor Cyan
            Write-Host "Executable: $(Join-Path $installDir $ExeName)" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "To start the application:" -ForegroundColor Yellow
            Write-Host "- Double-click the desktop shortcut, or" -ForegroundColor White
            Write-Host "- Run: $installDir\$ExeName" -ForegroundColor White
            Write-Host ""
            Write-Host "To uninstall:" -ForegroundColor Yellow
            Write-Host "- Run: PowerShell -ExecutionPolicy Bypass -File `"$installDir\uninstall.ps1`"" -ForegroundColor White
            Write-Host ""
            
            $launchResponse = Read-Host "Launch the application now? (Y/n)"
            if ($launchResponse -ne "n" -and $launchResponse -ne "N") {
                Start-Process (Join-Path $installDir $ExeName)
            }
        }
        
        return $true
        
    } catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
        Write-Host "- Try running as administrator" -ForegroundColor White
        Write-Host "- Choose a different installation directory" -ForegroundColor White
        Write-Host "- Check if antivirus is blocking the installation" -ForegroundColor White
        Write-Host "- Use the portable ZIP version instead" -ForegroundColor White
        return $false
    }
}

# Run the installer
Install-TouchPadPro
