#ifndef MyAppName
  #define MyAppName "SinaClinic"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "1.4.0"
#endif
#define MyAppPublisher "MedevSync"
#define MyAppURL "https://sinaclinic.medevsync.com"
#ifndef MyAppExeName
  #define MyAppExeName "chifa.exe"
#endif
#ifndef MyAppGuid
  #define MyAppGuid "9A7E4B10-5E2C-4C3A-B10D-514A9C11C202"
#endif
#ifndef MyOutputDir
  #define MyOutputDir "..\..\win-dist"
#endif
#ifndef MyOutputBaseFilename
  #define MyOutputBaseFilename "SinaClinic_Windows_Setup"
#endif
#ifndef MyReleaseDir
  #define MyReleaseDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef MyIconFile
  #define MyIconFile "..\runner\resources\app_icon.ico"
#endif

[Setup]
AppId={{{#MyAppGuid}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\app_icon.ico
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
SetupIconFile={#MyIconFile}
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyOutputBaseFilename}
ChangesAssociations=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyIconFile}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{#MyAppName}"; Flags: nowait postinstall skipifsilent
