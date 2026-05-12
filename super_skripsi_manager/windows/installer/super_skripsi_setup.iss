#define MyAppName "Super Skripsi Gandi"
#ifndef MyAppVersion
  #define MyAppVersion GetEnv("MyAppVersion")
#endif
#if MyAppVersion == ""
  #define MyAppVersion "1.1.26"
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
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Folder Python RAG Backend
Source: "..\..\..\super_skripsi_rag\*"; DestDir: "{app}\rag"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "__pycache__\*, .venv\*, .git\*"

; Browser Extension & API Bridge
Source: "..\..\..\super_skripsi_extension\*"; DestDir: "{app}\extension"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "api-bridge\node_modules\*"

; Word Add-in (Built files only)
Source: "..\..\..\super_skripsi_addin\dist\*"; DestDir: "{app}\addin"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\..\super_skripsi_addin\manifest.xml"; DestDir: "{app}\addin"; Flags: ignoreversion
Source: "..\..\..\super_skripsi_addin\install_addin.bat"; DestDir: "{app}\addin"; Flags: ignoreversion

; Portable Node.js (Akan diunduh oleh CI/CD ke folder 'node')
Source: "..\..\..\node\*"; DestDir: "{app}\node"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
; Daftarkan folder Add-in ke Trusted Catalogs Office (agar muncul otomatis di Word)
Root: HKCU; Subkey: "Software\Microsoft\Office\16.0\Word\Trusted Catalogs\{{a8b2c3d4-e5f6-7890-abcd-ef1234567890}"; ValueType: string; ValueName: "URL"; ValueData: "{app}\addin"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Office\16.0\Word\Trusted Catalogs\{{a8b2c3d4-e5f6-7890-abcd-ef1234567890}"; ValueType: dword; ValueName: "Flags"; ValueData: "1"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Office\16.0\Word\Trusted Catalogs\{{a8b2c3d4-e5f6-7890-abcd-ef1234567890}"; ValueType: dword; ValueName: "Id"; ValueData: "1"; Flags: uninsdeletekey

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Install API Bridge dependencies (jika diperlukan, namun sebaiknya sudah dipre-build)
; Filename: "{app}\node\node.exe"; Parameters: """{app}\node\node_modules\npm\bin\npm-cli.js"" install --production"; WorkingDir: "{app}\extension\api-bridge"; Flags: runhidden

; Langsung jalankan aplikasi
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
