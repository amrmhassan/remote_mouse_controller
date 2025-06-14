; TouchPad Pro Server Installer Script
; Created with Inno Setup 6.x
; This script creates a single installable EXE for TouchPad Pro Server

#define MyAppName "TouchPad Pro Server"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "TouchPad Pro Team"
#define MyAppURL "https://github.com/touchpadpro"
#define MyAppExeName "touchpad_pro_server.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
AppId={{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=installer_output
OutputBaseFilename=TouchPadProServer_Setup
SetupIconFile=app_icon.png
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DisableDirPage=no
DisableProgramGroupPage=no
UsePreviousAppDir=yes
DirExistsWarning=no
EnableDirDoesntExistWarning=no
AllowRootDirectory=no
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start with Windows"; GroupDescription: "Startup Options:"; Flags: unchecked

[Files]
; Main executable
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Required DLLs - Check if they exist before including
Source: "build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\build\windows\x64\runner\Release\flutter_windows.dll'))
Source: "build\windows\x64\runner\Release\screen_retriever_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\build\windows\x64\runner\Release\screen_retriever_plugin.dll'))
Source: "build\windows\x64\runner\Release\system_tray_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\build\windows\x64\runner\Release\system_tray_plugin.dll'))
Source: "build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\build\windows\x64\runner\Release\window_manager_plugin.dll'))
; Data folder (Flutter assets)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: DirExists(ExpandConstant('{src}\build\windows\x64\runner\Release\data'))
; Assets
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: DirExists(ExpandConstant('{src}\assets'))
; Icon
Source: "app_icon.png"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\app_icon.png'))
; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\README.md'))

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

[Code]
function FileExists(FileName: string): Boolean;
begin
  Result := FileExists(FileName);
end;

function DirExists(DirName: string): Boolean;
begin
  Result := DirExists(DirName);
end;

function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#emit SetupSetting("AppId")}_is1');
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  Result := sUnInstallString;
end;

function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;

function UnInstallOldVersion(): Integer;
var
  sUnInstallString: String;
  iResultCode: Integer;
begin
  Result := 0;
  sUnInstallString := GetUninstallString();
  if sUnInstallString <> '' then begin
    sUnInstallString := RemoveQuotes(sUnInstallString);
    if Exec(sUnInstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES','', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      Result := 3
    else
      Result := 2;
  end else
    Result := 1;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep=ssInstall) then
  begin
    if (IsUpgrade()) then
    begin
      UnInstallOldVersion();
    end;
  end;
end;
