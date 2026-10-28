# ref_senoidal

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Lo llama [`lazo_control`](lazo_control.md) una vez por interrupción.

## Objetivo

Entrega la muestra de la referencia sinusoidal de 50 Hz que toca en cada iteración.

## Entradas

- `amplitud_ref`, desde `lazo_control`.
- Avance de una muestra por iteración y orden de reinicio de fase.

## Salidas

- `i_ref` en amperes, en el mismo formato numérico que usa [`pr_discreto`](pr_discreto.md).

## Explicación general

Recorre una tabla de un período de seno con un índice de fase que avanza una posición por interrupción. Si la frecuencia de muestreo es múltiplo de 50 Hz la tabla tiene exactamente un período y el índice vuelve a cero sin error acumulado. Si no lo es, hace falta un acumulador de fase, y eso se decide cuando se fije el período de muestreo.

El cambio de amplitud entra en la siguiente muestra sin tocar la fase, que es lo que pide el ensayo de cambio de amplitud.
