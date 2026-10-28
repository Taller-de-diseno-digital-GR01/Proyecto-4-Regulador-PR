# drivers

Módulo del software del MicroBlaze V, ver el [nivel 3](../diagramas/nivel03.md). Lo usan los dos contextos de ejecución.

## Objetivo

Única capa que toca registros de periféricos. Los demás módulos llaman a sus funciones y no conocen direcciones.

## Entradas

- Llamadas de [`control_principal`](control_principal.md), [`lazo_control`](lazo_control.md) y [`exportador_uart`](exportador_uart.md).
- Direcciones base de `xparameters.h`, generado por Vitis desde el `.xsa` y el Address Editor.
- Lecturas por AXI4-Lite de los periféricos.

## Salidas

- Escrituras por AXI4-Lite al PWM, ADC, GPIO, UART, Timer e INTC.
- Datos y estados leídos, hacia el módulo que llamó.

## Explicación general

Para Timer, INTC, GPIO y UART Lite usa los drivers de Xilinx que genera Vitis. Para el PWM y la interfaz del ADC, que son propios, son funciones cortas sobre `Xil_In32` y `Xil_Out32` con los offsets de cada mapa de registros.

Las funciones que usa la rutina de interrupción no esperan nunca. El envío de un byte por UART tampoco, devuelve si el byte cupo en la FIFO de transmisión o no. La escritura del registro de control del PWM desde el lazo principal se hace con la interrupción enmascarada, porque es lectura, modificación y escritura, y si la rutina declarara una falla en medio el lazo principal volvería a escribir `enable` en uno.
