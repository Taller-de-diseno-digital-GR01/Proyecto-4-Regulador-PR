# Diseño del regulador PR, decisiones y justificación

Este documento junta las decisiones de diseño del regulador proporcional-resonante (PR) del lazo de corriente, con la razón de cada una. La carga ya quedó en `R = 10 Ω` y `L = 2 mH`. `Vdc` y `fsw` siguen provisionales y están marcados como tales, y los valores reales de `L` y `R` salen de medir la carga montada. Todo lo que depende de ellos se rehace cambiando esos números, el procedimiento no cambia.

Los márgenes y las curvas de error de este documento se calcularon en Python con el lazo discreto descrito en las secciones de sintonización, y cada cifra lleva sus condiciones. Los coeficientes finales los escribe `sw/generar_pr_params.m` en `pr_params.h`, y corre igual en Octave y en MATLAB.

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

- `Vdc = 18 V`, punto medio del rango de 12 a 24 V del enunciado. El rizado máximo es lineal en `Vdc`, así que con 24 V sube un tercio y con 12 V baja a dos tercios. A 1,0 A pico el control pide unos 10 V. Con 18 V eso es un índice de 0,56 y sobra margen, pero con 12 V sube a 0,84, apenas debajo de `PR_U_MAX = 0,92`, y el escalón de 0,2 a 1,0 A llega a pedir 1,24 y satura. Los ensayos con 1,0 A van entonces con 18 V o más.
- `fsw = fs = 20 kHz`, muestreando una vez por período. A 100 MHz son 5000 ciclos de reloj por iteración, de sobra para las seis multiplicaciones del PR incluso en flotante por software. Es una frecuencia habitual para MOSFET de baja tensión, pero Nicolás tiene que confirmar que su puente y su tiempo muerto la aguantan. La tabla de `nucleo_pwm.md` trae 10 y 40 kHz en las otras dos frecuencias y el código `11` satura a 20 kHz. Cada frecuencia pide regenerar los coeficientes.
- `L = 2 mH` y `R = 10 Ω`, la carga que se va a montar. La `L` cumple con holgura el criterio de rizado de abajo, y el inductor no tiene que saturar a 1,5 A. Con 1,0 A pico la `R` disipa 5 W en promedio, así que tiene que ser de potencia, de al menos 10 W. Jefferson mide los valores reales (#31).

A 50 Hz la impedancia es `|Z| = |R + jω0L| = 10,02 Ω`, casi toda resistiva, con 3,6° de desfase. De ahí sale el índice de modulación que pide cada amplitud con 18 V, 0,111 para 0,2 A, 0,278 para 0,5 A y 0,557 para 1,0 A.

## Rizado y la `L` mínima

Con modulación unipolar, el voltaje de salida salta entre 0 y `±Vdc` a `2·fsw` con ciclo de trabajo `D = |m|`. El rizado pico a pico queda en

$$\Delta I_{pp} \approx \frac{V_{dc}\,D(1-D)}{2\,L\,f_{sw}}$$

cuyo máximo está en `D = 0,5` y vale `Vdc/(8·L·fsw)`. Esta fórmula es derivación propia, los libros solo dan la duplicación efectiva de la frecuencia. Exigir que ese máximo quede bajo 0,20 A da `L ≥ Vdc/(1,6·fsw)`.

- Con 18 V y 20 kHz, `L ≥ 0,56 mH`.
- Con 24 V y 20 kHz, `L ≥ 0,75 mH`.

Con `L = 2 mH` y 18 V el máximo teórico es 0,056 A. A 1,0 A pico el índice de modulación pico es `10,02/18 ≈ 0,56`, muy cerca del `D = 0,5` del máximo, así que el rizado real ronda esos mismos 0,055 A. Con 24 V sube a 0,075 A, y a 10 kHz, con `freq_sel = 00`, se duplica. El tiempo muerto y las caídas en los transistores lo empeoran un poco y no están incluidos.

## Ganancia proporcional

Se fija el ancho de banda del lazo `fc` en `fs/20 = 1 kHz`. Más alto el retardo de 1,5 `Ts` come margen de fase y de ganancia, y más bajo la parte proporcional se vuelve lenta aunque el resonante domina el seguimiento de todas formas. Con `fc` en 2 kHz el margen de fase queda en 57° pero el de ganancia cae a 5,0 dB, y con 500 Hz sobra margen (129° y 12,2 dB) pero no se gana nada medible. Con la `R` de 10 Ω la carga aporta fase en el cruce, y el que limita es el margen de ganancia.

En el cruce el resonante aporta apenas `Kr/ωc ≈ 0,48` contra `Kp ≈ 16`, así que `Kp` se calcula como si el resonante no estuviera. Imponiendo ganancia unitaria de lazo en `ωc`.

$$K_p = \sqrt{R^2 + (\omega_c L)^2} = 16{,}06\ \mathrm{V/A}$$

## Ganancia resonante

`Kr` fija qué tan rápido converge el error en 50 Hz. Con `Kp = 16,06` se probó en un lazo discreto completo (planta por ZOH exacto, un muestreo de retardo, regulador con Tustin precorregido) y un escalón de 0,2 a 1,0 A pico aplicado en un cruce por cero de la referencia, midiendo el error de la fundamental en ventanas de un período. El error es el de amplitud de la fundamental, `(|I1| - |R1|)/|R1|` con `I1` y `R1` los fasores de 50 Hz de la corriente y de la referencia, que es el criterio de 4.3.5 y el que calcula `receptor_pc.md` en su sección h.2, y se informa en valor absoluto. Los fasores se extraen proyectando sobre seno y coseno en el período completo. El desfase sale aparte y en estas pruebas no pasó de 2,1°, por lo que el error del fasor completo da casi lo mismo.

- `Kr = 1000`, error de 29,8 %, 20,3 %, 13,8 %, 9,4 %, 6,4 % en los cinco primeros períodos.
- `Kr = 3000`, error de 19,8 %, 6,1 %, 1,9 %, 0,6 %, 0,2 %.
- `Kr = 5000`, error de 14,3 %, 1,9 %, 0,2 % y de ahí en adelante menos de 0,05 %.

Se elige `Kr = 3000`. Cumple los 10 % desde el segundo período y deja el margen de fase prácticamente igual al de los otros dos (99,8° contra 100,9° con 1000 y 98,6° con 5000), con un margen de ganancia de 9,5 a 9,6 dB en los tres. Los polos de lazo cerrado del resonante quedan en `|z| = 0,9971`, una constante de tiempo de 17 ms, o sea unos 0,86 períodos de 50 Hz, y eso explica que el error caiga a un tercio por período. `Kr = 5000` converge un período antes, pero el enunciado mide el error en régimen y no durante el transitorio, y con 3000 ya se cumple desde el segundo período.

Con la carga provisional anterior, de 2 Ω y 1 mH, el mismo criterio daba `Kr = 1000`. Con 10 Ω hace falta el triple porque la convergencia del resonante se frena con `Kp + |Z|`, que pasó de unos 8,6 a unos 26, y con 1000 el error recién baja de 10 % en el cuarto período.

## Discretización

El resonante discretizado queda como filtro de segundo orden, `r[k] = b0·e[k] + b1·e[k-1] + b2·e[k-2] - a1·r[k-1] - a2·r[k-2]`. Con Tustin simple, `s = (2/T)(z-1)/(z+1)`, el polo se corre por debajo de 50 Hz hasta `(2/T)·arctan(ω0T/2)`. A 20 kHz, con 400 muestras por período, ese corrimiento es de apenas 1 mHz, y a 10 kHz son 4 mHz, así que en este lazo la diferencia práctica es muy chica. Yepes et al. (2010) estudian el efecto y concluyen que el método de discretización pesa mucho en el desempeño de los controladores resonantes, y el peso crece cuando la frecuencia de muestreo baja respecto a la resonante.

Se usa Tustin con precorrección en 50 Hz, `s = (ω0/tan(ω0T/2))(z-1)/(z+1)`. Cuesta lo mismo que el simple, deja el polo exactamente en `ω0` a cualquier `fs`, y los coeficientes quedan en forma cerrada, con `θ = ω0·Ts`.

- `b0 = Kr·sin(θ)/(2ω0)`
- `b1 = 0`
- `b2 = -b0`
- `a1 = -2·cos(θ)`
- `a2 = 1`

La estructura de cinco coeficientes de `pr_discreto` y de `generar_pr_params.m` ya soporta esto sin cambios, y `coeficientes_resonante` implementa estas fórmulas para `tustin_prewarp`. `sw/pruebas/prueba_generar_pr_params.m` revisa que salgan los coeficientes de abajo y que el polo quede en 50 Hz después de redondear `A1`.

## Coeficientes resultantes

Con los valores provisionales y dividiendo entre `Vdc` para que la salida sea índice de modulación, como ya prevé el script.

- `KP = 0,8922`
- `B0 = 4,1665e-3`
- `B1 = 0`
- `B2 = -4,1665e-3`
- `A1 = -1,99975`
- `A2 = 1`

`A1` queda muy cerca de -2, y lo que importa es que la diferencia con -2 se represente bien porque ella fija la frecuencia del polo. Un paso de 1e-6 en `A1` corre el polo unos 0,1 Hz. En flotante de 32 bits el paso en ese valor es de 1,2e-7, o sea 0,012 Hz, y con ese corrimiento la ganancia del resonante en 50 Hz sigue siendo de miles, con un error de seguimiento menor a 0,03 %. En punto fijo hace falta un formato con al menos dos bits enteros y unos 20 fraccionarios para `A1`, y esto es un argumento a favor de habilitar la FPU.

## Saturación y anti-windup

El PR calcula un índice de modulación `u[k]` que se recorta a `±PR_U_MAX` antes de convertirlo a `duty_ref` en Q2.14. El tope absoluto es 1,0, el rango del periférico, y lo que lo baja son el tiempo muerto y el bootstrap. A 20 kHz, con `MAX = 2500`, hace falta `PR_U_MAX < 1 - (DEAD_TIME_CICLOS + 100)/MAX`, que con 100 ciclos de tiempo muerto da 0,92. Si hubo recorte, el estado que se guarda del resonante es el que habría hecho caer la suma justo en el límite, y así no acumula energía mientras el puente está saturado. La fórmula y las razones están en `pr_discreto.md`, sección h.5, que es la fuente de verdad de esa parte.

Con 18 V no hay saturación ni en régimen ni en el escalón de 0,2 a 1,0 A, que en el peor instante del período llega a pedir 0,83 contra un tope de 0,92. Con 12 V el régimen de 1,0 A pide 0,84 y el escalón 1,24, así que ahí el anti-windup sí trabaja, y por eso 1,0 A se ensaya con 18 V o más.

## Aliasing y filtro del sensor

El criterio `fs > 2·BW` se cumple de sobra para la señal. La referencia es de 50 Hz y el lazo cruza en 1 kHz, contra una `fs` de 20 kHz. Lo que el criterio no mira es todo lo demás que entra al ADC, porque al muestrear cualquier contenido por encima de `fs/2` se pliega hacia la banda del lazo y se confunde con corriente.

- El rizado de conmutación se sincroniza solo. Si la captura cae en el valle o en el pico de la portadora, el rizado es un múltiplo exacto de `fs` y se pliega a continua. Se simuló el puente unipolar en lazo cerrado con la carga de 10 Ω y 2 mH y 18 V, con la portadora de 2500 cuentas a 100 MHz, la carga RL resuelta de forma exacta entre flancos y el PR de las secciones anteriores, sin tiempo muerto ni cuantización del ADC. El error de amplitud de la fundamental de la corriente verdadera, no la muestreada, da lo siguiente con 1,0 A pico.
  - Captura en el valle, 0,05 %. Con +200 ns de error en el instante sube a 0,15 % y con -200 ns baja a -0,05 %, y con ±400 ns queda entre -0,15 % y 0,25 %. En el pico de la portadora es igual (0,05 % y 0,15 % con +200 ns).
  - Captura adelantada respecto al valle de la corriente, por el retardo de la cadena de compuertas (#18, de 0,1 a 0,91 µs). Con 0,91 µs antes del valle da -0,41 % con 1,0 A y -0,39 % con 0,2 A, y con 0,1 µs da menos de 0,01 %. En el valle la tensión sobre la carga es cero y la pendiente es `-R·i/L`, proporcional a la corriente, así que el error crece con la amplitud igual que la señal y a 0,2 A el error relativo no sube. Es más que con la carga de 2 Ω y 1 mH porque `R/L` pasó de 2000 a 5000 por segundo, pero queda unas 25 veces por debajo del 10 % y la envoltura sigue sin necesitar retardo antes de `CONVST`.
  - Captura en el centro del pulso, con la portadora en `MAX/2`, donde el rizado también pasa por su promedio pero con la pendiente máxima. Con 1,0 A y ±200 ns da entre -0,18 % y 0,08 %, parecido al valle, porque con 10 V sobre la carga la pendiente en el pulso es baja. Con 0,2 A pico da entre -1,2 % y 0,9 %, unas 7 veces más que en el valle, porque el error absoluto no baja con la amplitud.
  - Captura en el flanco del pulso, donde se lee el extremo del rizado, 2,8 % con 1,0 A.
  - Con una fase cualquiera, a 5, 7,8 y 20 µs del valle, el error va de -2,4 % a +2,6 %.

  Por eso `pwm_trigger_o` tiene que caer en el valle o el pico. La tolerancia es holgada, unos pocos cientos de nanosegundos alcanzan, y eso le sirve a #34 para decidir cuántos ciclos adelantar el trigger por el sample and hold del XADC.
- El ruido de banda ancha del sensor y de la conmutación no se sincroniza con nada, y lo único que lo frena es un filtro analógico antes del ADC. Ese filtro todavía no existe. Su corte sale de medir el ruido real del sensor, y lo mide Jefferson, que también diseña el filtro (#29).

El filtro cuesta fase en el cruce. Para un RC de primer orden con corte `fF`, el retardo de grupo a baja frecuencia es `τF = 1/(2π·fF)`, que vale 32 µs con 5 kHz, 53 µs con 3 kHz y 80 µs con 2 kHz, o sea 0,64, 1,06 y 1,59 `Ts`. Los márgenes que quedan con cada uno están en la sección siguiente. Todavía no hay corte ni orden elegidos, así que el retardo total del lazo es `Td = 1,5·Ts + τF` con `τF` pendiente, y los márgenes se recalculan cuando Jefferson fije el filtro.

Con `freq_sel` la tabla de `nucleo_pwm.md` quedó en `00` a 10 kHz, `01` a 20 kHz y `10` a 40 kHz, y `11` satura a 20 kHz. El lazo cerrado corre solo a 20 kHz, con el Timer fijo en 5000 ciclos, así que el argumento del aliasing a 10 kHz ya no aplica. Las otras frecuencias son para mostrar el PWM y para el testbench, con el control deshabilitado, y `control_principal` solo deja habilitar el control con `freq_sel = 01`.

## Análisis de estabilidad

Se analiza `L(s) = Gc(s)·e^(-s·Td)/(Ls + R)` con `Td = 1,5·Ts = 75 µs`. Todos los márgenes de esta sección salen de ese lazo abierto, con `Kp = 16,06` y `Kr = 3000` salvo que se diga otra cosa, y se miden en el cruce de ganancia más alto.

El diseño nominal, con `L = 2 mH` y `R = 10 Ω`, cruza en 1,0 kHz con 99,8° de margen de fase y 9,6 dB de margen de ganancia. El criterio que se pide es margen de fase de al menos 45° y de ganancia de al menos 6 dB con la `L` medida y el filtro del sensor puestos, y de al menos 30° y 3 dB en las esquinas de `L` y `R` de abajo con `Kp` sin retocar. Si la `L` medida difiere de 2 mH se recalcula `Kp` con la fórmula de arriba y el nominal se mantiene parecido, por ejemplo con 1,4 mH sale `Kp = 13,32` y 109,5° y 8,6 dB.

Si `L` y `R` varían después de sintonizar, por ejemplo por saturación del inductor o por calentamiento de la resistencia, `Kp` queda fijo y los márgenes se mueven. Las esquinas son ±30 % en `L` y ±25 % en `R`. El mínimo está en la `L` más chica con la `R` más chica, porque sube el cruce y la carga aporta menos fase.

- `L = 1,4 mH`, `R = 7,5 Ω`, cruce en 1615 Hz, 73,2° y 6,6 dB.
- `L = 1,4 mH`, `R = 12,5 Ω`, cruce en 1147 Hz, 108,6° y 7,4 dB.
- `L = 2,6 mH`, `R = 7,5 Ω`, cruce en 870 Hz, 92,4° y 11,3 dB.
- `L = 2,6 mH`, `R = 12,5 Ω`, cruce en 619 Hz, 121,5° y 11,8 dB.

El retardo que se le agrega al `Td` es lo que más mueve los márgenes. En el cruce de 1 kHz cada microsegundo extra cuesta 0,36° de fase.

- 25 µs extra, 90,8° y 7,5 dB.
- 50 µs extra, 81,8° y 5,9 dB.
- 75 µs extra, 72,7° y 4,7 dB.
- Con 49 µs extra el margen de ganancia baja a 6 dB. El de fase recién llega a 45° con 153 µs, y el de ganancia se agota con unos 280 µs, que es donde el lazo se vuelve inestable.

Con esta carga el retardo extra que se tolera queda fijado por el margen de ganancia y ya no por el de fase, y es la mitad que con la de 2 Ω y 1 mH.

El retardo del aislamiento de las compuertas (#21) se espera de pocos microsegundos como mucho, y con 2 µs el margen queda en 99,0° y 9,4 dB, así que se puede sumar al `Td` sin rehacer la sintonización. El del filtro del sensor pesa bastante más. Con `Kp` y `Kr` fijos, el RC de primer orden da lo siguiente en el diseño nominal. El filtro también baja la ganancia en el cruce, por eso el margen de fase cae menos de lo que saldría de sumar `τF` al retardo, y el de ganancia casi no se mueve.

- `fF = 5 kHz`, cruce en 971 Hz, 90,4° y 8,4 dB.
- `fF = 3 kHz`, cruce en 927 Hz, 86,6° y 8,5 dB.
- `fF = 2 kHz`, cruce en 863 Hz, 84,0° y 8,9 dB.

Un Butterworth de segundo orden a 5 kHz atenúa 12 dB en `fs/2` y 36 dB a 40 kHz, contra los 7 dB y 18 dB del RC a 5 kHz, y a cambio deja el nominal en 83,4° y 6,2 dB, justo encima del criterio. En la esquina de `L = 1,4 mH` y `R = 7,5 Ω` el RC de 5 kHz queda en 60,0° y 5,4 dB, el RC de 3 kHz en 56,4° y 5,6 dB y el Butterworth en 46,8° y 3,3 dB. Los tres cumplen el criterio de arriba, el Butterworth casi sin holgura. El RC de 2 kHz, el más lento de la lista, queda en esa misma esquina en 55,1° y 6,1 dB y también cumple, así que el corte lo puede fijar el ruido del sensor (#29) y no la estabilidad. Si el filtro elegido queda más lento que eso, o si el retardo extra medido en el banco pasa de unos 50 µs, se rehace la sintonización con `fc` más bajo.

## Verificación por simulación

El mismo lazo discreto de la sección de `Kr` se probó con `L` entre 1,4 y 2,6 mH y `R` entre 7,5 y 12,5 Ω, con `Kp` y `Kr` fijos, y con un cambio de `R` de 10 a 12,5 Ω (25 %) a 1,0 A pico.

- En todas las combinaciones de `L` y `R` el lazo es estable y el error de la fundamental baja de 10 % desde el segundo período. El peor caso es 23,7 % en el primer período (con `R = 12,5 Ω`, con cualquiera de las dos `L`) y 8,2 % en el segundo.
- Con el escalón de 0,2 a 0,5 A el error es 16,6 %, 5,2 % y 1,6 % en los tres primeros períodos, y de 0,5 a 1,0 A es 15,0 %, 4,7 % y 1,4 %. Los dos cumplen los 10 % desde el segundo período.
- En el cambio de `R`, con el lazo ya en régimen, el error sube a 5,5 % en el primer período y baja a 1,9 % y 0,6 % en los dos siguientes. Con 12,5 Ω, 1,0 A pico pide 12,5 V, así que este ensayo no se puede hacer a 1,0 A con 12 V.
- En ningún caso la corriente del escalón de 0,2 a 1,0 A pasa de 1,0 A pico, probado en 20 instantes del período y en las esquinas de `L` y `R`.

Eso no cubre el rizado de conmutación, la cuantización del ADC, el ruido del sensor, el tiempo muerto ni la saturación con anti-windup. Se modela la corriente promedio con retardo de un muestreo y nada más. Estos puntos se validan en el modelo de PLECS de Nicolás y en el banco.

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

Se arranca con `Vdc = 12 V` y 0,2 A, y se sube a 18 V y a 1,0 A cuando el paso anterior sale bien. Con 1,0 A no se baja de 18 V, por lo de la sección de saturación.

1. Lazo abierto, con un `duty_ref` senoidal fijo de 50 Hz y sin PR. El índice que pide una corriente `I` es `m = |Z|·I/Vdc`, que con 18 V y la carga de 10 Ω y 2 mH da 0,111, 0,278 y 0,557 para 0,2, 0,5 y 1,0 A. Se mide la amplitud y el desfase de la corriente, que tienen que salir cerca de `Vdc·m/|Z|` y de -3,6°. Con esto se verifican la ganancia del sensor, el signo y los valores medidos de `L` y `R`. Si la amplitud se aleja más de 10 % se detiene la prueba y se revisa antes de cerrar el lazo.
2. Solo la parte proporcional, con `Kr = 0`. Con la carga de 10 Ω y 2 mH el error de amplitud en régimen tiene que ser de unos 38 % (es el `1/|1 + Kp·e^(-jω0Td)/Z|` del modelo), con 1,9° de desfase. Si sale muy distinto, la planta o el retardo no son los del modelo.
3. PR completo con 0,2, 0,5 y 1,0 A pico. Error de amplitud de la fundamental menor a 10 % en una ventana de al menos cinco períodos y en régimen, calculado con `receptor_pc` sobre el histórico exportado. El rizado menor a 0,20 A pico a pico se mide con el osciloscopio sobre la corriente de la carga, porque el histórico no lo ve.
4. Cambios de amplitud de 0,2 a 0,5 A y de 0,5 a 1,0 A con los switches. En la simulación el error de amplitud es 16,6 % y 15,0 % en el primer período y menos de 6 % en el segundo. Eso sirve de referencia para detectar desvíos grandes, y el criterio de aceptación es el del enunciado.
5. Cambio de `R` de al menos 25 % con 0,5 A pico. La forma de cambiarla la define Jefferson, que arma la carga. En la simulación el error sube a 5,5 % en el primer período y baja a 1,9 % y 0,6 % en los dos siguientes, sin disparar el umbral de falla.

### Mediciones que acompañan a todo el ensayo

- Período y jitter del lazo con el GPIO que sube al entrar a la ISR y baja al salir, visto en el osciloscopio. El período tiene que ser de 50 µs (5000 ciclos), y la duración de la ISR y su fase respecto a `pwm_trigger_o` tienen que quedar estables.
- Retardo efectivo del lazo, desde la captura hasta el cambio en las compuertas, contra los 75 µs del modelo más `τF`. Con unos 49 µs extra el margen de ganancia baja a 6 dB, y si el retardo medido se pasa de ahí se rehace la sintonización con la sección de estabilidad.
- Exportación durante un ensayo en régimen. Al apretar el botón, el período y el jitter no cambian, y la ventana exportada, de 2000 muestras para cinco períodos en un histórico de 2048, calza con lo medido.
- Evidencia de cada ensayo con la referencia, la corriente medida, la tensión sobre la carga y las señales PWM, distinguiendo pico y RMS, y con el método de extracción de la fundamental descrito.

## Pendientes

Del lado de Jefferson.

- Medir `L` y `R` reales de la carga de 10 Ω y 2 mH (#31), con lo que se repite la sintonización si se alejan del nominal.
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

## Referencias

- R. Teodorescu, F. Blaabjerg, M. Liserre y P. C. Loh, "Proportional-resonant controllers and filters for grid-connected voltage-source converters", IEE Proc. Electric Power Applications, vol. 153, no. 5, pp. 750-762, 2006. DOI 10.1049/ip-epa:20060008.
- A. G. Yepes, F. D. Freijedo, J. Doval-Gandoy, O. López, J. Malvar y P. Fernández-Comesaña, "Effects of discretization methods on the performance of resonant controllers", IEEE Trans. Power Electronics, vol. 25, no. 7, pp. 1692-1712, 2010. Tiene una corrección publicada en el vol. 27, no. 12, p. 4976, 2012.
- N. Mohan, T. Undeland y W. Robbins, Power Electronics: Converters, Applications and Design, sección 8-3-2-2 (PWM con conmutación unipolar de tensión).
- D. W. Hart, Power Electronics, capítulo 8 (modulación unipolar).
