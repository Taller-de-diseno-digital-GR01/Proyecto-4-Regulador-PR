# Inconsistencias encontradas investigando la corriente en 0A al habilitar

Salió de revisar por qué la corriente se cae a 0A y se enciende el LED de falla al habilitar el control con los 18V puestos. En el camino aparecieron varios desacoples entre documentos, esquemáticos y firmware que conviene cerrar antes de la próxima sesión de potencia. Avisarle a Carlos (`ccv0708`) si alguno de estos toca la simulación temporizada o el testbench.

## Ganancia del acondicionador, texto vs esquemático

[`diseño_carga_sensor.tex`](../../potencia/carga_RL-Sensor/diseño_carga_sensor.tex) (rama `doc/sensor-carga`) calcula y declara $A_v = 2{,}4$, con $R_7 = 7{,}5\text{k}\Omega$. El LTspice que Jefferson simuló ahí mismo, `circuito_acondicionador.asc`, tiene $R_1=12\text{k}\Omega$, $R_2=R_3=20\text{k}\Omega$, $R_7=15\text{k}\Omega$, que da $A_v = R_1/(R_2\|R_3) = 1{,}2$. Confirmado que el circuito real usa los valores del `.asc`, $A_v = 1{,}2$. El texto queda desactualizado, corregirlo para no confundir en la defensa.

## Sensibilidad de sensor asumida en ese cálculo

El $A_v=2{,}4$ del texto se calculó con una sensibilidad de sensor de 100 mV/A, la del ACS712 de ±20A. El sensor que realmente se usa es el de ±5A (185 mV/A de hoja de datos, 183 mV/A medido). El cálculo de ganancia del texto nunca correspondió al sensor instalado, aunque quedó sin efecto práctico porque el circuito real tampoco siguió ese cálculo (ver arriba).

## Carga RL de diseño del PR vs carga RL candidata de Jefferson

[`pr_discreto.md`](modulos/pr_discreto.md) fija $K_p = 188{,}88$ V/A y $K_r = 3000$ para la carga de 12 Ω y 30 mH, y la planta simulada (`PLANTA_SIMULADA` en `sw/lazo_control.c`) usa esos mismos 12 Ω y 30 mH. El punto de diseño candidato de `diseño_carga_sensor.tex` es $R=10\ \Omega$, $L=2$ mH, quince veces menos inductancia que la asumida por el PR. Falta confirmar cuál es la carga realmente armada en el banco ahora. Si es la de 2 mH el PR nunca se validó contra esa dinámica, y eso explica mejor la sobrecorriente al habilitar que cualquier problema del sensor.

## Ganancia asumida en firmware vs ganancia real confirmada

`sw/lazo_control.h` asume 0,3 V/A y 0,5V de offset a la entrada del ADC (`ADC_AMPERES_POR_CUENTA`, `ADC_OFFSET_CUENTAS`, ya marcados "provisional" en el propio código, y el mismo pendiente que [`pruebas_integracion.md`](../pruebas_integracion.md) deja anotado). Con $A_v=1{,}2$ confirmado y el sensor de 183 mV/A, la ganancia real a la entrada del ADC es de unos 0,22 V/A, no 0,3 V/A. El offset sí coincide, 0,5V. Hay que recalcular esa constante, y de paso `UMBRAL_SOBRECORRIENTE` en `supervisor_falla.h`, para que reflejen la ganancia real.
