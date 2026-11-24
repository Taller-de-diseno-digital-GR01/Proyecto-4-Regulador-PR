function r = analizar_osc(ruta, r_shunt, fsw)
  % fundamental, RMS y rizado de una captura CSV del osciloscopio (formato Keysight, dos filas de encabezado)
  % la columna 2 es la tensión sobre las resistencias externas, que se divide entre r_shunt para tener la corriente
  % se corre con octave --eval "addpath('potencia'); analizar_osc('potencia/mediciones/2026-11-24/D3_05A_Rnom_osc_largo.csv', 9.6)"
  if nargin < 3, fsw = 20e3; end
  fid = fopen(ruta, 'r');
  c = textscan(fid, '%f %f', 'Delimiter', ',', 'HeaderLines', 2);
  fclose(fid);
  t = c{1}; v = c{2};
  ok = ~isnan(t) & ~isnan(v);
  t = t(ok); v = v(ok);
  i_ = v / r_shunt;
  dt = median(diff(t));
  w0 = 2 * pi * 50;
  r = struct('archivo', ruta, 'dt', dt);

  % fundamental por mínimos cuadrados sobre períodos enteros de 50 Hz, igual que analizar_csv.m
  periodos = floor((t(end) - t(1)) * 50 + 1e-9);
  if periodos >= 1
    sel = t <= t(1) + periodos / 50 + 1e-12;
    m = [sin(w0 * t(sel)) cos(w0 * t(sel)) ones(nnz(sel), 1)];
    k = m \ i_(sel);
    r.periodos = periodos;
    r.pico = hypot(k(1), k(2));
    r.fase = atan2(k(2), k(1)) * 180 / pi;
    r.continua = k(3);
    r.rms_fund = r.pico / sqrt(2);
    r.rms_total = sqrt(mean(i_(sel) .^ 2));
    if periodos < 5
      fprintf('aviso, la ventana tiene %d períodos de 50 Hz y el enunciado pide al menos 5\n', periodos);
    end
  end

  % rizado, la corriente menos su promedio móvil de un período de conmutación, pico a pico en cada período
  n = round(1 / (fsw * dt));
  if n >= 20
    lenta = conv(i_, ones(n, 1) / n, 'same');
    rizo = i_ - lenta;
    bloques = floor((numel(rizo) - 2 * n) / n);
    pp = zeros(bloques, 1);
    for b = 1:bloques
      tramo = rizo(n + (b - 1) * n + (1:n));
      pp(b) = max(tramo) - min(tramo);
    end
    r.rizado_max = max(pp);
    r.rizado_mediana = median(pp);
  else
    fprintf('aviso, %.2g s por punto deja %d puntos por período de conmutación, no alcanza para el rizado (hacen falta 20 o más)\n', dt, n);
    r.rizado_max = NaN;
    r.rizado_mediana = NaN;
  end

  fprintf('%s | dt %.3g s | %d períodos | pico %.4f A | fase %.2f° | continua %.4f A | RMS fund %.4f A | RMS total %.4f A | rizado máx %.4f A pp | mediana %.4f A pp\n', ...
          ruta, dt, r.periodos, r.pico, r.fase, r.continua, r.rms_fund, r.rms_total, r.rizado_max, r.rizado_mediana);
end
