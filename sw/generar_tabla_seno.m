function generar_tabla_seno(salida)
  if nargin < 1
    salida = fullfile(fileparts(mfilename('fullpath')), 'tabla_seno.h'); % por defecto al lado del script, en sw/
  end
  cuarto = 256; % ref_senoidal.c saca el índice con 8 bits de la fase, cambiarlo es cambiar los shifts
  valores = (0:cuarto) * (pi / 2) / cuarto;
  valores = sin(valores); % 257 puntos, el último es sin(pi/2) = 1 justo

  f = fopen(salida, 'w');
  if f < 0 % fopen no tira error solo, devuelve -1
    error('generar_tabla_seno:salida', 'no se pudo abrir %s', salida);
  end
  fprintf(f, '// Generado por sw/generar_tabla_seno.m, no editar a mano\n');
  fprintf(f, '#ifndef TABLA_SENO_H\n#define TABLA_SENO_H\n\n#include "numerico.h"\n\n');
  fprintf(f, '#define TABLA_SENO_CUARTO %du\n\n', cuarto);
  fprintf(f, '// Solo la incluye ref_senoidal.c, por eso puede ir static en el header\n');
  fprintf(f, 'static const valor_t tabla_seno[TABLA_SENO_CUARTO + 1] = {\n');
  for k = 1:numel(valores)
    fprintf(f, '  VALOR(%s),\n', literal_float(valores(k)));
  end
  fprintf(f, '};\n\n#endif\n');
  fclose(f);
end

function s = literal_float(x) % igual que en generar_pr_params.m
  s = sprintf('%.9g', x);
  if ~any(s == '.' | s == 'e') % 1f o 0f no compilan en C, hace falta el punto
    s = [s '.0'];
  end
  s = [s 'f'];
end
