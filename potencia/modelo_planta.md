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

El tiempo muerto que se cuenta es el programado. El hueco real en las patas de los MOSFET cambia con la asimetría de la cadena de compuertas, y la pérdida escala en proporción. El modelo de onda cuadrada también supone que la corriente no cambia de signo dentro de un período de conmutación, lo que deja de valer cerca de los cruces por cero, donde la corriente es menor que medio rizado. Por eso con 0,2 A la pérdida real es algo menor que la calculada.

| Referencia | `m` aplicado | Con tiempo muerto | Con tiempo muerto y `RDS(on)` |
|---|---|---|---|
| 0,2 A | 0,111 | 0,109 A (−46 %) | 0,104 A (−48 %) |
| 0,5 A | 0,278 | 0,409 A (−18 %) | 0,393 A (−21 %) |
| 1,0 A | 0,557 | 0,909 A (−9 %) | 0,874 A (−13 %) |

Los valores salen de resolver `I = (Vdc·m − 0,92·e^(jφ_I)) / Z'` en 50 Hz, con `φ_I` el ángulo de la propia corriente y `Z'` la impedancia con o sin los 0,4 Ω. El desfase baja de 3,6° a unos 2° a 3,3°, porque la pérdida está en fase con la corriente. Esta tabla es la predicción del ensayo en lazo abierto con un `duty_ref` senoidal fijo.

En lazo cerrado el PR trata los dos efectos como una perturbación y corrige la fundamental. Las armónicas impares de la onda cuadrada (tercera, quinta) quedan sin corregir, porque el resonante solo actúa en 50 Hz, y se ven como una deformación de la corriente en los cruces por cero.

## Referencias

[1] International Rectifier, "IRF520N HEXFET Power MOSFET", hoja de datos PD-91339A, 13 may. 1998.
