function figuras_informe(R, L, vdc)
  % genera las figuras 2 a 4 y las cifras del modelo promediado de docs/informe/informe.md
  % se corre desde la raiz del repo con octave potencia/figuras_informe.m
  graphics_toolkit('gnuplot');
  salida = 'docs/informe/figuras/';
  if nargin < 3, R = 9; L = 200e-6; vdc = 18; end
  fs = 20000; ts = 1 / fs; td = 1.5 * ts;
  kp = 4.5; kr = 10000; w0 = 2 * pi * 50;

  f = logspace(1, log10(5000), 800);
  w = 2 * pi * f;
  lazo = (kp + kr * 1i * w ./ (w0 ^ 2 - w .^ 2)) .* exp(-1i * w * td) ./ (R + 1i * w * L);
  figure('visible', 'off');
  subplot(2, 1, 1); semilogx(f, 20 * log10(abs(lazo))); grid on; ylabel('|L| (dB)'); ylim([-40 40]);
  subplot(2, 1, 2); semilogx(f, unwrap(angle(lazo)) * 180 / pi); grid on; ylabel('fase (grados)'); xlabel('f (Hz)');
  print('-dpng', '-r110', [salida 'bode_carga_actual.png']);

  vbus = [12 18 24]; ipk = [0.2 0.5 1.0];
  h = 1 / (2 * fs);
  rizado = zeros(3);
  for i = 1:3
    for j = 1:3
      d = min(abs(R + 1i * w0 * L) * ipk(j) / vbus(i), 0.5);
      rizado(i, j) = vbus(i) / R * (1 - exp(-R * d * h / L)) * (1 - exp(-R * (1 - d) * h / L)) / (1 - exp(-R * h / L));
    end
  end
  figure('visible', 'off');
  plot(ipk, rizado', 'o-'); hold on; plot([0.2 1], [0.2 0.2], 'k--'); grid on;
  xlabel('amplitud de referencia (A pico)'); ylabel('rizado (A pp)'); legend('12 V', '18 V', '24 V', 'limite 0,20 A pp', 'location', 'northwest');
  print('-dpng', '-r110', [salida 'rizado_carga_actual.png']);

  casos = {'0,2 A', 0.2, 0.2, R, R; '0,5 A', 0.5, 0.5, R, R; '1,0 A', 1.0, 1.0, R, R; ...
           '0,2 a 0,5 A', 0.2, 0.5, R, R; '0,5 a 1,0 A', 0.5, 1.0, R, R; 'R +33 %, 0,5 A', 0.5, 0.5, R, R * 4 / 3};
  fid = fopen('docs/informe/evidencia/modelo_promediado.txt', 'w');
  fprintf(fid, 'caso, amplitud final de referencia (A), amplitud final de corriente (A), error (%%), desfase (grados)\n');
  figure('visible', 'off');
  for c = 1:size(casos, 1)
    [t, i_, ref, a, ph] = simular(casos{c, 2}, casos{c, 3}, casos{c, 4}, casos{c, 5}, L, vdc, ts, kp, kr);
    fprintf(fid, '%s, %.4f, %.4f, %.5f, %.4f\n', casos{c, 1}, casos{c, 3}, a, 100 * abs(a - casos{c, 3}) / casos{c, 3}, ph);
    subplot(3, 2, c); plot(t, ref, t, i_); title(casos{c, 1}); xlim([0.25 0.45]); grid on;
  end
  print('-dpng', '-r110', [salida 'transitorios_promediados.png']);
  fprintf(fid, '\nrizado ideal (A pp), filas 12, 18 y 24 V, columnas 0,2 0,5 y 1,0 A pico\n');
  fprintf(fid, '%.4f %.4f %.4f\n', rizado');
  fclose(fid);
end

function [t, i_, ref, amp, fase] = simular(a0, a1, r0, r1, L, vdc, ts, kp, kr)
  w0 = 2 * pi * 50; th = w0 * ts;
  b0 = kr * sin(th) / (2 * w0) / vdc; a1c = -2 * cos(th); kpn = kp / vdc;
  n = round(0.7 / ts); t = (0:n - 1)' * ts;
  i_ = zeros(n, 1); ref = zeros(n, 1);
  amp_k = a0; ik = 0; u1 = 0; e1 = 0; e2 = 0; r_1 = 0; r_2 = 0;
  for k = 1:n
    R = r0; if t(k) >= 0.3, R = r1; end
    if t(k) >= 0.3, objetivo = a1; else objetivo = a0; end
    amp_k = amp_k + max(-0.0025, min(0.0025, objetivo - amp_k));
    ref(k) = amp_k * sin(w0 * t(k));
    i_(k) = ik;
    e = ref(k) - ik;
    rr = b0 * e - b0 * e2 - a1c * r_1 - r_2;
    u = kpn * e + rr; sat = abs(u) > 0.92; u = max(-0.92, min(0.92, u));
    if sat, rr = u - kpn * e; end
    a = exp(-R * ts / L); b = vdc / R * (1 - a);
    ik = a * ik + b * u1; u1 = u;
    e2 = e1; e1 = e; r_2 = r_1; r_1 = rr;
  end
  v = t >= 0.6;
  m = [sin(w0 * t(v)) cos(w0 * t(v)) ones(nnz(v), 1)];
  c = m \ i_(v); cr = m \ ref(v);
  amp = hypot(c(1), c(2)); fase = (atan2(c(2), c(1)) - atan2(cr(2), cr(1))) * 180 / pi;
end
