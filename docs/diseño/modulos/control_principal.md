# control_principal

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Corre en el lazo principal, fuera de la interrupción.

## Objetivo

Arranca el sistema y atiende todo lo que no tiene plazo, los botones, los LEDs y el pedido de exportación.

## Entradas

- Estado de `BTN_HABILITAR` y `BTN_EXPORTAR`, leído por [`drivers`](drivers.md) desde el AXI GPIO.
- `SW[1:0]`, selección de la amplitud de la referencia, también por `drivers` desde el AXI GPIO.
- `falla`, desde [`lazo_control`](lazo_control.md).
- Estado de la exportación en curso, desde [`exportador_uart`](exportador_uart.md).

## Salidas

- `control_habilitado` y `amplitud_ref` hacia `lazo_control`.
- `exportar` hacia `exportador_uart`.
- `led[1:0]` (habilitado y falla), por medio de `drivers`.
- Habilitación del PWM, por medio de `drivers`.

## Explicación general

Al arrancar configura los periféricos en un orden fijo. Primero deja el PWM deshabilitado, después configura el ADC, la UART y el GPIO, inicializa [`pr_discreto`](pr_discreto.md), [`ref_senoidal`](ref_senoidal.md) y [`buffer_muestras`](buffer_muestras.md), y por último programa el Timer y habilita la interrupción. Así la primera interrupción ya encuentra todo listo.

En cada vuelta del lazo principal lee los botones, saca los flancos y los atiende. Un flanco de `BTN_HABILITAR` alterna el control entre habilitado y deshabilitado, salvo que haya falla, en cuyo caso se ignora. Un flanco de `BTN_EXPORTAR` pide la exportación si no hay una en curso. Después llama a `exportador_uart` para que avance y actualiza los LEDs. Los botones llegan filtrados del bloque 11 del nivel 2, este módulo solo detecta el flanco.

Al habilitar, primero reinicia los estados del PR y la fase de la referencia y después sube `control_habilitado` y el `enable` del PWM, en ese orden, para que el primer `duty_ref` salga de un PR limpio.

La amplitud de la referencia sale de `SW[1:0]`. Con `00` la referencia queda en cero, y `01`, `10` y `11` dan 0,2, 0,5 y 1,0 A pico. El lazo principal lee los switches en cada vuelta y actualiza `amplitud_ref` aunque el control esté andando, que es lo que necesita el ensayo de cambio de amplitud. El código `00` sirve para habilitar el puente con corriente nula antes de subir a un punto de operación. Los switches son niveles fijos y no rebotan durante el ensayo, así que no hace falta sacarles flanco.
