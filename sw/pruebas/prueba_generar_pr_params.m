addpath(fullfile(fileparts(mfilename('fullpath')), '..')); % sw/, pa encontrar generar_pr_params

ruta = [tempname() '.h']; % no pisa el pr_params.h de verdad
generar_pr_params('estructura', 'ideal', 'metodo', 'tustin_prewarp', 'kp', 6.59, 'kr', 1000, 'vdc', 18, 'fs', 20000, 'u_max', 0.92, 'salida', ruta);
texto = fileread(ruta);
delete(ruta);
leer = @(nombre) str2double(regexp(texto, ['#define ' nombre ' VALOR\(([^)]+)f\)'], 'tokens', 'once')); % saca el numero de adentro de VALOR(...f)

errores = 0;
casos = {
  abs(leer('PR_KP') - 0.3661) < 5e-5, 'KP no es el de diseno_pr.md'; % 6.59/18, tolerancia por los 4 decimales del doc
  abs(leer('PR_B0') - 1.3888e-3) < 1e-7, 'B0 no es el de diseno_pr.md';
  leer('PR_B1') == 0, 'B1 no es cero';
  leer('PR_B2') == -leer('PR_B0'), 'B2 no es -B0';
  abs(leer('PR_A1') + 1.99975) < 5e-6, 'A1 no es el de diseno_pr.md';
  leer('PR_A2') == 1, 'A2 no es uno';
  leer('PR_U_MAX') == 0.92, 'U_MAX no pasó tal cual';
  abs(max(angle(roots([1, leer('PR_A1'), leer('PR_A2')]))) * 20000 / (2 * pi) - 50) < 0.01, 'el polo no quedó en 50 Hz'; %ojo, ya con A1 redondeado
  ~isempty(strfind(texto, '#define PR_FRECUENCIA_MUESTREO_HZ 20000u')), 'la frecuencia de muestreo no quedó como entero';
};
for k = 1:size(casos, 1) % cada fila es {condicion, mensaje}
  if ~casos{k, 1}
    fprintf('FALLA, %s\n', casos{k, 2});
    errores = errores + 1;
  end
end

fprintf('prueba_generar_pr_params, %d errores\n', errores);
if errores > 0 % error() y no exit pa no cerrar matlab si se corre desde la GUI
  error('prueba_generar_pr_params:falla', '%d errores', errores);
end
