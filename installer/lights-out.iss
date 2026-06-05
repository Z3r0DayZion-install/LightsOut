; Lights Out installer — requires Inno Setup 6
#define MyAppName "Lights Out"
#define MyAppVersion "5.2.0"
#define MyAppPublisher "KickA"
#define MyAppExeName "SleepTimer.exe"
#define MyAppURL "https://github.com/Z3r0DayZion-install/ForgeCore_OS"

[Setup]
AppId={{C3D4E5F6-A7B8-9012-CDEF-123456789ABC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={localappdata}\Programs\Lights Out
DefaultGroupName={#MyAppName}
OutputDir=..\installer\output
OutputBaseFilename=LightsOut-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\SleepTimer.ico

[Files]
Source: "..\dist\Release\SleepTimer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\Release\modules\*"; DestDir: "{app}\modules"; Flags: ignoreversion recursesubdirs
Source: "..\dist\Release\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\Release\README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\Release\SleepTimer.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\Release\LightsOut-Logo.png"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\SleepTimer.ico"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\SleepTimer.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: postinstall nowait skipifsilent
