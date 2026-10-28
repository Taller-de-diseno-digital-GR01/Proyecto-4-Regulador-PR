# lazo_control

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Es la rutina de interrupción del AXI Timer.

## Objetivo

Ejecuta una iteración del control en el orden que fija el enunciado, siempre igual.

## Entradas

- Interrupción periódica del AXI Timer, por el AXI INTC.
- Bandera de dato nuevo y muestra del ADC, por [`drivers`](drivers.md).
- `control_habilitado` y `amplitud_ref`, desde [`control_principal`](control_principal.md).
- `i_ref` desde [`ref_senoidal`](ref_senoidal.md), `duty_ref` y `saturado` desde [`pr_discreto`](pr_discreto.md), y `falla` desde [`supervisor_falla`](supervisor_falla.md).

## Salidas

- `duty_ref` hacia el periférico PWM, por `drivers`.
- Un registro por iteración hacia [`buffer_muestras`](buffer_muestras.md).
- `falla` hacia `control_principal`.
- Salida de depuración temporal, en alto mientras dura la rutina.

## Explicación general

La secuencia de cada interrupción es la siguiente.

1. Sube la salida de depuración y reconoce la interrupción del Timer.
2. Revisa la bandera de dato nuevo del ADC. Si no hay dato, avisa a `supervisor_falla` con `dato_ausente`, no calcula y deja el `duty_ref` anterior.
3. Lee la muestra y la convierte a corriente con signo, con el offset y la ganancia medidos del sensor.
4. Pasa la corriente a `supervisor_falla`. Si declara falla, deshabilita el PWM y termina.
5. Si el control está habilitado, pide `i_ref` a `ref_senoidal`, calcula `pr_discreto` y escribe el `duty_ref` resultante en el PWM.
6. Guarda corriente, `duty_ref` y `saturado` en `buffer_muestras`.
7. Baja la salida de depuración.

Con el control deshabilitado la rutina sigue corriendo y registrando la corriente, que debería ser cero. Eso sirve para revisar el offset del sensor sin energizar el puente.

La salida de depuración la escribe solo esta rutina, y los LEDs solo `control_principal`. Por eso tienen que quedar en canales distintos del AXI GPIO. Si compartieran registro, una lectura y escritura del lazo principal interrumpida a la mitad podría pisar el valor que dejó la rutina.
