# Reparto del trabajo del Proyecto 4

Este proyecto vale para dos cursos a la vez. EL3313 Taller de Diseño Digital pone la plataforma digital (MicroBlaze V, periférico PWM, ADC, UART, software en C) y EL4201 PEDP pone la etapa de potencia, la carga RL y el diseño del regulador PR. Los profesores de ambos cursos se conocen y coordinaron el enunciado, así que las dudas de interfaz entre las dos mitades se pueden llevar a los dos al mismo tiempo.

Cada tarea de abajo lleva una etiqueta.

- Digitales, cae en la nota de Taller.
- Potencia, cae en la nota de PEDP.
- Conjunto, la tienen que resolver juntas las dos mitades y por eso se anota en las dos partes.

Los nombres de las personas se asignan después. Mientras tanto son Persona A, B, C y D.

## En una oración por persona

- A diseña el PWM en SystemVerilog (portadora, tiempo muerto, trigger) y arma el puente H con sus drivers y protecciones.
- B escribe la interfaz AXI4-Lite con su testbench y la simulación temporizada, dimensiona la carga RL, y diseña y sintoniza el PR en PLECS.
- C arma el Block Design con MicroBlaze V, periféricos y XADC, y construye el sensor de corriente con su acondicionamiento de 0 a 1 V.
- D escribe todo el software en C (ISR, buffer, UART, falla) y el script de PC, y discretiza el PR para correrlo en punto fijo o flotante.

## Cómo se pesan las dos notas

Esto condiciona el orden de trabajo.

- PEDP da hasta 80 puntos independientes del MicroBlaze. Se pueden sacar completos aunque la parte digital no termine, siempre que el PR discreto corra en lazo cerrado sobre el inversor real, incluso en una plataforma de control alternativa. Las simulaciones solas no sustituyen la demostración experimental.
- Los otros 20 puntos de PEDP son de integración conjunta, y solo se obtienen si el MicroBlaze mueve el inversor de verdad.
- En Taller, la presentación funcional pesa 60 % y se reparte en sistema base MicroBlaze V (15 %), periférico PWM (20 %), ADC y sincronización (15 %), integración con potencia y PR (15 %), UART y simulación autoverificable (15 %) y defensa (20 %).

La consecuencia práctica es que la parte de potencia no debe quedar esperando al MicroBlaze. Conviene tener el inversor probado con alguna fuente de PWM provisional (la que PEDP elija) antes de que el periférico propio esté listo, y el PR validado en PLECS desde el principio. Así, si la parte digital se atrasa, los 80 puntos de PEDP siguen a salvo.

## Reglas de parejas

Cada persona tiene una tarea digital y una de potencia, elegidas para que se toquen entre sí. Así nadie es solo digital o solo potencia, y en la defensa todos pueden hablar de la interfaz entre las dos mitades.

- Persona A. Núcleo del PWM (digitales) con puente H y drivers (potencia). Ambos comparten el tiempo muerto.
- Persona B. Interfaz AXI4-Lite y verificación del PWM (digitales) con carga RL, modelo, PLECS y diseño del PR (potencia).
- Persona C. Block Design y XADC (digitales) con sensor de corriente y acondicionamiento (potencia). Ambos comparten el rango de 0 a 1 V.
- Persona D. Software en C, UART y script de PC (digitales) con la discretización del PR (potencia). Ambos comparten la ecuación en diferencias que corre en la ISR.

Revisión cruzada de pull requests, A con B y C con D, y los pares se rotan cuando haga falta para que más de una persona entienda cada módulo.

## Persona A

### Digitales, núcleo del periférico PWM

Es el módulo con más peso del proyecto (20 % de la presentación funcional) y el único obligatorio en SystemVerilog. A se encarga de la lógica de generación, B de la interfaz AXI que lo envuelve. Se sugiere separarlo en dos archivos desde el inicio para que cada uno trabaje en su rama sin pisarse.

- Portadora triangular (contador ascendente y descendente) cuyo valor máximo sale de `freq_sel`. Al menos tres frecuencias válidas, y hay que decidir qué hace el cuarto código (otra frecuencia, o reservado que satura a una de las tres).
- Dos comparadores contra la misma portadora, uno con `duty_ref` y otro con `-duty_ref`. Esa es la modulación unipolar, cada pierna del puente compara contra su referencia.
- Cuatro señales de compuerta, dos por pierna, cada par complementario con tiempo muerto configurable. El tiempo muerto no puede dejar glitches ni solapamiento en ningún caso, ni siquiera al apagar `enable` a medio período.
- Actualización de `duty_ref` solo en el pico o el valle de la portadora, para que un cambio a medio período no genere pulsos raros. Hace falta un registro sombra entre el valor que escribe el software y el que ve el comparador.
- Saturación de `duty_ref` fuera de rango, con el rango admisible definido por el máximo de la portadora a cada frecuencia.
- `running` y `enable` con semántica distinta. Propuesta, `running` sube al empezar el primer período completo tras `enable` y baja al terminar el período en curso, para no cortar un pulso a medias.
- Salida `pwm_trigger_o` hacia el ADC, ubicada en el centro de los pulsos (pico o valle de la portadora) para no muestrear el rizado de conmutación. Debe funcionar igual con las tres frecuencias.
- Documento en `docs/diseño/modulos/` del núcleo PWM, con diagrama de estados y la tabla de temporización.

### Potencia, puente H y accionamiento de compuertas

Es la parte física que recibe las cuatro señales de A. Por eso va en la misma persona.

- Elegir los semiconductores (MOSFET) según Vdc de 12 a 24 V y la corriente pico de 1,0 A más el rizado, y justificar la elección con las pérdidas de conducción y de conmutación estimadas de forma simplificada.
- Elegir y justificar el driver de compuertas (bootstrap o aislado), incluyendo el nivel lógico, porque las salidas de la Basys3 son de 3,3 V. Hay que revisar que el driver acepte ese nivel o agregar una etapa.
- Justificar el tiempo muerto mínimo que necesita el par MOSFET y driver elegido, a partir de las hojas de datos (tiempos de encendido y apagado). Este valor es la entrada principal del registro de tiempo muerto.
- Dibujar el circuito del inversor, identificar los estados de conmutación y explicar los caminos de corriente de la carga en cada uno.
- Diseñar la protección y la desconexión ante falla (límite de corriente, corte del driver), porque la rúbrica de PEDP lo pide explícito.
- Comprobar las señales de compuerta y el tiempo muerto con la potencia apagada antes de energizar. Es una condición de la demostración, se hace con osciloscopio y se documenta con capturas.
- Conjunto con B y D, definir qué hace el hardware en el arranque antes de que el software configure el PWM (las compuertas deben estar apagadas por defecto).

## Persona B

### Digitales, interfaz AXI4-Lite, empaquetado y verificación del PWM

- Escribir el esclavo AXI4-Lite completo, con los canales AW y W independientes (pueden llegar en distinto ciclo), canal B de respuesta, y lectura con AR y R. Es uno de los puntos donde más se equivocan en este tipo de proyecto.
- Mapa de registros según el enunciado. Offset `0x00` control y estado (`enable`, `freq_sel`, `running` de solo lectura), offset `0x04` `duty_ref` en los 16 bits bajos, y los bits reservados leyendo cero. Hay que definir qué pasa con escrituras a `running` o a direcciones fuera de mapa.
- Los nombres de las señales del bus siguen el estándar (`s_axi_awaddr`, `s_axi_wvalid` y así) para que Vivado infiera la interfaz al empaquetar.
- Empaquetar el periférico como IP y dejarlo listo para el Block Design de C.
- Testbench autoverificable con conteo de errores. Debe cubrir lectura y escritura de registros, saturación, complementariedad de las compuertas con el tiempo muerto, comportamiento de `running`, y el `pwm_trigger_o`. Los parámetros del DUT se reescalan a valores chicos en simulación para que corra rápido.
- Simulación post-implementación temporizada del periférico (netlist con `write_verilog -mode timesim` y `.sdf` con `write_sdf`). Es un entregable explícito de la presentación funcional.
- Propietario de los diagramas de estado del periférico y de la descripción formal de la interfaz que pide el informe.

### Potencia, carga RL, modelo, PLECS y diseño del PR

- Dimensionar R y L de la carga para alcanzar 0,2, 0,5 y 1,0 A pico a 50 Hz con la tensión disponible. La tensión pico necesaria es la corriente pico por el módulo de la impedancia R más jωL, y tiene que caber en Vdc con margen para que el control no sature.
- Verificar la disipación. Con una referencia sinusoidal de 1,0 A pico circula una corriente eficaz de unos 0,71 A, o sea que la potencia en R es aproximadamente R por 0,5 W. Con resistencias de 5 W hay que dejar margen, el enunciado lo exige para el punto de 1,0 A. Hay que diseñar también para el ensayo de cambio de R de al menos 25 %, que debe ser realizable dentro de los límites térmicos.
- Caracterizar la inductancia y la resistencia total (incluido el devanado) bajo condiciones representativas de operación, y comprobar que no sature. Si se usa un devanado de transformador, justificar la configuración y el estado del otro devanado.
- Obtener el modelo dinámico de la carga RL y la función de transferencia entre tensión aplicada y corriente, y relacionar el `duty_ref` con la tensión promedio sobre la carga.
- Construir el modelo del inversor en PLECS y contrastarlo con el análisis teórico.
- Estimar el rizado de conmutación en cada punto de operación. En PWM unipolar la tensión diferencial de salida tiene componentes al doble de la frecuencia de cada transistor, y el enunciado pide no confundirlas.
- Seleccionar la frecuencia de conmutación (rizado menor a 0,20 A pico a pico, pérdidas, capacidad del driver y resolución del PWM). De ahí sale el valor máximo de portadora de A.
- Seleccionar y justificar la estructura del PR. Una forma habitual es un proporcional más un término resonante a 50 Hz, ideal o con amortiguamiento para hacerlo menos sensible a la desviación de frecuencia. Hay que investigar las dos y quedarse con una.
- Establecer un procedimiento de diseño y de sintonización con criterios explícitos (márgenes de estabilidad, ancho de banda, seguimiento de la referencia de 50 Hz) y justificar las ganancias elegidas.
- Analizar la estabilidad y el efecto del muestreo y de los retardos sobre el lazo. Hay que contar el retardo del cómputo, el de la actualización del PWM, el del filtro antialias que diseña C, y el del propio período de muestreo. Los retardos reales los mide D.
- Validar el controlador en PLECS sobre el modelo de la planta antes de pasarlo al MicroBlaze.
- Conjunto con D, el período de muestreo y de actualización del control, el formato de `duty_ref` y las ganancias, que B entrega a D como Kp, Kr y parámetros del resonante.

### Extra de B

B lleva el seguimiento del repositorio y de los documentos. Eso incluye vigilar issues, ramas, PRs, el README y que `docs/diseño/` y `docs/informe/` se mantengan al día.

## Persona C

### Digitales, sistema base, Block Design y XADC

- Crear el proyecto de Vivado 2025.1 con MicroBlaze V a 100 MHz, 32 KB de BRAM local, caché de instrucciones de 8 KB, master AXI4-Lite, MDM y AXI Timer. Es la Fase 1 del enunciado y el primer hito de todo el proyecto, porque desbloquea el trabajo de D.
- Usar el IP AXI UART Lite de Xilinx para el UART. El enunciado lo permite, Vitis genera su driver y no hay razón para adaptar el UART propio del Proyecto 3.
- Verificar si hace falta un AXI Interrupt Controller para el timer (y el botón, si no se lee por sondeo), porque el MicroBlaze V tiene una sola línea de interrupción y el enunciado no lo lista.
- Decidir con el equipo qué hacer con la caché de instrucciones. Con el programa en la BRAM local por LMB no cambia nada, y la Basys3 no tiene DDR. Hay que habilitarla para cumplir la letra o justificar por escrito por qué no sirve.
- Agregar AXI GPIO (botones y LEDs de habilitación y falla), controlar el Address Editor y exportar el Block Design con `write_bd_tcl` a `src/bd/`.
- Dejar la creación del proyecto en un script Tcl para que nadie tenga que rehacer clics, y entregar el `.xsa` a D para armar la plataforma en Vitis.
- Crear el XADC con el wizard (o a mano) y envolverlo en una interfaz AXI4-Lite propia. Debe permitir iniciar la conversión por software y por `pwm_trigger_o`, tener una bandera de dato nuevo, y exponer el dato al MicroBlaze. Se diseña para que el trigger sirva a las tres frecuencias.
- Constraints de la Basys3 (`basys3.xdc`), incluyendo el Pmod JXADC para la entrada analógica y los pines hacia las compuertas.
- Reportes de recursos y de timing para el informe.
- Conjunto con A, definir cuántos ciclos de reloj después del pico o valle ocurre la captura, y verificar con el osciloscopio o con una señal de depuración que el muestreo cae en el centro del pulso.

### Potencia, sensor de corriente y acondicionamiento

El XADC de la Basys3 solo acepta de 0 a 1 V unipolar y la corriente es AC. Este es el punto más delicado de la frontera entre las dos mitades.

- Elegir el método de medición (resistencia shunt con amplificador diferencial, o sensor Hall), justificar la elección y definir los límites de operación.
- Diseñar el acondicionamiento para llevar una corriente de ±1,0 A pico (más margen para el rizado y las transiciones) a un rango de 0 a 1 V con un offset de aproximadamente 0,5 V. Hay que dejar margen en ambos extremos para que ningún transitorio sature la entrada del XADC o la dañe.
- Diseñar el filtro antialias, equilibrando el atenuar el rizado de conmutación con no introducir un retardo de fase que degrade el PR. Ese retardo lo incorpora B en su análisis de estabilidad.
- Medir la ganancia y el offset reales del montaje, para que el software convierta cuentas del ADC a amperes con valores calibrados y no con los teóricos.
- Proteger la entrada del XADC (diodos o limitación) y definir la referencia de tierra común entre la etapa de potencia y la Basys3.
- Conjunto con D, entregar la constante de conversión de cuentas a amperes y el offset en cuentas, para que el PR trabaje en unidades físicas.

## Persona D

### Digitales, software de control, UART y script de PC

Casi todo el trabajo de D es C y Python y no pasa por Vivado. Lo único que necesita de ahí es el `.xsa` que exporta C, para crear la plataforma en Vitis. La lógica del PR y del buffer se puede probar en la PC con gcc, y dejar Vitis para la integración.

- Fase 3, drivers básicos en C para cada periférico (PWM, ADC, GPIO, UART, Timer) apoyándose en las funciones de lectura y escritura de registros que generan Vitis y el Address Editor.
- Fase 4, rutina de interrupción periódica ligada al AXI Timer. En cada interrupción, siempre en el mismo orden, inicia o captura la conversión, valida que haya dato nuevo, lee la corriente, calcula el PR, escribe `duty_ref` en el PWM y guarda la muestra en el buffer circular.
- Decidir si el PR corre en punto fijo o en punto flotante. Depende de si se habilita la FPU en el MicroBlaze V y de si el cálculo cabe en el período de muestreo. Con un período de decenas de microsegundos a 100 MHz hay miles de ciclos por interrupción, pero hay que medir en vez de suponer. Si es punto fijo, hay que cuidar el formato de los coeficientes y los estados del resonante, que se acumulan y pueden saturar.
- Buffer circular en la BRAM. Comparte los 32 KB con el programa, así que su tamaño sale de lo que sobre, y D tiene que reportar cuánto cabe. Cada registro guarda la corriente, `duty_ref` y un contador de saturaciones, no solo la corriente, para poder separar lo que pide el controlador de lo que hace la planta.
- Exportación por UART al presionar el botón. La transmisión va en el lazo principal, nunca dentro de la ISR, y no debe corromper el buffer mientras la ISR sigue escribiendo en él (por ejemplo, congelar una copia del índice de escritura al empezar la exportación).
- Medición del período efectivo y del jitter del lazo. La técnica propuesta es un GPIO que sube al entrar a la ISR y baja al salir, visto en el osciloscopio. Entra en la sección 6 del enunciado como precisión temporal. Los retardos medidos se entregan a B para el análisis de estabilidad.
- Script de PC que recibe las muestras por el puerto serial y las grafica fuera de línea. Se parte de `enlace.py` del Proyecto 3 (detección de la Basys3 por el FT2232 con pyserial), cambiando el envío por lectura, y se agrega el parseo y la gráfica. Falta decidir dónde vive.
- Lógica de falla en software. Si la corriente supera un umbral configurable, la ISR baja `enable`, enciende el LED de falla y deja el sistema en un estado seguro. Se coordina con la desconexión por hardware que diseña A.
- Puede arrancar antes de tener el hardware, probando la lógica del PR y del buffer en el PC o contra un modelo de la planta, mientras C termina el Block Design.

### Potencia, discretización del PR

D recibe de B la estructura del PR y sus ganancias, y las lleva a algo que corra en el MicroBlaze.

- Elegir el método de discretización (Tustin con o sin precorrección en 50 Hz, ZOH, y otros) y obtener la ecuación en diferencias que implementará la ISR.
- Definir el formato de los coeficientes y los estados, las cotas de saturación y el anti-windup.
- Acordar con A y B el formato de `duty_ref` (por ejemplo Qn.m con signo) y el rango admisible, para que lo que el PR calcula no se sature de forma inesperada en el periférico.

### Mecanismos para el ida y vuelta con B

La sintonización con la planta real genera iteraciones entre B y D. Para que cada ajuste no sea una negociación se acuerda lo siguiente.

- Un script en Python, de D, que recibe Kp, Kr, la frecuencia de muestreo y el método de discretización, y genera un `pr_params.h` con los coeficientes ya en el formato correcto. B cambia dos números, corre el script y recompila. Cambiar las ganancias por UART en caliente queda como mejora si sobra tiempo.
- Un modelo de referencia del controlador discreto, con la misma aritmética del MicroBlaze, corriendo en Python o en C con gcc contra un modelo de la planta. Con vectores de prueba, D comprueba que la ISR da la misma salida que el modelo. Si después falla en hardware, ya se descartó el código del PR como sospechoso.
- Las primeras pruebas energizadas las hacen B y D juntos, en el mismo lugar y en orden. Primero lazo abierto con un duty sinusoidal fijo, para ver la planta sola, luego solo la parte proporcional, y recién entonces se enciende el resonante.

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

- Primero los acuerdos con PEDP y el Block Design base de C (Fase 1). Mientras tanto A y B escriben en papel el mapa de registros y los diagramas del PWM, B arranca el modelo de la planta y la estructura del PR, y D prepara la estructura del software y el modelo de referencia en la PC.
- Después el periférico PWM con su testbench (A y B), el XADC (C) y el diseño de la etapa de potencia, la carga y el sensor (A, B y C en sus partes de potencia). Esta es la Fase 2.
- Luego la integración al Block Design, los drivers y el lazo de control (Fase 3 y 4, con D al frente), probando antes cada pieza sola y recién al final con el inversor energizado.
- Al final la validación, los ensayos de la sección 4.3, la medición de jitter y el informe (Fase 5).

## Decisiones abiertas

- Confirmar nombres de las personas A a D, y quiénes en el equipo son de PEDP si es que el equipo de Taller y el de PEDP no son el mismo.
- Fechas de planteamiento y de entrega, y si el planteamiento debe estar aprobado antes de la presentación funcional.
- Caché de instrucciones, habilitarla o justificarla por escrito.
- Controlador de interrupciones, si hace falta en el Block Design.
- Cuarto código de `freq_sel`.
- Punto fijo o punto flotante para el PR.
- Dónde vive el script de PC, y qué queda en `make` (probablemente solo la simulación del PWM con iverilog) y qué se corre desde Vivado en batch.
- Plataforma alternativa de control para el respaldo de PEDP, por si la parte digital se atrasa.
