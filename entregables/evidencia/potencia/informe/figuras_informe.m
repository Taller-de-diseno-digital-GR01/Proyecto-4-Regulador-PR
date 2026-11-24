function figuras_informe()
  % figuras del informe de PEDP, mismo lazo y mismos parametros que verificar_pr.m
  L = 30e-3;
  R = 12;
  fs = 20000;
  kr = 3000;
  td = 1.5 / fs;
  kp = sqrt(R ^ 2 + (2 * pi * 1000 * L) ^ 2);
  carpeta = fileparts(mfilename('fullpath'));
  fig_bode(kp, kr, L, R, td, carpeta);
  fig_retardo(kp, kr, L, R, td, carpeta);
  fig_escalones(kp, kr, L, R, fs, carpeta);
end

function guardar(h, carpeta, nombre)
  set(h, 'paperunits', 'centimeters', 'papersize', [8.8 6.2], 'paperposition', [0 0 8.8 6.2]);
  print(h, fullfile(carpeta, 'fig', [nombre '.pdf']), '-dpdf');
  close(h);
end

function fig_bode(kp, kr, L, R, td, carpeta)
  w0 = 2 * pi * 50;
  f = logspace(log10(80), 4, 4000);
  s = 1i * 2 * pi * f;
  h = figure('visible', 'off');
  casos = {[L R], 'k-'; [0.7 * L 0.75 * R], 'b--'; [1.3 * L 1.25 * R], 'r--'};
  subplot(2, 1, 1);
  for k = 1:3
    g = (kp + kr * s ./ (s .^ 2 + w0 ^ 2)) .* exp(-s * td) ./ (casos{k, 1}(1) * s + casos{k, 1}(2));
    semilogx(f, 20 * log10(abs(g)), casos{k, 2}); hold on;
  end
  semilogx([80 1e4], [0 0], 'k:');
  ylabel('|L| (dB)'); ylim([-30 40]); grid on;
  legend('nominal', 'L y R -30 %, -25 %', 'L y R +30 %, +25 %', 'location', 'northeast');
  subplot(2, 1, 2);
  for k = 1:3
    g = (kp + kr * s ./ (s .^ 2 + w0 ^ 2)) .* exp(-s * td) ./ (casos{k, 1}(1) * s + casos{k, 1}(2));
    semilogx(f, unwrap(angle(g)) * 180 / pi, casos{k, 2}); hold on;
  end
  semilogx([80 1e4], [-180 -180], 'k:');
  xlabel('f (Hz)'); ylabel('fase (grados)'); grid on;
  guardar(h, carpeta, 'bode_lazo');
end

function [fc, mf, mg] = margenes(kp, kr, L, R, td)
  w0 = 2 * pi * 50;
  f = logspace(log10(80), 4, 100000);
  s = 1i * 2 * pi * f;
  g = (kp + kr * s ./ (s .^ 2 + w0 ^ 2)) .* exp(-s * td) ./ (L * s + R);
  m = abs(g);
  fase = unwrap(angle(g));
  ic = find(m(1:end-1) >= 1 & m(2:end) < 1, 1, 'last');
  ip = find(fase(1:end-1) > -pi & fase(2:end) <= -pi, 1);
  fc = f(ic);
  mf = 180 + fase(ic) * 180 / pi;
  mg = -20 * log10(m(ip));
end

function fig_retardo(kp, kr, L, R, td, carpeta)
  extra = 0:5:200;
  mf = zeros(size(extra));
  mg = zeros(size(extra));
  for k = 1:numel(extra)
    [~, mf(k), mg(k)] = margenes(kp, kr, L, R, td + extra(k) * 1e-6);
  end
  h = figure('visible', 'off');
  [ax, h1, h2] = plotyy(extra, mf, extra, mg);
  set(h1, 'color', 'b'); set(h2, 'color', 'r');
  hold(ax(1), 'on'); plot(ax(1), [0 200], [45 45], 'b:');
  hold(ax(2), 'on'); plot(ax(2), [0 200], [6 6], 'r:');
  xlabel('retardo extra (\mus)');
  ylabel(ax(1), 'margen de fase (grados)');
  ylabel(ax(2), 'margen de ganancia (dB)');
  grid on;
  guardar(h, carpeta, 'margenes_retardo');
end

function [i, ref] = lazo(kp, kr, L, R, fs, ref, n_cambio, r_despues)
  % planta por retenedor de orden cero y un muestreo de retardo entre calcular y aplicar, igual que verificar_pr.m
  ts = 1 / fs;
  w0 = 2 * pi * 50;
  theta = w0 / fs;
  b0 = kr * sin(theta) / (2 * w0);
  a1 = -2 * cos(theta);
  a = exp(-R / L * ts);
  b = (1 - a) / R;
  i = zeros(size(ref));
  ik = 0; e1 = 0; e2 = 0; r1 = 0; r2 = 0; v_ant = 0;
  for n = 1:numel(ref)
    if n == n_cambio
      a = exp(-r_despues / L * ts);
      b = (1 - a) / r_despues;
    end
    i(n) = ik;
    e = ref(n) - ik;
    r = b0 * e - b0 * e2 - a1 * r1 - r2;
    v = kp * e + r;
    e2 = e1; e1 = e; r2 = r1; r1 = r;
    ik = a * ik + b * v_ant;
    v_ant = v;
  end
end

function err = error_periodos(i, ref, inicio, periodos, fs)
  w0 = 2 * pi * 50;
  n = round(fs / 50);
  err = zeros(1, periodos);
  for p = 1:periodos
    k = inicio + (p - 1) * n + (0:n-1);
    giro = exp(-1i * w0 * (k - 1) / fs);
    err(p) = 100 * abs(abs(sum(i(k) .* giro)) - abs(sum(ref(k) .* giro))) / abs(sum(ref(k) .* giro));
  end
end

function fig_escalones(kp, kr, L, R, fs, carpeta)
  n = round(fs / 50);
  k = 0:7 * n - 1;
  t = k / fs * 1e3;
  amp = 0.2 * ones(size(k));
  amp(n+1:end) = 1.0;
  ref = amp .* sin(2 * pi * 50 * k / fs);
  i = lazo(kp, kr, L, R, fs, ref, 0, R);
  h = figure('visible', 'off');
  plot(t, ref, 'k-', t, i, 'b-');
  xlabel('t (ms)'); ylabel('corriente (A)'); grid on;
  legend('referencia', 'corriente', 'location', 'northwest');
  guardar(h, carpeta, 'escalon_02_10');

  casos = {[0.2 0.5], [0.5 1.0], [0.2 1.0]};
  e = zeros(3, 5);
  for c = 1:3
    amp = casos{c}(1) * ones(size(k));
    amp(n+1:end) = casos{c}(2);
    ref = amp .* sin(2 * pi * 50 * k / fs);
    i = lazo(kp, kr, L, R, fs, ref, 0, R);
    e(c, :) = error_periodos(i, ref, n + 1, 5, fs);
  end
  kk = 0:(40 + 5) * n - 1;
  ref = 0.5 * sin(2 * pi * 50 * kk / fs);
  i = lazo(kp, kr, L, R, fs, ref, 40 * n + 1, 1.25 * R);
  e(4, :) = error_periodos(i, ref, 40 * n + 1, 5, fs);
  h = figure('visible', 'off');
  plot(1:5, e(1, :), 'o-', 1:5, e(2, :), 's-', 1:5, e(3, :), '^-', 1:5, e(4, :), 'd-');
  hold on; plot([1 5], [10 10], 'k:');
  xlabel('período tras el cambio'); ylabel('error de la fundamental (%)'); grid on;
  legend('0,2 a 0,5 A', '0,5 a 1,0 A', '0,2 a 1,0 A', 'R +25 % a 0,5 A', 'location', 'northeast');
  guardar(h, carpeta, 'error_escalones');
  printf('%s\n', sprintf('%.1f ', e'));
end
