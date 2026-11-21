# Puente sin optoacopladores y sensor sin acondicionador, situación y plan

El 2026-11-21 el equipo decidió sacar del banco dos etapas, los VO3120 (con el PN2222A que los maneja) que aislaban las compuertas, y el acondicionador con el AD822 que iba después del ACS712. Lo que queda es la Basys 3, los dos IR2110, el puente con los IRF520N, la carga RL y el sensor. Este documento junta qué implica eso, qué hace falta en el hardware para que funcione y qué cambia en el firmware. A la fecha nada de esto está aplicado todavía, ni en el banco ni en `sw/`.

## Por qué salen

Con el acondicionador LD1 se enciende a los pocos segundos de habilitar, y las mediciones del 2026-11-19 al 21 apuntan a ruido y deriva del offset entrando por esa etapa y por las tierras. Una deriva de 0,285 V en la entrada del XADC ya equivale a los 1,3 A del umbral de sobrecorriente con la ganancia del AD822, así que cualquier cosa que mueva ese offset apaga el puente.

Los optoacopladores salen para simplificar la cadena de compuertas, una vez que las tierras van a quedar unidas de todas formas.

## Si quitar los optoacopladores baja puntos

El enunciado no pide aislamiento galvánico en ninguna parte. La sección 4.3.2 pide justificar el circuito de accionamiento de compuertas, la condición de demostración pide documentarlo, y ningún criterio de las rúbricas de Taller ni de PEDP (anexos B.1 y B.2) evalúa el aislamiento.

Donde sí se pueden perder puntos es en la documentación. [`potencia/diseno_puente_h.md`](../potencia/diseno_puente_h.md) está escrito alrededor del aislamiento, desde la sección "Qué cruza el aislamiento" hasta la cadena de cada compuerta y el cálculo del tiempo muerto con los retardos del VO3120. [`diseño.md`](diseño.md) también dice que la etapa de potencia está aislada de la Basys 3. Si el banco no coincide con eso, pega en el 30 % de etapa de potencia de B.1 y en la defensa. Esa reescritura le toca a quien lleva el puente (Nicolás, #21).

## Qué necesita el hardware para que funcione

El VO3120 hacía dos cosas, aislar y además subir la señal de 3,3 V a 15 V. El IR2110 con `VDD` en 15 V lee un alto desde 9,5 V, así que la FPGA conectada directo nunca enciende una compuerta.

- `VDD` del IR2110 a los 3,3 V del Pmod. La hoja acepta `VDD` entre `VSS`+3 y `VSS`+20 V, y los umbrales de entrada bajan con `VDD` (figuras 12B y 13B de la hoja del IR2110). Hay que confirmar en esas curvas que 3,3 V en la entrada queda como alto con margen. Con `VDD` en 5 V el margen para los 3,3 V de la FPGA es menor.
- `VCC` del IR2110 sigue en los 15 V del canal aparte, que ahora alimenta solo los dos IR2110.
- `VSS` a la tierra de la Basys y `COM` a la tierra de potencia, unidas en un solo punto. El IR2110 tolera hasta ±5 V entre las dos. El 2026-11-19 salió humo de un cable de tierra de la Basys por un lazo de tierra con la protoboard, así que la unión tiene que ser una sola. Si el negativo de alguna fuente de banco va a la tierra del enchufe, el USB de la PC cierra un segundo camino.
- Pin de la FPGA directo a `HIN` o `LIN`, sin el PN2222A. La polaridad se mantiene, pin en 1 es compuerta encendida. Nada de etapas inversoras, porque mientras la FPGA se configura sus pines quedan en alta impedancia y el pull-down interno del IR2110 tiene que dejar las cuatro compuertas apagadas. Con una etapa inversora, una Basys sin configurar encendería las cuatro y cortocircuitaría las dos piernas.
- Las resistencias de 10 Ω de compuerta y de 100 kΩ entre compuerta y source se quedan.

El ACS712 de ±5 A da unos 2,5 V con 0 A y 183 mV/A medidos, y el XADC lee de 0 a 1 V. Conectado directo, la cuenta se queda en 4095, el supervisor salta por `CUENTA_ADC_MAX` y LD1 se enciende en la primera muestra. Hace falta como mínimo el divisor de 12 kΩ y 3 kΩ que ya se había diseñado (`divisor_xadc`, recuperable del historial de git), que divide entre 5 y deja 0,5 V a 0 A y 36,6 mV/A en el pin.

- Antes de conectar al JXADC, con el sensor alimentado y sin corriente, entre el pin 1 (vauxp6) y el pin 7 del JXADC tiene que haber entre 0,45 y 0,55 V.
- Sin el RC que traía el acondicionador, el ruido del ACS712 llega entero. Son unos 21 mV pp típicos según su hoja, alrededor de 0,11 A pp, y eso pesa en el ensayo de 0,2 A. Lo más barato es un capacitor en el pin FILTER del sensor, revisando primero si el módulo ya trae uno.
- La resolución baja a 6,67 mA por cuenta, unas 30 cuentas para los 0,2 A pico. Alcanza para la fundamental en ventanas de cinco períodos.

## Qué cambia en el firmware

El RTL, `basys3.xdc` y el Block Design no cambian con esto, así que el bitstream actual sirve. El tiempo muerto de 1 µs se calculó sumando los retardos del VO3120 y del PN2222A, sin ellos el margen crece y `DEAD_TIME_CICLOS` se queda en 100.

En `sw/` el cambio ya existió una vez. Se armó el 2026-11-20 para el divisor y se revirtió cuando se decidió no montarlo, así que el plan es deshacer esas reversiones, en este orden, en `feature/tope-modulacion`.

1. Revertir `d8af079`. Devuelve la medición del offset al arrancar, 256 muestras con el puente apagado en `calibrar_offset` de `control_principal.c`, la variable `adc_offset_cuentas` que usa `lazo_control.c`, el offset medido en la cabecera de `exportador_uart.c` y sus pruebas. Con el divisor es obligatorio. El cero del ACS712 es la mitad de su alimentación de 5 V, y un 2 % de diferencia son unas 41 cuentas, 0,27 A de error fijo. Si el offset medido queda fuera de ±205 cuentas de 2048 (`OFFSET_TOLERANCIA`), el arranque falla y no deja habilitar.
2. Revertir `f02bac9`. Las pruebas de `lazo_control` y `control_principal` vuelven a las cuentas del divisor.
3. Revertir `d9cda1a`. `ADC_AMPERES_POR_CUENTA` en `lazo_control.h` vuelve a 6,6705e-3, que sale de 1 V / (4096 · 0,0366 V/A).
4. En `lazo_control.c` el comentario de `DUTY_FLANCO_CERCA` menciona el RC del acondicionador y hay que corregirlo. El valor se queda hasta verlo en el osciloscopio.
5. Correr las pruebas de `sw/pruebas/` y bajar con `make program`.

`UMBRAL_SOBRECORRIENTE` no cambia porque está en amperios. Con 1,0 A pico, el ruido sin filtrar más el rizado de los 200 µH dejan poco margen hasta 1,3 A. Si aparecen fallas falsas solo en el ensayo de 1,0 A, la causa es esa.

## Pendiente aparte, un LED por causa de falla

Hoy LD1 junta cuatro causas y en el banco no hay forma de saber cuál saltó sin exportar el CSV. La idea es repartirlas entre LD1 y LD4.

- Sobrecorriente, más allá de `UMBRAL_SOBRECORRIENTE`.
- Cuenta del ADC fuera de escala, `CUENTA_ADC_MIN` o `CUENTA_ADC_MAX`.
- Falta de dato nuevo del XADC durante `ITERACIONES_SIN_DATO_MAX` iteraciones.
- Error de arranque, que con el paso 1 también cubre el offset fuera de tolerancia.

`supervisor_falla` tiene que pasar de guardar un `bool` a recordar cuál causa disparó primero. Esto sí toca hardware, el GPIO de LEDs en `src/bd/sistema.tcl` pasa de 2 a 5 bits y hay que descomentar `led[2]` a `led[4]` en `basys3.xdc`, así que obliga a regenerar el bitstream. Conviene hacerlo por separado del cambio del divisor, para no mezclar una prueba que solo necesita `make program` con una que necesita Vivado.

## Lo que sigue abierto de antes

En [`diseño/inconsistencias.md`](diseño/inconsistencias.md) quedan dos puntos sin resolver. El rizado no cumple los 0,20 A pp a 20 kHz con 200 µH, y hace falta más inductancia (al menos 0,56 mH con 18 V) o el puente a 40 kHz. `diseno_puente_h.md` todavía trae las cifras del transformador de 30 mH. Ese documento ahora tiene dos razones para reescribirse.

## Qué avisarle al equipo

- Jefferson y Nicolás. Antes de energizar, `VDD` de los IR2110 a 3,3 V, tierras unidas en un solo punto, divisor de 12k y 3k entre el ACS712 y el JXADC, y medir los 0,5 V en el pin 1 del JXADC. Revisar compuertas y tiempo muerto en el osciloscopio con el bus apagado, como pide el enunciado.
- Nicolás. Reescribir la parte de aislamiento de `diseno_puente_h.md` y su copia en `diseño.md`.
- Mattio. Aplicar los pasos 1 a 5 del firmware, decidir cuándo meter los LEDs de falla y cerrar con el equipo el tema del rizado.
- Carlos. Nada de esto toca el periférico PWM, el testbench ni la simulación temporizada.
