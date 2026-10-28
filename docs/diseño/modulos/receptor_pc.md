# receptor_pc

Script de Python que corre en la computadora, ver el [nivel 3](../diagramas/nivel03.md). Es el único módulo del software que no corre en el MicroBlaze V.

## Objetivo

Recibe el histórico por UART y lo grafica fuera de línea.

## Entradas

- Bytes por el puerto serie del puente USB-UART de la Basys 3, a 115200 baudios y 8N1, enviados por [`exportador_uart`](exportador_uart.md).

## Salidas

- Gráficas de corriente medida, referencia reconstruida y `duty_ref` contra el tiempo.
- Un archivo CSV con las muestras ya en amperes y segundos.
- Error de la fundamental y rizado pico a pico, calculados por separado.

## Explicación general

Parte de `enlace.py` del Proyecto 3, que ya detecta la Basys 3 por el FT2232 con pyserial, cambiando el envío por la lectura. Espera la cabecera, lee la cantidad de registros que anuncia y revisa la verificación de la trama antes de graficar.

Con el período y la fase de la cabecera reconstruye la referencia y la superpone a la corriente medida. El error de la fundamental se calcula sobre una ventana de al menos cinco períodos de 50 Hz y el rizado se mide aparte, que es como lo piden los ensayos de la sección 4.3. La PC no manda nada a la FPGA.
