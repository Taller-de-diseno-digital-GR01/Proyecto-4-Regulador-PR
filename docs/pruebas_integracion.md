# Pruebas de integración, qué medir

Lista de lo que hay que medir al probar todo junto (Basys3, Block Design, `sw/`, puente H, carga y PR) para poder decir que funciona. El orden de los ensayos energizados y los valores esperados de la corriente están en el plan de pruebas de [`diseno_pr.md`](../potencia/diseno_pr.md), acá no se repiten las cuentas, se anota qué se mide en cada etapa, con qué instrumento y cuándo se da por bueno. Lo que falle en una etapa se arregla antes de pasar a la siguiente.

## Ya confirmado, software de Persona D

- Se da por bueno y no se vuelve a medir el PR, la referencia senoidal, el supervisor de falla, el buffer circular, `lazo_control`, `control_principal` (botones, switches, habilitación), la exportación por UART y `receptor_pc`.
- Lo que sí se usa de ahí es la exportación y `receptor_pc` como instrumento, para sacar la fundamental y el error de cada ensayo energizado.
- Lo que queda pendiente de esa parte es solo lo que depende del hardware real, la fase y el retardo de la ISR contra el trigger y la ganancia y el offset del sensor.

## Antes de tocar la potencia

- Bitstream y plataforma. El bitstream carga, `main` arranca y el Timer espera al segundo avance del contador del XADC. Si el sondeo vence, queda el LED de falla y el Timer detenido.
- Pines. Las cuatro compuertas, `pwm_trigger_o` y el pin de depuración de la ISR salen donde dice `basys3.xdc`, vistos con el analizador (sesión descrita en [`TODO.md`](TODO.md)).
- Compuertas con `freq_sel = 01`. Período de portadora de 5000 ciclos (50 µs, 20 kHz) en cada pierna, complementarias dentro de la pierna, y con `duty_ref = 0` las dos piernas simétricas.
- Tiempo muerto. Entre el apagado de una compuerta y el encendido de su complementaria pasan 1 µs (100 ciclos). Se mide en las dos piernas y en los dos flancos, con osciloscopio y no solo con el analizador. Si da distinto de 1 µs se recalcula la predicción del paso 1 energizado.
- Nunca alta y baja de una misma pierna encendidas a la vez, ni en el arranque, ni al cambiar `duty_ref` a medio período, ni al bajar `enable`.
- Cambio de `duty_ref` solo en la frontera de actualización. Escribir valores distintos a mitad de período no genera pulsos partidos.
- Apagado. Al bajar `enable` el pulso en curso termina entero y `running` baja después, leído desde software.
- Saturación. Escribir un `duty_ref` fuera de rango deja la salida en el máximo, no en el valor envuelto.
- Trigger. `pwm_trigger_o` cae un ciclo después del valle de la portadora, en las tres frecuencias, y la captura del ADC queda en el centro del pulso.
- ADC con 0 A. La cuenta es `ADC_OFFSET_CUENTAS` (2048, 0,5 V) con ruido de pocas cuentas, y la corriente que reporta el XADC se compara con la de la sonda (#32). Se anota la ganancia y el offset reales para reemplazar el 8,138e-4 A por cuenta provisional.
- Falla sin carga. Con un valor de umbral bajo la falla baja `enable`, enciende el LED y no rearma sola. Con el Pmod al aire la cuenta cae fuera de 16 a 4079 y también tiene que enclavar.

## El lazo en tiempo real

- Período de la ISR en el pin de depuración, 50 µs (5000 ciclos) entre flancos de subida, con su jitter pico a pico. Se mide con el lazo habilitado y también deshabilitado.
- Duración de la ISR, ancho del pulso del pin. Tiene que dejar tiempo al lazo principal, y se anota el peor caso con el PR corriendo y con la falla enclavada.
- Fase de la ISR contra `pwm_trigger_o`. Estable de un reinicio a otro y sin deriva. Se repite tras varios reinicios.
- Retardo efectivo, desde la captura hasta el cambio en las compuertas, contra los 75 µs del modelo más `τF`. Con unos 49 µs de más el margen de ganancia baja a 6 dB, y si se pasa de eso se rehace la sintonización.
- Con la caché de instrucciones y sin ella, si se alcanza a probar las dos, para decidir cómo se justifica el punto de la caché del enunciado.

## Energizado, por pasos

Con los instrumentos de cada ensayo (osciloscopio sobre la corriente de la carga y sobre las compuertas, `receptor_pc` sobre el histórico) y empezando en 12 V y 0,2 A, como dice `diseno_pr.md`.

- Paso 1, lazo abierto. Amplitud y desfase de la corriente contra la predicción de 0,104 A, 0,393 A y 0,874 A a 18 V. Fuera de 10 % se detiene la prueba. Sirve para validar la ganancia del sensor, el signo y los `L` y `R` medidos (#31).
- Paso 2, solo proporcional. Error de amplitud de unos 57 %, 46 % y 43 % con 0,2, 0,5 y 1,0 A. Si sale muy distinto, la planta o el retardo no son los del modelo.
- Paso 3, PR completo con 0,2, 0,5 y 1,0 A. Error de la fundamental menor a 10 % en al menos cinco períodos en régimen, calculado con `receptor_pc`, y rizado menor a 0,20 A pico a pico medido con el osciloscopio, que el histórico no ve.
- Paso 4, cambios de amplitud de 0,2 a 0,5 A y de 0,5 a 1,0 A. Error de 16,6 % y 15,0 % en el primer período y menos de 6 % en el segundo, como referencia para detectar desvíos grandes.
- Paso 5, cambio de `R` de al menos 25 % con 0,5 A. Error de 5,5 % en el primer período y bajando, sin disparar el umbral de falla.
- Saturación. `saturado` no aparece en régimen con 18 V y 1,0 A, y `duty_ref` queda por debajo de 0,92.
- Falla con carga. Una sobrecorriente real (arriba de 1,3 A) baja las cuatro compuertas, enciende el LED y el sistema no rearma solo. Se prueba con el PR corriendo, no solo en vacío.
- Deshabilitar y volver a habilitar a mitad de un ensayo. El primer período tras habilitar no trae escalón de corriente, porque `duty_ref` y el PR arrancan en cero.
- Temperatura de los MOSFET, de la resistencia de carga (potencia disipada, #27) y de la fuente tras unos minutos en 1,0 A. Se anota el tiempo del ensayo.

## Qué se guarda de cada ensayo

- Referencia, corriente medida, tensión sobre la carga y señales PWM en la misma captura, con pico y RMS bien rotulados.
- Histórico exportado y el comando de `receptor_pc` con el que se sacó la fundamental.
- Valores de `Vdc`, `R`, `L`, tiempo muerto y `freq_sel` con los que se corrió, para poder reproducir la medición.
- Qué falló, qué se cambió y en qué commit quedó corregido, para el informe y para el repositorio.

## Qué decide que está todo bien

- Compuertas sin cruce y con 1 µs de tiempo muerto, trigger en el valle.
- ISR de 50 µs con jitter estable, retardo medido dentro del margen del modelo y exportación sin efecto sobre ambos.
- Error de la fundamental menor a 10 % en 0,2, 0,5 y 1,0 A, en al menos cinco períodos, y rizado menor a 0,20 A pico a pico.
- Cambio de amplitud y cambio de `R` de 25 % o más recuperados sin saturar ni disparar la falla.
- Falla enclavada y apagado seguro verificados con la potencia real.
