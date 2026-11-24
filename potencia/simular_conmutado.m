function simular_conmutado(R, L, vdc, vdc_pr)
  % lazo cerrado conmutado con puente H unipolar, tiempo muerto, muestra en el valle, orden aplicada en el valle siguiente y ADC cuantizado
  % se corre desde la raiz con octave --eval "addpath('potencia'); simular_conmutado" y acepta R, L y vdc medidos
  if nargin < 3, R = 9; L = 200e-6; vdc = 18; end
  if nargin < 4, vdc_pr = vdc; end % tension con que se normalizaron los coeficientes del firmware
  graphics_toolkit('gnuplot');
  casos = {'0,2 A', 0.2, 0.2, R, R; '0,5 A', 0.5, 0.5, R, R; '1,0 A', 1.0, 1.0, R, R; ...
           '0,2 a 0,5 A', 0.2, 0.5, R, R; '0,5 a 1,0 A', 0.5, 1.0, R, R; 'R +33 %, 0,5 A', 0.5, 0.5, R, R * 4 / 3; ...
           'esquina R -25 %, 1,0 A', 1.0, 1.0, 0.75 * R, 0.75 * R; 'esquina R +25 %, 1,0 A', 1.0, 1.0, 1.25 * R, 1.25 * R};
  fid = fopen('docs/informe/evidencia/modelo_conmutado.txt', 'w');
  fprintf(fid, 'R=%g ohm, L=%g uH, Vdc=%g V, 20 kHz, tiempo muerto 1 us, paso 0,5 us, ADC de 1,1118 mA por cuenta\n', R, L * 1e6, vdc);
  fprintf(fid, 'caso | ref (A) | fundamental fisica (A) | error (%%) | fase (grados) | fundamental muestreada (A) | error muestreada (%%) | rizado maximo (A pp) | saturacion\n');
  for c = 1:size(casos, 1)
    [m, t, i_f, ref] = un_caso(casos{c, 2}, casos{c, 3}, casos{c, 4}, casos{c, 5}, L, vdc, vdc_pr);
    fprintf(fid, '%s | %.3f | %.4f | %.2f | %.2f | %.4f | %.2f | %.3f | %d\n', casos{c, 1}, casos{c, 3}, m(1), 100 * abs(m(1) - casos{c, 3}) / casos{c, 3}, m(2), m(3), 100 * abs(m(3) - casos{c, 3}) / casos{c, 3}, m(4), m(5));
    if c == 2
      figure('visible', 'off'); k = t >= 0.4 & t < 0.44;
      subplot(2, 1, 1); plot(t(k), i_f(k)); grid on; ylabel('i (A)'); title('0,5 A pico, cuatro periodos de 50 Hz');
      k2 = t >= 0.4 & t < 0.4005; subplot(2, 1, 2); plot(t(k2) * 1e3, i_f(k2)); grid on; ylabel('i (A)'); xlabel('t (ms)'); title('rizado de conmutacion');
      print('-dpng', '-r110', 'docs/informe/figuras/conmutado_05A.png');
    end
    printf('%s listo\n', casos{c, 1});
  end
  fclose(fid);
end

function [m, tt, i_f, ref_s] = un_caso(a0, a1, r0, r1, L, vdc, vdc_pr)
  fs = 20000; ts = 1 / fs; dt = 0.5e-6; npp = round(ts / dt); nd = round(1e-6 / dt);
  kp = 4.5; kr = 10000; w0 = 2 * pi * 50; th = w0 * ts;
  b0 = kr * sin(th) / (2 * w0) / vdc_pr; a1c = -2 * cos(th); kpn = kp / vdc_pr;
  kA = 1.1118e-3; tfin = 0.5; np = round(tfin * fs);
  i_f = zeros(np * npp, 1); tt = (0:np * npp - 1)' * dt;
  prom = zeros(np, 1); mues = zeros(np, 1); ref_s = zeros(np, 1); tp = zeros(np, 1);
  i_ = 0; amp = a0; e1 = 0; e2 = 0; rr1 = 0; rr2 = 0; u_pend = 0; sat = 0;
  chA = 0; clA = 0; chB = 0; clB = 0; rizado = zeros(np, 1);
  for k = 1:np
    t0 = (k - 1) * ts; tp(k) = t0;
    if t0 >= 0.2, obj = a1; R = r1; else obj = a0; R = r0; end
    amp = amp + max(-0.0025, min(0.0025, obj - amp));
    ref = amp * sin(w0 * t0);
    muestra = round(i_ / kA) * kA;
    e = ref - muestra; rr = b0 * e - b0 * e2 - a1c * rr1 - rr2;
    u = kpn * e + rr; if abs(u) > 0.92, sat = 1; end
    u = max(-0.92, min(0.92, u)); if abs(u) >= 0.92 && abs(kpn * e + rr) > 0.92, rr = u - kpn * e; end
    e2 = e1; e1 = e; rr2 = rr1; rr1 = rr;
    uc = u_pend; u_pend = u;
    dA = (1 + uc) / 2; dB = (1 - uc) / 2;
    a = exp(-R * dt / L); base = (k - 1) * npp;
    for m_ = 1:npp
      tau = (m_ - 0.5) / npp; c = 2 * tau; if tau > 0.5, c = 2 - 2 * tau; end
      if c < dA, chA = chA + 1; clA = 0; else clA = clA + 1; chA = 0; end
      if c < dB, chB = chB + 1; clB = 0; else clB = clB + 1; chB = 0; end
      if chA > nd, vA = vdc; elseif clA > nd, vA = 0; elseif i_ > 0, vA = 0; else vA = vdc; end
      if chB > nd, vB = vdc; elseif clB > nd, vB = 0; elseif i_ > 0, vB = vdc; else vB = 0; end
      i_ = a * i_ + (vA - vB) / R * (1 - a);
      i_f(base + m_) = i_;
    end
    seg = i_f(base + 1:base + npp); prom(k) = mean(seg); mues(k) = muestra; ref_s(k) = ref; rizado(k) = max(seg) - min(seg);
  end
  v = tp >= 0.4 & tp < 0.5; tv = tp(v);
  M = [sin(w0 * tv) cos(w0 * tv) ones(nnz(v), 1)];
  cf = M \ prom(v); cm = M \ mues(v); cr = M \ ref_s(v);
  ph = (atan2(cf(2), cf(1)) - atan2(cr(2), cr(1))) * 180 / pi;
  m = [hypot(cf(1), cf(2)), ph, hypot(cm(1), cm(2)), max(rizado(v)), sat];
end
