% Parámetros de la planta y del puente, fuente única para el modelo de PLECS y los scripts de potencia
% Se carga con run('parametros.m') desde los comandos de inicialización del modelo

% Carga RL del montaje (valores nominales, la resistencia del inductor y del cableado se suman a R al medirlas)
R = 10;
L = 2e-3;

% Tensión del bus de continua, la de operación acordada
Vdc = 18;

% Reloj de la FPGA y cuenta máxima de la portadora con freq_sel = 01 (núcleo del PWM)
fclk = 100e6;
MAX = 2500;

% La portadora sube y baja, así que un período dura 2*MAX ciclos
fsw = fclk/(2*MAX);
Ts = 1/fsw;

% Tiempo muerto programado en el núcleo del PWM (DEAD_TIME_CICLOS)
DEAD_TIME_CICLOS = 100;
TM = DEAD_TIME_CICLOS/fclk;

% RDS(on) máxima del IRF520N con VGS = 10 V (PD-91339A, p. 2)
RDSon = 0.20;

% Ensayo en lazo abierto con un duty_ref senoidal fijo, Iref es la corriente pico que se le pide
% El modelo le aplica el índice m = |R + j*2*pi*fref*L|*Iref/Vdc, sin contar tiempo muerto ni RDS(on)
fref = 50;
Iref = 1.0;
