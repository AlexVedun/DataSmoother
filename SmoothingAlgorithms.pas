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
    class procedure SplineMethod(const XData, YData: TDoubleArray; var OutputData: TDoubleArray; const Lambda: Double);
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

class procedure TSmoother.SplineMethod(const XData, YData: TDoubleArray; var OutputData: TDoubleArray; const Lambda: Double);
var
  n, m, i: Integer;
  h, d, e, f, b, u, z, y_val: TDoubleArray;
  D_diag, E_diag, F_diag: TDoubleArray;
  q00, q10, q20, q11, q21, q22: Double;
begin
  n := Length(XData);
  if n < 4 then begin
    SetLength(OutputData, n);
    for i := 0 to n - 1 do OutputData[i] := YData[i];
    Exit;
  end;

  m := n - 2;
  SetLength(h, n - 1);
  for i := 0 to n - 2 do begin
    h[i] := XData[i+1] - XData[i];
    if h[i] <= 0.0 then h[i] := 1e-6; // Prevent division by zero
  end;

  SetLength(d, m);
  SetLength(e, m);
  SetLength(f, m);
  SetLength(b, m);

  for i := 0 to m - 1 do begin
    b[i] := (YData[i+2] - YData[i+1]) / h[i+1] - (YData[i+1] - YData[i]) / h[i];

    d[i] := (h[i] + h[i+1]) / 3.0;
    if i < m - 1 then e[i] := h[i+1] / 6.0 else e[i] := 0.0;
    f[i] := 0.0;

    q00 := 1.0 / h[i];
    q10 := -1.0 / h[i] - 1.0 / h[i+1];
    q20 := 1.0 / h[i+1];

    d[i] := d[i] + Lambda * (q00*q00 + q10*q10 + q20*q20);

    if i < m - 1 then begin
      q11 := 1.0 / h[i+1];
      q21 := -1.0 / h[i+1] - 1.0 / h[i+2];
      e[i] := e[i] + Lambda * (q10*q11 + q20*q21);
    end;

    if i < m - 2 then begin
      q22 := 1.0 / h[i+2];
      f[i] := f[i] + Lambda * (q20*q22);
    end;
  end;

  SetLength(D_diag, m);
  SetLength(E_diag, m);
  SetLength(F_diag, m);

  D_diag[0] := d[0];
  if D_diag[0] = 0.0 then D_diag[0] := 1e-12;
  E_diag[0] := e[0] / D_diag[0];
  F_diag[0] := f[0] / D_diag[0];

  if m > 1 then begin
    D_diag[1] := d[1] - E_diag[0] * E_diag[0] * D_diag[0];
    if D_diag[1] = 0.0 then D_diag[1] := 1e-12;
    if 1 < m - 1 then E_diag[1] := (e[1] - E_diag[0] * F_diag[0] * D_diag[0]) / D_diag[1] else E_diag[1] := 0.0;
    if 1 < m - 2 then F_diag[1] := f[1] / D_diag[1] else F_diag[1] := 0.0;
  end;

  for i := 2 to m - 1 do begin
    D_diag[i] := d[i] - F_diag[i-2] * F_diag[i-2] * D_diag[i-2] - E_diag[i-1] * E_diag[i-1] * D_diag[i-1];
    if D_diag[i] = 0.0 then D_diag[i] := 1e-12;
    if i < m - 1 then
      E_diag[i] := (e[i] - E_diag[i-1] * F_diag[i-1] * D_diag[i-1]) / D_diag[i]
    else E_diag[i] := 0.0;
    if i < m - 2 then
      F_diag[i] := f[i] / D_diag[i]
    else F_diag[i] := 0.0;
  end;

  SetLength(z, m);
  z[0] := b[0];
  if m > 1 then z[1] := b[1] - E_diag[0] * z[0];
  for i := 2 to m - 1 do
    z[i] := b[i] - E_diag[i-1] * z[i-1] - F_diag[i-2] * z[i-2];

  SetLength(y_val, m);
  for i := 0 to m - 1 do y_val[i] := z[i] / D_diag[i];

  SetLength(u, m);
  u[m-1] := y_val[m-1];
  if m > 1 then u[m-2] := y_val[m-2] - E_diag[m-2] * u[m-1];
  for i := m - 3 downto 0 do
    u[i] := y_val[i] - E_diag[i] * u[i+1] - F_diag[i] * u[i+2];

  SetLength(OutputData, n);
  OutputData[0] := YData[0] - Lambda * (u[0] / h[0]);
  OutputData[1] := YData[1] - Lambda * (u[0] * (-1.0/h[0] - 1.0/h[1]));
  if m > 1 then OutputData[1] := OutputData[1] - Lambda * (u[1] / h[1]);

  for i := 2 to n - 3 do begin
    OutputData[i] := YData[i] - Lambda * (u[i-2] / h[i-1] + u[i-1] * (-1.0/h[i-1] - 1.0/h[i]) + u[i] / h[i]);
  end;

  if n > 3 then begin
    OutputData[n-2] := YData[n-2] - Lambda * (u[m-2] / h[m-1] + u[m-1] * (-1.0/h[m-1] - 1.0/h[m]));
    OutputData[n-1] := YData[n-1] - Lambda * (u[m-1] / h[m]);
  end;
end;

end.
