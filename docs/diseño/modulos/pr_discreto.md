# pr_discreto

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Lo llama [`lazo_control`](lazo_control.md) una vez por interrupción.

## Objetivo

Calcula la ecuación en diferencias del regulador PR que entrega PEDP, ya discretizada.

## Entradas

- `i_ref` y `corriente` de la iteración actual, desde `lazo_control`.
- Coeficientes del PR, desde `pr_params.h`.
- Orden de reinicio de estados, desde [`control_principal`](control_principal.md).

## Salidas

- `duty_ref` en el formato y el rango que acepta el periférico PWM.
- `saturado`, en uno si la salida tuvo que recortarse.

## Explicación general

Guarda entre llamadas los estados del término resonante. La salida se satura al rango admisible del `duty_ref`, y cuando eso pasa se aplica anti-windup sobre el resonante para que sus estados no sigan creciendo. El periférico también satura, pero el PR no debe depender de eso, porque necesita saber que se saturó.

Los coeficientes los genera un script de Python a partir de Kp, Kr, la frecuencia de muestreo y el método de discretización, y quedan en `pr_params.h`. La decisión entre punto fijo y punto flotante, el método de discretización y el formato de `duty_ref` se cierran en el nivel 4, cuando estén el período de muestreo y la FPU del Block Design.
