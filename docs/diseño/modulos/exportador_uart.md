# exportador_uart

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Corre en el lazo principal, fuera de la interrupción.

## Objetivo

Saca el histórico congelado por UART sin bloquear el lazo principal.

## Entradas

- `exportar`, desde [`control_principal`](control_principal.md).
- Registros congelados, desde [`buffer_muestras`](buffer_muestras.md).
- Espacio libre en la FIFO de transmisión de la UART, por [`drivers`](drivers.md).

## Salidas

- Bytes hacia la AXI UART Lite, por `drivers`.
- Órdenes de congelar y liberar hacia `buffer_muestras`.
- Estado de la exportación hacia `control_principal`.

## Explicación general

Es una máquina de estados que avanza un poco en cada vuelta del lazo principal. En cada llamada mete bytes en la FIFO de la UART mientras haya espacio y retorna. Al empezar congela el buffer, manda una cabecera y después los registros uno por uno, y al terminar libera el buffer.

La cabecera lleva lo que [`receptor_pc`](receptor_pc.md) necesita para reconstruir la señal, la cantidad de registros, el período de muestreo, la escala de corriente y de `duty_ref`, y la amplitud y la fase de la referencia en el primer registro. La trama cierra con una verificación sobre todos los bytes enviados, para que `receptor_pc` descarte una exportación que llegó incompleta o corrupta. El formato exacto de la trama va en el nivel 4.
