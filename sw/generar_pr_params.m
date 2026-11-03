function generar_pr_params(varargin)
  escalar = @(x) isnumeric(x) && isscalar(x);
  p = inputParser;
  p.FunctionName = 'generar_pr_params';
  p.addParameter('estructura', '', @ischar);
  p.addParameter('metodo', '', @ischar);
  p.addParameter('kp', [], escalar);
  p.addParameter('kr', [], escalar);
  p.addParameter('amortiguamiento', [], escalar);
  p.addParameter('vdc', [], escalar);
  p.addParameter('fs', [], @(x) escalar(x) && x > 0 && x == round(x));
  p.addParameter('u_max', [], escalar);
  p.addParameter('salida', fullfile(fileparts(mfilename('fullpath')), 'pr_params.h'), @ischar);
  p.parse(varargin{:});
  a = p.Results;

  requeridos = {'estructura', 'metodo', 'kp', 'kr', 'vdc', 'fs', 'u_max'};
  for k = 1:numel(requeridos)
    if isempty(a.(requeridos{k}))
      error('generar_pr_params:falta', 'falta el parámetro %s', requeridos{k});
    end
  end
  estructura = validatestring(a.estructura, {'ideal', 'amortiguado'});
  metodo = validatestring(a.metodo, {'tustin', 'tustin_prewarp', 'zoh', 'impulso'});
  if strcmp(estructura, 'amortiguado') && isempty(a.amortiguamiento)
    error('generar_pr_params:falta', 'la estructura amortiguado necesita amortiguamiento');
  end

  coef = coeficientes_resonante(estructura, a.kr, a.fs, metodo, a.amortiguamiento);
  escala = 1 / a.vdc; % el PWM recibe índice de modulación, así la ISR no divide entre Vdc
  coef(1:3) = coef(1:3) * escala;
  escribir_header(a.salida, a.fs, a.kp * escala, coef, a.u_max);
end

function coef = coeficientes_resonante(estructura, kr, fs, metodo, amortiguamiento)
  w0 = 2 * pi * 50;
  theta = w0 / fs;
  if strcmp(estructura, 'ideal') && strcmp(metodo, 'tustin_prewarp')
    b0 = kr * sin(theta) / (2 * w0); % forma cerrada de potencia/diseno_pr.md
    coef = [b0, 0, -b0, -2 * cos(theta), 1];
    return;
  end
  % TODO: Revisar con PEDP si hace falta otra combinación, solo la ideal con tustin_prewarp está acordada
  error('generar_pr_params:sin_definir', 'resonante %s con %s sin definir', estructura, metodo);
end

function escribir_header(ruta, fs, kp, coef, u_max)
  f = fopen(ruta, 'w');
  if f < 0
    error('generar_pr_params:salida', 'no se pudo abrir %s', ruta);
  end
  fprintf(f, '// Generado por sw/generar_pr_params.m, no editar a mano\n');
  fprintf(f, '#ifndef PR_PARAMS_H\n#define PR_PARAMS_H\n\n#include "numerico.h"\n\n');
  fprintf(f, '#define PR_FRECUENCIA_MUESTREO_HZ %du\n', fs);
  nombres = {'PR_KP', 'PR_B0', 'PR_B1', 'PR_B2', 'PR_A1', 'PR_A2', 'PR_U_MAX'};
  valores = [kp, coef, u_max];
  for k = 1:numel(nombres)
    fprintf(f, '#define %s VALOR(%s)\n', nombres{k}, literal_float(valores(k)));
  end
  fprintf(f, '\n#endif\n');
  fclose(f);
end

function s = literal_float(x)
  s = sprintf('%.9g', x); % 9 cifras dejan el float idéntico sin ensuciar 0.98
  if ~any(s == '.' | s == 'e')
    s = [s '.0'];
  end
  s = [s 'f'];
end
