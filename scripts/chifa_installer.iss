; Script Inno Setup pour Chifa Clinic Management Windows Desktop
; Génère un installateur professionnel Chifa_Setup_v1.0.0.exe

#define MyAppName "Chifa"
#define MyAppFullName "Clinique Chifa"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "Chifa Clinic Health Systems"
#define MyAppURL "https://medevsync.com/chifa"
#define MyAppExeName "chifa.exe"
#define MyAppSourceDir "..\deployment\windows\Chifa"

[Setup]
AppId={{E4B82A17-9102-4D3B-8C4E-7C5F72A52B99}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\deployment
OutputBaseFilename=Chifa_Setup_v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Copie tous les fichiers de l'application compilée
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

