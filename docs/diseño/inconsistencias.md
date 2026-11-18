# Inconsistencias encontradas investigando la corriente en 0A al habilitar

Salió de revisar por qué la corriente se cae a 0A y se enciende el LED de falla al habilitar el control con los 18V puestos. En el camino aparecieron varios desacoples entre documentos, esquemáticos y firmware que conviene cerrar antes de la próxima sesión de potencia. Avisarle a Carlos (`ccv0708`) si alguno de estos toca la simulación temporizada o el testbench.

## Ganancia del acondicionador, texto vs esquemático

[`diseño_carga_sensor.tex`](../../potencia/carga_RL-Sensor/diseño_carga_sensor.tex) (rama `doc/sensor-carga`) calcula y declara $A_v = 2{,}4$, con $R_7 = 7{,}5\text{k}\Omega$. El LTspice que Jefferson simuló ahí mismo, `circuito_acondicionador.asc`, tiene $R_1=12\text{k}\Omega$, $R_2=R_3=20\text{k}\Omega$, $R_7=15\text{k}\Omega$, que da $A_v = R_1/(R_2\|R_3) = 1{,}2$. Confirmado que el circuito real usa los valores del `.asc`, $A_v = 1{,}2$. El texto queda desactualizado, corregirlo para no confundir en la defensa.

## Sensibilidad de sensor asumida en ese cálculo

El $A_v=2{,}4$ del texto se calculó con una sensibilidad de sensor de 100 mV/A, la del ACS712 de ±20A. El sensor que realmente se usa es el de ±5A (185 mV/A de hoja de datos, 183 mV/A medido). El cálculo de ganancia del texto nunca correspondió al sensor instalado, aunque quedó sin efecto práctico porque el circuito real tampoco siguió ese cálculo (ver arriba).

## Carga RL de diseño del PR vs carga RL candidata de Jefferson

[`pr_discreto.md`](modulos/pr_discreto.md) fija $K_p = 188{,}88$ V/A y $K_r = 3000$ para la carga de 12 Ω y 30 mH, y la planta simulada (`PLANTA_SIMULADA` en `sw/lazo_control.c`) usa esos mismos 12 Ω y 30 mH. El punto de diseño candidato de `diseño_carga_sensor.tex` es $R=10\ \Omega$, $L=2$ mH, quince veces menos inductancia que la asumida por el PR. Falta confirmar cuál es la carga realmente armada en el banco ahora. Si es la de 2 mH el PR nunca se validó contra esa dinámica, y eso explica mejor la sobrecorriente al habilitar que cualquier problema del sensor.

Confirmado con Mattio, la carga del banco es de unos 12,5 Ω y 30 mH. Queda cerca de lo que ya asume el PR, con 12,5 Ω el margen nominal pasa de 66,5° a 66,7° (`potencia/verificar_pr.m`), así que no hace falta rehacer el Bode ni resintonizar `Kp`/`Kr`. Eso vale solo si `pr_params.h` está generado con un `Vdc` igual o mayor al del bus, ver la sección de `Vdc` más abajo.

## Ganancia asumida en firmware vs ganancia real confirmada

`sw/lazo_control.h` asume 0,3 V/A y 0,5V de offset a la entrada del ADC (`ADC_AMPERES_POR_CUENTA`, `ADC_OFFSET_CUENTAS`, ya marcados "provisional" en el propio código, y el mismo pendiente que [`pruebas_integracion.md`](../pruebas_integracion.md) deja anotado). Con $A_v=1{,}2$ confirmado y el sensor de 183 mV/A, la ganancia real a la entrada del ADC es de unos 0,22 V/A, no 0,3 V/A. El offset sí coincide, 0,5V. Hay que recalcular esa constante para que refleje la ganancia real.

`ADC_AMPERES_POR_CUENTA` ya quedó corregida a 1,1118e-3 (ganancia real de 0,2196 V/A). `UMBRAL_SOBRECORRIENTE` no necesitaba tocarse, está en amperios físicos y no depende de esa constante.

## Vdc con que se generan los coeficientes del PR

`sw/generar_pr_params.m` mete el $1/V_{dc}$ dentro de `PR_KP` y `PR_B0`, y el bus real lo vuelve a multiplicar en el puente. La ganancia del lazo en el banco es entonces la de diseño por $V_{dc,bus}/V_{dc,generado}$. `pr_params.h` estaba generado con 18 V. Si la prueba de 1,0 A se corre a 24 V con ese header, `Kp` y `Kr` efectivos suben a 251,8 V/A y 4000, y en la esquina de $L$ baja el lazo queda con 40,5° y 5,0 dB, debajo del criterio de 45° y 6 dB. Con el filtro antialias RC de 2 kHz (#29) baja a 14,3° y 2,3 dB, casi oscilando.

Se regeneró `pr_params.h` con 24 V, el máximo del enunciado, así que ahora el bus solo puede bajar la ganancia. Con 24 V quedan los márgenes de diseño, 66,5° y 10,5 dB. Con 18 V el cruce baja a 749 Hz con 74,4° y 13,0 dB, la esquina con el RC de 2 kHz mejora a 42,1° y 7,3 dB, y el escalón de 0,2 a 1,0 A empieza en 7,0 % el primer período. Con 12 V queda en 83,6° nominal, pero ahí no se corre 1,0 A. Las cifras salen de `potencia/verificar_pr.m` y el detalle está en [`pr_discreto.md`](modulos/pr_discreto.md), h.3.

## Causa de la falla al habilitar, sigue abierta

Ninguna de las inconsistencias de arriba explica la corriente en 0 A con el LED de falla. La carga de 2 mH quedó descartada porque el banco tiene 30 mH. La ganancia vieja del firmware tampoco alcanza. Con 8,138e-4 A por cuenta el software leía el 73 % de la corriente real, entonces el lazo llevaba la corriente a 1,37 veces la referencia y el umbral de 1,3 A equivalía a 1,78 A reales. Con eso la falla salta más tarde que con la ganancia correcta.

La corriente en 0 A con el LED encendido es lo que deja el supervisor después de disparar, así que el dato que falta es cuál de sus tres condiciones disparó (`supervisor_falla.c`).

- Sobrecorriente, más de 1,3 A medidos. Con el signo del sensor invertido el lazo realimenta positivo, satura y llega al umbral en pocos períodos.
- Cuenta del ADC fuera de `CUENTA_ADC_MIN` y `CUENTA_ADC_MAX`, por ejemplo con la entrada del XADC sin el offset de 0,5 V.
- Más de `ITERACIONES_SIN_DATO_MAX` iteraciones sin dato nuevo del XADC, que apunta al trigger o a la envoltura (#35).

El ensayo de lazo abierto de la guía de mediciones (D1) revisa el signo y el cero antes de cerrar el lazo, y es lo primero que hay que correr en la próxima sesión.
