unit UpdaterUnit;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, fpjson, jsonparser, zipper, fileinfo, winpeimagereader, process, ComObj, urlmon, ActiveX;

type
  TUpdateThread = class(TThread)
  private
    FCurrentVersion: String;
    FLatestVersion: String;
    FDownloadUrl: String;
    function GetCurrentVersion: String;
    function CompareVersions(const V1, V2: String): Integer;
    procedure PromptRestart;
    function GetHttpString(const URL: String): String;
    function DownloadFileNative(const URL, Dest: String): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
  end;

implementation

constructor TUpdateThread.Create;
begin
  inherited Create(False); // Start immediately
  FreeOnTerminate := True;
end;

function TUpdateThread.GetCurrentVersion: String;
var
  FileVerInfo: TFileVersionInfo;
begin
  Result := '0.0.0.0';
  FileVerInfo := TFileVersionInfo.Create(nil);
  try
    FileVerInfo.FileName := ParamStr(0);
    FileVerInfo.ReadFileInfo;
    if FileVerInfo.VersionStrings.IndexOfName('FileVersion') >= 0 then
      Result := FileVerInfo.VersionStrings.Values['FileVersion'];
  finally
    FileVerInfo.Free;
  end;
end;

function TUpdateThread.CompareVersions(const V1, V2: String): Integer;
var
  L1, L2: TStringList;
  I, N1, N2: Integer;
  S1, S2: String;
begin
  S1 := StringReplace(V1, 'v', '', [rfReplaceAll, rfIgnoreCase]);
  S2 := StringReplace(V2, 'v', '', [rfReplaceAll, rfIgnoreCase]);
  
  L1 := TStringList.Create;
  L2 := TStringList.Create;
  try
    L1.Delimiter := '.';
    L1.StrictDelimiter := True;
    L1.DelimitedText := S1;
    
    L2.Delimiter := '.';
    L2.StrictDelimiter := True;
    L2.DelimitedText := S2;
    
    for I := 0 to 3 do begin
      N1 := 0; N2 := 0;
      if I < L1.Count then TryStrToInt(L1[I], N1);
      if I < L2.Count then TryStrToInt(L2[I], N2);
      if N1 > N2 then Exit(1);
      if N1 < N2 then Exit(-1);
    end;
    Result := 0;
  finally
    L1.Free;
    L2.Free;
  end;
end;

procedure TUpdateThread.PromptRestart;
var
  Proc: TProcess;
begin
  if MessageDlg('Update', 'Update is ready. Restart the application?', mtConfirmation, [mbOK, mbCancel], 0) = mrOk then
  begin
    Proc := TProcess.Create(nil);
    try
      Proc.Executable := ParamStr(0);
      Proc.Options := [poNoConsole];
      Proc.Execute;
    finally
      Proc.Free;
    end;
    Application.Terminate;
  end;
end;

function TUpdateThread.GetHttpString(const URL: String): String;
var
  HTTP: OleVariant;
begin
  HTTP := CreateOleObject('WinHttp.WinHttpRequest.5.1');
  HTTP.Open('GET', URL, False);
  HTTP.SetRequestHeader('User-Agent', 'DataSmoother-Updater');
  HTTP.Send;
  Result := HTTP.ResponseText;
end;

function TUpdateThread.DownloadFileNative(const URL, Dest: String): Boolean;
begin
  Result := URLDownloadToFile(nil, PChar(URL), PChar(Dest), 0, nil) = 0;
end;

procedure TUpdateThread.Execute;
var
  JSONString: String;
  JSONData, AssetsObj: TJSONData;
  AppExe, AppDir, OldExe, ZipFile: String;
  UnZipper: TUnZipper;
  I: Integer;
begin
  CoInitialize(nil);
  try
    FCurrentVersion := GetCurrentVersion;
    
    try
      JSONString := GetHttpString('https://api.github.com/repos/AlexVedun/DataSmoother/releases/latest');
  except
    Exit;
  end;

  if Trim(JSONString) = '' then Exit;

  try
    JSONData := GetJSON(JSONString);
  except
    Exit;
  end;

  try
    FLatestVersion := JSONData.FindPath('tag_name').AsString;
    
    // Check version
    if CompareVersions(FLatestVersion, FCurrentVersion) <= 0 then Exit;

    // Find the zip asset download URL
    AssetsObj := JSONData.FindPath('assets');
    if (AssetsObj = nil) or (AssetsObj.Count = 0) then Exit;
    
    FDownloadUrl := '';
    for I := 0 to AssetsObj.Count - 1 do begin
      if Pos('.zip', LowerCase(AssetsObj.Items[I].FindPath('name').AsString)) > 0 then begin
        FDownloadUrl := AssetsObj.Items[I].FindPath('browser_download_url').AsString;
        Break;
      end;
    end;
    
    if FDownloadUrl = '' then Exit;
  finally
    JSONData.Free;
  end;

  // Download the ZIP
  AppDir := ExtractFilePath(ParamStr(0));
  ZipFile := AppDir + 'update.zip';
  
  try
    if not DownloadFileNative(FDownloadUrl, ZipFile) then Exit;
  except
    Exit;
  end;

  // Rename and Extract
  AppExe := ParamStr(0);
  OldExe := ChangeFileExt(AppExe, '_old.exe');
  
  if FileExists(OldExe) then DeleteFile(OldExe);
  if not RenameFile(AppExe, OldExe) then begin
    DeleteFile(ZipFile);
    Exit;
  end;

  UnZipper := TUnZipper.Create;
  try
    UnZipper.FileName := ZipFile;
    UnZipper.OutputPath := AppDir;
    try
      UnZipper.UnZipAllFiles;
    except
      // Rollback on unzip fail
      RenameFile(OldExe, AppExe);
      DeleteFile(ZipFile);
      Exit;
    end;
  finally
    UnZipper.Free;
  end;
  
  DeleteFile(ZipFile);

  // Notify UI
  Synchronize(PromptRestart);
  finally
    CoUninitialize;
  end;
end;

end.
