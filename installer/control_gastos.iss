#define AppVersion "1.0.0"
#define ProductName "Control de gastos"

[Setup]
AppId={{4B01C75D-7BBF-48BE-B357-DBA2589BF2CD}
AppName={#ProductName}
AppVersion={#AppVersion}
AppPublisher=SGCG
DefaultDirName={localappdata}\Programs\SGCG
DefaultGroupName={#ProductName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist\installer
OutputBaseFilename=Control-de-gastos-Setup-{#AppVersion}
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\control_gastos.exe
WizardStyle=modern
Compression=lzma2/ultra64
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
Uninstallable=yes
VersionInfoVersion=1.0.0.0
VersionInfoProductName={#ProductName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked

[Files]
Source: "..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#ProductName}"; Filename: "{app}\control_gastos.exe"
Name: "{autodesktop}\{#ProductName}"; Filename: "{app}\control_gastos.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\control_gastos.exe"; Description: "Abrir {#ProductName}"; Flags: nowait postinstall skipifsilent
