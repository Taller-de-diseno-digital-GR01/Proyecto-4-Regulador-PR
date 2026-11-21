# Inconsistencias encontradas investigando la corriente en 0A al habilitar

Salió de revisar por qué la corriente se cae a 0A y se enciende el LED de falla al habilitar el control con los 18V puestos. En el camino aparecieron varios desacoples entre documentos, esquemáticos y firmware que conviene cerrar antes de la próxima sesión de potencia. Avisarle a Carlos (`ccv0708`) si alguno de estos toca la simulación temporizada o el testbench.

## Ganancia del acondicionador, texto vs esquemático

[`diseño_carga_sensor.tex`](../../potencia/carga_RL-Sensor/diseño_carga_sensor.tex) (rama `doc/sensor-carga`) calcula y declara $A_v = 2{,}4$, con $R_7 = 7{,}5\text{k}\Omega$. El LTspice que Jefferson simuló ahí mismo, `circuito_acondicionador.asc`, tiene $R_1=12\text{k}\Omega$, $R_2=R_3=20\text{k}\Omega$, $R_7=15\text{k}\Omega$, que da $A_v = R_1/(R_2\|R_3) = 1{,}2$. Confirmado que el circuito real usa los valores del `.asc`, $A_v = 1{,}2$. El texto queda desactualizado, corregirlo para no confundir en la defensa.

## Sensibilidad de sensor asumida en ese cálculo

El $A_v=2{,}4$ del texto se calculó con una sensibilidad de sensor de 100 mV/A, la del ACS712 de ±20A. El sensor que realmente se usa es el de ±5A (185 mV/A de hoja de datos, 183 mV/A medido). El cálculo de ganancia del texto nunca correspondió al sensor instalado, aunque quedó sin efecto práctico porque el circuito real tampoco siguió ese cálculo (ver arriba).

## Carga RL de diseño del PR vs carga RL candidata de Jefferson

[`pr_discreto.md`](modulos/pr_discreto.md) fija $K_p = 188{,}88$ V/A y $K_r = 3000$ para la carga de 12 Ω y 30 mH, y la planta simulada (`PLANTA_SIMULADA` en `sw/lazo_control.c`) usa esos mismos 12 Ω y 30 mH. El punto de diseño candidato de `diseño_carga_sensor.tex` es $R=10\ \Omega$, $L=2$ mH, quince veces menos inductancia que la asumida por el PR. Falta confirmar cuál es la carga realmente armada en el banco ahora. Si es la de 2 mH el PR nunca se validó contra esa dinámica, y eso explica mejor la sobrecorriente al habilitar que cualquier problema del sensor.

Confirmado con Mattio, la carga del banco es de unos 12,5 Ω y 30 mH. Queda cerca de lo que ya asume el PR, no hace falta rehacer el Bode ni resintonizar `Kp`/`Kr`.

## Ganancia asumida en firmware vs ganancia real confirmada

`sw/lazo_control.h` asume 0,3 V/A y 0,5V de offset a la entrada del ADC (`ADC_AMPERES_POR_CUENTA`, `ADC_OFFSET_CUENTAS`, ya marcados "provisional" en el propio código, y el mismo pendiente que [`pruebas_integracion.md`](../pruebas_integracion.md) deja anotado). Con $A_v=1{,}2$ confirmado y el sensor de 183 mV/A, la ganancia real a la entrada del ADC es de unos 0,22 V/A, no 0,3 V/A. El offset sí coincide, 0,5V. Hay que recalcular esa constante, y de paso `UMBRAL_SOBRECORRIENTE` en `supervisor_falla.h`, para que reflejen la ganancia real.

`ADC_AMPERES_POR_CUENTA` ya quedó corregida a 1,1118e-3 (ganancia real de 0,2196 V/A). `UMBRAL_SOBRECORRIENTE` no necesitaba tocarse, está en amperios físicos y no depende de esa constante.

## Carga nueva de 9 Ω y 200 µH (2026-11-19)

El transformador de 30 mH se cambió por dos inductores de 100 µH en serie, con unos 0,5 Ω cada uno, y la resistencia de 8 Ω sigue. El PR se resintonizó en [`potencia/diseno_pr.md`](../../potencia/diseno_pr.md), con `Kp = 4,5` y `Kr = 10000`, y `pr_params.h`, `PLANTA_SIMULADA` y los docs de `pr_discreto`, `lazo_control`, `supervisor_falla` y `control_principal` ya están al día. Quedan abiertos dos puntos.

- Sin resolver. El rizado de conmutación no cumple los 0,20 A pp del enunciado a 20 kHz con ninguna `Vdc` del rango. Con 18 V da 0,41 A pp a 0,5 A y 0,55 A pp a 1,0 A, y con 12 V 0,34 y 0,37 A. Para cumplir hace falta `L` de al menos 0,56 mH con 18 V (0,38 mH con 12 V), o el puente a 40 kHz con 12 V, que hoy el firmware no permite con el lazo cerrado. Lo decide el equipo, el detalle está en la sección de rizado de `diseno_pr.md`.
- Sin resolver. [`potencia/diseno_puente_h.md`](../../potencia/diseno_puente_h.md), de Nicolás, sigue con las cifras del transformador (τ de 2,5 ms, techo de falla de 1,38 y 1,84 A, 6 W en la carga, 51 mJ devueltos al bus), y la copia de su sección de protecciones en [`diseño.md`](../diseño.md) también. Con 200 µH la τ es de 22 µs, la corriente llega al techo dentro de los 100 µs del apagado, y el techo sube a 1,84 A con 18 V y 2,45 A con 24 V porque la `R` bajó a 9 Ω. Sigue lejos de los 6,8 A del IRF520N a 100 °C, y la energía devuelta baja a menos de 1 mJ.

