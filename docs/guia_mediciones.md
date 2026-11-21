# Guía de mediciones, qué medir y cómo

Esta guía es para la sesión de laboratorio. Cada medición lleva un código (0.1, A2, D3, ...), el instrumento, el montaje, los pasos, lo que se espera y cuándo se da por buena. Los 16 puntos marcados `PENDIENTE` en la sección 12.8 del informe y la columna de medición de la Tabla 13.1 salen de acá, y al lado de cada título dice cuál. Lo que se espera sale de [`diseno_pr.md`](../potencia/diseno_pr.md), [`pruebas_integracion.md`](pruebas_integracion.md) y el informe, y acá no se repiten las cuentas, solo el número que hay que comparar.

El orden importa. El sensor bloquea al ADC y el ADC bloquea todo lo que se mide con el lazo cerrado, así que se mide primero. Lo que falle en una etapa se arregla antes de pasar a la siguiente.

## Antes de empezar

Instrumentos. Osciloscopio (de cuatro canales si se puede) con una sonda diferencial y una sonda de corriente si hay, analizador lógico, el multímetro Agilent 34405A (dos, si se consigue), medidor LCR, fuente de laboratorio con límite de corriente, y un termómetro o cámara térmica para el punto D9. La referencia de corriente de cada ensayo es la sonda de corriente del osciloscopio. Si no hay sonda, la tensión sobre la resistencia externa de la carga dividida entre su valor, porque la inductancia no entra en ella.

Límites de seguridad.
- Primera energización con `Vdc = 12 V` y la fuente limitada a 0,1 A. Ensayos con `Vdc = 18 V` y la fuente limitada a 0,52 A. El fusible de la entrada es de 630 mA.
- Con la carga de 9 Ω y 200 µH, 12 V alcanzan para 1,0 A (índice de 0,75), y dan menos rizado que 18 V. Con 24 V el rizado llega a 0,69 A pp a 1,0 A, así que no se sube de 18 V.
- Antes de energizar, las compuertas y el tiempo muerto se revisan con la potencia apagada (etapa B). Es condición del enunciado.
- Las sondas de las compuertas altas flotan. La tierra de la sonda nunca va a la salida de una pierna. Se usa sonda diferencial, o se mide del lado de la FPGA.

Software que tiene que estar listo, y hoy no lo está del todo.
- `ADC_AMPERES_POR_CUENTA` vale 8,138e-4 y el análisis de la sección 9.4 del informe espera 1,017e-3 si el banco quedó con el restador de ganancia 2,4. La etapa A dice cuál corresponde. Hasta cambiarla, las corrientes que muestra `receptor_pc` salen mal escaladas, y las cuentas crudas se recuperan con `cuenta = corriente_a / amperes_por_cuenta + offset` usando los valores de la cabecera.
- El ensayo D1 pide un `duty_ref` senoidal fijo sin PR, y en `sw/` no hay ese modo. Hay que decidir cómo se hace (por ejemplo una compilación aparte de `lazo_control.c`) antes de la sesión, o D1 se salta y se anota como no hecho.
- Para D6 hace falta una compilación con `UMBRAL_SOBRECORRIENTE` temporalmente bajo, y volverlo a 1,3 A al terminar.

Cómo se guarda. Cada captura va a `docs/informe/mediciones/` con el nombre `AAAA-MM-DD_codigo_descripcion`, por ejemplo `2026-11-17_D3_pr_05A.png` y `2026-11-17_D3_pr_05A.csv`. Junto a cada una se anotan `Vdc`, `R` y `L` medidos, `freq_sel`, el commit de `sw/` con que se corrió, la escala vertical y horizontal del osciloscopio y qué instrumento tomó la medida. La lista completa de lo que se anota está al final.

## Etapa 0, la carga y las fuentes (#31)

0.1 Resistencia total de la carga. Multímetro en cuatro hilos si hay, y si no en dos hilos restando la resistencia de las puntas. Se mide en frío y otra vez tras unos minutos con corriente, porque el cobre sube con la temperatura. Esperado 9 Ω, los 8 Ω de la resistencia más unos 0,5 Ω de cada inductor. Si se aleja más de 25 %, se corre `potencia/verificar_pr.m` con el valor medido antes de seguir, porque los márgenes de esquina del PR cubren ±25 % en `R`.

0.2 Inductancia de los dos inductores en serie. Medidor LCR en serie a 1 kHz, porque a 100 Hz la reactancia de 200 µH es de 0,13 Ω, menos que la resistencia del propio devanado, y la lectura sale ruidosa. Esperado 200 µH. Si se aleja más de 30 %, lo mismo que en 0.1. El LCR mide con corriente chica y el núcleo puede saturar, así que en la hoja de datos la corriente de saturación tiene que pasar holgada los 1,3 A del umbral de falla. Con 200 µH el desfase a 50 Hz es de 0,4° y el ensayo D1 ya no sirve para contrastar `L`, así que se contrasta con la pendiente del rizado en el osciloscopio durante D3.

0.3 `Vdc` con la carga conectada y `VCC` del sensor, ambos con multímetro. `VCC` tiene que dar 5,0 V, y su valor entra en el cálculo del cero en A1.

## Etapa A, el sensor y el ADC (#32, #29)

Potencia apagada para A1, A3 y A4. Sensor alimentado, Pmod del XADC conectado, firmware corriendo con el control deshabilitado. La portadora corre aunque `enable` esté en 0, y el trigger sigue llegando al XADC.

A1 Cuenta del ADC con 0 A (parte de la fila de ADC en 12.8). Sin corriente en el primario del sensor, se deja correr unos segundos y se aprieta el botón de exportar. Con `receptor_pc`, se pasa el CSV a cuentas y se saca la media y la desviación de las 2048 muestras. Con el multímetro se mide también la salida del acondicionador en reposo, que tiene que ser `0,1·VCC`, 0,5 V con 5 V. Esperado 2048 cuentas, con ±102 si `VCC` se corre ±5 %. Se da por bueno si la media cae dentro de esa banda y coincide con el multímetro. Lo que dé se anota, aunque sea bueno, porque el software supone 2048 fijo.

A2 Ganancia del sensor de extremo a extremo (segunda parte de la fila de ADC en 12.8). Sin usar el puente. Fuente de laboratorio en continua, la resistencia externa de la carga en serie con el primario del ACS712 y el multímetro en serie como referencia de corriente. Se toman los puntos de -0,5, -0,2, 0, +0,2 y +0,5 A (se invierte la polaridad de la fuente para los negativos). Hay que parar en 0,5 A, que son 3 W en unas resistencias de 5 W. En cada punto se espera a que se estabilice, se exporta y se anota la media de cuentas con la corriente del multímetro. La pendiente por mínimos cuadrados da cuentas por ampere. Esperado 1/(1,017e-3) ≈ 983 cuentas por ampere si el restador es de ganancia 2,4 (0,24 V/A), y la mitad si quedó el del archivo de LTspice (0,12 V/A). La tolerancia de ±4 % del ACS712 es parte del resultado, y dentro de ella se da por buena. Con la pendiente se fija `ADC_AMPERES_POR_CUENTA`, y se anota la desviación contra lo que supone el software.

A3 Ruido del sensor. Sale de los mismos datos de A1, desviación y valor pico a pico en cuentas con corriente cero. La cota del análisis es de unas 108 cuentas pico a pico (0,11 A), y de lo que salga depende cuánto pesa en el ensayo de 0,2 A. Se anota también si el ruido cambia con el puente habilitado y sin carga, para ver cuánto aporta la conmutación (se hace en la etapa D, con tensión).

A4 Retardo del filtro del sensor. Se inyecta una senoidal de 1 kHz en la entrada del acondicionador con un generador, y se mide el desfase entre la entrada y la salida del RC con el osciloscopio. Esperado un retardo de 33 µs (corte en 4823 Hz). Sirve para sumar el valor real a los 75 µs del modelo en C4.

## Etapa B, compuertas con la potencia apagada

Sin `Vdc` en el puente. Con el control habilitado y `freq_sel = 01`, que es lo único con que se habilita. Las capturas se hacen en el Pmod JA y en las compuertas de los MOSFET, con las precauciones de arriba para las flotantes.

B1 Período de cada compuerta (fila de período de las compuertas). Esperado 50,0 µs, con el osciloscopio midiendo período con estadística en los cuatro canales. Se da por bueno si el período mide 50,0 µs dentro de la resolución del instrumento.

B2 Tiempo muerto (fila de tiempo muerto). En cada pierna, un canal en la compuerta alta y otro en la baja, disparo en el flanco de bajada de una y medida entre los puntos del 50 % de las dos. Se mide en los dos flancos y en las dos piernas. Esperado 1,00 µs en el Pmod. En los MOSFET el hueco es más corto o más largo según los retardos de la cadena de compuertas, entre 0,1 y 0,91 µs de diferencia, y se anota cuánto. Si da distinto de 1 µs en el Pmod, se recalcula la predicción del ensayo D1.

B3 Conducción simultánea (fila de conducción simultánea). Alta y baja de la misma pierna en el osciloscopio con persistencia infinita durante al menos 10 s, mientras se cambia `duty_ref` con los switches, se baja y sube `enable` y se hacen varios reinicios. No puede haber una sola captura con las dos en alto. En los MOSFET, el peor caso de la cadena deja 0,19 µs de hueco, así que se espera un hueco mayor que cero en todas.

B4 Centro de los pulsos (fila del valle). Con `duty_ref` distinto de cero, un canal en la compuerta alta de la pierna A y otro en la de la B. El centro de los dos pulsos cae en el mismo instante, el valle de la portadora. Se anota la diferencia entre los centros.

B5 Trigger. `pwm_trigger_o` contra la compuerta alta de la pierna A. Esperado un pulso de un ciclo (10 ns) que cae en el valle de la portadora, ese instante más un ciclo, a las tres frecuencias (`freq_sel` 00, 01 y 10). Se anota el instante en que cae respecto del centro de los pulsos.

B6 Resto de comportamientos del PWM de [`pruebas_integracion.md`](pruebas_integracion.md). Apagado con el pulso en curso terminando entero, saturación de `duty_ref` fuera de rango, escritura a mitad de período sin pulsos partidos. No tienen fila propia en 12.8, y se prueban con el mismo montaje de B3.

## Etapa C, el lazo en tiempo real

Potencia apagada, lazo habilitado. Canal 1 en el pin de depuración (`axi_gpio_1`, bit 0) y canal 2 en `pwm_trigger_o`.

C1 Período y jitter de la ISR (fila del período de la interrupción). Medida de período con estadística sobre los flancos de subida del pin, y persistencia para el jitter pico a pico. Esperado 50,0 µs. Se mide con el lazo habilitado y con el lazo deshabilitado, y se repite mientras se exporta, para confirmar que la exportación no mueve ninguno de los dos.

C2 Duración de la ISR (fila de la duración). Ancho del pulso del pin, medido con el PR corriendo y con la falla enclavada. Se anota el peor caso. Tiene que dejar tiempo de sobra de los 50 µs al lazo principal.

C3 Fase de la ISR contra el trigger (fila de la fase). Tiempo entre `pwm_trigger_o` y el flanco de subida del pin de depuración, repetido al menos 10 veces tras reiniciar la placa. Esperado el mismo valor en todas, sin deriva dentro de una misma corrida.

C4 Retardo efectivo del lazo (fila del retardo). Se suman las partes medidas, el retardo de la ISR contra el trigger de C3, el tiempo desde el fin de la ISR hasta el valle siguiente, el retardo de la cadena de compuertas de B2 y el del filtro del sensor de A4. Se compara con los 75 µs del modelo más el `τF` del filtro. El margen es de 203 µs antes de perder los 6 dB de margen de ganancia, y el de fase no baja de 45° ni con 400 µs. Es una estimación por suma y no una medida directa. Si la suma se pasa, hay que rehacer la sintonización.

## Etapa D, energizado por pasos

Arranque. `Vdc = 12 V` y límite de 0,1 A, y se verifica que no hay corriente con el control deshabilitado. Se habilita con amplitud 0,2 A, y cuando eso sale bien se sube a 18 V con límite de 0,52 A y a 0,5 y 1,0 A. En cada ensayo, el osciloscopio lleva la corriente de la carga, la tensión sobre la carga, la compuerta alta de una pierna y la referencia si se puede sacar. El histórico se exporta con el botón una vez en régimen, y la ventana es de 5,12 períodos.

D1 Ensayo 1, lazo abierto (fila del ensayo 1). Necesita el modo de lazo abierto de arriba. Con 18 V y `duty_ref` senoidal fijo de índice 0,100, 0,250 y 0,500. Esperado 0,097, 0,381 y 0,860 A de fundamental, con desfases de -11,1°, -0,3° y -0,3°. Con la carga casi resistiva el tiempo muerto se come casi la mitad de la tensión a 0,2 A, por eso la predicción queda tan por debajo. Las cifras de PLECS que había acá eran de la carga de 30 mH y ya no aplican. Se da por bueno dentro de 10 % de la predicción, y si se pasa se detiene y se revisa el sensor, el signo y los `L` y `R` de la etapa 0 antes de cerrar el lazo.

D2 Ensayo 2, solo proporcional (fila del ensayo 2). Con `Kr = 0` regenerando `pr_params.h` con `sw/generar_pr_params.m`. Esperado un error de amplitud de 80,8 % con 0,5 A y 74,2 % con 1,0 A, con desfase de -1,2°. Con `Kp = 4,5` el proporcional solo hace poco, y con 0,2 A la tensión que pide queda casi igual a la que se come el tiempo muerto, así que esa amplitud no tiene predicción útil y se salta. Se mide con `receptor_pc` sobre la ventana exportada. Si sale muy distinto, la planta o el retardo no son los del modelo.

D3 Ensayo 3, PR completo (fila del ensayo 3). Con 0,2, 0,5 y 1,0 A pico elegidos con los switches. Error de la fundamental menor a 10 % en una ventana de al menos cinco períodos en régimen, con `receptor_pc`, que además da el desfase. El rizado de conmutación es lo que el histórico no ve, y se mide con el osciloscopio sobre la corriente con acople AC, el ancho de banda limitado a 20 MHz y la sonda de corriente, o con la tensión sobre la resistencia externa dividida entre su valor. El criterio es un rizado menor a 0,20 A pico a pico, y con 200 µH a 20 kHz la predicción es de 0,20, 0,41 y 0,55 A con 18 V, y de 0,19, 0,34 y 0,37 A con 12 V, así que se espera que falle en 0,5 y 1,0 A (`potencia/diseno_pr.md`, sección de rizado). El rizado no se saca de la salida del sensor, porque el RC de 4,8 kHz lo filtra, se mide en la sonda.

D4 Ensayo 4, cambios de amplitud (fila del ensayo 4). Con el lazo en régimen se cambia el switch de 0,2 a 0,5 A y de 0,5 a 1,0 A. Se captura con disparo único por nivel de corriente en el osciloscopio, 10 períodos como mínimo, y se guarda la forma de onda en CSV. Se anota la amplitud pico de cada período tras el cambio. La rampa de 400 muestras hace que la amplitud suba durante 20 ms, y el criterio está en el segundo período en adelante. Se espera menos de 10 % desde ahí (en la simulación 4,0 % en el segundo y 3,5 % en el tercero con el peor caso). No hay todavía un cálculo por período sobre el CSV del osciloscopio, y mientras no exista se mide a mano.

D5 Ensayo 5, cambio de `R` (fila del ensayo 5). Con 0,5 A en régimen, se agrega en serie una resistencia de 3 Ω (33 % de 9 Ω, sobre el 25 % mínimo) con un interruptor en paralelo que la cortocircuite, y se abre el interruptor para cambiar `R`. Nunca se desconectan los inductores, porque aunque 200 µH guardan poca energía, una corriente que se corta de golpe levanta una tensión que el puente no aguanta. Misma captura que en D4. Esperado un error de unos 2,2 % en el primer período (es la cifra con 25 %, con 3 Ω da algo más) y bajando, sin disparar la falla.

D6 Falla con carga (fila de la falla). Con la compilación de umbral bajo, y el PR corriendo con 1,0 A, el supervisor tiene que bajar las cuatro compuertas, encender `led[1]` y no rearmar solo. Se mide con el osciloscopio el tiempo entre que la corriente cruza el umbral y las compuertas bajan, que tiene que ser de hasta 100 µs (dos períodos). Una sobrecorriente real de más de 1,3 A no se puede armar con seguridad con el lazo cerrado, porque con 18 V el PR saturado solo llega a 1,38 A, y por eso la prueba se hace con el umbral bajo. Al terminar se vuelve el umbral a 1,3 A y se recompila.

D7 Saturación. `saturado` no aparece en el histórico con 18 V y 1,0 A en régimen, y `duty_ref` queda por debajo de 0,92. Sale del mismo histórico de D3.

D8 Deshabilitar y volver a habilitar a mitad de un ensayo. El primer período tras habilitar no trae un escalón de corriente, porque `duty_ref` y el PR arrancan en cero. Se ve en el osciloscopio.

D9 Temperatura (fila de las temperaturas). Tras unos minutos a 1,0 A con 18 V, temperatura de los MOSFET, de la resistencia de la carga, de los dos inductores y de la fuente. Se anota el tiempo transcurrido. A 1,0 A pico la resistencia de 8 Ω disipa unos 4 W y cada inductor unos 0,25 W, más lo que pierda el núcleo con 0,55 A pp de rizado, y de ahí se compara con la potencia que aguantan.

## Qué se anota de cada ensayo

- Valor medido, instrumento y su resolución, y el valor esperado con su fuente.
- Fecha, hora y quién operó y quién tomó los datos.
- `Vdc`, `R` y `L` medidos en la etapa 0, `freq_sel`, y el commit de `sw/` con que se compiló.
- Escalas del osciloscopio, acople, límite de ancho de banda y el punto del circuito donde estaba cada sonda.
- Archivos de la captura y del histórico exportado, con el comando de `receptor_pc` que se usó (`python3 sw/receptor_pc.py muestras.bin -o muestras.csv`).
- Qué falló, qué se cambió y en qué commit quedó corregido.

Con esas medidas se reemplaza cada `PENDIENTE` de 12.8 por el valor medido, se llena la columna de medición de la Tabla 13.1 y se discuten las diferencias contra la predicción y PLECS en la sección 13.

## Criterio de aprobación general

- Compuertas sin cruce y con 1 µs de tiempo muerto en el Pmod, trigger en el valle.
- ISR de 50 µs con jitter estable y retardo medido dentro del margen del modelo, con la exportación sin efecto sobre los dos.
- Error de la fundamental menor a 10 % con 0,2, 0,5 y 1,0 A en al menos cinco períodos, y rizado menor a 0,20 A pico a pico.
- Cambio de amplitud y cambio de `R` de 25 % recuperados sin saturar ni disparar la falla.
- Falla enclavada y apagado seguro verificados con la potencia real.

## Si el tiempo alcanza para poco

Con la clase de las 17:00 el tiempo útil es corto, y el orden en que conviene gastarlo es este.

1. A1 y A2, porque sin ellos nada de lo que sigue tiene la escala correcta, y 0.1 y 0.2 en paralelo mientras alguien arma el montaje.
2. B2 y B3, que son la condición del enunciado para energizar.
3. D3 con 0,5 A, y después 0,2 y 1,0 A. Es lo que más pesa en la nota de PEDP (los tres ensayos con valores reales de `R` y `L`) y en el informe de Taller.
4. D4 y D5, que son los otros dos ensayos que pide la rúbrica de PEDP.
5. C1 a C4, que se pueden hacer sin tensión y entre ensayos mientras se enfría algo.
6. El resto, D1, D2 y D6 a D9, según haya modo de lazo abierto y tiempo.
