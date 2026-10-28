# supervisor_falla

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Lo llama [`lazo_control`](lazo_control.md) una vez por interrupción.

## Objetivo

Decide si la corriente medida obliga a apagar el puente.

## Entradas

- `corriente` y `dato_ausente` de cada iteración, desde `lazo_control`.
- Umbral de corriente y cantidad máxima de iteraciones sin dato, configurables en el código.

## Salidas

- `falla`, enclavada hasta `BTN_RST`.

## Explicación general

Declara falla si el valor absoluto de la corriente pasa el umbral, si la muestra del ADC llega pegada a uno de los extremos de la escala (sensor fuera de rango o desconectado), o si se acumulan demasiadas iteraciones seguidas sin dato nuevo. Con falla, `lazo_control` deshabilita el PWM en esa misma iteración y [`control_principal`](control_principal.md) enciende el LED de falla en su siguiente vuelta.

La falla no se borra con `BTN_HABILITAR`, solo con `BTN_RST`. Esta protección por software complementa la desconexión por hardware de la etapa de potencia y no la reemplaza.
