# Diseño del regulador PR, decisiones y justificación

Este documento junta las decisiones de diseño del regulador proporcional-resonante (PR) del lazo de corriente, con la razón de cada una. Los valores de `Vdc`, `fsw`, `L` y `R` son provisionales y están marcados como tales, porque la carga y el puente todavía no se miden. Todo lo que depende de ellos se rehace cambiando esos números, el procedimiento no cambia.

## Objetivo del lazo

Que la corriente en la carga RL siga una referencia senoidal de 50 Hz con 0,2, 0,5 y 1,0 A pico, con error de la fundamental menor a 10 % en una ventana de al menos cinco períodos y rizado de conmutación menor a 0,20 A pico a pico. También tiene que sobrevivir a un cambio de amplitud y a un cambio de `R` de al menos 25 %. Los criterios salen de la sección 4.3 del enunciado.

## Por qué un PR

Un PI tiene ganancia infinita en continua, y por eso sigue referencias constantes sin error. Con una senoidal deja error de amplitud y de fase. El término resonante pone la ganancia infinita en `ω0 = 2π·50` y deja error nulo en esa frecuencia, sin transformar a ejes sincrónicos y sin PLL, lo que lo hace barato de ejecutar en un MicroBlaze. Teodorescu et al. (2006) lo presentan justo así, como alternativa en marco estacionario que también permite compensar armónicos selectivos con poco cómputo.

La estructura elegida es la ideal.

$$G_c(s) = K_p + K_r \frac{s}{s^2 + \omega_0^2}$$

La versión amortiguada cambia exactitud en 50 Hz por tolerancia a que la frecuencia se corra. Acá la referencia la genera el propio MicroBlaze a 50 Hz exactos, así que no hay frecuencia que se corra y el término ideal no pierde nada.

## Planta y retardo

El puente H con modulación unipolar entrega `v = Vdc·u`, con `u` el índice de modulación entre -1 y 1. La carga cumple `I(s)/V(s) = 1/(Ls + R)`. La modulación unipolar sale del enunciado y de ella se toma que la frecuencia efectiva del rizado es el doble de la de conmutación (Mohan, sección 8-3-2-2, y Hart, capítulo 8).

Además hay un retardo. La muestra se toma en el centro del pulso con `pwm_trigger_o`, la interrupción calcula con ella y escribe `duty_ref`, y el periférico lo aplica en el siguiente pico o valle de la portadora. Eso es un período de muestreo de cómputo más medio de actualización, y se modela como `Td = 1,5·Ts`, con `Ts = 1/fs`. Es el modelo habitual de los lazos digitales de corriente y es una suposición mía hasta medir el lazo real con el GPIO de la ISR. `nucleo_pwm.md` lo respalda en lo que toca al periférico, porque `pwm_trigger_o` sale en el valle y lo que el software escribe a mitad de período rige desde el valle siguiente. A ese `Td` todavía hay que sumarle el retardo del filtro analógico del sensor, que se calcula en la sección siguiente.

## Aliasing y filtro del sensor

El criterio `fs > 2·BW` se cumple de sobra para la señal. La referencia es de 50 Hz y el lazo cruza en 1 kHz, contra una `fs` de 20 kHz. Lo que el criterio no mira es todo lo demás que entra al ADC, porque al muestrear cualquier contenido por encima de `fs/2` se pliega hacia la banda del lazo y se confunde con corriente.

- El rizado de conmutación se sincroniza solo. Si la captura cae en el valle o en el pico de la portadora, el rizado es un múltiplo exacto de `fs` y se pliega a continua. En una simulación en lazo abierto del puente unipolar con los valores provisionales, el error de la fundamental por esa causa fue 0,01 %. En el cruce de portadora, que es donde está el flanco del pulso de tensión, la sensibilidad al instante de captura es unas 9 veces mayor y un error de 200 ns ya da 0,42 %. Por eso `pwm_trigger_o` tiene que caer en el valle o el pico.
- El ruido de banda ancha del sensor y de la conmutación no se sincroniza con nada, y lo único que lo frena es un filtro analógico antes del ADC. Ese filtro todavía no existe. Su corte sale de medir el ruido real del sensor, y lo mide Nicolás.

El filtro cuesta fase en el cruce. Para un RC de primer orden con corte `fF`, el retardo de grupo a baja frecuencia es `τF = 1/(2π·fF)` y la fase que se pierde en `fc = 1 kHz` es `arctan(fc/fF)`.

- `fF = 5 kHz`, `τF = 32 µs` (0,64 `Ts`), pierde 11,3°.
- `fF = 3 kHz`, `τF = 53 µs` (1,06 `Ts`), pierde 18,4°.
- `fF = 2 kHz`, `τF = 80 µs` (1,59 `Ts`), pierde 26,6°.

Contra los 79° de margen de fase de `Kr = 1000` quedan unos 68°, 61° y 52°. Son cuentas aproximadas que no mueven el cruce de ganancia, y eso se cumple bien a 5 kHz (la ganancia en 1 kHz baja 2 %) y menos a 2 kHz (baja 11 %). Un filtro de segundo orden tipo Butterworth a 5 kHz atenúa 12 dB en `fs/2` y 36 dB a 40 kHz, contra los 7 dB y 18 dB del RC a esa misma frecuencia, y pierde 16° en 1 kHz, o sea deja el margen cerca de 63°. Todavía no hay corte ni orden elegidos, así que el retardo total del lazo queda como `Td = 1,5·Ts + τF` con `τF` pendiente, y los márgenes de la sección de `Kp` se recalculan cuando Nicolás fije el filtro.

Con `freq_sel` pasa algo parecido. La tabla provisional de `nucleo_pwm.md` de Jefferson pone `00` en 10 kHz, `01` en 20 kHz y `10` en 40 kHz, con el `11` pendiente. A 10 kHz el lazo muestrea a 10 kHz, el Nyquist baja a 5 kHz y un filtro pensado para 20 kHz casi no atenuaría nada ahí. Conviene que los códigos sean frecuencias de 20 kHz o más, por ejemplo 20, 30 y 40 kHz, pero la tabla depende de lo que cierre PEDP, y falta confirmar con Nicolás que su puente aguanta 40 kHz.

## Valores provisionales de partida

- `Vdc = 18 V`, punto medio del rango de 12 a 24 V del enunciado. Con 24 V el rizado sube un tercio, con 12 V la carga se ve más.
- `fsw = fs = 20 kHz`, muestreando una vez por período. A 100 MHz son 5000 ciclos de reloj por iteración, de sobra para las siete multiplicaciones del PR incluso en flotante por software. Es una frecuencia habitual para MOSFET de baja tensión, pero Nicolás tiene que confirmar que su puente y su tiempo muerto la aguantan. La tabla provisional de `nucleo_pwm.md` trae 10 y 40 kHz en las otras dos, con un cuarto código pendiente (ver la sección de aliasing), y cada frecuencia pide regenerar los coeficientes.
- `L = 1 mH` y `R = 2 Ω`. La `L` sale del criterio de rizado de abajo, con un inductor que no sature a 1,5 A. La `R` es del orden en que 1 A pico cae 2 V, muy por debajo de `Vdc`, y una resistencia de 5 W lo disipa sin problema (1 W rms). Jefferson mide los valores reales.

## Rizado y la `L` mínima

Con modulación unipolar, el voltaje de salida salta entre 0 y `±Vdc` a `2·fsw` con ciclo de trabajo `D = |m|`. El rizado pico a pico queda en

$$\Delta I_{pp} \approx \frac{V_{dc}\,D(1-D)}{2\,L\,f_{sw}}$$

cuyo máximo está en `D = 0,5` y vale `Vdc/(8·L·fsw)`. Esta fórmula es derivación propia, los libros solo dan la duplicación efectiva de la frecuencia. Exigir que ese máximo quede bajo 0,20 A da `L ≥ Vdc/(1,6·fsw)`.

- Con 18 V y 20 kHz, `L ≥ 0,56 mH`.
- Con 24 V y 20 kHz, `L ≥ 0,75 mH`.

Con `L = 1 mH` y 18 V el máximo teórico es 0,11 A. En la práctica es menor, porque a 1,0 A pico el índice de modulación pico es `2,02/18 ≈ 0,11` y el rizado ronda 0,04 A. El tiempo muerto y las caídas en los transistores lo empeoran un poco y no están incluidos.

## Ganancia proporcional

Se fija el ancho de banda del lazo `fc` en `fs/20 = 1 kHz`. Más alto el retardo de 1,5 `Ts` come margen de fase y de ganancia, y más bajo la parte proporcional se vuelve lenta aunque el resonante domina el seguimiento de todas formas. Con `fc` en 2 kHz el margen de fase cae a 45° y el de ganancia a 4,8 dB, y con 500 Hz sobra margen pero no se gana nada medible.

En el cruce el resonante aporta apenas `Kr/ωc ≈ 0,16` contra `Kp ≈ 6,6`, así que `Kp` se calcula como si el resonante no estuviera. Imponiendo ganancia unitaria de lazo en `ωc`.

$$K_p = \sqrt{R^2 + (\omega_c L)^2} = 6{,}59\ \mathrm{V/A}$$

## Ganancia resonante

`Kr` fija qué tan rápido converge el error en 50 Hz. Con `Kp = 6,59` se probó en un lazo discreto completo (planta por ZOH exacto, un muestreo de retardo, regulador con Tustin precorregido) y un escalón de 0,2 a 1,0 A, midiendo el error de la fundamental en ventanas de un período.

- `Kr = 500`, error de 14,6 %, 8,1 %, 4,5 %, 2,5 %, 1,4 % en los cinco primeros períodos.
- `Kr = 1000`, error de 11,3 %, 3,4 %, 1,0 %, 0,3 %, 0,1 %.
- `Kr = 2000`, error de 7,5 %, 0,6 % y de ahí en adelante nulo.

Se elige `Kr = 1000`. Cumple los 10 % desde el segundo período y deja el margen de fase prácticamente igual al de `Kr` chico (unos 79° contra 80°), con un margen de ganancia de 10,5 dB. `Kr = 2000` converge más rápido pero amplifica más el ruido del sensor sin ganar nada que el enunciado pida.

## Discretización

El resonante discretizado queda como filtro de segundo orden, `r[k] = b0·e[k] + b1·e[k-1] + b2·e[k-2] - a1·r[k-1] - a2·r[k-2]`. Con Tustin simple, `s = (2/T)(z-1)/(z+1)`, el polo se corre por debajo de 50 Hz y la ganancia infinita deja de caer en la frecuencia de la referencia, que es justo lo que se quería evitar. Yepes et al. (2010) estudian este efecto y concluyen que el método de discretización pesa mucho en el desempeño de los controladores resonantes.

Se usa Tustin con precorrección en 50 Hz, `s = (ω0/tan(ω0T/2))(z-1)/(z+1)`. Con esa sustitución el polo cae exactamente en `ω0` y los coeficientes quedan en forma cerrada, con `θ = ω0·Ts`.

- `b0 = Kr·sin(θ)/(2ω0)`
- `b1 = 0`
- `b2 = -b0`
- `a1 = -2·cos(θ)`
- `a2 = 1`

La estructura de cinco coeficientes de `pr_discreto` y de `generar_pr_params.py` ya soporta esto sin cambios. Falta implementar la fórmula en `coeficientes_resonante` para `tustin_prewarp`.

## Coeficientes resultantes

Con los valores provisionales y dividiendo entre `Vdc` para que la salida sea índice de modulación, como ya prevé el script.

- `KP = 0,3661`
- `B0 = 1,3888e-3`
- `B1 = 0`
- `B2 = -1,3888e-3`
- `A1 = -1,99975`
- `A2 = 1`

`A1` queda muy cerca de -2, y lo que importa es que la diferencia con -2 se represente bien porque ella fija la frecuencia del polo. En flotante de 32 bits sobra resolución. En punto fijo hace falta un formato con al menos dos bits enteros y muchos fraccionarios para `A1`, y esto es un argumento a favor de habilitar la FPU.

## Verificación por simulación

El mismo lazo discreto se probó con `L` entre 0,7 y 1,3 mH y `R` entre 1,5 y 2,5 Ω, y con un cambio de `R` de 2,0 a 2,5 Ω (25 %) a 1 A pico. En todos los casos el lazo es estable y el error de la fundamental baja de 10 % antes del tercer período, el peor caso es 13,6 % en el primero. En el cambio de `R` el error sube a 3,4 % en el primer período y vuelve a menos de 1 % en el tercero.

Eso no cubre el rizado de conmutación, la cuantización del ADC, el ruido del sensor, el tiempo muerto ni la saturación con anti-windup. Se modela la corriente promedio con retardo de un muestreo y nada más. Estos puntos se validan en el modelo de PLECS de PEDP y en el banco.

## Pendientes

- Medir `L` y `R` reales y repetir la sintonización con ellos.
- Confirmar `Vdc`, `fsw` y que el puente aguanta la frecuencia con el tiempo muerto elegido.
- Ganancia y offset del sensor de corriente, para la conversión de cuentas del ADC a amperes en `lazo_control`.
- Medir el retardo efectivo del lazo (GPIO en la ISR) y comparar con `1,5·Ts`.
- Filtro analógico del sensor, tipo y corte, que sale de medir el ruido (Nicolás). Con él se suma `τF` al `Td` y se recalculan los márgenes.
- Acordar entre Jefferson y Nicolás que la captura del XADC caiga en el valle o el pico, y cuántos ciclos adelantar el trigger por el tiempo que tarda en cerrarse el sample and hold.
- Que el Timer y la portadora cuenten exactamente lo mismo (5000 ciclos a 20 kHz), y medir con el GPIO de la ISR contra `pwm_trigger_o` que la fase no deriva.
- Habilitar o no la FPU del MicroBlaze V, y fijar `U_MAX`, que tiene 1,0 como tope porque `duty_ref` va en Q2.14 de -1,0 a +1,0, y baja según el tiempo muerto.
- Decidir con Jefferson y PEDP las frecuencias de `freq_sel`, por el 10 kHz de la tabla provisional.
- Implementar `tustin_prewarp` en `generar_pr_params.py`.

## Referencias

- R. Teodorescu, F. Blaabjerg, M. Liserre y P. C. Loh, "Proportional-resonant controllers and filters for grid-connected voltage-source converters", IEE Proc. Electric Power Applications, vol. 153, no. 5, pp. 750-762, 2006. DOI 10.1049/ip-epa:20060008.
- A. G. Yepes, F. D. Freijedo, J. Doval-Gandoy, O. López, J. Malvar y P. Fernández-Comesaña, "Effects of discretization methods on the performance of resonant controllers", IEEE Trans. Power Electronics, vol. 25, no. 7, pp. 1692-1712, 2010. Tiene una corrección publicada en el vol. 27, no. 12, p. 4976, 2012.
- N. Mohan, T. Undeland y W. Robbins, Power Electronics: Converters, Applications and Design, sección 8-3-2-2 (PWM con conmutación unipolar de tensión).
- D. W. Hart, Power Electronics, capítulo 8 (modulación unipolar).
