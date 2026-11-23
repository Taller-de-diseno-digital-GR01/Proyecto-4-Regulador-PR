# Uso de la Basys 3 con el control PR

Resumen de lo que hace la placa una vez cargada. El detalle está en los docs de cada módulo en `docs/diseño/modulos/`.

## Carga

`make program` sintetiza si hace falta, baja el bitstream y corre `control_pr.elf` por JTAG. Al arrancar el control queda deshabilitado, con `enable = 0` y los LEDs apagados.

Orden de encendido:

1. Basys 3.
2. Alimentación del sensor y del acondicionador. J3 tiene que dar 0,5 V respecto del GND del JXADC.
3. `BTN_RST`, o `make program` recién en este punto.

Si el firmware arranca con el sensor apagado, el XADC lee cerca de 0 V, la cuenta queda en 16 o menos y LD2 se enclava aunque después se encienda el sensor. Al revés tampoco conviene, con la Basys 3 apagada los diodos de protección del pin conducen y el acondicionador le inyecta corriente a la FPGA sin alimentar (en J3 se ven unos 0,4 V en vez de 0,5 V). Para apagar, primero el sensor y después la Basys 3.

## Botones y switches

- `BTN_RST`, botón central (U18). Reinicia toda la plataforma, MicroBlaze incluido. Es la única forma de salir de una falla.
- `BTN_HABILITAR`, botón de arriba (T18). Habilita o deshabilita el control. Al habilitar reinicia el PR, la fase de la referencia y la rampa de amplitud. Se ignora si hay falla o error de arranque.
- `BTN_EXPORTAR`, botón de abajo (U17). Congela el histórico y lo manda por UART. El control sigue corriendo mientras tanto.
- `SW1 SW0`, amplitud pico de la referencia. `00` da 0 A, `01` da 0,2 A, `10` da 0,5 A y `11` da 1,0 A. Se lee siempre, también con el control andando, y el cambio entra con rampa de 2,5 mA por muestra (de 0 a 1 A en 20 ms).

## LEDs

- LD0 (U16), control habilitado.
- LD1 (E19), sobrecorriente, corriente medida fuera de ±1,3 A.
- LD2 (U19), cuenta del ADC fuera de escala, en 16 o menos o en 4079 o más. Con la ganancia real eso son ±2,26 A, así que en la práctica solo salta con el sensor apagado o desconectado, o el JXADC al aire.
- LD3 (V19), más de 3 interrupciones seguidas sin dato nuevo del XADC.
- LD4 (W18), error de arranque, el XADC no avanzó durante el sondeo inicial. En ese caso el Timer ni siquiera arranca.

Las fallas de LD1 a LD3 se revisan en todas las interrupciones, aunque el control esté deshabilitado. Quedan enclavadas hasta `BTN_RST` y la ISR baja `enable` en la misma iteración que la detecta. Se enciende solo el LED de la primera causa que disparó, aunque después se sumen otras.

Si LD1 se enciende sin haber habilitado, lo primero es medir la salida del acondicionador con la potencia apagada. Tiene que dar 0,5 V, y un corrimiento de 0,285 V ya equivale a 1,3 A.

## Pines

- Compuertas en JA. JA7 `compuerta_b_baja` (H1), JA8 `compuerta_b_alta` (K2), JA9 `compuerta_a_baja` (H2), JA10 `compuerta_a_alta` (G3).
- Depuración en JB1 (A14). Alto mientras corre la ISR, así que el ancho del pulso es la duración del servicio y su período el de muestreo (50 µs).
- Sensor en JXADC. Pin 1 (J3, `vauxp6`) a la salida del acondicionador, pin 7 (K3, `vauxn6`) a su tierra. Rango de 0 a 1 V.
- UART por el USB de la placa (A18), 115200 baudios.

## Lazo

- AXI Timer a 20 kHz y PWM unipolar a 20 kHz con `freq_sel = 01`. Los códigos `00` (10 kHz), `10` (40 kHz) y `11` (20 kHz) existen en el periférico, pero el firmware solo habilita con `01`.
- El XADC convierte con `pwm_trigger_o`, en el valle de la portadora, para no ver el rizado.
- Cada interrupción lee el ADC, pasa por `supervisor_falla`, calcula el PR, escribe `duty_ref` y guarda la muestra.
- Corriente `i = (cuenta - 2048) · 1,1118e-3 A`, con 0 A en 0,5 V y 0,2196 V/A a la entrada del ADC.
- PR con `Kp = 4,5` y `Kr = 10000`, Tustin con precorrección en 50 Hz, salida recortada a ±0,92 con anti-windup. Referencia senoidal de 50 Hz.

## Exportación

El histórico tiene 2048 muestras, 102,4 ms a 20 kHz, unos cinco períodos de 50 Hz. Al apretar `BTN_EXPORTAR` se manda la ventana justo anterior al botón. Mientras sale no se guardan muestras nuevas, y al terminar el buffer se vacía y vuelve a llenarse.

En la PC, `python3 sw/receptor_pc.py [puerto]` recibe la trama, la guarda en `muestras.csv` y la grafica. Sin puerto busca la Basys 3 sola.
