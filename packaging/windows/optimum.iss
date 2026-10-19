#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputPath
  #error OutputPath is required
#endif

[Setup]
AppId={{929641B1-6391-4F35-B470-CC67E7B19E49}
AppName=OPTIMUM
AppVersion={#AppVersion}
AppPublisher=OPTIMUM
AppPublisherURL=https://github.com/nobklop/OPTIMUM
AppSupportURL=https://github.com/nobklop/OPTIMUM/issues
DefaultDirName={localappdata}\Programs\OPTIMUM
DefaultGroupName=OPTIMUM
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir={#OutputPath}
OutputBaseFilename=OPTIMUM-{#AppVersion}-Setup-x64
SetupIconFile=..\..\client\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\optimum.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableFinishedPage=yes
ShowLanguageDialog=no
CloseApplications=yes
RestartApplications=no
ArchiveExtraction=basic
SetupLogging=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{tmp}\optimum-engine\libmpv-2.dll"; DestDir: "{app}"; Flags: external ignoreversion; ExternalSize: 15525902

[Icons]
Name: "{userdesktop}\OPTIMUM"; Filename: "{app}\optimum.exe"; Check: ShouldCreateIcons
Name: "{group}\OPTIMUM"; Filename: "{app}\optimum.exe"; Check: ShouldCreateIcons
Name: "{group}\Удалить OPTIMUM"; Filename: "{uninstallexe}"; Check: ShouldCreateIcons

[Run]
Filename: "{app}\optimum.exe"; Flags: nowait skipifsilent; Check: ShouldLaunch

[Code]
const
  EngineURL = 'https://github.com/media-kit/libmpv-win32-audio-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z';
  ArchiveHash = '583af5a291fc99ae2641794ede1955c368eb4c19dc05f4f0a9c7f9456edeb6a8';
  EngineHash = '0a5a0b476866c91a639a4e511e8153968f8fa23564461b0aa09acdba816164a4';

function ShouldLaunch: Boolean;
begin
  Result := ExpandConstant('{param:NOAUTOLAUNCH|0}') <> '1';
end;

function ShouldCreateIcons: Boolean;
begin
  Result := ExpandConstant('{param:NOSHORTCUTS|0}') <> '1';
end;

function InitializeSetup: Boolean;
var
  Installed: String;
  InstalledVersion, NewVersion: Int64;
begin
  Result := True;
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{929641B1-6391-4F35-B470-CC67E7B19E49}_is1', 'DisplayVersion', Installed) then
    if StrToVersion(Installed, InstalledVersion) and StrToVersion('{#AppVersion}', NewVersion) and
      (ComparePackedVersion(InstalledVersion, NewVersion) > 0) then begin
      SuppressibleMsgBox('Установлена более новая версия OPTIMUM (' + Installed + '). Используйте последнюю версию с GitHub.', mbError, MB_OK, IDOK);
      Result := False;
    end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  EngineDir, EngineFile, Existing: String;
begin
  Result := '';
  try
    EngineDir := ExpandConstant('{tmp}\optimum-engine');
    EngineFile := EngineDir + '\libmpv-2.dll';
    Existing := ExpandConstant('{app}\libmpv-2.dll');
    ForceDirectories(EngineDir);
    if FileExists(Existing) and (GetSHA256OfFile(Existing) = EngineHash) then begin
      if not CopyFile(Existing, EngineFile, False) then
        RaiseException('Не удалось подготовить аудиодвижок.');
    end else begin
      WizardForm.StatusLabel.Caption := 'Загрузка аудиодвижка OPTIMUM…';
      DownloadTemporaryFile(EngineURL, 'optimum-engine.7z', ArchiveHash, nil);
      ExtractArchive(ExpandConstant('{tmp}\optimum-engine.7z'), EngineDir, '', True, nil);
    end;
    if not FileExists(EngineFile) or (GetSHA256OfFile(EngineFile) <> EngineHash) then
      RaiseException('Контрольная сумма аудиодвижка не совпала.');
  except
    Result := 'Установка ещё не выполнена. Для первой установки нужен доступ к GitHub. ' + GetExceptionMessage;
  end;
end;
