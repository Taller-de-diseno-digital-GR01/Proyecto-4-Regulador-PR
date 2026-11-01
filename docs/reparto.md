# Reparto del trabajo del Proyecto 4

Este proyecto vale para dos cursos a la vez. EL3313 Taller de Diseño Digital pone la plataforma digital (MicroBlaze V, periférico PWM, ADC, UART, software en C) y EL4201 PEDP pone la etapa de potencia, la carga RL y el diseño del regulador PR. Los profesores de ambos cursos se conocen y coordinaron el enunciado, así que las dudas de interfaz entre las dos mitades se pueden llevar a los dos al mismo tiempo.

Cada tarea de abajo lleva una etiqueta.

- Digitales, cae en la nota de Taller.
- Potencia, cae en la nota de PEDP.
- Conjunto, la tienen que resolver juntas las dos mitades y por eso se anota en las dos partes.

Los nombres de las personas se asignan después. Mientras tanto son Persona A, B, C y D en la parte digital, y P1, P2 y P3 en la de potencia.

## En una oración por persona

- A diseña en SystemVerilog el núcleo del PWM (portadora, tiempo muerto, trigger) y la envoltura del XADC, y hace la simulación temporizada del PWM.
- B escribe la interfaz AXI4-Lite del PWM con su testbench y la empaqueta como IP.
- C arma el Block Design con MicroBlaze V y periféricos, e integra los IP de PWM y XADC.
- D escribe todo el software en C (ISR, buffer, UART, falla) y el script de PC, y lleva el repositorio.
- P1 construye el puente H con sus drivers y protecciones.
- P2 arma la carga RL y la instrumentación de corriente.
- P3 modela la planta y diseña, discretiza y valida el PR.

## Cómo se pesan las dos notas

Esto condiciona el orden de trabajo.

- PEDP da hasta 80 puntos independientes del MicroBlaze. Se pueden sacar completos aunque la parte digital no termine, siempre que el PR discreto corra en lazo cerrado sobre el inversor real, incluso en una plataforma de control alternativa. Las simulaciones solas no sustituyen la demostración experimental.
- Los otros 20 puntos de PEDP son de integración conjunta, y solo se obtienen si el MicroBlaze mueve el inversor de verdad.
- En Taller, la presentación funcional pesa 60 % y se reparte en sistema base MicroBlaze V (15 %), periférico PWM (20 %), ADC y sincronización (15 %), integración con potencia y PR (15 %), UART y simulación autoverificable (15 %) y defensa (20 %).

La consecuencia práctica es que la parte de potencia no debe quedar esperando al MicroBlaze. Conviene tener el inversor probado con alguna fuente de PWM provisional (la que PEDP elija) antes de que el periférico propio esté listo, y el PR validado en PLECS desde el principio. Así, si la parte digital se atrasa, los 80 puntos de PEDP siguen a salvo.

## Revisión cruzada

Revisión cruzada de pull requests, A con C y B con D, y los pares se rotan cuando haga falta para que más de una persona entienda cada módulo.

## Persona A

### Digitales, núcleo del PWM y envoltura del XADC

- Núcleo del PWM en SystemVerilog: portadora, comparadores con `duty_ref` y `-duty_ref`, cuatro compuertas con tiempo muerto sin glitches, registro sombra con actualización en pico o valle, saturación, `running` y `pwm_trigger_o` en el pico o valle de la portadora.
- Envoltura AXI4-Lite del XADC: inicio por software y por `pwm_trigger_o`, bandera de dato listo y registro de dato.
- Simulación post-implementación temporizada del PWM.
- Documento del módulo y diagrama de estados.

## Persona B

### Digitales, interfaz AXI4-Lite y testbench del PWM

- Esclavo AXI4-Lite del PWM, mapa de registros y empaquetado como IP.
- Testbench autoverificable del PWM.

## Persona C

### Digitales, sistema base y Block Design

- Block Design con MicroBlaze V, Timer, UART Lite y GPIO. Integra los IP de PWM y XADC.
- Constraints de la Basys3, reportes de recursos y timing, `write_bd_tcl` en `src/bd/` y el `.xsa` para D.
- Decidir si hace falta el controlador de interrupciones y qué hacer con la caché de 8 KB.

## Persona D

### Digitales, software de control, UART y script de PC

- Drivers, ISR determinista, buffer circular con corriente, `duty_ref` y contador de saturaciones.
- Exportación por UART con el botón, lógica de falla por sobrecorriente y medición de jitter y latencia.
- Script de PC a partir de `enlace.py`, con el método de medición del error fundamental (al menos 5 períodos) y la separación del rizado.
- Plataforma en Vitis con el `.xsa` de C, y pruebas en la PC con gcc.
- Gestión del repo, issues, README y documentos.

## Potencia

En potencia somos tres, así que el reparto es aparte del digital.

| Rol | Carga | Comentario |
|---|---|---|
| P1 – Puente H | Media-alta | Construcción pesada al inicio. Después de validar compuertas, su carga baja. |
| P2 – Carga e instrumentación | Alta | Tiene la carga RL, el sensor, el acondicionamiento, la calibración y el script de análisis. Son dos subsistemas físicos más el procesamiento de datos. |
| P3 – Modelado y control | Media-alta | Es trabajo de escritorio y pesa mucho en las rúbricas, pero está bien acotado. |

### P1 – Puente H

- Puente H con MOSFET y drivers, compatible con los 3,3 V de la Basys3.
- Tiempo muerto según las hojas de datos. Entrega el valor a A.
- Protecciones, desconexión ante falla y revisión de compuertas con la potencia apagada.
- Pérdidas de conducción y de conmutación estimadas de forma simplificada, para justificar los MOSFET.
- Circuito del inversor, estados de conmutación y caminos de corriente de la carga en cada uno.
- Conjunto con A, compuertas apagadas por defecto en el arranque, antes de que el software configure el PWM.
- Selección de f_sw con sus pérdidas, la capacidad del driver, el rizado de P2 y la estabilidad que revisa P3. De ahí salen los valores de `MAX` de A.

### P2 – Carga e instrumentación

- Sensor de corriente, acondicionamiento a 0–1 V con offset, filtro antialias y protección de la entrada del XADC.
- Calibración real de ganancia y offset. Entrega `calib.h` a D.
- Dimensionamiento y caracterización de la carga RL: disipación, saturación, margen a 1,0 A pico, cambio de R de 25 %. Incluye el cálculo del rizado frente a f_sw.
- Comparar lo que mide el XADC contra la sonda del osciloscopio.
- Tierra común entre la etapa de potencia y la Basys3.

### P3 – Modelado y control

- Modelo dinámico de la carga y modelo en PLECS.
- Estructura del PR, sintonización, análisis de estabilidad con los retardos reales y validación en PLECS.
- Criterios del plan de validación.
- Discretización del PR, ecuación en diferencias, formato de coeficientes, saturación y anti-windup.
- Script que genera `pr_params.h`, modelo de referencia con la misma aritmética y vectores de prueba.
- Recibe de D el jitter y la latencia reales.

### Ida y vuelta entre P3 y D

La sintonización con la planta real genera iteraciones entre P3 y D. Para que cada ajuste no sea una negociación se acuerda lo siguiente.

- El script de P3 recibe Kp, Kr, la frecuencia de muestreo y el método de discretización, y genera un `pr_params.h` con los coeficientes ya en el formato correcto. P3 cambia dos números, corre el script y recompila. Cambiar las ganancias por UART en caliente queda como mejora si sobra tiempo.
- El modelo de referencia del controlador discreto usa la misma aritmética del MicroBlaze y corre en Python o en C con gcc contra un modelo de la planta. Con vectores de prueba se comprueba que la ISR de D da la misma salida que el modelo. Si después falla en hardware, ya se descartó el código del PR como sospechoso.
- Las primeras pruebas energizadas las hacen P3 y D juntos, en el mismo lugar y en orden. Primero lazo abierto con un duty sinusoidal fijo, para ver la planta sola, luego solo la parte proporcional, y recién entonces se enciende el resonante.

## Trabajo de todos

- Acordar con PEDP, lo antes posible, los cuatro parámetros que bloquean el diseño del PWM y del ADC.
  - Frecuencia de conmutación y las que se soportan en `freq_sel`.
  - Período de muestreo y de actualización del control.
  - Formato de `duty_ref`.
  - Acondicionamiento del sensor (rango, offset y filtro).
- Diseño en `docs/diseño/`. Cada persona escribe el `.md` de su módulo en `docs/diseño/modulos/`, y los diagramas de nivel van en `docs/diseño/diagramas/`. La parte de potencia tiene que reflejarse también en el documento de diseño de PEDP, con dimensionamiento del puente H, caracterización de la inductancia, elección de componentes, modelo RL, frecuencia de conmutación, metodología del PR, análisis de estabilidad y plan de pruebas.
- Una sola fuente de verdad por módulo, para no repetir el problema del Proyecto 1 donde dos documentos divergieron.
- Issues por integrante y rama de feature para cada pieza, con PR revisado por otra persona antes de entrar a `main`. En el repositorio pesan igual commits, ramas, issues, PRs y README.
- Ensayos finales, repartidos entre todos con una persona operando y otra tomando datos.
  - Seguimiento de 0,2, 0,5 y 1,0 A pico a 50 Hz.
  - Cambio de amplitud de 0,2 a 0,5 y de 0,5 a 1,0 A.
  - Cambio de la resistencia de carga en al menos 25 % con 0,5 A pico.
  - Para cada uno, referencia, corriente medida, tensión sobre la carga y evidencia de las señales PWM, distinguiendo pico y RMS.
  - Error de la fundamental menor a 10 % en una ventana de cinco períodos como mínimo, y rizado menor a 0,20 A pico a pico, informados por separado y con el método de extracción de la fundamental descrito.

## Orden sugerido

Sin fechas, porque el enunciado no las trae. Se puede mapear a las fases de la sección 5.1.

- Primero los acuerdos con PEDP y el Block Design base de C (Fase 1). Mientras tanto A y B escriben en papel el mapa de registros y los diagramas del PWM, P3 arranca el modelo de la planta, la estructura del PR y el modelo de referencia en la PC, y D prepara la estructura del software.
- Después el periférico PWM con su testbench (A y B), el XADC (A) y el diseño de la etapa de potencia, la carga y el sensor (P1, P2 y P3). Esta es la Fase 2.
- Luego la integración al Block Design, los drivers y el lazo de control (Fase 3 y 4, con D al frente), probando antes cada pieza sola y recién al final con el inversor energizado.
- Al final la validación, los ensayos de la sección 4.3, la medición de jitter y el informe (Fase 5).

## Decisiones abiertas

- Confirmar nombres de las personas A a D y de P1 a P3, y quiénes en el equipo son de PEDP si es que el equipo de Taller y el de PEDP no son el mismo.
- Fechas de planteamiento y de entrega, y si el planteamiento debe estar aprobado antes de la presentación funcional.
- Caché de instrucciones, habilitarla o justificarla por escrito.
- Controlador de interrupciones, si hace falta en el Block Design.
- Cuarto código de `freq_sel`.
- Punto fijo o punto flotante para el PR.
- Dónde vive el script de PC, y qué queda en `make` (probablemente solo la simulación del PWM con iverilog) y qué se corre desde Vivado en batch.
- Plataforma alternativa de control para el respaldo de PEDP, por si la parte digital se atrasa.
