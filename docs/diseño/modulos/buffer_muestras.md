# buffer_muestras

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Lo escribe la interrupción y lo lee el lazo principal.

## Objetivo

Guarda el histórico de las últimas iteraciones en la BRAM local, en un arreglo circular.

## Entradas

- Un registro por iteración desde [`lazo_control`](lazo_control.md), con corriente, `duty_ref` y `saturado`.
- Órdenes de congelar y liberar, desde [`exportador_uart`](exportador_uart.md).

## Salidas

- Registros congelados en orden temporal, del más viejo al más nuevo, hacia `exportador_uart`.

## Explicación general

La rutina escribe en la posición del índice de escritura y lo avanza, y al llegar al final vuelve al inicio sobre las muestras más viejas. El tamaño del arreglo sale de lo que sobre de los 32 KB después de enlazar el programa, y se reporta en el nivel 4.

Exportar el histórico completo a 115200 baudios tarda del orden de segundos. En ese tiempo la rutina daría varias vueltas al arreglo y pisaría registros que todavía no salieron. Por eso, mientras el buffer está congelado, la rutina sigue controlando pero no escribe registros nuevos, y lo exportado es la ventana justo antes de presionar `BTN_EXPORTAR`. Copiar solo el índice de escritura al empezar no alcanza, porque no evita que la rutina siga sobrescribiendo.
