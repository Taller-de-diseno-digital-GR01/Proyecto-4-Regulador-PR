# Modelo de la planta, decisiones y justificación

Este documento reúne el modelo de la planta del lado de potencia. Cubre el modelo dinámico de la carga RL, la función de transferencia desde `duty_ref` hasta la corriente y la relación entre `duty_ref` y la tensión promedio sobre la carga con modulación unipolar.

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

que equivale a `Δd = 2·TM·f_sw` = 0,04. Con la corriente negativa conducen los otros dos diodos y el efecto se invierte. A lo largo de un ciclo de 50 Hz el error es una onda cuadrada de ±0,72 V en fase con la corriente, con fundamental `(4/π)·0,72` = 0,92 V. La caída de los diodos durante el hueco suma una pérdida más, la caída por 0,04, que queda por debajo de una décima de los 0,72 V y no se cuenta.

En cualquier estado del puente conducen dos MOSFET en serie con la carga, uno por pierna, así que la `RDS(on)` suma hasta 0,4 Ω a `R`. Es una cota, porque con 15 V de compuerta la resistencia es menor que la de la hoja a 10 V.

El tiempo muerto que se cuenta es el programado. El hueco real en las patas de los MOSFET cambia con la asimetría de la cadena de compuertas, y la pérdida escala en proporción. El modelo de onda cuadrada también supone que el error cambia de signo justo cuando la corriente cruza por cero. Cerca del cruce eso no pasa. Mientras `|Vdc·d|` es menor que 0,72 V, el tiempo muerto se lleva toda la tensión aplicada y la corriente queda en cero hasta que la referencia supera ese valor. En ese tramo el error copia a la tensión de referencia en lugar de valer ±0,72 V, así que la pérdida es algo menor que la de la onda cuadrada y su fundamental queda casi en fase con la tensión. Con 0,2 A el tramo cubre unos ±21° alrededor de cada cruce.

| Referencia | `m` aplicado | Con tiempo muerto | Con tiempo muerto y `RDS(on)` | Modelo conmutado | Desfase en el modelo conmutado |
|---|---|---|---|---|---|
| 0,2 A | 0,111 | 0,109 A (−46 %) | 0,104 A (−48 %) | 0,106 A (−47 %) | 3,35° |
| 0,5 A | 0,278 | 0,409 A (−18 %) | 0,393 A (−21 %) | 0,393 A (−21 %) | 3,38° |
| 1,0 A | 0,557 | 0,909 A (−9 %) | 0,874 A (−13 %) | 0,874 A (−13 %) | 3,39° |

Las dos columnas del medio salen de resolver `I = (Vdc·m − 0,92·e^(jφ_I)) / Z'` en 50 Hz, con `φ_I` el ángulo de la propia corriente y `Z'` la impedancia con o sin los 0,4 Ω. Las dos últimas salen del modelo conmutado del inversor en PLECS, con tiempo muerto y `RDS(on)`, y son la fundamental de la corriente sobre cuatro períodos de 50 Hz. El desfase se mide respecto de la fundamental de `d`. El modelo de onda cuadrada acierta la amplitud, con 2 % de diferencia en 0,2 A, pero no el desfase. Según la onda cuadrada el desfase bajaría a 1,9° con 0,2 A, y en el modelo conmutado queda cerca de 3,4° en los tres casos, el valor que da la carga con los 0,4 Ω de la `RDS(on)` (`atan(ωL/(R + 0,4))` = 3,46°). Esta tabla es la predicción del ensayo en lazo abierto con un `duty_ref` senoidal fijo.

En lazo cerrado el PR trata los dos efectos como una perturbación y corrige la fundamental. Las armónicas impares de la onda cuadrada (tercera, quinta) quedan sin corregir, porque el resonante solo actúa en 50 Hz, y se ven como una deformación de la corriente en los cruces por cero.

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

### Validación contra el análisis

Con `Iref` = 0,2 A se separan los dos efectos anulando `TM` y `RDSon`.

| Caso | Amplitud de `i` | Desfase | Análisis |
|---|---|---|---|
| Sin tiempo muerto ni `RDS(on)` | 0,2000 A | 3,60° | 0,2 A y 3,60° |
| Solo `RDS(on)` | 0,1923 A | 3,46° | 0,1923 A y 3,46° |
| Solo tiempo muerto | 0,1104 A | 3,48° | 0,1086 A y 1,95° |
| Los dos | 0,1062 A | 3,35° | 0,1044 A y 1,88° |

Sin tiempo muerto el modelo da exactamente la corriente de la impedancia de la carga, así que el puente y el modulador no agregan error y el promedio `v̄_o = Vdc·d` vale. La `RDS(on)` también coincide. Con tiempo muerto la amplitud queda a 2 % del análisis y el desfase no, por el tramo de corriente nula alrededor de los cruces que se describe en la sección anterior. La fundamental de `d` da 0,1113, el `m` aplicado. La comparación con 0,5 y 1,0 A está en la tabla de la sección del tiempo muerto.

## Referencias

[1] International Rectifier, "IRF520N HEXFET Power MOSFET", hoja de datos PD-91339A, 13 may. 1998.
