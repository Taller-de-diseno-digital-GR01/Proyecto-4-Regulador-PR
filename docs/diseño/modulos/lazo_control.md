# lazo_control

## a) Nombre del módulo

`lazo_control`, en `sw/lazo_control.c` y `sw/lazo_control.h`. Es la rutina de interrupción del AXI Timer dentro del software del MicroBlaze V del [nivel 3](../diagramas/nivel03.md).

## b) Diagrama modular

```mermaid
flowchart LR
    TMR(["AXI Timer"]) -->|"interrupción periódica"| LC["lazo_control<br/>una iteración del control<br/>en orden fijo"]
    DRV_IN(["drivers"]) -->|"dato nuevo y cuenta del ADC"| LC
    CP_IN(["control_principal"]) -->|"control_habilitado, amplitud_ref"| LC
    REF(["ref_senoidal"]) -->|"i_ref"| LC
    PR(["pr_discreto"]) -->|"duty_ref, saturado"| LC
    SF(["supervisor_falla"]) -->|"falla"| LC
    LC -->|"duty_ref, enable en cero ante falla"| DRV_OUT(["drivers"])
    LC -->|"registro por iteración"| BUF(["buffer_muestras"])
    LC -->|"falla"| CP_OUT(["control_principal"])
    LC -->|"salida de depuración"| DRV_OUT
```

## c) Objetivo del módulo

Ejecuta una iteración del control en cada interrupción del Timer, siempre en el mismo orden que fija la sección 4.2.4 del enunciado.

## d) Entradas

- La interrupción del AXI Timer, que llega directo a la entrada de interrupción del procesador, sin pasar por un controlador.
- La bandera de dato nuevo y la cuenta del ADC, por [`drivers`](drivers.md).
- `control_habilitado` y `amplitud_ref`, escritas por [`control_principal`](control_principal.md).
- `i_ref` de [`ref_senoidal`](ref_senoidal.md), `duty_ref` y `saturado` de [`pr_discreto`](pr_discreto.md), y `falla` de [`supervisor_falla`](supervisor_falla.md).
- La calibración del sensor, como `#define` en `lazo_control.h`.
  - `ADC_OFFSET_CUENTAS`, la cuenta que corresponde a 0 A.
  - `ADC_AMPERES_POR_CUENTA`, cuántos amperes vale una cuenta.

## e) Salidas

- `duty_ref` hacia el offset `0x04` del periférico PWM, y `enable` en cero si hay falla, por `drivers`.
- Un `registro_t` por iteración hacia [`buffer_muestras`](buffer_muestras.md).
- `falla`, variable compartida que lee `control_principal`.
- La salida de depuración temporal, en alto mientras dura la rutina, por `drivers`.

## f) Explicación de la relación con otros módulos

Es el único módulo con plazo fijo y el centro del contexto de interrupción. Llama a `ref_senoidal`, `pr_discreto`, `supervisor_falla` y `buffer_muestras`, y por `drivers` toca el ADC, el PWM, el Timer y la salida de depuración. Con `control_principal` se comunica solo por las tres variables compartidas del nivel 3. `control_principal` lo registra como manejador de la interrupción del procesador durante el arranque.

## g) Explicación de funcionamiento

Cada interrupción sigue esta secuencia.

1. Sube la salida de depuración.
2. Reconoce la interrupción del Timer.
3. Lee una vez el registro del ADC por medio de `drivers`. Si hay muestra nueva, actualiza la cuenta y la corriente con `corriente = (cuenta - ADC_OFFSET_CUENTAS) · ADC_AMPERES_POR_CUENTA` y llama a `supervisor_falla_revisar`. Si falta la muestra, conserva la última cuenta válida, marca `dato_ausente` y llama a `supervisor_falla_sin_dato`.
4. Con el resultado de cualquiera de las dos llamadas, detecta una transición a falla. Si aparece, escribe `enable = 0` mediante `drivers_pwm_apagar()`, preserva `freq_sel` y publica `falla = 1`.
5. Si el control está habilitado y libre de falla, obtiene `i_ref` para esta iteración. Con muestra nueva, ejecuta el PR y escribe su `duty_ref`. Con muestra ausente dentro de la tolerancia, avanza la fase de la referencia, conserva los estados del PR y mantiene el último `duty_ref`. Con el control deshabilitado o en falla, registra `i_ref = 0` y omite el PR.
6. Arma el registro con la cuenta, el último `duty_ref` escrito, `i_ref` y las cuatro banderas, y se lo pasa a `buffer_muestras`.
7. Baja la salida de depuración.

Con el control deshabilitado la rutina sigue registrando la corriente cuando el Timer está en marcha. Esto permite revisar el offset del sensor con el puente deshabilitado.

## h) Diseño

### h.1) Orden respecto al enunciado

La sección 4.2.4 pide adquirir y validar el dato, calcular el PR, escribir `duty_ref` y guardar la muestra. Los pasos 3 y 4 validan la adquisición y procesan la falla antes de permitir el cálculo y la escritura del paso 5. El paso 6 conserva un registro incluso cuando falta una muestra o hay una falla.

### h.2) Reconocimiento del Timer

Se reconoce escribiendo directo el bit de interrupción del registro de control y estado del AXI Timer, por medio de `drivers`, en vez de pasar por el manejador genérico del driver de Xilinx. El manejador genérico recorre los contadores y llama a una función de usuario, y eso agrega llamadas en el camino más sensible al tiempo del programa.

Reconocerlo al principio y no al final no cambia nada mientras la rutina dure menos que el período, y si algún día dura más, la interrupción siguiente queda pendiente en vez de perderse.

### h.3) Salida de depuración

La sube al entrar y la baja al salir, así que en el osciloscopio el ancho del pulso es el tiempo de servicio y la distancia entre flancos de subida es el período efectivo, con su jitter. Los retardos que se midan así se le entregan a quien analice la estabilidad del PR.

La escribe solo esta rutina, y los LEDs solo `control_principal`. Por eso tienen que quedar en canales distintos del AXI GPIO. Si compartieran registro, una lectura y escritura del lazo principal interrumpida a la mitad podría pisar el valor que dejó la rutina.

### h.4) Apagado ante falla

El paso 4 es común a las rutas con y sin dato. En la primera iteración que declara falla, `drivers_pwm_apagar()` lee, modifica y escribe el offset `0x00`, baja solo `enable` y mantiene `freq_sel`. Las iteraciones posteriores conservan la falla enclavada y omiten escrituras del PR. El núcleo toma la orden de apagado en el siguiente valle que capture el nuevo `enable` y desactiva las compuertas con su latencia registrada.

La ISR publica `falla` y el lazo principal baja `control_habilitado` en su siguiente vuelta. La última comprobación de `falla` y la habilitación del PWM quedan en una misma sección crítica del [control principal](control_principal.md#h2-orden-al-habilitar-y-al-deshabilitar).

### h.5) Registro de la iteración

- `cuenta_banderas` lleva la cuenta en `[11:0]`, `saturado` en el bit 15, `dato_ausente` en el 14, si el control estaba habilitado en el 13 y `falla` en el 12.
- `duty_ref` es el último valor escrito en el PWM, aunque en esta iteración no se haya calculado.
- `i_ref_ma` es `i_ref · 1000` truncado a entero. Vale cero con el control deshabilitado o en falla. Ante una ausencia tolerada se registra la referencia de esa iteración y la cuenta anterior se identifica con `dato_ausente`. La bandera `saturado` conserva el resultado del último cálculo del PR si la orden se mantiene.

### h.6) Calibración

`ADC_OFFSET_CUENTAS` y `ADC_AMPERES_POR_CUENTA` salen de medir el sensor montado, y los mide Jefferson (#32). Mientras tanto quedan con valores teóricos, marcados con `// TODO: Revisar` en `lazo_control.h`.

El offset es el del nivel 2, 0 A en 0,5 V, o sea 2048 cuentas, la mitad de la escala de 12 bits. Para la ganancia se parte de una sensibilidad del sensor de 0,3 V/A, que lleva ±1,0 A a 0,2 V y 0,8 V y deja 0,2 V de margen en cada extremo de los 0 a 1 V del XADC para los transitorios. Con ella `ADC_AMPERES_POR_CUENTA = 1 V / (4096 · 0,3 V/A) = 8,138e-4 A`, 0,81 mA por cuenta, que es 0,4 % de la corriente del ensayo más chico (0,2 A). La escala completa queda en ±1,67 A, y eso pesa porque el umbral de sobrecorriente de `supervisor_falla` (1,3 A) tiene que caer dentro de lo que el ADC puede ver. Con 0,4 V/A también habría margen de tensión, pero la escala llegaría solo a ±1,25 A y el umbral no se alcanzaría nunca. La sensibilidad real la fija Jefferson en #28, y si cambia se actualizan las dos constantes y los límites de `supervisor_falla`.

### h.7) Presupuesto de tiempo

El período del Timer sale de `PR_FRECUENCIA_MUESTREO_HZ`, que con los valores de partida es 20 kHz, o sea 5000 ciclos de 100 MHz por iteración. La rutina hace un puñado de accesos AXI, seis multiplicaciones del PR, una de la referencia y una de la conversión, así que con FPU debería quedar en cientos de ciclos. Sin FPU, cada operación en `float` por software cuesta del orden de 50 a 100 ciclos, y las unas veinte operaciones de la rutina suman entre 1500 y 2500 ciclos, de 15 a 25 µs. Es una estimación gruesa y lo que vale es lo que mida la salida de depuración, antes de decidir si se pasa a punto fijo.

Para sostener el retardo de diseño, el flanco que acepta la lectura del XADC debe ocurrir después de publicar la muestra del valle actual. La orden registrada de `duty_ref` debe llegar a la primera etapa del núcleo al menos dos ciclos antes del siguiente valle, más un margen de integración. Se cuenta la latencia de la ISR, los accesos AXI y la tubería del PWM. La ISR completa debe terminar antes de la siguiente interrupción.

El [plan de verificación](../plan_verificacion_pwm.md) mide estas condiciones tras varios reinicios y con exportación UART concurrente. Si se incumple la ventana, se ajusta el arranque o el presupuesto de la ISR y se revisa el retardo usado en el modelo del lazo.

### h.8) Interfaz en C

- `void lazo_control_isr(void *ref)`, la rutina que `control_principal` registra como manejador de la interrupción del procesador.
- Las variables compartidas `volatile uint32_t control_habilitado`, `volatile valor_t amplitud_ref` y `volatile uint32_t falla`, declaradas en `lazo_control.h`.

## i) Diagrama esquemático detallado del diseño

No aplica, la rutina es código C que corre en el MicroBlaze V y no tiene compuertas propias, el hardware que la dispara es el AXI Timer de Xilinx.

## j) Diagrama completo de conexiones eléctricas del diseño

No aplica, el módulo no tiene pines, la única señal física que maneja es la salida de depuración, cuyo pin lo asigna el `basys3.xdc` del Block Design.
