# TODO, verificación del PWM con analizador lógico

Prompt para el agente de Jefferson (Persona A). Arranca desde acá.

## Contexto

Estás en el repo del Proyecto 4 (inversor en puente H con regulador PR sobre MicroBlaze V, Basys3). Trabaja sobre `develop`. Jefferson tiene la Basys3 con el bitstream del Block Design cargado, la plataforma de Vitis con todo `sw/` compilado, y un analizador lógico. No hay puente H, ni sensor, ni carga conectados. El objetivo es que Jefferson pueda decir con una sola sesión de mediciones que `nucleo_pwm` está listo para conectarse al puente, y que el Timer y la ISR corren en fase con el disparo del ADC.

Antes de guiarlo, lee `src/design/nucleo_pwm.sv`, `src/design/interfaz_axi_pwm.sv`, `src/fpga/basys3.xdc`, `sw/lazo_control.c`, `sw/drivers.c` y `sw/control_principal.c`, y confirma que lo de abajo sigue siendo cierto. Si algo cambió (pines, direcciones, parámetros del núcleo), ajusta los números antes de pasárselos.

## Por qué funciona sin hardware de potencia

Con el Pmod JXADC al aire la cuenta del XADC sale fuera de `CUENTA_ADC_MIN`/`CUENTA_ADC_MAX` y `supervisor_falla` enclava la falla en la primera ISR. `drivers_pwm_apagar()` solo se llama en la iteración en que la falla se enclava (`if(en_falla && !falla)` en `lazo_control.c`), y después ni la ISR ni el lazo principal vuelven a escribir el registro de control del PWM. Entonces, con LD1 encendido, se puede subir `enable` a mano con XSDB y la app lo deja quieto, mientras la ISR sigue moviendo el pin de depuración. Así se ven el PWM y la ISR en la misma captura.

## Conexión del analizador

- JA10 (G3) `compuerta_a_alta`
- JA9 (H2) `compuerta_a_baja`
- JA8 (K2) `compuerta_b_alta`
- JA7 (H1) `compuerta_b_baja`
- JB1 (A14) `depuracion`
- GND del analizador a JA5 o JB5

Muestreo de 24 MHz o más, así el tiempo muerto de 1 µs se mide con unos ±40 ns. Lógica de 3,3 V.

## Captura principal

Correr la app desde Vitis, esperar a que LD1 encienda y en la consola XSDB, con el target del MicroBlaze V seleccionado:

```
stop
mwr 0x44A00004 0x2000   ;# m = +0,5 en Q2.14
mwr 0x44A00000 0x3      ;# freq_sel 01, enable
con
```

Capturar unos cuantos ms y revisar estos criterios, todos tienen que cumplirse.

1. Período de cada compuerta de 50,0 µs (20 kHz, `MAX_FREQ_01 = 2500`).
2. `a_alta` cerca del 75 % y `b_alta` cerca del 25 %, que es (1 ± m)/2, un poco menos por el tiempo muerto.
3. Tiempo muerto de 1,00 µs (`DEAD_TIME_CICLOS = 100`) entre la bajada de una compuerta y la subida de su complementaria, en los dos sentidos y en las dos piernas.
4. Trigger en `a_alta AND a_baja` y otro en `b_alta AND b_baja`. En una captura larga no deben dispararse nunca. Es el criterio que más importa antes de conectar el puente.
5. Los pulsos altos de A y de B tienen el centro en el mismo instante, el valle de la portadora.
6. `depuracion` con período de 50,0 µs exacto, sin pulsos perdidos. En falla la ISR se salta el PR, así que su ancho acá es solo un mínimo.
7. La distancia entre el flanco de subida de `depuracion` y el centro del pulso de `a_alta` es constante en toda la captura. Si deriva, el Timer y la portadora no están en fase.

## Variantes en la misma sesión

Cada una con `stop`, `mwr` y `con`.

- Precarga. Con `mwr 0x44A00000 0x2` antes y el trigger en la subida de `a_baja`, escribir `0x3`. Las dos bajas quedan encendidas 70 µs (`PRECARGA_CICLOS = 7000`) con las altas apagadas, y después entra el PWM normal.
- Apagado. Con el PWM corriendo, `mwr 0x44A00000 0x2`. Las cuatro bajan en un valle y el último pulso de `a_alta` no sale recortado.
- Saturación. `mwr 0x44A00004 0x7FFF`. `a_alta` casi al 100 % y `b_alta` en 0. Leer `0x44A00004` devuelve `0x7FFF` porque la saturación está en el núcleo y no en el registro, eso es esperado.
- `freq_sel` con `enable`. `0x1` (código 00) da 100 µs, `0x5` (código 10) da 25 µs y `0x7` (código 11) da 50 µs.

## Qué entregar

Una sección nueva en `docs/informe/` (o donde Jefferson diga) con cada criterio marcado como cumplido o no, el valor medido, y una captura de pantalla del analizador por criterio. Si algo falla, abrir un issue con la captura y el criterio que no se cumplió, y avisarle a Mattio (`Mattio-cmd`) si el problema toca `sw/`. No cambiar código de `sw/` sin hablarlo con él.

Esta prueba no cubre el PR. Eso va aparte con un build de prueba que simula la carga RL dentro de la ISR, y lo lleva Mattio.
