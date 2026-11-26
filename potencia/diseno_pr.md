# Diseño del regulador PR, decisiones y justificación

Este documento junta las decisiones de diseño del regulador proporcional-resonante (PR) del lazo de corriente, con la razón de cada una. La carga quedó en dos inductores de 100 µH en serie, con unos 0,5 Ω de devanado cada uno, más la resistencia de 8 Ω, o sea `L = 200 µH` y `R = 9 Ω`. Antes fue un transformador de 30 mH con 12 Ω, y antes de eso una bobina de 2 mH con 10 Ω. `Vdc` y `fsw` siguen provisionales y están marcados como tales. Con 200 µH la carga es casi resistiva en toda la banda del lazo, y eso cambió el criterio con el que se fija `Kp` además de los números (sección de ganancia proporcional).

Los márgenes y las curvas de error de este documento se calcularon en Octave con el lazo discreto descrito en las secciones de sintonización, y cada cifra lleva sus condiciones. `potencia/verificar_pr.m` calcula los márgenes del lazo abierto y simula el lazo promedio, con los escalones, las esquinas de `L` y `R`, el cambio de `R` y la saturación. `potencia/aliasing_pr.m` simula el puente conmutado de la sección de aliasing. Los dos imprimen las cifras en el orden en que aparecen acá. Los coeficientes finales los escribe `sw/generar_pr_params.m` en `pr_params.h`, y los tres corren igual en Octave y en MATLAB.

## Objetivo del lazo

Que la corriente en la carga RL siga una referencia senoidal de 50 Hz con 0,2, 0,5 y 1,0 A pico, con error de la fundamental menor a 10 % en una ventana de al menos cinco períodos y rizado de conmutación menor a 0,20 A pico a pico. También tiene que sobrevivir a un cambio de amplitud y a un cambio de `R` de al menos 25 %. Los criterios salen de la sección 4.3 del enunciado.

## Por qué un PR

Un PI tiene ganancia infinita en continua, y por eso sigue referencias constantes sin error. Con una senoidal deja error de amplitud y de fase. El término resonante pone la ganancia infinita en `ω0 = 2π·50` y deja error nulo en esa frecuencia, sin transformar a ejes sincrónicos y sin PLL, lo que lo hace barato de ejecutar en un MicroBlaze. Teodorescu et al. (2006) lo presentan justo así, como alternativa en marco estacionario que también permite compensar armónicos selectivos con poco cómputo.

La estructura elegida es la ideal.

$$G_c(s) = K_p + K_r \frac{s}{s^2 + \omega_0^2}$$

La versión amortiguada cambia exactitud en 50 Hz por tolerancia a que la frecuencia se corra. Acá la referencia la genera el propio MicroBlaze a 50 Hz exactos, así que no hay frecuencia que se corra y el término ideal no pierde nada.

## Planta y retardo

El puente H con modulación unipolar entrega `v = Vdc·u`, con `u` el índice de modulación entre -1 y 1. La carga cumple `I(s)/V(s) = 1/(Ls + R)`. La modulación unipolar sale del enunciado y de ella se toma que la frecuencia efectiva del rizado es el doble de la de conmutación (Mohan, sección 8-3-2-2, y Hart, capítulo 8).

Además hay un retardo. La muestra se toma en el centro del pulso con `pwm_trigger_o`, la interrupción calcula con ella y escribe `duty_ref`, y el periférico lo aplica en el siguiente pico o valle de la portadora. Eso es un período de muestreo de cómputo más medio de actualización, y se modela como `Td = 1,5·Ts`, con `Ts = 1/fs`. Es el modelo habitual de los lazos digitales de corriente y queda como suposición hasta medir el lazo real con el GPIO de la ISR. `nucleo_pwm.md` lo respalda en lo que toca al periférico, porque `pwm_trigger_o` sale en el valle y lo que el software escribe a mitad de período rige desde el valle siguiente.

El lazo abierto que se analiza es entonces

$$L(s) = G_c(s)\, e^{-sT_d}\, \frac{1}{Ls + R}$$

A ese `Td` todavía hay que sumarle el retardo del filtro analógico del sensor y el del aislamiento de las compuertas (#21), que separa la tierra de la Basys 3 de la del puente y queda en la ruta de las cuatro compuertas sin componente elegido. El del filtro se calcula en la sección de aliasing. El del aislamiento se espera del orden de cientos de nanosegundos a pocos microsegundos contra `Ts = 50 µs`, así que mueve poco el `Td`, y pesa más en el tiempo muerto, porque el retardo no es igual al subir que al bajar.

## Valores provisionales de partida

- `Vdc = 18 V`, punto medio del rango de 12 a 24 V del enunciado. A 1,0 A pico el control pide unos 9 V, un índice de 0,50 con 18 V y de 0,75 con 12 V, los dos debajo de `PR_U_MAX = 0,92`. El escalón de 0,2 a 1,0 A sin rampa pide como máximo 0,52 con 18 V y 0,77 con 12 V, así que con esta carga los ensayos de 1,0 A también se pueden correr a 12 V. El que empuja a bajar `Vdc` ahora es el rizado (sección de rizado).
- `fsw = fs = 20 kHz`, muestreando una vez por período. A 100 MHz son 5000 ciclos de reloj por iteración, de sobra para las seis multiplicaciones del PR incluso en flotante por software. Es una frecuencia habitual para MOSFET de baja tensión, pero Nicolás tiene que confirmar que su puente y su tiempo muerto la aguantan. La tabla de `nucleo_pwm.md` trae 10 y 40 kHz en las otras dos frecuencias y el código `11` satura a 20 kHz. Cada frecuencia pide regenerar los coeficientes.
- `L = 200 µH` y `R = 9 Ω`. Son dos inductores de 100 µH en serie con unos 0,5 Ω cada uno, más la resistencia de 8 Ω que ya estaba. Con 1,0 A pico la carga disipa 4,5 W en promedio, 4 W de ellos en la resistencia de 8 Ω. Son los valores nominales, falta medirlos (#31).

A 50 Hz la impedancia es `|Z| = 9,00 Ω` con 0,4° de desfase, prácticamente resistiva. El índice que pide cada amplitud con 18 V es 0,100 para 0,2 A, 0,250 para 0,5 A y 0,500 para 1,0 A. La constante de tiempo `τ = L/R` es de 22 µs, menos que los 50 µs del período de muestreo, así que la carga llega a su valor final dentro de una sola muestra.

## Rizado y la `L` mínima

Con modulación unipolar, el voltaje de salida salta entre 0 y `±Vdc` a `2·fsw` con ciclo de trabajo `D = |m|`. El rizado pico a pico queda en

$$\Delta I_{pp} \approx \frac{V_{dc}\,D(1-D)}{2\,L\,f_{sw}}$$

cuyo máximo está en `D = 0,5` y vale `Vdc/(8·L·fsw)`. Esta fórmula es derivación propia, los libros solo dan la duplicación efectiva de la frecuencia. Exigir que ese máximo quede bajo 0,20 A da `L ≥ Vdc/(1,6·fsw)`.

- Con 12 V y 20 kHz, `L ≥ 0,38 mH`.
- Con 18 V y 20 kHz, `L ≥ 0,56 mH`.
- Con 24 V y 20 kHz, `L ≥ 0,75 mH`.

Con `L = 200 µH` no se cumple con ninguna `Vdc` del rango a 20 kHz. Como `τ = 22 µs` es del orden de los 25 µs entre pulsos, la fórmula lineal sobrestima un poco. Con la solución exponencial exacta de la RL, el rizado en el pico de la senoidal (donde `D = m`, o `D = 0,5` si `m` pasa de 0,5) queda así para 0,2, 0,5 y 1,0 A.

- 12 V y 20 kHz, 0,19, 0,34 y 0,37 A pp.
- 18 V y 20 kHz, 0,20, 0,41 y 0,55 A pp.
- 24 V y 20 kHz, 0,21, 0,45 y 0,69 A pp.
- 12 V y 40 kHz, 0,10, 0,18 y 0,19 A pp.

El límite de 0,20 A pp de la sección 4.3.5 solo se cumple en las tres amplitudes con 12 V y 40 kHz, y a 1,0 A queda en 0,19 A, sin margen para el tiempo muerto y las caídas de los transistores, que no están incluidos. Con 18 V y 20 kHz falla en 0,5 y 1,0 A por un factor de dos a casi tres.

El PR no puede hacer nada con esto, el rizado depende solo de `L`, `Vdc` y `fsw`. Hay dos salidas. Una es subir `L` a por lo menos 0,56 mH, que con inductores de 100 µH son seis en serie con 18 V o cuatro con 12 V, y cada uno suma su 0,5 Ω. La otra es correr el puente a 40 kHz, que no sale gratis, porque el lazo cerrado hoy corre solo a 20 kHz con el Timer fijo en 5000 ciclos y `control_principal` solo habilita con `freq_sel = 01`. A 40 kHz, con `MAX = 1250`, el tope de índice baja a `PR_U_MAX = 0,84`, que es justo lo que pide 1,0 A con 12 V sumando el tiempo muerto. Queda abierto en `docs/diseño/inconsistencias.md`.

## Ganancia proporcional

Con las cargas anteriores `Kp` se fijaba imponiendo ganancia unitaria de lazo en `fc = fs/20 = 1 kHz`, sin contar el resonante.

$$K_p = \sqrt{R^2 + (\omega_c L)^2}$$

Con 200 µH eso da `Kp = 9,09 V/A`, y ahí el criterio deja de servir. La carga es resistiva hasta su polo en `R/(2πL) = 7,2 kHz`, así que la ganancia del lazo queda casi plana en `Kp/R` desde 50 Hz hasta cerca de Nyquist, mientras el retardo de 1,5 `Ts` sigue restando fase. La fase llega a -180° con la ganancia todavía cerca de 1 y el margen de ganancia queda en 1,8 dB. En la esquina de `L = 140 µH` y `R = 6,75 Ω` el lazo es inestable.

Lo que manda ahora es el margen de ganancia, que sale casi directo de `Kp/R`. Con `Kr = 10000` y la carga nominal.

- `Kp = 3`, 11,3 dB.
- `Kp = 4,5`, 7,8 dB.
- `Kp = 6`, 5,4 dB.
- `Kp = 9,09`, el del cruce en 1 kHz, 1,8 dB.

Se elige `Kp = R/2 = 4,5 V/A`, que deja 7,8 dB en el nominal y 5,2 dB en la peor esquina, sobre los 6 dB y 3 dB pedidos. Con 6 V/A la esquina ya baja a 2,7 dB. El cruce de ganancia ya no lo pone `Kp` sino el resonante, y queda en 216 Hz con 112,4° de margen de fase.

Con `Kp` debajo de `R` la parte proporcional sola deja 66,7 % de error de amplitud, y el seguimiento lo hace casi todo el resonante. Con el transformador pasaba lo contrario, `Kp = 188,88` cerraba el lazo casi solo y era el que saturaba el puente en los escalones.

## Ganancia resonante

`Kr` fija qué tan rápido converge el error en 50 Hz. Con `Kp = 4,5` se probó en un lazo discreto completo (planta por ZOH exacto, un muestreo de retardo, regulador con Tustin precorregido) y un escalón de 0,2 a 1,0 A pico aplicado en un cruce por cero de la referencia, midiendo el error de la fundamental en ventanas de un período. El error es el de amplitud de la fundamental, `(|I1| - |R1|)/|R1|` con `I1` y `R1` los fasores de 50 Hz de la corriente y de la referencia, que es el criterio de 4.3.5 y el que calcula `receptor_pc.md` en su sección h.2, y se informa en valor absoluto. Los fasores se extraen proyectando sobre seno y coseno en el período completo.

- `Kr = 3000`, error de 22,4 %, 1,9 % y 0,1 % en los tres primeros períodos.
- `Kr = 5000`, 14,5 %, 0,1 % y 0 %.
- `Kr = 10000`, 7,0 %, 0,3 % y 0 %.

Se elige `Kr = 10000`, el único de los tres que cumple los 10 % ya en el primer período, con un desfase que no pasa de 0,1°. Subirlo casi no toca los márgenes (7,9 dB con 3000 y 7,8 dB con 10000), porque solo mueve el cruce de 89 a 216 Hz, lejos de donde la fase llega a -180°. El polo más lento del lazo cerrado queda en `|z| = 0,9915`, una constante de tiempo de 5,9 ms.

Con el transformador alcanzaba `Kr = 3000` porque `Kp` hacía casi todo el trabajo. Con `Kp` chico el resonante tiene que converger solo, y por eso subió.

## Discretización

El resonante discretizado queda como filtro de segundo orden, `r[k] = b0·e[k] + b1·e[k-1] + b2·e[k-2] - a1·r[k-1] - a2·r[k-2]`. Con Tustin simple, `s = (2/T)(z-1)/(z+1)`, el polo se corre por debajo de 50 Hz hasta `(2/T)·arctan(ω0T/2)`. A 20 kHz, con 400 muestras por período, ese corrimiento es de apenas 1 mHz, y a 10 kHz son 4 mHz, así que en este lazo la diferencia práctica es muy chica. Yepes et al. (2010) estudian el efecto y concluyen que el método de discretización pesa mucho en el desempeño de los controladores resonantes, y el peso crece cuando la frecuencia de muestreo baja respecto a la resonante.

Se usa Tustin con precorrección en 50 Hz, `s = (ω0/tan(ω0T/2))(z-1)/(z+1)`. Cuesta lo mismo que el simple, deja el polo exactamente en `ω0` a cualquier `fs`, y los coeficientes quedan en forma cerrada, con `θ = ω0·Ts`.

- `b0 = Kr·sin(θ)/(2ω0)`
- `b1 = 0`
- `b2 = -b0`
- `a1 = -2·cos(θ)`
- `a2 = 1`

La estructura de cinco coeficientes de `pr_discreto` y de `generar_pr_params.m` ya soporta esto sin cambios, y `coeficientes_resonante` implementa estas fórmulas para `tustin_prewarp`. `sw/pruebas/prueba_generar_pr_params.m` revisa que salgan los coeficientes de abajo y que el polo quede en 50 Hz después de redondear `A1`.

### Deducción paso a paso

Se parte de la parte resonante sola, `Gr(s) = Kr·s/(s²+ω0²)`, y se sustituye `s` por la forma con precorrección, con `K = ω0/tan(θ/2)` y `θ = ω0·Ts`.

`Gr(z) = Kr·K·(z-1)/(z+1) / [K²·(z-1)²/(z+1)² + ω0²]`

Multiplicando arriba y abajo por `(z+1)²` para sacar la fracción de adentro del denominador,

`Gr(z) = Kr·K·(z-1)(z+1) / [K²(z-1)² + ω0²(z+1)²] = Kr·K·(z²-1) / [(K²+ω0²)·z² + 2(ω0²-K²)·z + (K²+ω0²)]`

Dividiendo arriba y abajo entre `z²` para pasar a potencias de `z⁻¹`, y después entre `(K²+ω0²)` para dejar el término sin retardo del denominador en 1, que es la forma `a2 = 1` de `pr_discreto`,

`Gr(z) = [Kr·K/(K²+ω0²)]·(1 - z⁻²) / [1 + (2·(ω0²-K²)/(K²+ω0²))·z⁻¹ + z⁻²]`

Comparando término a término con `(b0 + b1·z⁻¹ + b2·z⁻²) / (1 + a1·z⁻¹ + a2·z⁻²)` ya quedan `b1 = 0`, `b2 = -b0` y `a2 = 1` sin hacer más cuentas, y faltan

- `b0 = Kr·K/(K²+ω0²)`
- `a1 = 2·(ω0²-K²)/(K²+ω0²)`

Para llegar a la forma de arriba hace falta reemplazar `K` por su definición y simplificar con identidades trigonométricas. De `1/tan²(θ/2) + 1 = 1/sin²(θ/2)` sale `K² + ω0² = ω0²/sin²(θ/2)`, y con eso

`b0 = Kr·[ω0·cos(θ/2)/sin(θ/2)]·[sin²(θ/2)/ω0²] = Kr·sin(θ/2)·cos(θ/2)/ω0 = Kr·sin(θ)/(2ω0)`

usando `sin(θ) = 2·sin(θ/2)·cos(θ/2)`. Para `a1`, de `sin²(θ/2) - cos²(θ/2) = -cos(θ)` sale `ω0² - K² = -ω0²·cos(θ)/sin²(θ/2)`, y entonces

`a1 = 2·[-ω0²·cos(θ)/sin²(θ/2)] / [ω0²/sin²(θ/2)] = -2·cos(θ)`

Las dos coinciden con los coeficientes de arriba.

## Coeficientes resultantes

Con los valores provisionales y dividiendo entre `Vdc` para que la salida sea índice de modulación, como ya prevé el script.

- `KP = 0,25`
- `B0 = 1,3888e-2`
- `B1 = 0`
- `B2 = -1,3888e-2`
- `A1 = -1,99975`
- `A2 = 1`

`A1` y `A2` dependen solo de `fs` y no cambiaron. `B0` y `B2` subieron con `Kr` de 3000 a 10000, y `KP` bajó de 10,4932 a 0,25.

`A1` queda muy cerca de -2, y lo que importa es que la diferencia con -2 se represente bien porque ella fija la frecuencia del polo. Un paso de 1e-6 en `A1` corre el polo unos 0,1 Hz. En flotante de 32 bits el paso en ese valor es de 1,2e-7, o sea 0,012 Hz, y con ese corrimiento la ganancia del resonante en 50 Hz sigue siendo de miles, con un error de seguimiento menor a 0,03 %. En punto fijo hace falta un formato con al menos dos bits enteros y unos 20 fraccionarios para `A1`, y esto es un argumento a favor de habilitar la FPU.

## Saturación y anti-windup

El PR calcula un índice de modulación `u[k]` que se recorta a `±PR_U_MAX` antes de convertirlo a `duty_ref` en Q2.14. El tope absoluto es 1,0, el rango del periférico, y lo que lo baja son el tiempo muerto y el bootstrap. A 20 kHz, con `MAX = 2500`, hace falta `PR_U_MAX < 1 - (DEAD_TIME_CICLOS + 100)/MAX`, que con 100 ciclos de tiempo muerto da 0,92. Si hubo recorte, el estado que se guarda del resonante es el que habría hecho caer la suma justo en el límite, y así no acumula energía mientras el puente está saturado. La fórmula y las razones están en `pr_discreto.md`, sección h.5, que es la fuente de verdad de esa parte.

Con esta carga no hay saturación ni en régimen ni en el escalón. En régimen el índice a 1,0 A es 0,50 con 18 V y 0,75 con 12 V. El escalón de 0,2 a 1,0 A sin rampa, barriendo 20 fases del período, pide como máximo 0,52 con 18 V, 0,64 con la `R` subida a 11,25 Ω y 0,77 con 12 V.

### Rampa de amplitud

La rampa de `amplitud_ref` de [`lazo_control`](../docs/diseño/modulos/lazo_control.md#h6-rampa-de-amplitud) (`AMPLITUD_PASO_MAX`, 400 muestras de 0 a 1,0 A) nació con el transformador, donde `Kp = 188,88` hacía que el escalón de un switch pidiera un índice de 8,5 y dejara el puente pegado al tope varios períodos. Con `Kp = 4,5` ese problema desaparece, y la rampa se deja porque no estorba.

Compilando `lazo_control.c` con `PLANTA_SIMULADA` junto con `pr_discreto.c` y `ref_senoidal.c`, con la carga nueva y barriendo 20 fases del escalón contra la amplitud verdadera del switch (no la rampeada), el peor caso queda así, sin ninguna muestra saturada.

- 0,2 a 1,0 A, 0,5 % en el segundo período y 0 % desde el tercero, con pico de 1,010 A.
- 0,2 a 0,5 A, 0,3 % y 0 %.
- 0,5 a 1,0 A, 0,5 % y 0 %, con pico de 1,012 A.
- 1,0 a 0,2 A, 2,7 % y 0,1 %.

El primer período no se compara porque ahí la amplitud todavía está subiendo. `control_principal` también reinicia la rampa en 0 al habilitar, así que arrancar con el switch ya puesto en una amplitud alta tampoco pega un escalón completo.

## Aliasing y filtro del sensor

El criterio `fs > 2·BW` se cumple de sobra para la señal. La referencia es de 50 Hz y el lazo cruza en 216 Hz, contra una `fs` de 20 kHz. Lo que el criterio no mira es todo lo demás que entra al ADC, porque al muestrear cualquier contenido por encima de `fs/2` se pliega hacia la banda del lazo y se confunde con corriente.

- El rizado de conmutación se sincroniza solo. Si la captura cae en el valle o en el pico de la portadora, el rizado es un múltiplo exacto de `fs` y se pliega a continua. Esto se simuló con `potencia/aliasing_pr.m`, con la portadora de 2500 cuentas a 100 MHz, la carga RL resuelta de forma exacta entre flancos y el PR de las secciones anteriores, sin tiempo muerto, sin cuantización del ADC y sin el filtro del sensor. Con 200 µH lo que se pliega ya no es el promedio. En el valle la tensión sobre la carga es cero y la corriente decae con `τ = 22 µs`, del orden del propio tramo, así que la muestra del medio del tramo queda por debajo del promedio del período. El PR lleva la muestra a la referencia y la corriente verdadera queda por encima. Con las cargas anteriores `τ` era de milisegundos, el tramo era casi recto y el error daba 0,05 %. El error de amplitud de la fundamental de la corriente verdadera, no la muestreada, queda así.
  - Captura en el valle, 4,2 % con 1,0 A y 5,3 % con 0,2 A. Con ±200 ns de error en el instante va de 3,3 % a 5,2 % con 1,0 A, y con ±400 ns de 2,4 % a 6,1 %. En el pico de la portadora es igual (4,2 % y 5,2 % con +200 ns).
  - Captura adelantada respecto al valle, por el retardo de la cadena de compuertas (#18, de 0,1 a 0,91 µs). Con 0,91 µs antes da 0,13 % con 1,0 A y 1,1 % con 0,2 A, y con 0,1 µs da 3,8 %. Adelantar la captura compensa en parte la caída del tramo, así que acá el retardo de la cadena juega a favor.
  - Captura en el centro del pulso, con ±200 ns, entre -6,0 % y -3,3 % con 1,0 A y entre -18,1 % y 1,3 % con 0,2 A. Con esta carga deja de ser una alternativa.
  - Captura en el flanco del pulso, donde se lee el extremo del rizado, 27,4 % con 1,0 A.
  - Con una fase cualquiera, a 5, 7,8 y 20 µs del valle, el error va de -16,5 % a +28,4 %.

  `pwm_trigger_o` tiene que seguir cayendo en el valle o el pico. Ahí todo queda bajo el 10 %, pero el aliasing ya se come hasta 6 % del presupuesto según dónde caiga la captura. El filtro del sensor promedia parte del rizado antes del ADC y no está en la simulación, así que la cifra real puede ser otra, y se confirma en el banco con el ensayo 3.
- El ruido de banda ancha del sensor y de la conmutación no se sincroniza con nada, y lo único que lo frena es un filtro analógico antes del ADC. Ese filtro todavía no existe. Su corte sale de medir el ruido real del sensor, y lo mide Jefferson, que también diseña el filtro (#29).

El filtro cuesta fase. Para un RC de primer orden con corte `fF`, el retardo de grupo a baja frecuencia es `τF = 1/(2π·fF)`, que vale 33 µs con 4,8 kHz, 53 µs con 3 kHz y 80 µs con 2 kHz, o sea 0,66, 1,06 y 1,59 `Ts`. Con el cruce en 216 Hz eso casi no pesa, y los márgenes que quedan con cada uno están en la sección siguiente. El retardo total del lazo es `Td = 1,5·Ts + τF`, con `τF` el del filtro que fije Jefferson.
Con `freq_sel` la tabla de `nucleo_pwm.md` quedó en `00` a 10 kHz, `01` a 20 kHz y `10` a 40 kHz, y `11` satura a 20 kHz. El lazo cerrado corre solo a 20 kHz, con el Timer fijo en 5000 ciclos, así que el argumento del aliasing a 10 kHz ya no aplica. Las otras frecuencias son para mostrar el PWM y para el testbench, con el control deshabilitado, y `control_principal` solo deja habilitar el control con `freq_sel = 01`.

## Análisis de estabilidad

Se analiza `L(s) = Gc(s)·e^(-s·Td)/(Ls + R)` con `Td = 1,5·Ts = 75 µs`. Todos los márgenes de esta sección salen de ese lazo abierto, con `Kp = 4,5` y `Kr = 10000` salvo que se diga otra cosa, y se miden en el cruce de ganancia más alto.

El diseño nominal, con `L = 200 µH` y `R = 9 Ω`, cruza en 216 Hz con 112,4° de margen de fase y 7,8 dB de margen de ganancia. El criterio que se pide es margen de fase de al menos 45° y de ganancia de al menos 6 dB con la `L` medida y el filtro del sensor puestos, y de al menos 30° y 3 dB en las esquinas de `L` y `R` de abajo con `Kp` sin retocar. Si la `R` medida difiere de 9 Ω se recalcula `Kp = R/2`.

Si `L` y `R` varían después de sintonizar, por ejemplo por saturación del inductor o por calentamiento de la resistencia, `Kp` queda fijo y los márgenes se mueven. Las esquinas son ±30 % en `L` y ±25 % en `R`. El mínimo está en la `R` más chica, porque sube `Kp/R`, y la `L` casi no importa.

- `L = 140 µH`, `R = 6,75 Ω`, cruce en 324 Hz, 120,6° y 5,2 dB.
- `L = 140 µH`, `R = 11,25 Ω`, cruce en 169 Hz, 108,3° y 8,7 dB.
- `L = 260 µH`, `R = 6,75 Ω`, cruce en 322 Hz, 118,5° y 7,1 dB.
- `L = 260 µH`, `R = 11,25 Ω`, cruce en 169 Hz, 107,6° y 9,9 dB.

Las cuatro cumplen el mínimo de esquina (30°/3 dB).

El retardo que se le agrega al `Td` ahora mueve poco.

- 2 µs extra, 112,3° y 7,8 dB.
- 25 µs extra, 110,5° y 7,2 dB.
- 50 µs extra, 108,6° y 6,8 dB.
- 75 µs extra, 106,6° y 6,6 dB.
- El margen de ganancia baja a 6 dB con 203 µs extra, y el de fase no llega a 45° ni con 400 µs.

Con el transformador el límite estaba en unos 53 µs. Con esta carga sobra presupuesto para el aislamiento de las compuertas (#21) y el filtro del sensor juntos.

Con `Kp` y `Kr` fijos, el filtro del sensor hasta sube el margen de ganancia, porque atenúa justo donde la fase llega a -180°. La esquina de abajo es la de `L = 140 µH` y `R = 6,75 Ω`.

- RC de 4,8 kHz, 109,8° y 9,4 dB en el nominal, 116,7° y 6,8 dB en la esquina.
- RC de 3 kHz, 108,3° y 10,8 dB, y 114,3° y 8,3 dB.
- RC de 2 kHz, 106,2° y 12,6 dB, y 111,2° y 10,1 dB.
- Butterworth de segundo orden a 5 kHz, 108,9° y 7,6 dB, y 115,4° y 5,0 dB.

Ninguno compromete la estabilidad, así que el corte lo puede fijar el ruido del sensor (#29) sin mirar el PR.
## Verificación por simulación

El mismo lazo discreto de la sección de `Kr` se probó con `L` entre 140 y 260 µH y `R` entre 6,75 y 11,25 Ω, con `Kp` y `Kr` fijos, y con un cambio de `R` de 9 a 11,25 Ω (25 %) a 1,0 A pico. Este modelo no tiene saturación ni rampa, y con esta carga eso no cambia nada porque el índice nunca llega al tope (sección de saturación).

- En todas las combinaciones de `L` y `R` el lazo es estable y el error de la fundamental baja de 10 % desde el primer período. El peor caso es 8,9 % en el primer período con `R = 11,25 Ω` y 0,5 % en el segundo con `R = 6,75 Ω`, con cualquiera de las dos `L`.
- Con el escalón de 0,2 a 0,5 A el error es 5,3 %, 0,2 % y 0 % en los tres primeros períodos, y de 0,5 a 1,0 A es 4,5 %, 0,2 % y 0 %.
- En el cambio de `R`, con el lazo ya en régimen, el error queda en 2,2 % en el período siguiente y en 0 % después.
- En 20 instantes del período y en las esquinas de `L` y `R`, el pico de corriente sin rampa llega a 1,034 A.

Eso no cubre el rizado de conmutación, la cuantización del ADC, el ruido del sensor ni el tiempo muerto. Se modela la corriente promedio con retardo de un muestreo y nada más. El rizado y el aliasing están en sus secciones, y el resto se valida en el modelo de PLECS de Nicolás y en el banco.
## Plan de pruebas

El orden es el que se acordó en el reparto, primero sin energizar, después con la potencia por pasos y el PR completo al final, para que cada paso descarte una causa antes de sumar la siguiente. Las pruebas energizadas las hacen Mattio, Jefferson y Nicolás juntos en el mismo lugar, una persona opera y otra toma datos.

### Sin hardware

- Modelo de referencia. El mismo PR con la aritmética de la ISR corre en la PC con gcc contra un modelo de la planta, con vectores de prueba, y la salida de `pr_discreto` tiene que coincidir con la del modelo. Si después falla en el banco, ya se descartó el código del PR.
- PLECS (#38). Lazo cerrado con el puente, el tiempo muerto, el ADC de 12 bits y el ruido del sensor, que son lo que la simulación de este documento no tiene. Tiene que quedar estable en las esquinas de `L` y `R`, con error menor a 10 % desde el segundo período de un escalón, sin saturar en régimen y con rizado menor a 0,20 A pico a pico.

### Antes de energizar

- Compuertas y tiempo muerto con la potencia apagada, con osciloscopio y con capturas (Nicolás y Jefferson).
- Con 0 A en la carga, el ADC tiene que dar `ADC_OFFSET_CUENTAS`, y la corriente que mide el XADC se compara con la de la sonda (#32).
- El umbral de `supervisor_falla` fijado y la falla probada con un valor bajo, para ver que baja `enable`, enciende el LED y no rearma sola.

### Energizado, por pasos

Se arranca con `Vdc = 12 V` y 0,2 A, y se sube a 1,0 A cuando el paso anterior sale bien. Con esta carga 12 V alcanzan para 1,0 A (índice de 0,75) y dan menos rizado que 18 V, así que no hace falta subir la fuente.

1. Lazo abierto, con un `duty_ref` senoidal fijo de 50 Hz y sin PR. El índice que pide una corriente `I` es `m = |Z|·I/Vdc`, que con 18 V y la carga de 9 Ω y 200 µH da 0,100, 0,250 y 0,500 para 0,2, 0,5 y 1,0 A. Se mide la amplitud y el desfase de la corriente. Vale `Vdc·m/|Z|` solo si el puente fuera ideal, y el puente real pierde tensión por el tiempo muerto (`2·Vdc·TM·fsw` = 0,72 V a 18 V, con el signo de la corriente) y suma hasta 0,4 Ω de `RDS(on)` en serie con la carga. Con eso la predicción del ensayo es de 0,097 A para 0,2 A (-51 %, -11,1°), 0,381 A para 0,5 A (-24 %, -0,3°) y 0,860 A para 1,0 A (-14 %, -0,3°). Con la carga casi resistiva la pérdida pesa mucho más que antes en las amplitudes chicas, porque a 0,2 A la carga pide 1,8 V de fundamental y el tiempo muerto se come 0,92 V (la sección del tiempo muerto de `modelo_planta` tiene las cuentas). Con esto se verifican la ganancia del sensor, el signo y los valores medidos de `L` y `R`. Si la amplitud se aleja más de 10 % de esa predicción se detiene la prueba y se revisa antes de cerrar el lazo. La pérdida escala con el tiempo muerto real de los MOSFET, así que si el banco de compuertas da distinto de 1 µs se recalcula la predicción antes de comparar.
2. Solo la parte proporcional, con `Kr = 0`. Con `Kp = 4,5` el proporcional solo deja 66,7 % de error sin tiempo muerto, y con el tiempo muerto 80,8 % con 0,5 A y 74,2 % con 1,0 A, con desfase de -1,2° (`verificar_pr.m`, mismo método de onda cuadrada que la sección del tiempo muerto de `modelo_planta`). Con 0,2 A la tensión que pide el proporcional queda casi igual a la que se come el tiempo muerto y la predicción no sirve, así que este paso se hace solo con 0,5 y 1,0 A. Si sale muy distinto, la planta o el retardo no son los del modelo.
3. PR completo con 0,2, 0,5 y 1,0 A pico. Error de amplitud de la fundamental menor a 10 % en una ventana de al menos cinco períodos y en régimen, calculado con `receptor_pc` sobre el histórico exportado. El rizado menor a 0,20 A pico a pico se mide con el osciloscopio sobre la corriente de la carga, porque el histórico no lo ve. Con 200 µH a 20 kHz se espera que falle en 0,5 y 1,0 A (sección de rizado).
4. Cambios de amplitud de 0,2 a 0,5 A y de 0,5 a 1,0 A con los switches. Con la rampa de 400 muestras, en la simulación con el código real el peor caso de 20 fases da 0,5 % en el segundo período y 0 % en el tercero, con pico de 1,012 A (sección de rampa de amplitud). El primer período ya no se compara, porque la amplitud sube durante 20 ms. Eso sirve de referencia para detectar desvíos grandes, y el criterio de aceptación es el del enunciado.
5. Cambio de `R` de al menos 25 % con 0,5 A pico. La forma de cambiarla la define Jefferson, que arma la carga. En la simulación, a 1,0 A, el error sube a 2,2 % en el primer período y baja a 0 % en los siguientes, sin disparar el umbral de falla.

### Mediciones que acompañan a todo el ensayo

- Período y jitter del lazo con el GPIO que sube al entrar a la ISR y baja al salir, visto en el osciloscopio. El período tiene que ser de 50 µs (5000 ciclos), y la duración de la ISR y su fase respecto a `pwm_trigger_o` tienen que quedar estables.
- Retardo efectivo del lazo, desde la captura hasta el cambio en las compuertas, contra los 75 µs del modelo más `τF`. El margen de ganancia baja a 6 dB recién con 203 µs extra, y si el retardo medido se pasa de ahí se rehace la sintonización con la sección de estabilidad.
- Exportación durante un ensayo en régimen. Al apretar el botón, el período y el jitter no cambian, y la ventana exportada, de 2000 muestras para cinco períodos en un histórico de 2048, calza con lo medido.
- Evidencia de cada ensayo con la referencia, la corriente medida, la tensión sobre la carga y las señales PWM, distinguiendo pico y RMS, y con el método de extracción de la fundamental descrito.

## Pendientes

Del lado de Jefferson.

- Medir `L` y `R` reales de los dos inductores y la carga (#31), 200 µH y 9 Ω son nominales, no todavía una medición con LCR. Si `R` se aleja del nominal se recalcula `Kp = R/2`.
- Decidir con el equipo cómo bajar el rizado bajo 0,20 A pp, más `L` o el puente a 40 kHz (sección de rizado).
- Ganancia y offset del sensor de corriente (#32), para la conversión de cuentas del ADC a amperes en `lazo_control`.
- Filtro analógico del sensor, tipo y corte, que sale de medir el ruido (#29). Con él se suma `τF` al `Td` y se recalculan los márgenes.
- Con las tierras separadas por el aislamiento de las compuertas (#21), el sensor tiene que ser aislado o cruzar la barrera de otra forma (#30), y su offset y su ruido pueden no ser los del supuesto de 0 A en 0,5 V. Se mide con el sensor montado.

Del lado de Nicolás.

- Retardo del aislamiento de las compuertas (#21), subida y bajada por separado, para sumarlo al `Td` y para que el tiempo muerto lo cubra. Queda pendiente hasta que cierre #21.
- Confirmar `Vdc`, `fsw` y que el puente aguanta la frecuencia con el tiempo muerto elegido (#18).
- Habilitar o no la FPU del MicroBlaze V.
- Modelo en PLECS (#38), para completar la verificación con rizado, tiempo muerto, cuantización y ruido.

Entre Jefferson y Nicolás.

- Que la captura del XADC caiga en el valle o el pico, y cuántos ciclos adelantar el trigger por el tiempo que tarda en cerrarse el sample and hold (#34).

Propios.

- Medir el retardo efectivo del lazo con el GPIO de la ISR y comparar con `1,5·Ts`.
- Que el Timer y la portadora cuenten exactamente lo mismo (5000 ciclos a 20 kHz), y medir con el GPIO de la ISR contra `pwm_trigger_o` que la fase no deriva.
- Fijar `PR_U_MAX`, que tiene 1,0 como tope porque `duty_ref` va en Q2.14 de -1,0 a +1,0, y baja a 0,92 por el tiempo muerto y el bootstrap.
- Rampeo de `amplitud_ref` listo y verificado contra el código real con la carga de 200 µH (sección de rampa de amplitud). Falta confirmarlo en el banco con potencia.

## Referencias

- R. Teodorescu, F. Blaabjerg, M. Liserre y P. C. Loh, "Proportional-resonant controllers and filters for grid-connected voltage-source converters", IEE Proc. Electric Power Applications, vol. 153, no. 5, pp. 750-762, 2006. DOI 10.1049/ip-epa:20060008.
- A. G. Yepes, F. D. Freijedo, J. Doval-Gandoy, O. López, J. Malvar y P. Fernández-Comesaña, "Effects of discretization methods on the performance of resonant controllers", IEEE Trans. Power Electronics, vol. 25, no. 7, pp. 1692-1712, 2010. Tiene una corrección publicada en el vol. 27, no. 12, p. 4976, 2012.
- N. Mohan, T. Undeland y W. Robbins, Power Electronics: Converters, Applications and Design, sección 8-3-2-2 (PWM con conmutación unipolar de tensión).
- D. W. Hart, Power Electronics, capítulo 8 (modulación unipolar).
