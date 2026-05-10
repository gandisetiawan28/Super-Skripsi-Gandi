#define MyAppName "Super Skripsi Gandi"
#define MyAppVersion GetEnv("MyAppVersion")
#if MyAppVersion == ""
  #define MyAppVersion "1.1.13"
#endif
#define MyAppPublisher "Gandi Setiawan"
#define MyAppExeName "super_skripsi_manager.exe"

[Setup]
AppId={{C6D26A1A-A6F5-47B2-9A8E-F6E4C238A99B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=SuperSkripsi_Setup_v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
InfoBeforeFile=install_info.txt

; Version Info
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription="Smart Research Engine for Students"

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Utama Flutter App
Source: "..\..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Folder Python RAG Backend (Sudah termasuk python_portable yang siap pakai)
Source: "..\..\..\super_skripsi_rag\*"; DestDir: "{app}\rag"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "__pycache__\*, .venv\*, .git\*"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Langsung jalankan aplikasi, tidak perlu instal Python/Pip lagi karena sudah portable
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
