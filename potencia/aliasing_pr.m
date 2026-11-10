function aliasing_pr()
  % seccion de aliasing de potencia/diseno_pr.md, error de la fundamental segun donde cae la captura
  L = 2e-3;
  R = 10;
  vdc = 18;
  fs = 20000;
  kr = 3000;
  kp = sqrt(R ^ 2 + (2 * pi * 1000 * L) ^ 2);
  ts = 1 / fs;
  m_pico = abs(R + 1i * 2 * pi * 50 * L) / vdc; % indice pico con 1.0 A, pa ubicar el flanco

  casos = {
    'valle', 0, 1.0;
    'valle +200 ns', 200e-9, 1.0;
    'valle -200 ns', -200e-9, 1.0;
    'valle +400 ns', 400e-9, 1.0;
    'valle -400 ns', -400e-9, 1.0;
    'pico', ts / 2, 1.0;
    'pico +200 ns', ts / 2 + 200e-9, 1.0;
    '0.91 us antes del valle', -0.91e-6, 1.0;
    '0.91 us antes del valle, 0.2 A', -0.91e-6, 0.2;
    '0.1 us antes del valle', -0.1e-6, 1.0;
    'centro del pulso -200 ns', ts / 4 - 200e-9, 1.0;
    'centro del pulso +200 ns', ts / 4 + 200e-9, 1.0;
    'valle, 0.2 A', 0, 0.2;
    'valle +200 ns, 0.2 A', 200e-9, 0.2;
    'valle -200 ns, 0.2 A', -200e-9, 0.2;
    'centro del pulso -200 ns, 0.2 A', ts / 4 - 200e-9, 0.2;
    'centro del pulso +200 ns, 0.2 A', ts / 4 + 200e-9, 0.2;
    'flanco del pulso', (1 - m_pico) * ts / 4, 1.0;
    '5 us', 5e-6, 1.0;
    '7.8 us', 7.8e-6, 1.0;
    '20 us', 20e-6, 1.0;
  };
  for k = 1:size(casos, 1)
    fprintf('%s, %.2f %%\n', casos{k, 1}, conmutado(kp, kr, L, R, vdc, fs, casos{k, 3}, casos{k, 2}));
  end
end

function err = conmutado(kp, kr, L, R, vdc, fs, amp, adelanto)
  % puente unipolar con portadora de 2500 cuentas a 100 MHz, la carga RL resuelta exacta entre flancos, sin tiempo muerto ni cuantizacion del ADC
  ts = 1 / fs;
  t_clk = 1e-8;
  u_max = 0.92;
  w0 = 2 * pi * 50;
  tau = L / R;
  theta = w0 / fs;
  b0 = kr * sin(theta) / (2 * w0);
  a1 = -2 * cos(theta);
  n = round(fs / 50);
  periodos = 30;
  medidos = 5; % los ultimos, ya en regimen
  sub = ((0:23) + 0.5) / 24; % puntos medios de cada tramo pa integrar la fundamental
  t_muestra = mod(adelanto, ts); % si es negativo cae en el periodo anterior al valle
  ik = 0;
  e1 = 0;
  e2 = 0;
  r1 = 0;
  r2 = 0;
  m = 0;
  m_sig = 0;
  fi = 0;
  fr = 0;
  for k = 0:periodos * n - 1
    t0 = k * ts;
    q = min(abs(m), 1);
    ea = round((1 - q) * ts / 4 / t_clk) * t_clk; % el comparador cambia en un flanco de reloj
    eb = round((1 + q) * ts / 4 / t_clk) * t_clk;
    bordes = [0, ea, eb, ts - eb, ts - ea, ts];
    tension = [0, 1, 0, 1, 0] * sign(m) * vdc; % unipolar, cero en el valle y en el pico, +-Vdc en el pulso
    for j = 1:5
      dt = bordes(j + 1) - bordes(j);
      if dt <= 0
        continue;
      end
      v = tension(j);
      if k >= (periodos - medidos) * n
        t = bordes(j) + sub * dt;
        i = v / R + (ik - v / R) * exp(-sub * dt / tau);
        giro = exp(-1i * w0 * (t0 + t));
        fi = fi + sum(i .* giro) * dt / numel(sub);
        fr = fr + sum(amp * sin(w0 * (t0 + t)) .* giro) * dt / numel(sub);
      end
      if t_muestra >= bordes(j) && t_muestra < bordes(j + 1)
        muestra = v / R + (ik - v / R) * exp(-(t_muestra - bordes(j)) / tau);
      end
      ik = v / R + (ik - v / R) * exp(-dt / tau);
    end
    valle = k + (adelanto < 0); % una captura adelantada es la del valle siguiente
    e = amp * sin(w0 * valle * ts) - muestra;
    r = b0 * e - b0 * e2 - a1 * r1 - r2;
    u = (kp * e + r) / vdc;
    if abs(u) > u_max
      u = sign(u) * u_max;
      r = u * vdc - kp * e; % anti-windup de pr_discreto.md h.5
    end
    e2 = e1;
    e1 = e;
    r2 = r1;
    r1 = r;
    if adelanto < 0
      m = m_sig; % la muestra del valle k+1 rige desde el valle k+2, igual que con captura en el valle
      m_sig = u;
    else
      m = u;
    end
  end
  err = 100 * (abs(fi) - abs(fr)) / abs(fr);
end
