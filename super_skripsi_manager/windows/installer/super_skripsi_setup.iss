; Skrip Inno Setup untuk Super Skripsi Gandi
; Menangani instalasi aplikasi dan Python secara otomatis

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

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "indonesian"; MessagesFile: "compiler:Languages\Indonesian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; File Utama Aplikasi (Hasil build Flutter)
Source: "{#BuildFolder}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Bundling Python Installer (Download dulu python-3.11.exe dan letakkan di folder ini)
Source: "python-3.11-amd64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Instalasi Python secara otomatis (Silent) jika user memilih
Filename: "{tmp}\python-3.11-amd64.exe"; Parameters: "/quiet InstallAllUsers=1 PrependPath=1"; StatusMsg: "Menginstal Python Dependensi (Mohon tunggu)..."; Check: NeedsPython

[Code]
// Fungsi untuk mengecek apakah Python sudah terinstall
function NeedsPython(): Boolean;
var
  ResultCode: Integer;
begin
  // Mencoba menjalankan perintah python --version
  if Exec('cmd.exe', '/c python --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    // Jika ResultCode bukan 0, berarti python tidak ditemukan
    Result := (ResultCode <> 0);
  end
  else
  begin
    Result := True;
  end;
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
