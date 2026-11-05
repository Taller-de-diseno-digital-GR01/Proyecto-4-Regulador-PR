# control_principal

## a) Nombre del módulo

`control_principal`, en `sw/main.c`. Es el lazo principal del software del MicroBlaze V del [nivel 3](../diagramas/nivel03.md), fuera de la interrupción.

## b) Diagrama modular

```mermaid
flowchart LR
    DRV_IN(["drivers"]) -->|"BTN_HABILITAR, BTN_EXPORTAR, SW[1:0]"| CP["control_principal<br/>arranque y lazo principal"]
    LC_IN(["lazo_control"]) -->|"falla"| CP
    EXP_IN(["exportador_uart"]) -->|"exportación en curso"| CP
    CP -->|"control_habilitado, amplitud_ref"| LC_OUT(["lazo_control"])
    CP -->|"exportar"| EXP_OUT(["exportador_uart"])
    CP -->|"led[1:0], enable del PWM"| DRV_OUT(["drivers"])
    CP -->|"reinicio de estados y de fase"| PRREF(["pr_discreto y ref_senoidal"])
```

## c) Objetivo del módulo

Arranca el sistema en un orden seguro y después atiende todo lo que no tiene plazo, los botones, los switches de amplitud, los LEDs y el pedido de exportación.

## d) Entradas

- `BTN_HABILITAR` y `BTN_EXPORTAR`, ya filtrados por el bloque 10 del nivel 2, leídos por [`drivers`](drivers.md) desde el AXI GPIO.
- `SW[1:0]`, la selección de la amplitud de la referencia, también por `drivers`.
- `falla`, desde [`lazo_control`](lazo_control.md).
- Si hay una exportación en curso, desde [`exportador_uart`](exportador_uart.md).

## e) Salidas

- `control_habilitado` y `amplitud_ref`, hacia `lazo_control`.
- El pedido de exportación, hacia `exportador_uart`.
- `led[1:0]`, `led[0]` para control habilitado y `led[1]` para falla, por `drivers`.
- `enable` del PWM, por `drivers`.
- El reinicio de estados de [`pr_discreto`](pr_discreto.md) y de fase de [`ref_senoidal`](ref_senoidal.md).

## f) Explicación de la relación con otros módulos

Es el dueño del arranque. Inicia todos los demás módulos y registra `lazo_control` como manejador de la interrupción del procesador, que viene directo del AXI Timer. Después corre para siempre en el lazo principal junto con `exportador_uart`, al que llama en cada vuelta. Con la interrupción se comunica solo por las tres variables compartidas del nivel 3, y es el único escritor de `control_habilitado` y `amplitud_ref`.

## g) Explicación de funcionamiento

### g.1) Arranque

1. Deja el PWM con `enable` en cero y `freq_sel` en `FREQ_SEL_INICIAL`.
2. Configura el ADC, la UART y el GPIO, con los LEDs y la salida de depuración en cero.
3. Inicia `pr_discreto`, `ref_senoidal` con `PR_FRECUENCIA_MUESTREO_HZ`, `supervisor_falla` y `buffer_muestras`.
4. Deja `control_habilitado` en cero, `amplitud_ref` según `SW[1:0]` y `falla` en cero.
5. Registra `lazo_control` como manejador de la interrupción del procesador con las funciones de excepciones del BSP, programa el Timer con el período de muestreo y habilita la interrupción.

El Timer va al final para que la primera interrupción ya encuentre todo listo.

### g.2) Lazo principal

En cada vuelta, en este orden.

1. Lee los botones y los switches y saca los flancos de subida de los botones.
2. Actualiza `amplitud_ref` con `SW[1:0]`.
3. Si `falla` está en uno y el control seguía habilitado, baja `control_habilitado`.
4. Atiende un flanco de `BTN_HABILITAR`, si lo hay.
5. Atiende un flanco de `BTN_EXPORTAR`, si lo hay, con `exportador_uart_pedir`.
6. Llama a `exportador_uart_avanzar`.
7. Actualiza los LEDs.

Ningún paso espera a un periférico, así que una vuelta dura pocos microsegundos más lo que tarde la interrupción si cae en medio.

## h) Diseño

### h.1) Estados del control

| Estado | `control_habilitado` | `enable` | `led[0]` | `led[1]` |
| --- | --- | --- | --- | --- |
| deshabilitado | 0 | 0 | 0 | 0 |
| habilitado | 1 | 1 | 1 | 0 |
| falla | 0 | 0 | 0 | 1 |

| Estado | Evento | Acción | Siguiente |
| --- | --- | --- | --- |
| deshabilitado | flanco de `BTN_HABILITAR` con `freq_sel = 01` | reinicia PR y fase, `control_habilitado = 1`, `enable = 1` | habilitado |
| deshabilitado | flanco de `BTN_HABILITAR` con `freq_sel` distinto de `01` | nada | deshabilitado |
| habilitado | flanco de `BTN_HABILITAR` | `enable = 0`, `control_habilitado = 0` | deshabilitado |
| deshabilitado o habilitado | `falla = 1` | `control_habilitado = 0` | falla |
| falla | flanco de `BTN_HABILITAR` | nada | falla |
| falla | `BTN_RST` | reinicio de la plataforma | arranque |

No hace falta una variable de estado aparte, porque el estado queda determinado por `control_habilitado` y `falla`.

### h.2) Orden al habilitar y al deshabilitar

Al habilitar, primero reinicia los estados del PR y la fase de la referencia, después sube `control_habilitado` y por último `enable`. Mientras `control_habilitado` está en cero la interrupción no toca ni el PR ni la referencia, así que el reinicio no puede chocar con ella, y el primer `duty_ref` sale de un PR limpio y de una referencia que arranca en cero.

Al deshabilitar el orden se invierte. Primero baja `enable`, para que las compuertas se apaguen cuanto antes, y después `control_habilitado`. Si en medio cae una interrupción y escribe un `duty_ref` más, el periférico ya está apagado y no pasa nada.

Bajar `enable` no corta las compuertas en el acto. El núcleo PWM lo toma en el valle siguiente de la portadora, así que el puente puede seguir conmutando hasta un período más, 50 µs a 20 kHz, y `running` baja recién entonces. El orden de arriba no cambia por eso, y el tiempo hasta el corte es el mismo en la deshabilitación por botón y en la falla.

La escritura de `enable` es una lectura, modificación y escritura del offset `0x00`, compartido con `freq_sel`, y la interrupción también lo escribe cuando declara falla. `drivers` la hace con las interrupciones deshabilitadas, para que una falla declarada en medio no quede pisada por un `enable` en uno.

### h.3) Amplitud de la referencia

| `SW[1:0]` | `amplitud_ref` |
| --- | --- |
| `00` | 0 A |
| `01` | 0,2 A pico |
| `10` | 0,5 A pico |
| `11` | 1,0 A pico |

Se lee en cada vuelta y se aplica aunque el control esté andando, que es lo que necesita el ensayo de cambio de amplitud. El código `00` sirve para habilitar el puente con corriente nula antes de subir a un punto de operación. Los switches son niveles que no se mueven durante un ensayo, así que se usa el valor directo y no se les saca flanco.

Los switches son `SW0` y `SW1` de la Basys 3.

### h.4) Detección de flancos

Se guarda la lectura de los botones de la vuelta anterior, y el flanco de subida es `actual & ~anterior`. El antirrebote ya viene resuelto por el bloque 10, así que una pulsación da un solo flanco. Como el lazo principal da miles de vueltas por segundo, no hay forma de perder una pulsación humana.

### h.5) Cambio de `freq_sel`

El lazo cerrado corre solo a 20 kHz, que es `freq_sel = 01`, y el Timer no cambia con `freq_sel`. Las otras frecuencias de la tabla de `nucleo_pwm.md` (10 kHz en `00`, 40 kHz en `10`, y `11` que satura a 20 kHz) sirven para mostrar el PWM y para el testbench, con el control deshabilitado. Por eso dos reglas.

- `freq_sel` solo se escribe con `control_habilitado` en cero. Con el Timer fijo, a 10 kHz llega un disparo del ADC cada dos interrupciones, y `supervisor_falla` podría declarar falla por `ITERACIONES_SIN_DATO_MAX` sin que haya nada roto.
- El flanco de `BTN_HABILITAR` solo habilita si `freq_sel` vale `01`. El código `11` también termina en 20 kHz, pero se exige `01` exacto para que lo que se lee en el registro sea lo que corre.

### h.6) Valores provisionales

- `FREQ_SEL_INICIAL` vale `01`, que en la tabla de `nucleo_pwm.md` es 20 kHz y coincide con los 20 kHz de `PR_FRECUENCIA_MUESTREO_HZ`. Si Jefferson y Nicolás cambian las frecuencias de la tabla, este código se cambia con ellas.
- El período del Timer en ciclos sale de `PR_FRECUENCIA_MUESTREO_HZ`. Con el AXI Timer contando hacia abajo y recarga automática, el período es `TLR + 2` ciclos, así que `TLR = 100 MHz / PR_FRECUENCIA_MUESTREO_HZ - 2`. Con los 20 kHz de partida da `100 MHz / 20 kHz - 2 = 4998`, división exacta. La portadora del PWM a 20 kHz dura `2 · MAX = 5000` ciclos según `nucleo_pwm.md`, y el Timer tiene que quedar en exactamente esos 5000. Los dos cuentan el mismo reloj pero no están amarrados, así que si el período difiere aunque sea un ciclo el desfase entre la interrupción y el valle se corre, y cada tanto la interrupción lee dos veces la misma muestra o se salta una. El valor del desfase depende del orden de arranque, por eso conviene medirlo para el retardo del análisis de estabilidad. Falta medirlo con el GPIO de la interrupción contra `pwm_trigger_o`, y repetir la cuenta si cambia la frecuencia.

Lo que se busca es que la interrupción caiga después de que termine la conversión del XADC, del orden de 1 µs desde el disparo, unos 1,1 µs con el divisor 4 según `envoltura_xadc.md`, y con tiempo de sobra antes del siguiente valle. Cualquier desfase fijo en ese rango sirve. Lo que no sirve es que se mueva. La prueba es ver en el osciloscopio el flanco de subida del GPIO de la interrupción contra `pwm_trigger_o` durante unos minutos, y si la distancia deriva, el Timer y la portadora no están contando lo mismo.

## i) Diagrama esquemático detallado del diseño

No aplica, el módulo es el `main` en C del MicroBlaze V y no tiene compuertas propias.

## j) Diagrama completo de conexiones eléctricas del diseño

No aplica, el módulo no tiene pines propios, los botones, los switches y los LEDs llegan por el AXI GPIO y sus pines los fija el `basys3.xdc`.
