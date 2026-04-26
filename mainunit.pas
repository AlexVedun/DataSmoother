unit MainUnit;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ActnList, Menus,
  ComCtrls, StdActns, ExtCtrls, TAGraph, TAFuncSeries, TASeries, TASources,
  fpSpreadsheetCtrls, fpSpreadsheetGrid, fpsallformats,
  Grids, StdCtrls, fpSpreadsheet, fpsTypes, fpsUtils, Generics.Collections,
  SmoothingAlgorithms, Math, UpdaterUnit;

const
  PANEL_SELECTED_RANGE = 0;
  PANEL_OUTPUT_CELL = 1;

  MODE_NONE = 0;
  MODE_MOVING_AVERAGE = 1;
  MODE_SIMPLE_EXPONENTIAL = 2;
  MODE_MEDIAN = 3;
  MODE_LOWESS = 4;
  MODE_SPLINE = 5;

type
  { TMainForm }

  TMainForm = class(TForm)
    MenuItem4: TMenuItem;
    SaveFile: TAction;
    ActionList1: TActionList;
    Label1: TLabel;
    ToolButton4: TToolButton;
    WriteButton: TButton;
    Chart1: TChart;
    GetSelectedDataMenuItem: TMenuItem;
    SmoothedDataSource: TListChartSource;
    OriginalDataSource: TListChartSource;
    Panel1: TPanel;
    MovingAverageRadioButton: TRadioButton;
    ExponentialRadioButton: TRadioButton;
    MedianRadioButton: TRadioButton;
    SelectOutputCellMenuItem: TMenuItem;
    OriginalData: TLineSeries;
    MovingAverageSpan: TTrackBar;
    ExponentialSpan: TTrackBar;
    MedianSpan: TTrackBar;
    LowessRadioButton: TRadioButton;
    LowessSpan: TTrackBar;
    SplineRadioButton: TRadioButton;
    SplineSpan: TTrackBar;
    WorksheetGridPopupMenu: TPopupMenu;
    SmoothedData: TLineSeries;
    FileExit: TFileExit;
    FileOpen: TFileOpen;
    ImageList1: TImageList;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    PageControl1: TPageControl;
    Separator1: TMenuItem;
    StatusBar: TStatusBar;
    sWorkbookTabControl1: TsWorkbookTabControl;
    WorkbookSource: TsWorkbookSource;
    WorksheetGrid: TsWorksheetGrid;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    ToolBar: TToolBar;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    procedure ExponentialRadioButtonChange(Sender: TObject);
    procedure ExponentialRadioButtonClick(Sender: TObject);
    procedure ExponentialSpanChange(Sender: TObject);
    procedure FileOpenAccept(Sender: TObject);
    procedure GetSelectedDataMenuItemClick(Sender: TObject);
    procedure MedianRadioButtonChange(Sender: TObject);
    procedure MedianRadioButtonClick(Sender: TObject);
    procedure MedianSpanChange(Sender: TObject);
    procedure LowessRadioButtonChange(Sender: TObject);
    procedure LowessRadioButtonClick(Sender: TObject);
    procedure LowessSpanChange(Sender: TObject);
    procedure SplineRadioButtonChange(Sender: TObject);
    procedure SplineRadioButtonClick(Sender: TObject);
    procedure SplineSpanChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure MovingAverageRadioButtonChange(Sender: TObject);
    procedure MovingAverageRadioButtonClick(Sender: TObject);
    procedure MovingAverageSpanChange(Sender: TObject);
    procedure SaveFileExecute(Sender: TObject);
    procedure SelectOutputCellMenuItemClick(Sender: TObject);
    procedure WorksheetGridTopLeftChanged(Sender: TObject);
    procedure WriteButtonClick(Sender: TObject);
  public
    FileName: String;
    OriginalDataArray: array of array of Double;
    SmoothingMode: Integer;
    OutputCell: TGridRect;
    SmoothedY: TDoubleArray;
    procedure redrawChart();
    procedure updateSmoothedChart();
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  OldExe: String;
begin
  OldExe := ChangeFileExt(ParamStr(0), '_old.exe');
  if FileExists(OldExe) then
    DeleteFile(OldExe);

  TUpdateThread.Create;
end;

procedure TMainForm.WorksheetGridTopLeftChanged(Sender: TObject);
begin
  MainForm.WorksheetGrid.Invalidate;
end;

procedure TMainForm.WriteButtonClick(Sender: TObject);
var
  Selection: TGridRect;
  Sheet: TsWorksheet;
  row, col, SelectedColsAmount, SelectedRowsAmount, rows, i: Integer;
  Cell: PCell;
  SelectionRange: string;
begin
  Sheet := WorksheetGrid.WorkbookSource.worksheet;
  if (not Sheet.IsEmpty) then begin
    rows := Length(OriginalDataArray);
    row := OutputCell.Top - 1;
    col := OutputCell.Left - 1;
    for i := 0 to rows - 1 do begin
      Sheet.WriteNumber(row, col, SmoothedY[i]);
      inc(row);
    end;

    //Selection := WorksheetGrid.Selection;
    //SelectedColsAmount := Selection.Right - Selection.Left + 1;
    //SelectedRowsAmount := Selection.Bottom - Selection.Top + 1;
    //if SelectedColsAmount = 2 then
    //begin
    //  MainForm.OriginalDataArray := nil;
    //  SetLength(MainForm.OriginalDataArray, SelectedRowsAmount, 2);
    //  for row := Selection.Top to Selection.Bottom do
    //    for col := Selection.Left to Selection.Right do
    //    begin
    //      Cell := Sheet.FindCell(row - 1 , col - 1);
    //      if (Cell <> nil) and (Cell^.ContentType = cctNumber) then
    //      begin
    //        MainForm.OriginalDataArray[row - Selection.Top, col - Selection.Left] := Cell^.NumberValue;
    //      end;
    //    end;
    //  MainForm.redrawChart;
    //
    //  SelectionRange := GetCellRangeString(Selection.Top - 1, Selection.Left - 1, Selection.Bottom - 1, Selection.Right - 1);
    //  StatusBar.Panels[PANEL_SELECTED_RANGE].Text := SelectionRange;
    //end;
  end;
end;

procedure TMainForm.FileOpenAccept(Sender: TObject);
var
  FileOpenAction: TFileOpen;
begin
  FileOpenAction:=Sender as TFileOpen;
  MainForm.FileName:=FileOpenAction.Dialog.FileName;
  MainForm.WorkbookSource.FileName:=MainForm.FileName;
end;

procedure TMainForm.ExponentialRadioButtonChange(Sender: TObject);
begin
  ExponentialSpan.Enabled := ExponentialRadioButton.Checked;
end;

procedure TMainForm.ExponentialRadioButtonClick(Sender: TObject);
begin
  SmoothingMode := MODE_SIMPLE_EXPONENTIAL;
  updateSmoothedChart;
end;

procedure TMainForm.ExponentialSpanChange(Sender: TObject);
begin
  updateSmoothedChart;
end;

procedure TMainForm.GetSelectedDataMenuItemClick(Sender: TObject);
var
  Selection: TGridRect;
  Sheet: TsWorksheet;
  row, col, SelectedColsAmount, SelectedRowsAmount: Integer;
  Cell: PCell;
  SelectionRange: string;
begin
  Sheet := WorksheetGrid.WorkbookSource.worksheet;
  if (not Sheet.IsEmpty) then begin
    Selection := WorksheetGrid.Selection;
    SelectedColsAmount := Selection.Right - Selection.Left + 1;
    SelectedRowsAmount := Selection.Bottom - Selection.Top + 1;
    if SelectedColsAmount = 2 then
    begin
      MainForm.OriginalDataArray := nil;
      SetLength(MainForm.OriginalDataArray, SelectedRowsAmount, 2);
      for row := Selection.Top to Selection.Bottom do
        for col := Selection.Left to Selection.Right do
        begin
          Cell := Sheet.FindCell(row - 1 , col - 1);
          if (Cell <> nil) and (Cell^.ContentType = cctNumber) then
          begin
            MainForm.OriginalDataArray[row - Selection.Top, col - Selection.Left] := Cell^.NumberValue;
          end;
        end;
      MainForm.redrawChart;

      SelectionRange := GetCellRangeString(Selection.Top - 1, Selection.Left - 1, Selection.Bottom - 1, Selection.Right - 1);
      StatusBar.Panels[PANEL_SELECTED_RANGE].Text := SelectionRange;
    end;
  end;
end;

procedure TMainForm.LowessRadioButtonChange(Sender: TObject);
begin
  LowessSpan.Enabled := LowessRadioButton.Checked;
end;

procedure TMainForm.LowessRadioButtonClick(Sender: TObject);
begin
  SmoothingMode := MODE_LOWESS;
  updateSmoothedChart;
end;

procedure TMainForm.LowessSpanChange(Sender: TObject);
begin
  if not Odd(LowessSpan.Position) then
  begin
    if LowessSpan.Position < LowessSpan.Max then
      LowessSpan.Position := LowessSpan.Position + 1
    else
      LowessSpan.Position := LowessSpan.Position - 1;
  end;
  updateSmoothedChart;
end;

procedure TMainForm.SplineRadioButtonChange(Sender: TObject);
begin
  SplineSpan.Enabled := SplineRadioButton.Checked;
end;

procedure TMainForm.SplineRadioButtonClick(Sender: TObject);
begin
  SmoothingMode := MODE_SPLINE;
  updateSmoothedChart;
end;

procedure TMainForm.SplineSpanChange(Sender: TObject);
begin
  updateSmoothedChart;
end;

procedure TMainForm.MedianRadioButtonChange(Sender: TObject);
begin
  MedianSpan.Enabled := MedianRadioButton.Checked;
end;

procedure TMainForm.MedianRadioButtonClick(Sender: TObject);
begin
  SmoothingMode := MODE_MEDIAN;
  updateSmoothedChart;
end;

procedure TMainForm.MedianSpanChange(Sender: TObject);
begin
  if not Odd(MedianSpan.Position) then
  begin
    if MedianSpan.Position < MedianSpan.Max then
      MedianSpan.Position := MedianSpan.Position + 1
    else
      MedianSpan.Position := MedianSpan.Position - 1;
  end;
  updateSmoothedChart;
end;

procedure TMainForm.MovingAverageRadioButtonChange(Sender: TObject);
begin
  MovingAverageSpan.Enabled := MovingAverageRadioButton.Checked;
end;

procedure TMainForm.MovingAverageRadioButtonClick(Sender: TObject);
begin
  SmoothingMode := MODE_MOVING_AVERAGE;
  updateSmoothedChart;
end;

procedure TMainForm.MovingAverageSpanChange(Sender: TObject);
begin
  if not Odd(MovingAverageSpan.Position) then
  begin
    if MovingAverageSpan.Position < MovingAverageSpan.Max then
      MovingAverageSpan.Position := MovingAverageSpan.Position + 1
    else
      MovingAverageSpan.Position := MovingAverageSpan.Position - 1;
  end;
  updateSmoothedChart;
end;

procedure TMainForm.SaveFileExecute(Sender: TObject);
begin
  WorkbookSource.SaveToSpreadsheetFile(WorkbookSource.FileName);
  ShowMessage('File has been saved successfully');
end;

procedure TMainForm.SelectOutputCellMenuItemClick(Sender: TObject);
var
  Sheet: TsWorksheet;
begin
  Sheet := WorksheetGrid.WorkbookSource.worksheet;
  if (not Sheet.IsEmpty) then begin
    OutputCell := WorksheetGrid.Selection;

    StatusBar.Panels[PANEL_OUTPUT_CELL].Text := GetCellString(OutputCell.Top - 1, OutputCell.Left - 1);
  end;
end;

procedure TMainForm.redrawChart();
var
  arraySize, i: Integer;
begin
  arraySize := length(OriginalDataArray);
  if arraySize <= 0 then Exit;

  OriginalDataSource.BeginUpdate;
  OriginalDataSource.Clear;
  for i := 0 to arraySize - 1 do
  begin
    OriginalDataSource.Add(OriginalDataArray[i, 0], OriginalDataArray[i, 1]);
  end;
  OriginalDataSource.EndUpdate;
end;

procedure TMainForm.updateSmoothedChart();
var
  maxRow, row, i, arraySize: Integer;
  X, Y: TDoubleArray;
begin
  X := nil;
  Y := nil;
  SmoothedY := nil;
  arraySize := length(OriginalDataArray);
  if arraySize <= 0 then Exit;
  SetLength(X, arraySize);
  SetLength(Y, arraySize);

  for i := 0 to arraySize - 1 do begin
    X[i] := OriginalDataArray[i, 0];
    Y[i] := OriginalDataArray[i, 1];
  end;

  SmoothedDataSource.BeginUpdate;
  SmoothedDataSource.Clear;
  case SmoothingMode of
    MODE_MOVING_AVERAGE: begin
      TSmoother.MovingAverageMethod(Y, SmoothedY, MovingAverageSpan.Position);
    end;
    MODE_SIMPLE_EXPONENTIAL: begin
      TSmoother.SimpleExponentialMethod(Y, SmoothedY, ExponentialSpan.Position / 10);
    end;
    MODE_MEDIAN: begin
      TSmoother.MedianMethod(Y, SmoothedY, MedianSpan.Position);
    end;
    MODE_LOWESS: begin
      TSmoother.LowessMethod(X, Y, SmoothedY, LowessSpan.Position);
    end;
    MODE_SPLINE: begin
      TSmoother.SplineMethod(X, Y, SmoothedY, Math.Power(10.0, (SplineSpan.Position - 50.0) / 10.0));
    end;
  end;
  if (length(SmoothedY) > 0) then begin
    for i := 0 to arraySize - 1 do begin
      SmoothedDataSource.Add(X[i], SmoothedY[i]);
    end;
  end;
  SmoothedDataSource.EndUpdate;
end;

end.

