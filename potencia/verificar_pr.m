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

  fprintf('\nMargenes segun Kr\n');
  for k = [1000 3000 5000]
    imprimir_margenes(sprintf('Kr %d', k), kp, k, L, R, td, []);
  end

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

end

function kp = kp_cruce(fc, L, R)
  kp = sqrt(R ^ 2 + (2 * pi * fc * L) ^ 2); % ganancia unitaria en fc sin contar el resonante
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

