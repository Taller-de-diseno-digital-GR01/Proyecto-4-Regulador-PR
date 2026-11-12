# Modelo de la planta, decisiones y justificación

Este documento reúne el modelo de la planta del lado de potencia. Cubre el modelo dinámico de la carga RL, la función de transferencia desde `duty_ref` hasta la corriente, la relación entre `duty_ref` y la tensión promedio sobre la carga con modulación unipolar, el rizado de conmutación en los puntos de operación y la justificación de la frecuencia de conmutación.

## Valores

- `R = 10 Ω` y `L = 2 mH`, la carga RL del montaje. La resistencia propia del inductor y la del cableado se suman a `R`.
- `Vdc = 18 V`, la tensión de operación (acordada para la integración con la etapa de control).
- `f_sw = 20 kHz`, con `freq_sel = 01` y `MAX = 2500` (núcleo del PWM en la FPGA). El lazo muestrea al mismo ritmo, `Ts = 50 µs`.
- Tiempo muerto `TM = 1 µs`, `DEAD_TIME_CICLOS = 100` (diseño del puente H, sección "Tiempo muerto").
- `RDS(on)` de 0,20 Ω máximos por MOSFET, con `VGS` = 10 V [1, p. 2].

## Tensión promedio con modulación unipolar

El puente tiene dos piernas, A y B. Cada una es un medio puente cuya salida respecto del negativo del bus vale `Vdc` mientras conduce la alta y 0 mientras conduce la baja. La carga ve `v_o = v_A − v_B`, así que `v_o` toma los valores `+Vdc`, 0 y `−Vdc`.

El núcleo del PWM compara las dos piernas contra la misma portadora triangular, que cuenta de 0 a `MAX` y vuelve. La referencia de la pierna A es `ref_a = MAX·(1 + d)/2`, con `d = duty_ref / 16384` por el formato Q2.14 y saturado a ±1. La pierna B usa la referencia opuesta, con `−d`.

La alta de A conduce mientras la portadora está por debajo de `ref_a`. Como la portadora es lineal y simétrica, esa fracción del período vale `ref_a / MAX = (1 + d)/2`, y la de B vale `(1 − d)/2`. Los promedios en un período de conmutación quedan en

```
v̄_A = Vdc·(1 + d)/2
v̄_B = Vdc·(1 − d)/2
v̄_o = v̄_A − v̄_B = Vdc·d
```

En promedio, el puente es un amplificador lineal de ganancia `Vdc` mientras `|d| ≤ 1`. Con `d = 0` las dos piernas quedan en `Vdc/2` y la carga en 0 V.

Con `d > 0`, los intervalos en que conducen las dos altas o las dos bajas dejan `v_o` en 0, así que en el semiciclo positivo la carga solo ve 0 y `+Vdc`. Eso es lo que hace unipolar a la modulación, y por eso la tensión sobre la carga pulsa a `2·f_sw` = 40 kHz aunque cada transistor conmute a 20 kHz.

## Validez del modelo promedio

La constante de tiempo de la carga es `τ = L/R` = 0,2 ms, cuatro veces el período de conmutación y ocho veces el de los pulsos de 40 kHz que ve la carga. En un pulso la corriente recorre solo una fracción de su excursión, y esa fracción es el rizado de conmutación.

Visto en frecuencia, el RL con la corriente como salida es un pasabajos de primer orden con corte en `f_c = R/(2π·L)` ≈ 796 Hz. La referencia de 50 Hz queda 16 veces por debajo del corte y pasa con poca atenuación y poco desfase. Los 40 kHz quedan 50 veces por encima y se atenúan en esa proporción. Para el lazo de control alcanza entonces con `v̄_o = Vdc·d`, y el rizado se calcula aparte. El cruce del PR en 1 kHz (diseño del PR) también queda muy por debajo de los 20 kHz de muestreo.

## Función de transferencia

La ley de tensiones de Kirchhoff sobre la carga da

```
v_o = R·i + L·di/dt
```

La tensión se reparte entre la caída en la resistencia y la que cambia la corriente en la bobina. Con condiciones iniciales nulas, en Laplace queda `I(s)/V_o(s) = 1/(L·s + R)`, con un polo en `s = −R/L` = −5000 rad/s, que es el corte de 796 Hz. Con `V_o = Vdc·D`, la planta que ve el PR es

```
I(s)/D(s) = Vdc/(L·s + R)
```

Su ganancia en continua es `Vdc/R` = 1,8 A por unidad de `d`. Es la corriente en la que se asienta la carga con `d = 1` sostenido, y con `PR_U_MAX = 0,92` da el techo de 1,66 A del diseño del puente H (sección "Tensión y corriente").

## Régimen senoidal en 50 Hz

En 50 Hz la carga es `Z = R + jωL`, con `ωL` = 0,63 Ω, así que `|Z|` = 10,02 Ω y la corriente atrasa 3,60° respecto de la tensión. La bobina casi no pesa en 50 Hz y la amplitud la fija la resistencia. El índice pico que pide una corriente `I` es `m = |Z|·I / Vdc`.

| Corriente pico | Tensión pico sobre la carga | `m` con 18 V |
|---|---|---|
| 0,2 A | 2,00 V | 0,111 |
| 0,5 A | 5,01 V | 0,278 |
| 1,0 A | 10,02 V | 0,557 |

Como `|Z|` depende casi solo de `R`, el cambio de carga de +27 % sube el `m` que pide cada referencia casi en la misma proporción.

## Modelo discreto

El núcleo del PWM carga el nuevo `duty_ref` en el valle y lo sostiene hasta el valle siguiente, así que durante un período `d` es constante (retenedor de orden cero). La corriente del RL con entrada constante sigue la respuesta de primer orden

```
i(t) = i_final + (i_inicial − i_final)·e^(−t/τ)
```

con `i_inicial = i[k]` e `i_final = (Vdc/R)·d[k]`, la corriente en la que se asentaría la carga si `d[k]` quedara aplicado. Evaluada en `t = Ts` y ordenada,

```
i[k+1] = a·i[k] + b·d[k]
a = e^(−Ts/τ) = e^(−0,25) = 0,7788
b = (Vdc/R)·(1 − e^(−Ts/τ)) = 0,398 A
```

`a` es la fracción de la corriente que pasa de un período al siguiente sin tensión aplicada, y `b` es la fracción del camino hacia `Vdc/R` que la corriente recorre en un período. Son los mismos coeficientes que usan el diseño del PR y la planta simulada del software de prueba.

El `duty_ref` que calcula la ISR del muestreo k entra al PWM en el valle k + 1, así que la corriente medida responde a `d[k−1]` y el lazo lleva un muestreo de retardo.

## Efecto del tiempo muerto y de la `RDS(on)`

Durante el tiempo muerto las dos compuertas de una pierna están apagadas. La bobina sostiene la corriente, que pasa por el diodo de cuerpo que le da camino, y el valor de la pierna lo fija el signo de la corriente y no el PWM.

El caso con la corriente positiva, que sale de A hacia la carga y entra a B, queda así.

- En A conduce el diodo de la baja y `v_A` queda en 0 (menos la caída del diodo). En el hueco que sigue al apagado de la alta, `v_A` iba a 0 de todos modos. En el hueco que sigue al apagado de la baja, `v_A` sigue en 0 durante `TM` cuando ya tendría que estar en `Vdc`. La pierna pierde `Vdc·TM` por período.
- En B conduce el diodo de la alta y `v_B` queda en `Vdc`. En el hueco que sigue al apagado de la alta, `v_B` sigue en `Vdc` durante `TM` cuando ya tendría que estar en 0. La pierna gana `Vdc·TM` por período.

Como la carga ve la resta, las dos se suman, y la tensión promedio pierde

```
Δv = 2·Vdc·TM·f_sw = 0,72 V
```

que equivale a `Δd = 2·TM·f_sw` = 0,04 [2, Sec. 8-5, ec. 8-77]. Con la corriente negativa conducen los otros dos diodos y el efecto se invierte. A lo largo de un ciclo de 50 Hz el error es una onda cuadrada de ±0,72 V en fase con la corriente, con fundamental `(4/π)·0,72` = 0,92 V. La caída de los diodos durante el hueco suma una pérdida más, la caída por 0,04, que queda por debajo de una décima de los 0,72 V y no se cuenta.

En cualquier estado del puente conducen dos MOSFET en serie con la carga, uno por pierna, así que la `RDS(on)` suma hasta 0,4 Ω a `R`. Es una cota, porque con 15 V de compuerta la resistencia es menor que la de la hoja a 10 V.

El tiempo muerto que se cuenta es el programado. El hueco real en las patas de los MOSFET cambia con la asimetría de la cadena de compuertas, y la pérdida escala en proporción. El modelo de onda cuadrada también supone que el error cambia de signo justo cuando la corriente cruza por cero. Cerca del cruce eso no pasa. Mientras `|Vdc·d|` es menor que 0,72 V, el tiempo muerto se lleva toda la tensión aplicada y la corriente queda en cero hasta que la referencia supera ese valor. En ese tramo el error copia a la tensión de referencia en lugar de valer ±0,72 V, así que la pérdida es algo menor que la de la onda cuadrada y su fundamental queda casi en fase con la tensión. Con 0,2 A el tramo cubre unos ±21° alrededor de cada cruce.

| Referencia | `m` aplicado | Con tiempo muerto | Con tiempo muerto y `RDS(on)` | Modelo conmutado | Desfase en el modelo conmutado |
|---|---|---|---|---|---|
| 0,2 A | 0,111 | 0,109 A (−46 %) | 0,104 A (−48 %) | 0,106 A (−47 %) | 3,35° |
| 0,5 A | 0,278 | 0,409 A (−18 %) | 0,393 A (−21 %) | 0,393 A (−21 %) | 3,38° |
| 1,0 A | 0,557 | 0,909 A (−9 %) | 0,874 A (−13 %) | 0,874 A (−13 %) | 3,39° |

Las dos columnas del medio salen de resolver `I = (Vdc·m − 0,92·e^(jφ_I)) / Z'` en 50 Hz, con `φ_I` el ángulo de la propia corriente y `Z'` la impedancia con o sin los 0,4 Ω. Las dos últimas salen del modelo conmutado del inversor en PLECS, con tiempo muerto y `RDS(on)`, y son la fundamental de la corriente sobre cuatro períodos de 50 Hz. El desfase se mide respecto de la fundamental de `d`. El modelo de onda cuadrada acierta la amplitud, con 2 % de diferencia en 0,2 A, pero no el desfase. Según la onda cuadrada el desfase bajaría a 1,9° con 0,2 A, y en el modelo conmutado queda cerca de 3,4° en los tres casos, el valor que da la carga con los 0,4 Ω de la `RDS(on)` (`atan(ωL/(R + 0,4))` = 3,46°). Esta tabla es la predicción del ensayo en lazo abierto con un `duty_ref` senoidal fijo.

En lazo cerrado el PR trata los dos efectos como una perturbación y corrige la fundamental. Las armónicas impares de la onda cuadrada (tercera, quinta) quedan sin corregir, porque el resonante solo actúa en 50 Hz, y se ven como una deformación de la corriente en los cruces por cero.

## Rizado de conmutación y frecuencia de conmutación

El rizado es la diferencia entre la corriente instantánea y su componente de baja frecuencia [2, Sec. 8-3-2-6]. Como la carga es lineal, toda la tensión de conmutación que no pertenece a la fundamental cae sobre la bobina, y el rizado de corriente sale de integrar esa tensión sobre `L` [2, ec. 8-41 y 8-42].

### Rizado en un pulso

En el semiciclo positivo la carga ve `+Vdc` durante dos pulsos por período de conmutación y 0 el resto del tiempo (sección de la tensión promedio). Un pulso dura mucho menos que τ, así que durante el pulso la corriente casi no se aparta de su promedio `i` y la resistencia toma `R·i`. En un período completo la corriente vuelve a casi el mismo valor, la tensión media sobre la bobina es casi nula y entonces `R·i` ≈ `Vdc·d`. A la bobina le queda

```
v_L = Vdc − R·i = Vdc·(1 − d)
```

El tiempo en `+Vdc` suma `d·Ts` por período y se reparte en dos pulsos, cada uno de `Δt = d/(2·f_sw)`. Con `v_L = L·Δi/Δt` el rizado pico a pico es

```
Δi = Vdc·d·(1 − d) / (2·L·f_sw)
```

El producto `d·(1 − d)` se anula en los dos extremos. Con `d` chico el pulso es corto, y con `d` cerca de 1 a la bobina le queda poca tensión. El máximo está en `d = 0,5` y vale

```
Δi_máx = Vdc / (8·L·f_sw)
```

En el semiciclo negativo la carga ve `−Vdc` y vale lo mismo con `|d|`.

### Rizado en los puntos de operación

A lo largo del ciclo de 50 Hz, `|d|` barre desde 0 hasta su valor en el pico de la senoidal. Si ese pico queda bajo 0,5 el rizado máximo del ciclo está en el pico, y si lo supera el máximo es `Δi_máx`. En lazo cerrado el PR lleva `d` hasta donde la corriente alcanza la referencia, compensando el tiempo muerto y la caída en la `RDS(on)`, así que a la carga le llega `|Z'|·I/Vdc`, con `Z'` la impedancia con los 0,4 Ω. Con 18 V el rizado máximo de cada punto queda así.

- 0,2 A, `d` de 0,116 en el pico, 0,023 A
- 0,5 A, `d` de 0,289 en el pico, 0,046 A
- 1,0 A, `d` pasa por 0,5, 0,056 A

Los tres quedan bajo el límite de 0,20 A pico a pico, el de 1,0 A con 3,6 veces de margen. En un transitorio el PR puede llevar `d` a 0,5 en cualquier punto, así que el peor caso es `Δi_máx`, 0,056 A con 18 V y 0,075 A con 24 V.

En lazo abierto el PR no compensa el tiempo muerto, el `d` que llega a la carga es `m − 0,04` y el rizado de 0,2 y 0,5 A es menor (validación en la sección del modelo de PLECS).

### Frecuencia de conmutación

Cada transistor conmuta a `f_sw` = 20 kHz, y la tensión diferencial sobre la carga lleva dos pulsos por período, así que su componente predominante está en `2·f_sw` = 40 kHz [2, Sec. 7-7-2]. Esa duplicación es la que entra en el `Δt` del rizado. La frecuencia queda entre un piso que pone el rizado y un techo que ponen el tiempo muerto y la recarga del bootstrap, y las pérdidas, la resolución del PWM y el lazo de control terminan de ubicarla.

El piso lo pone el rizado. De `Δi_máx` ≤ 0,20 A sale `f_sw ≥ Vdc/(8·L·0,20 A)`, 5,6 kHz con 18 V y 7,5 kHz con 24 V. A 20 kHz y con 24 V el rizado se mantiene bajo 0,20 A con una `L` de hasta 0,75 mH, casi tres veces menos que la nominal.

El techo sale de los drivers. El tiempo muerto de 1 µs, que cubre el retardo de la cadena de compuertas, y la conducción mínima de 100 ciclos de la baja para recargar el bootstrap son tiempos fijos (diseño del puente H). Su fracción del período crece con `f_sw`. La pérdida por tiempo muerto, `Δd = 2·TM·f_sw` [2, ec. 8-77], es 0,04 a 20 kHz y 0,08 a 40 kHz. El índice máximo del PR, `1 − (DEAD_TIME_CICLOS + 100)/MAX`, baja de 0,92 a 0,84. El escalón de 0,2 a 1,0 A le pide al PR un índice de 0,83 con 18 V y el cambio de `R` de +25 % uno de 0,85 (diseño del PR), sin contar el tiempo muerto. A 20 kHz, con los 0,04 del tiempo muerto, quedan en 0,87 y 0,89, bajo 0,92. A 40 kHz llegan a 0,91 y 0,93 contra un techo de 0,84, y el PR satura en los dos ensayos.

En las pérdidas, la conducción no depende de `f_sw`, mientras que la conmutación y la recuperación inversa crecen en proporción, y por eso subir la frecuencia para bajar el rizado tiene un costo en pérdidas [2, Sec. 8-3-2-6]. Por transistor, con 24 V y 1 A pico, suman unos 0,31 W a 20 kHz y 0,52 W a 40 kHz, con la recuperación como término mayor (diseño del puente H, sección "Pérdidas"). Ninguna de las dos limita la temperatura sin disipador, pero a 40 kHz la parte que depende de la frecuencia se duplica sin que el rizado lo pida.

En la resolución del PWM, cuando `ref_a` sube una cuenta, `ref_b` baja una, así que el paso mínimo es `Δd = 2/MAX`, 0,0008 con `MAX` = 2500. Con 18 V son 14,4 mV de tensión promedio y unos 1,4 mA de corriente en 50 Hz, el 0,7 % de la referencia más chica. El XADC convierte con 12 bits [3, Tabla 65, p. 57] sobre 1 V, unos 0,24 mV por código, que con los 0,24 V/A del acondicionamiento del sensor son unos 1 mA. El paso del actuador queda del mismo orden que el de la medición. Al duplicar `f_sw`, `MAX` baja a la mitad y el paso se duplica.

En el lazo de control, el PR muestrea una vez por período de conmutación, con un retardo de `1,5·Ts` (diseño del PR). En el cruce de 1 kHz el retardo resta 27° de fase a 20 kHz y 54° a 10 kHz. El margen de fase de 99,8° lo absorbe, y el que se cae es el margen de ganancia. Sumando al lazo de 20 kHz los 75 µs de retardo que lo separan del de 10 kHz, baja de 9,6 dB a 4,7 dB, por debajo del mínimo de 6 dB del diseño del PR, así que a 10 kHz habría que resintonizarlo con un cruce más bajo. El histórico de 2048 muestras cubre además 5,1 períodos de 50 Hz a 20 kHz, la ventana de cinco períodos en que se mide el error de amplitud, y a 40 kHz solo 2,6.

10 kHz tiene ventajas propias. El tiempo muerto pierde 0,02 en `d` (0,36 V), el índice máximo del PR sube a 0,96, la parte de las pérdidas que depende de la frecuencia baja a la mitad (unos 0,21 W por transistor) y el paso del PWM se reduce a 0,0004. En contra, el rizado con 24 V llega a 0,15 A, que solo cumple con una `L` de 1,5 mH o más, y el lazo pierde margen de ganancia. 20 kHz conserva margen de rizado con la `L` todavía sin medir y los márgenes del PR tal como están sintonizados, y queda por debajo del techo de 40 kHz.

## Modelo del inversor en PLECS

El modelo conmutado reproduce el puente, la modulación unipolar del núcleo del PWM, el tiempo muerto y la carga RL. Sirve para contrastar el análisis de este documento y como planta sobre la que se valida el PR.

### Parámetros

Todos los valores salen de un único archivo de parámetros en Octave, que los comandos de inicialización del modelo ejecutan al arrancar cada simulación. Los componentes llevan nombres de variables y ningún número propio. Del archivo salen `R`, `L`, `Vdc` y `RDSon`, y además el reloj de la FPGA (100 MHz), `MAX` y `DEAD_TIME_CICLOS`, de los que se calculan `f_sw = f_clk/(2·MAX)`, `Ts = 1/f_sw` y `TM = DEAD_TIME_CICLOS/f_clk`. Así la frecuencia y el tiempo muerto salen de los mismos números que fija el núcleo del PWM.

El ensayo se define con `fref` = 50 Hz y la corriente pico pedida `Iref`. La senoidal aplica el índice `m = |R + j·2π·fref·L|·Iref/Vdc` de la sección del régimen senoidal, sin contar el tiempo muerto ni la `RDS(on)`, que es lo que haría el ensayo en lazo abierto.

### Etapa de potencia

`Vdc` es una fuente de continua ideal. Cada transistor es un MOSFET con diodo en antiparalelo, porque durante el tiempo muerto la corriente de la bobina pasa por el diodo de cuerpo. El componente de PLECS es un interruptor ideal con resistencia de conducción `RDSon` en los dos sentidos y sin caída fija en el diodo, igual que el análisis, que tampoco cuenta la caída de los diodos. La carga va entre los puntos medios A y B, con un amperímetro, `L` y `R` en serie, y un voltímetro mide `v_o = v_A − v_B`.

### Modulador

La referencia es una senoidal de amplitud `m` y frecuencia `fref`, pasada por un retenedor de orden cero de período `Ts` que muestrea en los valles de la portadora. Es el mismo comportamiento del núcleo, que carga `duty_ref` en el valle y lo sostiene un período.

La portadora va de −1 a 1 en lugar de 0 a `MAX`. Con `c = 2·portadora/MAX − 1` la condición del núcleo, portadora por debajo de `ref_a = MAX·(1 + d)/2`, queda como `c < d`, así que la alta de A conduce con `c < d` y la de B con `c < −d`. Las bajas conducen con la condición opuesta.

El tiempo muerto se arma con dos portadoras iguales corridas en `±2·f_sw·TM` (±0,04). Las altas se comparan con la portadora corrida hacia arriba y las bajas con la corrida hacia abajo. La portadora recorre 2 unidades en medio período, así que su pendiente es `4·f_sw`, y un corrimiento de 0,04 de cada lado deja un hueco de `TM` entre el apagado de una compuerta y el encendido de la otra en cada flanco. El hueco queda centrado en el cruce ideal. El núcleo apaga en el cruce y enciende `TM` después, así que en el modelo cada flanco queda corrido `TM/2` (0,5 µs) respecto del hardware. La duración del hueco y la pérdida promedio por período son las mismas, y el corrimiento equivale a 0,009° en 50 Hz.

### Simulación y análisis

La simulación dura 0,1 s, cinco períodos de 50 Hz, con el resolvedor automático de PLECS y un paso máximo de 1 µs. Con `τ` = 0,2 ms el transitorio del arranque se extingue en el primer período.

La amplitud y la fase de la fundamental se calculan proyectando la señal sobre un seno y un coseno de 50 Hz, sobre cuatro períodos completos (de 0,02 a 0,1 s) muestreados cada 1 µs. Con un número entero de períodos la proyección no mezcla la fundamental con las armónicas. El desfase de la corriente se mide respecto de la fundamental de `d`, que es la tensión aplicada sobre `Vdc`.

El rizado se mide en un período de 50 Hz ya en régimen, de 0,04 a 0,06 s. A la corriente se le resta su componente lenta, el promedio de cada período de conmutación interpolado entre períodos, y en cada período se toma el máximo menos el mínimo. Para el rizado la simulación entrega los pasos del resolvedor y no una grilla fija. Entre conmutaciones la corriente es una exponencial sin extremos internos, y los pasos caen en las conmutaciones, así que los extremos salen exactos.

### Validación contra el análisis

Con `Iref` = 0,2 A se separan los dos efectos anulando `TM` y `RDSon`.

| Caso | Amplitud de `i` | Desfase | Análisis |
|---|---|---|---|
| Sin tiempo muerto ni `RDS(on)` | 0,2000 A | 3,60° | 0,2 A y 3,60° |
| Solo `RDS(on)` | 0,1923 A | 3,46° | 0,1923 A y 3,46° |
| Solo tiempo muerto | 0,1104 A | 3,48° | 0,1086 A y 1,95° |
| Los dos | 0,1062 A | 3,35° | 0,1044 A y 1,88° |

Sin tiempo muerto el modelo da exactamente la corriente de la impedancia de la carga, así que el puente y el modulador no agregan error y el promedio `v̄_o = Vdc·d` vale. La `RDS(on)` también coincide. Con tiempo muerto la amplitud queda a 2 % del análisis y el desfase no, por el tramo de corriente nula alrededor de los cruces que se describe en la sección anterior. La fundamental de `d` da 0,1113, el `m` aplicado. La comparación con 0,5 y 1,0 A está en la tabla de la sección del tiempo muerto.

El rizado en lazo abierto, con tiempo muerto y `RDS(on)`, se compara con `Δi` evaluado en el `d` que llega a la carga, `m − 0,04`.

- 0,2 A, 0,0149 A en el modelo y 0,0149 A en el análisis (0,0223 A con `m`)
- 0,5 A, 0,0408 A en el modelo y 0,0408 A en el análisis (0,0452 A con `m`)
- 1,0 A, 0,0563 A en el modelo y 0,0563 A en el análisis, igual que con `m`

En 0,2 y 0,5 A el máximo cae en el pico de la senoidal. En 1,0 A el `d` efectivo llega a 0,517, pasa por 0,5 y el máximo cae a unos 15° del pico, donde `d` vale 0,5. El tiempo muerto no cambia la forma del rizado, solo el `d` en que se evalúa.

## Referencias

[1] International Rectifier, "IRF520N HEXFET Power MOSFET", hoja de datos PD-91339A, 13 may. 1998.

[2] N. Mohan, T. M. Undeland y W. P. Robbins, *Power Electronics: Converters, Applications, and Design*, 3.ª ed. Hoboken, NJ, EE. UU.: Wiley, 2003.

[3] AMD, "Artix 7 FPGAs Data Sheet: DC and AC Switching Characteristics", DS181, v1.27.1, 3 jul. 2024.
