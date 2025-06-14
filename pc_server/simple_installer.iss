; TouchPad Pro Server - Simple Installer
; Minimal setup script to avoid permission and folder access issues

#define MyAppName "TouchPad Pro Server"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "TouchPad Pro Team"
#define MyAppExeName "touchpad_pro_server.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={userappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
PrivilegesRequired=lowest
OutputDir=installer_output
OutputBaseFilename=TouchPadProServer_Simple_Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DisableDirPage=no
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
DirExistsWarning=no
EnableDirDoesntExistWarning=no
AllowRootDirectory=no
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checked
Name: "startupicon"; Description: "Start with Windows"; GroupDescription: "Startup Options:"; Flags: unchecked

[Files]
; Main executable (required)
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Required DLLs (only include if they exist)
Source: "build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "build\windows\x64\runner\Release\screen_retriever_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "build\windows\x64\runner\Release\system_tray_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; Data folder (Flutter assets)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Add startup entry if requested
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"" --minimized"; Flags: uninsdeletevalue; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
