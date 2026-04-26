unit SmoothingAlgorithms;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math;

type
  TDoubleArray = array of Double;

  TSmoother = class
  public
    class procedure MovingAverageMethod(const InputData: TDoubleArray; var OutputData: TDoubleArray; const Span: Integer);
    class procedure SimpleExponentialMethod(const InputData: TDoubleArray; var OutputData: TDoubleArray; const Alpha: Real);
    class procedure MedianMethod(const InputData: TDoubleArray; var OutputData: TDoubleArray; const Span: Integer);
    class procedure LowessMethod(const XData, YData: TDoubleArray; var OutputData: TDoubleArray; const Span: Integer);
  end;

implementation

class procedure TSmoother.MovingAverageMethod(const InputData: TDoubleArray; var OutputData: TDoubleArray; const Span: Integer);
// InputData: входной массив (Y-значения).
// OutputData: сглаженный массив.
// Span: ширина окна (должна быть нечетной, например, 3, 5, 7...).
var
  i, j, HalfSpan, N, Count: Integer;
  SumY: Double;
begin
  N := Length(InputData);
  if (N = 0) or (Span < 3) then Exit;
  // Убедиться, что Span нечетный (если четный, округляем вниз и добавляем 1)
  HalfSpan := (Span - 1) div 2;
  SetLength(OutputData, N);
  // Основной цикл сглаживания
  for i := 0 to N - 1 do begin
    SumY := 0.0;
    Count := 0;
    // Итерация по окну вокруг текущей точки i (обработка краев)
    for j := -HalfSpan to HalfSpan do begin
      if (i + j >= 0) and (i + j < N) then begin
        SumY := SumY + InputData[i + j];
        Inc(Count);
      end;
    end;
    // Вычисление среднего
    if Count > 0 then OutputData[i] := SumY / Count
    else OutputData[i] := InputData[i];
    // Оставляем несглаженным, если не удалось найти соседей
  end;
end;

class procedure TSmoother.SimpleExponentialMethod(const InputData: TDoubleArray;
  var OutputData: TDoubleArray; const Alpha: Real);
// InputData: входной массив (Y-значения).
// OutputData: сглаженный массив.
// Alpha: коэффициент сглаживания (0.0 < Alpha < 1.0).
var
  i, N: Integer;
begin
  N := Length(InputData);
  if (N = 0) or (Alpha <= 0.0) or (Alpha >= 1.0) then Exit;
  SetLength(OutputData, N);
  // Инициализация: F_1 = Y_1
  OutputData[0] := InputData[0];
  // Итеративная формула: F[t] = Alpha * Y[t-1] + (1 - Alpha) * F[t-1]
  // Обратите внимание: F[t] в коде - это OutputData[i].
  for i := 1 to N - 1 do OutputData[i] := Alpha * InputData[i] + (1.0 - Alpha) * OutputData[i - 1];
end;

class procedure TSmoother.MedianMethod(const InputData: TDoubleArray;
  var OutputData: TDoubleArray; const Span: Integer);
// InputData: входной массив (Y-значения).
// OutputData: сглаженный массив.
// Span: ширина окна (должна быть нечетной, например, 3, 5, 7...).
var
  i, j, N, HalfSpan, WindowSize: Integer;
  Window: TDoubleArray;
  StartIndex, EndIndex: Integer;
begin
  N := Length(InputData);
  if (N = 0) or (Span < 3) then Exit;
  HalfSpan := (Span - 1) div 2;
  SetLength(OutputData, N);
  for i := 0 to N - 1 do begin
    // 1. Определение границ скользящего окна
    StartIndex := i - HalfSpan;
    if StartIndex < 0 then StartIndex := 0;
    EndIndex := i + HalfSpan;
    if EndIndex > N - 1 then EndIndex := N - 1;
    WindowSize := EndIndex - StartIndex + 1;
    // 2. Выделение памяти под окно и копирование данных
    SetLength(Window, WindowSize);
    for j := 0 to WindowSize - 1 do Window[j] := InputData[StartIndex + j];
    // 3. Сортировка окна с помощью Generics
    TArrayHelper<Double>.Sort(Window);
    // 4. Выбор медианы (центральный элемент)
    OutputData[i] := Window[WindowSize div 2];
  end;
end;

class procedure TSmoother.LowessMethod(const XData, YData: TDoubleArray; var OutputData: TDoubleArray; const Span: Integer);
// XData, YData: входные массивы.
// OutputData: сглаженный массив.
// Span: ширина окна (должна быть нечетной).
var
  i, j, N, HalfSpan: Integer;
  StartIndex, EndIndex, WindowSize: Integer;
  dMax, Dist: Double;
  Weights: TDoubleArray;
  SumW, SumWX, SumWY, SumWXX, SumWXY, Xw, Yw: Double;
  Beta0, Beta1: Double;
begin
  N := Length(XData);
  if (N = 0) or (Span < 3) then Exit;
  HalfSpan := (Span - 1) div 2;
  SetLength(OutputData, N);
  SetLength(Weights, Span);

  for i := 0 to N - 1 do begin
    StartIndex := i - HalfSpan;
    if StartIndex < 0 then StartIndex := 0;
    EndIndex := i + HalfSpan;
    if EndIndex > N - 1 then EndIndex := N - 1;
    WindowSize := EndIndex - StartIndex + 1;

    dMax := 0.0;
    for j := StartIndex to EndIndex do begin
      Dist := Abs(XData[j] - XData[i]);
      if Dist > dMax then dMax := Dist;
    end;

    SumW := 0.0;
    SumWX := 0.0;
    SumWY := 0.0;

    for j := StartIndex to EndIndex do begin
      if dMax > 0.0 then begin
        Dist := Abs(XData[j] - XData[i]) / dMax;
        Weights[j - StartIndex] := Math.Power(1.0 - Dist * Dist * Dist, 3.0);
      end else begin
        Weights[j - StartIndex] := 1.0;
      end;
      SumW := SumW + Weights[j - StartIndex];
      SumWX := SumWX + Weights[j - StartIndex] * XData[j];
      SumWY := SumWY + Weights[j - StartIndex] * YData[j];
    end;

    if SumW > 0.0 then begin
      Xw := SumWX / SumW;
      Yw := SumWY / SumW;

      SumWXX := 0.0;
      SumWXY := 0.0;
      for j := StartIndex to EndIndex do begin
        SumWXX := SumWXX + Weights[j - StartIndex] * (XData[j] - Xw) * (XData[j] - Xw);
        SumWXY := SumWXY + Weights[j - StartIndex] * (XData[j] - Xw) * (YData[j] - Yw);
      end;

      if SumWXX > 1e-12 then begin
        Beta1 := SumWXY / SumWXX;
        Beta0 := Yw - Beta1 * Xw;
        OutputData[i] := Beta0 + Beta1 * XData[i];
      end else begin
        OutputData[i] := Yw;
      end;
    end else begin
      OutputData[i] := YData[i];
    end;
  end;
end;

end.
