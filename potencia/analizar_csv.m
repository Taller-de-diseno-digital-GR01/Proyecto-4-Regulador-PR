function analizar_csv(ruta)
  % fundamental, fase y error de un CSV de receptor_pc.py, imprime la fila lista para pegar en la tabla 12.9 del informe
  % se corre con octave --eval "addpath('potencia'); analizar_csv('docs/informe/mediciones/archivo.csv')"
  graphics_toolkit('gnuplot');
  d = dlmread(ruta, ',', 1, 0); % t_s, corriente_a, i_ref_a, duty, saturado, dato_ausente, habilitado, falla
  t = d(:, 1); i_ = d(:, 2); ref = d(:, 3);
  w0 = 2 * pi * 50;
  periodos = floor((t(end) - t(1)) * 50 + 1e-9);
  if periodos < 5
    error('la ventana tiene %d periodos y el enunciado pide al menos 5', periodos);
  end
  v = t >= t(end) - periodos / 50 - 1e-9;
  m = [sin(w0 * t(v)) cos(w0 * t(v)) ones(nnz(v), 1)];
  c = m \ i_(v); cr = m \ ref(v);
  amp = hypot(c(1), c(2)); amp_ref = hypot(cr(1), cr(2));
  fase = (atan2(c(2), c(1)) - atan2(cr(2), cr(1))) * 180 / pi;
  fprintf('| %s | %d | %.4f | %.4f | %.2f | %.2f | %.4f | %.4f |\n', ruta, periodos, amp_ref, amp, 100 * abs(amp - amp_ref) / amp_ref, fase, c(3), std(i_(v) - m * c));
  figure('visible', 'off');
  plot(t, ref, t, i_); grid on; xlabel('t (s)'); ylabel('i (A)'); legend('referencia', 'corriente');
  print('-dpng', '-r110', [ruta(1:end - 4) '.png']);
end
