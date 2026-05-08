; Skrip Inno Setup untuk Super Skripsi Gandi
; Menangani instalasi aplikasi, Python, dan Pustaka AI secara otomatis

#define MyAppName "Super Skripsi Gandi"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Gandi Setiawan"
#define MyAppExeName "super_skripsi_manager.exe"
#define BuildFolder "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{GANDI-SUPER-SKRIPSI-2024}}
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

; Version Info
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription="Smart Research Engine for Students"
VersionInfoCopyright="Copyright (C) 2024 Gandi Setiawan"
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; File Utama Aplikasi
Source: "{#BuildFolder}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Folder Add-in Word (Mengecualikan folder dev)
Source: "..\..\..\super_skripsi_addin\*"; DestDir: "{app}\addin"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules\*, .git\*, .vscode\*"

; Folder Browser Extension
Source: "..\..\..\super_skripsi_extension\*"; DestDir: "{app}\extension"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules\*, .git\*, .vscode\*"

; Folder Python RAG Backend
Source: "..\..\..\super_skripsi_rag\*"; DestDir: "{app}\rag"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "__pycache__\*, .venv\*, .git\*"

; 5. Bundling Python Installer (AKTIFKAN JIKA SUDAH ADA FILENYA)
; Source: "python-3.11-amd64.exe"; DestDir: "{tmp}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 1. Instalasi Python (AKTIFKAN JIKA SUDAH ADA FILENYA)
; Filename: "{tmp}\python-3.11-amd64.exe"; Parameters: "/quiet InstallAllUsers=1 PrependPath=1"; StatusMsg: "Menginstal Python Base (Mohon tunggu)..."; Check: NeedsPython

; 2. Instalasi Pustaka AI (Pip Requirements)
Filename: "cmd.exe"; Parameters: "/c python -m pip install --upgrade pip && python -m pip install -r ""{app}\rag\requirements.txt"""; StatusMsg: "Menginstal Pustaka AI (Ini mungkin memakan waktu beberapa menit)..."; Flags: runhidden

[Code]
function NeedsPython(): Boolean;
var
  ResultCode: Integer;
begin
  if Exec('cmd.exe', '/c python --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := (ResultCode <> 0)
  else
    Result := True;
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
