# Simulaciones y pruebas autoverificables, módulo por módulo

Corridas el 2026-11-25 sobre `arreglo-final` (`origin/arreglo-final`, commit `05808ab`). Pensado para mostrarle al profesor Jefferson qué se verificó de cada módulo sin tener que leer el código. El log completo de cada corrida queda en `sim/sv/` o `sim/c/`, con el comando usado y toda la salida.

## Hardware, SystemVerilog con iverilog

### periferico_pwm

`src/design/periferico_pwm.sv`, el periférico AXI4-Lite obligatorio del enunciado. El testbench es `src/sim/tb_periferico_pwm.sv`, corrido con `make sim TB=periferico_pwm` (log en `sim/sv/tb_periferico_pwm.log`).

Qué cubre, en 23 grupos de prueba y 101554 comprobaciones:

- El handshake AXI4-Lite completo. Canales AW y W independientes y en cualquier orden, B retenida mientras el maestro no está listo, segunda escritura esperando, lectura en el mismo flanco que una escritura en curso, segunda AR bloqueada hasta que el maestro lee R, atributos de protección, offsets sin registro y no alineados, accesos aleatorios concurrentes con el PWM habilitado.
- Reset en cada fase posible, con AW o W aisladas, con B y R pendientes, y con las compuertas activas en medio de la modulación.
- El núcleo PWM, las tres frecuencias y el trigger hacia el ADC con el puente apagado, `running` y la precarga exacta de ambas piernas, saturación y signo de la referencia, deshabilitación durante la modulación y durante la precarga, cambios conjuntos de frecuencia y referencia, escrituras a dos, uno y cero ciclos del valle, conmutaciones y pulsos menores al tiempo muerto.

Resultado, 0 errores, termina en "PWM: APROBADO".

### envoltura_xadc

`src/design/envoltura_xadc.sv`, la envoltura AXI4-Lite propia sobre el XADC Wizard. El testbench es `src/sim/tb_envoltura_xadc.sv` con un modelo simple del XADC, corrido con `make sim TB=envoltura_xadc` (log en `sim/sv/tb_envoltura_xadc.log`).

Qué cubre, en 12 casos:

- Valores después del reinicio y arranque por software, con el inicio ignorado durante la calibración.
- `pwm_trigger_o` como fuente de disparo, con AW antes que W y viceversa, e inicios por software ignorados mientras esa fuente manda.
- El disparo en el valle de la portadora, con CONVST 20 ns después, y que un segundo valle durante una conversión en curso se ignore.
- El contador de canal dando la vuelta módulo 4.
- Direcciones sin registro y escrituras al registro de datos, que no deben tener efecto.

Resultado, 0 errores, termina en "PASA: tb_envoltura_xadc sin errores". iverilog tira un aviso ("sorry: constant selects in always_* processes are not fully supported") sobre `s_axi_araddr[3:0]` en la línea 137, es una limitación conocida del simulador con selects de ancho variable en `always_comb`, no afecta el resultado ni es un error del diseño.

## Software del MicroBlaze V, en C sobre la PC

Las siete corren reemplazando `drivers.c` por funciones de prueba (sin hardware real), compiladas con `cc -std=c99 -Wall` según el comentario de cada archivo. Las siete, 0 errores y sin warnings de `-Wall`.

### buffer_muestras

Histórico circular en `sw/buffer_muestras.c`. Prueba en `sw/pruebas/prueba_buffer_muestras.c` (log en `sim/c/prueba_buffer_muestras.log`).

- Orden de las muestras antes y después de dar la vuelta al buffer.
- Que no se escriba nada estando congelado, y que `buffer_muestras_liberar` vacíe de verdad el histórico sin dejar muestras viejas mezcladas.
- Que las banderas (`BANDERA_SATURADO`, `BANDERA_FALLA`, etc.) no se pisen con la cuenta del ADC ni entre sí.

### ref_senoidal

Generador de referencia senoidal en `sw/ref_senoidal.c`. Prueba en `sw/pruebas/prueba_ref_senoidal.c` (log en `sim/c/prueba_ref_senoidal.log`).

- Amplitud exacta en el pico y vuelta a cero tras un período completo.
- Que un cambio de amplitud a medio período no mueva la fase.
- Error acumulado menor al 1 % en 10 s de referencia con una frecuencia de muestreo que no es múltiplo exacto de 50 Hz (9973 Hz, para forzar el redondeo de fase).

### pr_discreto

El regulador PR en `sw/pr_discreto.c`, con los coeficientes de `sw/pr_params.h`. Prueba en `sw/pruebas/prueba_pr_discreto.c` (log en `sim/c/prueba_pr_discreto.log`).

- Salida cero sin error, y la primera iteración igual a `KP + B0` partiendo de estados en cero.
- Saturación simétrica en `±PR_U_MAX`, con el signo correcto en complemento a dos.
- El resonante ganando en 50 Hz (5,9 veces entre el primero y el quinto período) y sin crecer a 1 kHz, para comprobar que la resonancia está donde debe.
- Anti-windup, que el resonante no siga acumulando mientras la salida está saturada, comparando una saturación corta contra una de 50 ms.

### supervisor_falla

Detección de fallas en `sw/supervisor_falla.c`. Prueba en `sw/pruebas/prueba_supervisor_falla.c` (log en `sim/c/prueba_supervisor_falla.log`).

- Sobrecorriente positiva y negativa, justo en el umbral y por encima, y que la falla quede enclavada.
- Cuenta del ADC fuera de escala, en el mínimo y en el máximo exactos (`CUENTA_ADC_MIN`/`MAX`).
- Demasiadas iteraciones sin dato nuevo, y que iteraciones sin dato aisladas (con una muestra válida en medio) no se acumulen.
- Que la primera causa de falla no se pise con una causa posterior.

### lazo_control

La ISR del AXI Timer en `sw/lazo_control.c`, el corazón del lazo de control. Prueba en `sw/pruebas/prueba_lazo_control.c` (log en `sim/c/prueba_lazo_control.log`).

- Orden exacto de la ISR, control apagado sin escribir `duty_ref`, y con el control habilitado los bits de estado del registro (`cuenta_banderas`) correctos en cada combinación de habilitado, sin dato y en falla.
- Que sin dato nuevo del ADC se repita el último `duty_ref` sin volver a llamar al PR, y que la fase de la referencia siga avanzando igual.
- Disparo de falla por sobrecorriente y por datos ausentes, que apague el PWM una sola vez y no vuelva a escribir `duty_ref` mientras la falla esté enclavada.
- El autocero del offset del ADC completo, con muestras alternadas que promedian el valor esperado, que no se escriba nada mientras dura, que una falla a mitad de camino lo reinicie sin tocar el offset vigente, y que termine con el offset nuevo exacto.
- Que la señal de depuración (el GPIO que marca la duración de la ISR en el osciloscopio) suba y baje exactamente una vez por iteración, y que el Timer se reconozca siempre con esa señal arriba.

### control_principal

El lazo principal fuera de la interrupción, en `sw/control_principal.c`. Prueba en `sw/pruebas/prueba_control_principal.c` (log en `sim/c/prueba_control_principal.log`).

- Arranque, el sondeo del XADC cortándose en `SONDEO_MAX_LECTURAS` si nunca publica, el Timer arrancando justo en el segundo avance del contador, el TLR correcto a 20 kHz y LD4 encendido si el arranque falla.
- `SW[1:0]` seleccionando la amplitud de referencia (0, 0,2, 0,5 y 1,0 A).
- El flanco de `BTN_HABILITAR` habilitando y deshabilitando con una sola sección crítica, reiniciando la fase de la referencia, sin reaccionar al botón sostenido ni a un botón ya apretado desde el reset.
- Que no se pueda habilitar con `freq_sel` distinto del inicial, ni con una falla enclavada a mitad de la sección crítica.
- Las fallas y sus LEDs, sobrecorriente con LD1, cuenta fuera de escala con LD2, y que el botón no vuelva a habilitar mientras la falla esté activa.
- `BTN_EXPORTAR` arrancando la exportación por UART.

### exportador_uart

Exportación del histórico por UART en `sw/exportador_uart.c`. Prueba en `sw/pruebas/prueba_exportador_uart.c` (log en `sim/c/prueba_exportador_uart.log`), con una FIFO de prueba que simula estar llena cada 7 llamadas para cortar la trama en lugares raros.

- Trama con buffer vacío (solo cabecera y suma), con 37 registros y con el buffer lleno (`BUFFER_REGISTROS`).
- Cabecera completa, el byte de inicio `0xAA`, cantidad, frecuencia de muestreo, offset del ADC vigente (no una constante vieja), ganancia en A/cuenta, escala de `duty_ref` en Q2.14 y el bit de signo.
- Orden de los registros dentro de la trama y suma de verificación.
- Un pedido repetido a media trama no reinicia nada, y el buffer queda liberado al terminar.

## Formas de onda, sim/img

Volcado VCD de cada testbench con `vvp ... +VCD` (plusarg ya soportado en `tb_periferico_pwm.sv`, agregado ahora en `tb_envoltura_xadc.sv` con el mismo patrón, condicionado a `$test$plusargs("VCD")` así que no cambia nada si no se pide). El `.vcd` no se versiona (`*.vcd` en `.gitignore`, se regenera con el comando de abajo), lo que queda en el repo es una imagen recortada a una ventana representativa de cada uno.

periferico_pwm, tres escenas:

- `sim/img/tb_periferico_pwm_modulacion.png`, las cuatro compuertas (`ah`, `al`, `bh`, `bl`) y `trigger` durante la modulación unipolar normal, se ve el tiempo muerto entre cada conmutación y las dos piernas complementadas.
- `sim/img/tb_periferico_pwm_portadora.png`, adentro de `u_nucleo_pwm`, la portadora triangular (`portadora`) contra la referencia saturada de cada pierna (`ref_a_etapa2`) y las dos salidas del comparador (`comparacion_a`, `comparacion_b`), el mecanismo que después da lugar a las compuertas de la escena anterior.
- `sim/img/tb_periferico_pwm_axi.png`, handshake AXI4-Lite con AW y W retenidas mientras B está pendiente (`bvalid` alto y `bready` todavía en 0) y la siguiente escritura esperando a que se libere, caso AX07/PW17 del testbench.

envoltura_xadc, tres escenas:

- `sim/img/tb_envoltura_xadc_valle.png`, la secuencia completa de una conversión disparada por el valle (`pwm_trigger_o` a `xadc_convst` con los 20 ns de la sección 9 del testbench) seguida de un valle que llega con la conversión en curso y se ignora (sección 10), sin `convst` ni `busy` adicional hasta que termina la que ya estaba en marcha.
- `sim/img/tb_envoltura_xadc_calibracion.png`, sección 2 del testbench, una escritura de software al bit de inicio se acepta en el AXI (`s_axi_bvalid` pulsa) pero no dispara nada mientras `xadc_busy` sigue en 1 por la calibración.
- `sim/img/tb_envoltura_xadc_software.png`, sección 3, el mismo inicio por software ya fuera de la calibración, con la escritura disparando `xadc_convst` directamente (sin pasar por `pwm_trigger_o`) y la conversión completa hasta `xadc_drdy`.

Para regenerar cualquiera de los dos VCD:

```
iverilog -g2012 -s tb_periferico_pwm -o /tmp/tb.vvp src/design/*.sv src/sim/tb_periferico_pwm.sv && vvp /tmp/tb.vvp +VCD
iverilog -g2012 -s tb_envoltura_xadc -o /tmp/tb.vvp src/design/*.sv src/sim/tb_envoltura_xadc.sv && vvp /tmp/tb.vvp +VCD
```

## JB1, diagrama ilustrativo, no una simulación

`sim/img/jb1_cadencia_lazo_ilustrativo.png`. JB1 es la señal de depuración de `lazo_control.c` (`drivers_depuracion`, sube al entrar a la ISR y baja al salir, `lazo_control.c:49` y `:112`), pensada para verse con el osciloscopio en hardware real, tal como quedó anotado en el diagnóstico de LD1 del 2026-11-19. No existe en ningún testbench de `src/sim/` (ninguno modela la ISR ni el AXI Timer) y en `prueba_lazo_control.c` tampoco tiene tiempo real, esa prueba solo cuenta llamadas, no mide microsegundos.

El diagrama arma el período de 50 µs a partir de la constante real `PR_FRECUENCIA_MUESTREO_HZ = 20000` (`sw/pr_params.h`), y dibuja el ancho del pulso con la estimación sin FPU que ya está en `docs/diseño/modulos/lazo_control.md` (15 a 25 µs, tramo sólido hasta el mínimo y sombreado hasta el máximo). El ancho real de cada pulso, y si de verdad cae dentro de ese rango, solo se sabe midiendo JB1 con el osciloscopio.

## No corridas en esta ronda

`sw/pruebas/prueba_generar_pr_params.m` (Octave) y `sw/pruebas/test_receptor_pc.py` (pytest) quedan fuera, lo pedido fue SystemVerilog y C.

## Pendiente en `docs/diseño/inconsistencias.md`, sin tocar acá

El rizado de conmutación no cumple 0,20 A pp a 20 kHz con ninguna `Vdc` del rango, y `potencia/diseno_puente_h.md` de Nicolás sigue con las cifras del transformador viejo en vez de los 200 µH actuales.
