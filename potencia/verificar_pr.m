function verificar_pr()
  % cifras de potencia/diseno_pr.md, en el mismo orden
  L = 2e-3;
  R = 10;
  vdc = 18;
  fs = 20000;
  kr = 3000;
  ts = 1 / fs;
  td = 1.5 * ts; % un muestreo de computo mas medio de actualizacion
  w0 = 2 * pi * 50;
  kp = kp_cruce(1000, L, R);

  z = R + 1i * w0 * L;
  fprintf('|Z| = %.2f ohm, desfase %.1f grados\n', abs(z), -angle(z) * 180 / pi);
  fprintf('indice con %d V, %.3f, %.3f y %.3f para 0.2, 0.5 y 1.0 A\n', vdc, abs(z) * [0.2 0.5 1.0] / vdc);
  fprintf('Kp = %.2f V/A, KP = %.4f, Kr/wc = %.2f\n', kp, kp / vdc, kr / (2 * pi * 1000));

  fprintf('\nMargenes segun fc\n');
  for fc = [500 1000 2000]
    imprimir_margenes(sprintf('fc %d Hz', fc), kp_cruce(fc, L, R), kr, L, R, td, []);
  end

  fprintf('\nKr, margenes y error del escalon de 0.2 a 1.0 A por periodo\n');
  for k = [1000 3000 5000]
    imprimir_margenes(sprintf('Kr %d', k), kp, k, L, R, td, []);
    [err, desfase] = escalon(kp, k, L, R, fs, 0.2, 1.0, R, 5);
    fprintf('  error %s %%, desfase max %.1f grados\n', sprintf('%.1f ', err), max(abs(desfase)));
  end
  p = polos_lazo(kp, kr, L, R, fs);
  fprintf('|z| del resonante %.4f, tau %.1f ms\n', p, -ts / log(p) * 1e3);

  fprintf('\nNominal y esquinas, Kp fijo\n');
  imprimir_margenes('nominal', kp, kr, L, R, td, []);
  for lc = [0.7 1.3] * L
    for rc = [0.75 1.25] * R
      imprimir_margenes(sprintf('L %.1f mH, R %.1f ohm', lc * 1e3, rc), kp, kr, lc, rc, td, []);
    end
  end
  imprimir_margenes('L 1.4 mH con Kp recalculado', kp_cruce(1000, 1.4e-3, R), kr, 1.4e-3, R, td, []);

  fprintf('\nRetardo extra\n');
  for extra = [2 25 50 75] * 1e-6
    imprimir_margenes(sprintf('%g us', extra * 1e6), kp, kr, L, R, td + extra, []);
  end
  fprintf('MG en 6 dB con %d us, MF en 45 grados con %d us, MG en 0 con %d us\n', ...
    retardo_limite(kp, kr, L, R, td, 3, 6), retardo_limite(kp, kr, L, R, td, 2, 45), retardo_limite(kp, kr, L, R, td, 3, 0));

  fprintf('\nFiltro del sensor, nominal y esquina de L 1.4 mH y R 7.5 ohm\n');
  rc_f = @(ff) @(s) 1 ./ (1 + s / (2 * pi * ff));
  bw_f = @(ff) @(s) 1 ./ (1 + sqrt(2) * s / (2 * pi * ff) + (s / (2 * pi * ff)) .^ 2);
  filtros = {'RC 5 kHz', rc_f(5e3); 'RC 3 kHz', rc_f(3e3); 'RC 2 kHz', rc_f(2e3); 'Butterworth 5 kHz', bw_f(5e3)};
  for k = 1:size(filtros, 1)
    imprimir_margenes([filtros{k, 1} ' nominal'], kp, kr, L, R, td, filtros{k, 2});
    imprimir_margenes([filtros{k, 1} ' esquina'], kp, kr, 1.4e-3, 7.5, td, filtros{k, 2});
  end

  fprintf('\nEscalon en las esquinas\n');
  for lc = [0.7 1.3] * L
    for rc = [0.75 1.25] * R
      fprintf('L %.1f mH, R %.1f ohm, %s %%\n', lc * 1e3, rc, sprintf('%.1f ', escalon(kp, kr, lc, rc, fs, 0.2, 1.0, rc, 3)));
    end
  end
  fprintf('0.2 a 0.5 A, %s %%\n', sprintf('%.1f ', escalon(kp, kr, L, R, fs, 0.2, 0.5, R, 3)));
  fprintf('0.5 a 1.0 A, %s %%\n', sprintf('%.1f ', escalon(kp, kr, L, R, fs, 0.5, 1.0, R, 3)));
  fprintf('R de %g a %g ohm a 1.0 A, %s %%\n', R, 1.25 * R, sprintf('%.1f ', cambio_r(kp, kr, L, R, 1.25 * R, fs, 1.0, 3)));

  h = kp * exp(-1i * w0 * td) / (z + kp * exp(-1i * w0 * td));
  fprintf('\nSolo P, error %.1f %%, desfase %.1f grados\n', 100 * (1 - abs(h)), angle(h) * 180 / pi);

  % tiempo muerto de 1 us y RDS(on) de 0.2 ohm por MOSFET, como en la seccion del tiempo muerto de modelo_planta.md
  dv = 2 * vdc * 1e-6 * fs;
  dvf = 4 / pi * dv;
  zr = z + 0.4;
  fprintf('\nTiempo muerto, perdida %.2f V, fundamental %.2f V\n', dv, dvf);
  for iref = [0.2 0.5 1.0]
    m = abs(z) * iref / vdc;
    [i_ab, fi_ab] = fundamental_tm(vdc * m, 0, zr, dvf);
    g = kp * exp(-1i * w0 * td);
    [i_p, fi_p] = fundamental_tm(g * iref, g, zr, dvf);
    fprintf('%.1f A, lazo abierto %.3f A (%.0f %%), %.1f grados, solo P %.3f A, error %.1f %%, %.1f grados\n', ...
      iref, i_ab, 100 * (i_ab / iref - 1), fi_ab, i_p, 100 * (1 - i_p / iref), fi_p);
  end

  fprintf('Pico del escalon de 0.2 a 1.0 A en 20 instantes y en las esquinas, %.3f A\n', pico_escalon(kp, kr, L, R, fs));
  fprintf('Indice maximo del escalon con %d V, %.2f, y con R en %g ohm, %.2f\n', vdc, indice_maximo(kp, kr, L, R, fs, vdc), 1.25 * R, indice_maximo(kp, kr, L, 1.25 * R, fs, vdc));
  fprintf('Con 12 V, %.2f en regimen y %.2f en el escalon\n', abs(z) / 12, indice_maximo(kp, kr, L, R, fs, 12));
end

function [amp, fase] = fundamental_tm(fuente, g, z, dvf)
  % I*(z + g) = fuente - dvf*exp(j*fase de I), la perdida del tiempo muerto va en fase con la corriente, punto fijo en la fase
  i = fuente / (z + g);
  for k = 1:200
    i = (fuente - dvf * exp(1i * angle(i))) / (z + g);
  end
  amp = abs(i);
  fase = angle(i) * 180 / pi;
end

function kp = kp_cruce(fc, L, R)
  kp = sqrt(R ^ 2 + (2 * pi * fc * L) ^ 2); % ganancia unitaria en fc sin contar el resonante
end

function [b0, a1] = resonante(kr, fs)
  w0 = 2 * pi * 50;
  theta = w0 / fs;
  b0 = kr * sin(theta) / (2 * w0); % tustin precorregido, igual que generar_pr_params
  a1 = -2 * cos(theta);
end

function [fc, mf, mg] = margenes(kp, kr, L, R, td, filtro)
  w0 = 2 * pi * 50;
  f = logspace(log10(80), 4, 400000); % arranca arriba de 50 Hz pa que el salto del resonante no ensucie el unwrap
  s = 1i * 2 * pi * f;
  g = (kp + kr * s ./ (s .^ 2 + w0 ^ 2)) .* exp(-s * td) ./ (L * s + R);
  if ~isempty(filtro)
    g = g .* filtro(s);
  end
  m = abs(g);
  fase = unwrap(angle(g));
  ic = find(m(1:end-1) >= 1 & m(2:end) < 1, 1, 'last'); % el cruce mas alto, el resonante mete otros cerca de 50 Hz
  ip = find(fase(1:end-1) > -pi & fase(2:end) <= -pi, 1);
  fc = f(ic);
  mf = 180 + fase(ic) * 180 / pi;
  mg = -20 * log10(m(ip));
end

function imprimir_margenes(nombre, kp, kr, L, R, td, filtro)
  [fc, mf, mg] = margenes(kp, kr, L, R, td, filtro);
  fprintf('%s, cruce %.0f Hz, %.1f grados, %.1f dB\n', nombre, fc, mf, mg);
end

function us = retardo_limite(kp, kr, L, R, td, cual, limite)
  for us = 1:400 % de a un microsegundo alcanza pa lo que se reporta
    r = cell(1, 3);
    [r{:}] = margenes(kp, kr, L, R, td + us * 1e-6, []);
    if r{cual} < limite
      return;
    end
  end
end

function [i, v] = lazo_promedio(kp, kr, L, R, fs, ref, n_cambio, r_despues)
  % corriente promedio, planta por ZOH exacto y un muestreo de retardo entre calcular y aplicar
  ts = 1 / fs;
  [b0, a1] = resonante(kr, fs);
  a = exp(-R / L * ts);
  b = (1 - a) / R;
  i = zeros(size(ref));
  v = zeros(size(ref));
  ik = 0;
  e1 = 0;
  e2 = 0;
  r1 = 0;
  r2 = 0;
  v_ant = 0;
  for n = 1:numel(ref)
    if n == n_cambio
      a = exp(-r_despues / L * ts);
      b = (1 - a) / r_despues;
    end
    i(n) = ik;
    e = ref(n) - ik;
    r = b0 * e - b0 * e2 - a1 * r1 - r2; % b1 = 0 y a2 = 1
    v(n) = kp * e + r;
    e2 = e1;
    e1 = e;
    r2 = r1;
    r1 = r;
    ik = a * ik + b * v_ant;
    v_ant = v(n);
  end
end

function [err, desfase] = error_por_periodo(i, ref, inicio, periodos, fs)
  % error de amplitud de la fundamental, el mismo criterio de receptor_pc
  w0 = 2 * pi * 50;
  n = round(fs / 50);
  err = zeros(1, periodos);
  desfase = zeros(1, periodos);
  for p = 1:periodos
    k = inicio + (p - 1) * n + (0:n-1);
    giro = exp(-1i * w0 * (k - 1) / fs);
    fi = sum(i(k) .* giro);
    fr = sum(ref(k) .* giro);
    err(p) = 100 * abs(abs(fi) - abs(fr)) / abs(fr);
    desfase(p) = angle(fi / fr) * 180 / pi;
  end
end

function [err, desfase] = escalon(kp, kr, L, R, fs, antes, despues, r_despues, periodos)
  % un periodo con la amplitud de antes y el escalon en el cruce por cero
  n = round(fs / 50);
  k = 0:(1 + periodos) * n - 1;
  amp = antes * ones(size(k));
  amp(n+1:end) = despues;
  ref = amp .* sin(2 * pi * 50 * k / fs);
  i = lazo_promedio(kp, kr, L, R, fs, ref, n + 1, r_despues);
  [err, desfase] = error_por_periodo(i, ref, n + 1, periodos, fs);
end

function err = cambio_r(kp, kr, L, R, r_despues, fs, amp, periodos)
  % el cambio de R va con el lazo ya en regimen, por eso los 40 periodos antes
  n = round(fs / 50);
  k = 0:(40 + periodos) * n - 1;
  ref = amp * sin(2 * pi * 50 * k / fs);
  i = lazo_promedio(kp, kr, L, R, fs, ref, 40 * n + 1, r_despues);
  err = error_por_periodo(i, ref, 40 * n + 1, periodos, fs);
end

function [i, v] = escalon_en_fase(kp, kr, L, R, fs, fase)
  % fase de 0 a 19, el escalon cae en ese vigesimo del segundo periodo
  n = round(fs / 50);
  k = 0:6 * n - 1;
  n0 = n + fase * n / 20 + 1;
  amp = 0.2 * ones(size(k));
  amp(n0:end) = 1.0;
  [i, v] = lazo_promedio(kp, kr, L, R, fs, amp .* sin(2 * pi * 50 * k / fs), 0, R);
  v = v(n0:end); % solo desde el escalon, antes viene el arranque desde cero
end

function pico = pico_escalon(kp, kr, L, R, fs)
  pico = 0;
  for lc = [0.7 1 1.3] * L
    for rc = [0.75 1 1.25] * R
      for fase = 0:19
        pico = max(pico, max(abs(escalon_en_fase(kp, kr, lc, rc, fs, fase))));
      end
    end
  end
end

function u = indice_maximo(kp, kr, L, R, fs, vdc)
  u = 0;
  for fase = 0:19
    [~, v] = escalon_en_fase(kp, kr, L, R, fs, fase);
    u = max(u, max(abs(v)) / vdc);
  end
end

function p = polos_lazo(kp, kr, L, R, fs)
  % modulo del polo mas lento en lazo cerrado, estado [i, v anterior, e1, e2, r1, r2]
  ts = 1 / fs;
  [b0, a1] = resonante(kr, fs);
  a = exp(-R / L * ts);
  b = (1 - a) / R;
  m = zeros(6);
  for j = 1:6
    x = zeros(6, 1);
    x(j) = 1;
    e = -x(1);
    r = b0 * e - b0 * x(4) - a1 * x(5) - x(6);
    m(:, j) = [a * x(1) + b * x(2); kp * e + r; e; x(3); r; x(5)];
  end
  p = max(abs(eig(m)));
end
