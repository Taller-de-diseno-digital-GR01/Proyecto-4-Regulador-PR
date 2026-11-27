# Proyecto 4, Control de corriente en un inversor monofásico con regulador PR sobre MicroBlaze V

EL3313 Taller de Diseño Digital y EL4201 Procesamiento Electrónico de Potencia.

Profesores:
- Dr.-Ing. Jeferson González-Gómez
- PhD. Yeiner Arias-Esquivel
- Ing. Rolen Coto Calderón

Integrantes:
- Carlos Castro Villegas
- Jefferson Chinchilla Quesada
- Mattio Coghi Quirós
- Nicolás Mena Valerio

II Semestre 2026

## Propósito

Sistema de control de corriente para un inversor monofásico en puente H con carga RL. Un
MicroBlaze V, implementado en la Artix-7 de una Basys 3, ejecuta en C un regulador
proporcional-resonante discreto para seguir referencias senoidales de 50 Hz y amplitudes de
0,2, 0,5 y 1,0 A pico.

El procesador se comunica por AXI4-Lite con un periférico PWM propio en SystemVerilog, una
envoltura propia del XADC y las IP de Timer, UART y GPIO. El PWM genera cuatro señales de
compuerta con modulación unipolar, tiempo muerto y precarga de bootstrap, y su disparo en el
valle de la portadora sincroniza la conversión de corriente. Una interrupción periódica de
20 kHz calcula el nuevo índice de modulación y guarda un histórico, que se exporta por UART al
presionar un botón para analizarlo en la PC.

El enunciado y las rúbricas están en
[`EL3313_proyecto4_2S2026.pdf`](EL3313_proyecto4_2S2026.pdf).

## Documentos de la entrega

- Documento de diseño de Taller, [`docs/diseño.md`](docs/diseño.md).
- Informe técnico de Taller, [`docs/informe/informe.md`](docs/informe/informe.md), con su
  evidencia en `docs/informe/evidencia/`, las figuras en `docs/informe/figuras/` y los reportes
  de Vivado en `docs/informe/reportes/`.
- Documento de diseño de PEDP,
  [`entregables/documento_diseno_pedp.pdf`](entregables/documento_diseno_pedp.pdf).
- Informe técnico de PEDP,
  [`entregables/informe_tecnico_pedp.pdf`](entregables/informe_tecnico_pedp.pdf).
- `entregables/documento_diseno_pedp.zip`, con el documento de diseño de PEDP, los modelos de
  PLECS de `potencia/sim/` con sus scripts, los cálculos en Octave con sus salidas para 9,6 Ω y
  12 V, el diseño de la carga y el sensor en `potencia/carga_RL-Sensor/` y los archivos que cita
  su apéndice.
- `entregables/informe_tecnico_pedp.zip`, con el informe técnico de PEDP, los registros de
  banco, los scripts que los procesan, los modelos de PLECS y los cálculos con la carga medida.

Los dos zips conservan las rutas del repositorio que citan los documentos. Las fuentes en LaTeX
están en `potencia/informe/`.

## Estado del proyecto

Estado al 24 de noviembre de 2026, en la rama `develop`.

- El banco autoverificable del periférico PWM pasa con 0 errores en tres corridas, con
  contadores reducidos (101 554 comprobaciones), con los parámetros nominales (6 552 388) y en la
  simulación post-implementación temporizada con netlist y SDF (6 552 564).
- El banco de la envoltura del XADC pasa sin errores, igual que las siete pruebas del software
  en C en la PC y las 13 pruebas del receptor en Python.
- La implementación cumple el timing a 100 MHz, con WNS de 0,302 ns y WHS de 0,019 ns, y usa
  5561 LUT (26,7 %), 3664 registros, 8 bloques de BRAM, 7 DSP y 19 pines.
- En el banco, con 9,46 Ω en las resistencias, 11,8 Ω de carga total y 200 µH nominales, el
  lazo sigue 0,2 y 0,5 A con menos de 0,5 % de error según el sensor. La medición independiente
  con el osciloscopio da de 14,6 a 18,7 % más corriente física, 1,0 A no se alcanza porque la
  acción satura y el rizado medido, de 0,25 a 0,66 A pico a pico, supera los 0,20 A.

Lo que no se pudo medir y qué criterio deja sin demostrar está en 12.8.6 de `informe.md` y en
la discusión del informe técnico de PEDP.

## Estructura del repositorio

- `EL3313_proyecto4_2S2026.pdf`, enunciado común, entregables y rúbricas de ambos cursos.
- `docs/diseño.md`, documento consolidado de diseño.
- `docs/diseño/diagramas/`, arquitectura y diagramas de los niveles 1 a 3.
- `docs/diseño/modulos/`, documentos de los módulos del cuarto nivel y plan de verificación del
  PWM.
- `docs/informe/`, informe técnico de Taller con su evidencia, figuras, mediciones y reportes.
- `docs/investigacion_previa.md`, investigación previa del proyecto.
- `docs/guia_mediciones.md`, `docs/hojas_mediciones.tex` y `docs/pruebas_integracion.md`,
  procedimientos, hojas de registro y criterios de las pruebas de banco.
- `docs/uso_basys3.md`, botones, switches, LEDs, pines y exportación de muestras.
- `docs/reparto.md`, reparto del trabajo entre los integrantes.
- `src/design/`, RTL de `nucleo_pwm`, `interfaz_axi_pwm`, `periferico_pwm`, `envoltura_xadc` y
  `debounce`.
- `src/sim/`, bancos autoverificables del periférico PWM y de la envoltura del XADC.
- `src/bd/sistema.tcl`, Block Design exportado con Vivado 2026.1.
- `src/bd/sistema_wrapper.xsa`, plataforma de hardware exportada para Vitis.
- `src/fpga/basys3.xdc`, reloj y asignación de pines de la Basys 3.
- `src/crear_proyecto.tcl`, crea el proyecto de Vivado desde `src/`, lo implementa, exporta el
  `.xsa` con bitstream y escribe los reportes.
- `src/sim_temporizada.tcl`, simulación post-implementación temporizada del periférico PWM.
- `src/armar_vitis.py` y `src/programar_vitis.tcl`, compilación del software en Vitis y carga
  en la Basys 3.
- `sw/`, aplicación en C, drivers, coeficientes del PR, tabla senoidal y receptor de PC.
- `sw/config_vitis/`, configuración de fuentes y linker script de la memoria local.
- `sw/pruebas/`, pruebas de los módulos en C y del receptor en Python.
- `potencia/`, diseño de la etapa de potencia, modelos, simulaciones, procesamiento de las
  mediciones e informes de PEDP. El detalle está en [Carpeta `potencia/`](#carpeta-potencia).
- `muestras_Inversor/`, registros exportados por UART y capturas del osciloscopio de los
  ensayos de banco del 23 y 24 de noviembre.
- `entregables/`, los dos PDF de PEDP y un zip para cada uno.
- `Makefile`, accesos a simulación, compilación, programación y recepción de muestras.

## Carpeta `potencia/`

Reúne la parte de Procesamiento Electrónico de Potencia, con el diseño de la etapa de potencia,
los modelos y simulaciones, el procesamiento de las mediciones de banco y los dos informes de
PEDP. Los scripts se corren desde la raíz del repositorio, porque leen y escriben con rutas
relativas a ella (`muestras_Inversor/`, `docs/informe/evidencia/` y `docs/informe/figuras/`).

### Diseño

- `diseno_puente_h.md`, aislamiento de las compuertas, MOSFET y pérdidas, bootstrap y precarga,
  cadena de cada compuerta, tiempo muerto y protecciones.
- `diseno_pr.md`, estructura, sintonización, discretización, saturación y estabilidad del
  regulador PR, con su plan de pruebas.
- `docs/modelo_planta.md`, modelo de la carga RL, tensión promedio con modulación unipolar,
  modelo discreto, efecto del tiempo muerto y de la `RDS(on)`, rizado, elección de `f_sw` y
  descripción del modelo de PLECS.
- `carga_RL-Sensor/`, diseño de la carga y del sensor de corriente con su acondicionamiento
  (`diseño_carga_sensor.tex` y su PDF), la simulación del acondicionador en LTspice
  (`circuito_acondicionador.asc`) y las hojas de datos del ACS712 y del AD822.
- `figuras/conexiones_puente.tex`, esquemático de armado con números de pin. La primera página
  tiene las cuatro cadenas de compuerta y la segunda los dos IR2110, el puente H y las fuentes.
- `hojas_de_datos/`, hojas de los semiconductores del puente y de las alternativas evaluadas
  para el aislamiento, DS181 del XADC y el esquemático de la Basys 3.
- `preguntas_profesor_pr.tex`, consulta al profesor sobre el regulador PR.

### Simulación en PLECS (`sim/`)

- `parametros.m`, parámetros de la planta y del puente, que el modelo carga al inicializarse.
- `modelo-planta.plecs`, inversor conmutado en lazo abierto, con tiempo muerto y `RDS(on)`.
- `lazo_cerrado.plecs`, el mismo inversor con el PR de `sw/pr_params.h` en un C-Script.
- `lazo_abierto.py`, `rizado.py` y `lazo_cerrado.py`, ensayos sobre esos modelos. Necesitan
  PLECS abierto con la interfaz RPC activa en el puerto 1080. `lazo_cerrado.py` deja las formas
  de onda en `sim/lazo_cerrado_*.csv`, que no se versionan.

### Cálculos en Octave

- `verificar_pr.m`, cifras de `diseno_pr.md`, con márgenes, `Kp`, `Kr`, escalones y tiempo
  muerto.
- `aliasing_pr.m`, error de la fundamental según el instante de captura del XADC.
- `simular_conmutado.m`, lazo cerrado conmutado con tiempo muerto, captura en el valle, orden
  aplicada en el valle siguiente y ADC cuantizado. Recibe R, L, Vdc, la tensión con que se
  normalizaron los coeficientes y un factor de cambio de R, y escribe en
  `docs/informe/evidencia/modelo_conmutado.txt`.
- `figuras_informe.m`, figuras y cifras del modelo promediado del informe de Taller, en
  `docs/informe/figuras/`.

```sh
octave --no-gui --eval "addpath('potencia'); verificar_pr"
octave --no-gui --eval "addpath('potencia'); simular_conmutado(11.8, 212.4e-6, 12.5, 18)"
```

### Mediciones y procesamiento

- `mediciones/2026-11-24/registro.md`, lo anotado en el banco que no quedó en un archivo de
  captura (carga medida, límites de la fuente, tiempo muerto de las dos piernas y período de la
  rutina). Los CSV del receptor y las capturas del osciloscopio están en `muestras_Inversor/`,
  en la raíz.
- `analizar_csv.m`, fundamental, fase y error de un CSV de `sw/receptor_pc.py`.
- `analizar_osc.m`, fundamental, RMS y rizado de una captura CSV del osciloscopio. La tensión
  sobre las resistencias de la carga se divide entre su resistencia medida.
- `analizar_registros.py`, valores del informe técnico de PEDP que salen de los registros de
  banco (pico y RMS, armónicas, tensión aplicada estimada, corriente calibrada, deriva del cero
  y nivel de las capturas de rizado).
- `figuras_banco.py`, figura de los registros en régimen, en
  `docs/informe/figuras/banco_regimen.png`.

```sh
python3 potencia/analizar_registros.py
```

### Informes de PEDP (`informe/`)

- `informe_diseno_pedp.tex` e `informe_tecnico_pedp.tex`, con sus PDF. Comparten
  `preambulo.tex`, `instructivo.sty` y `literatura.bib`.
- `fig/`, figuras de los dos documentos, copiadas en esta carpeta porque MiKTeX no lee rutas
  con `../`.
- `figuras_informe.m`, figuras del Bode, de los márgenes con retardo y de los escalones del
  informe de PEDP, con el mismo lazo que `verificar_pr.m`. Es distinto del `figuras_informe.m`
  de `potencia/`.
- `Makefile`, compila los dos documentos con `pdflatex` y `biber`.

```sh
cd potencia/informe
make
```

## Diseño modular

El documento consolidado es [`docs/diseño.md`](docs/diseño.md). Los documentos de cada módulo
permiten consultar interfaces y funcionamiento sin recorrer todo el documento.

### Investigación previa y diagramas

- [Investigación previa](docs/investigacion_previa.md)
- [Nivel 1, sistema completo](docs/diseño/diagramas/nivel01.md)
- [Nivel 2, bloques principales](docs/diseño/diagramas/nivel02.md)
- [Nivel 3, módulos e interfaces](docs/diseño/diagramas/nivel03.md)

### Nivel 4, plataforma y periféricos

- [Block Design, reloj, reset, direcciones y pines](docs/diseño/modulos/block_design.md)
- [Periférico PWM completo](docs/diseño/modulos/periferico_pwm.md)
- [Interfaz AXI4-Lite del PWM](docs/diseño/modulos/interfaz_axi_pwm.md)
- [Núcleo PWM, portadora, precarga y tiempo muerto](docs/diseño/modulos/nucleo_pwm.md)
- [Envoltura del XADC](docs/diseño/modulos/envoltura_xadc.md)
- [Plan de verificación del PWM](docs/diseño/modulos/plan_verificacion_pwm.md)

### Nivel 4, software

- [Drivers](docs/diseño/modulos/drivers.md)
- [Control principal](docs/diseño/modulos/control_principal.md)
- [Lazo de control e interrupción](docs/diseño/modulos/lazo_control.md)
- [Regulador PR discreto](docs/diseño/modulos/pr_discreto.md)
- [Referencia senoidal](docs/diseño/modulos/ref_senoidal.md)
- [Supervisor de falla](docs/diseño/modulos/supervisor_falla.md)
- [Buffer de muestras](docs/diseño/modulos/buffer_muestras.md)
- [Exportador UART](docs/diseño/modulos/exportador_uart.md)
- [Receptor de PC](docs/diseño/modulos/receptor_pc.md)

### Potencia

- [Puente H, drivers y protecciones](potencia/diseno_puente_h.md)
- [Diseño y discretización del PR](potencia/diseno_pr.md)
- [Modelo de la planta, rizado y frecuencia de conmutación](potencia/docs/modelo_planta.md)

## Dependencias

### Hardware

- Basys 3, XC7A35T-1CPG236, y cable USB de datos para JTAG y UART.
- Para la integración, el puente H con los IR2110 y el aislamiento con VO3120, la carga RL, el
  sensor ACS712 y su acondicionamiento a 0 a 1 V, según `potencia/`.
- Para validar, osciloscopio, fuente de banco con límite de corriente y analizador lógico.

### Software

- Vivado 2026.1. `src/bd/sistema.tcl` comprueba la versión y no corre en otra. El enunciado
  pide 2025.1.
- Vitis y XSDB de la misma versión, para compilar y cargar la aplicación.
- Archivos de placa de Digilent para `digilentinc.com:basys3:part0:1.2`.
- Icarus Verilog 12 o posterior (`iverilog` y `vvp`), para los bancos de prueba.
- GCC o un compilador de C equivalente, para las pruebas del software en la PC.
- Python 3 con `pyserial`, `numpy` y `matplotlib`, definidos en `sw/requirements.txt`.
- GNU Make, para los objetivos del `Makefile`.
- Octave o MATLAB para los scripts `.m`, PLECS 5.0 para el modelo conmutado y LTspice para el
  acondicionador del sensor. Ninguno hace falta para los bancos RTL ni para las pruebas en C o
  Python.
- `pdflatex` y `biber` (MiKTeX o TeX Live) para compilar los documentos de PEDP.

## Instalación

Los comandos de consola siguientes usan GNU/Linux o WSL. El receptor en Python también puede
usarse en Windows indicando el puerto, por ejemplo `COM5`.

```sh
git clone https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR.git
cd Proyecto-4-Regulador-PR
git switch develop
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r sw/requirements.txt
```

En PowerShell el entorno se activa con `.venv\Scripts\Activate.ps1`, y se puede usar `python`
en lugar de `python3`. Las herramientas de AMD tienen que estar en el `PATH` de la consola desde
la que se corren los comandos de compilación.

## Compilación y simulación

### Periféricos en SystemVerilog

Desde la raíz del repositorio:

```sh
make sim TB=periferico_pwm
make sim TB=envoltura_xadc
```

El banco del PWM usa por defecto contadores reducidos. Para repetirlo con reloj de 10 ns,
tiempo muerto de 100 ciclos, precarga de 7000 y cuentas máximas de 5000, 2500 y 1250:

```sh
mkdir -p sw/build
iverilog -g2012 -s tb_periferico_pwm -Ptb_periferico_pwm.RAPIDO=0 \
  -o sw/build/tb_pwm_nominal.vvp src/design/*.sv src/sim/tb_periferico_pwm.sv
vvp sw/build/tb_pwm_nominal.vvp
```

El resultado esperado es `errores=0` y `PWM: APROBADO`. El banco del XADC termina con
`PASA: tb_envoltura_xadc sin errores`. Usa un modelo del XADC Wizard, así que no reemplaza la
comprobación de la adquisición analógica real.

La simulación post-implementación temporizada sintetiza e implementa `periferico_pwm` solo,
escribe la netlist y el SDF y corre el mismo banco en xsim. No necesita la placa y deja todo en
`vivado/timesim/`:

```sh
vivado -mode batch -source src/sim_temporizada.tcl
```

### Software en C en la PC

Estas pruebas reemplazan los accesos al hardware por dobles de prueba y no necesitan Vitis ni
la placa. Desde la raíz:

```sh
mkdir -p sw/build
gcc -std=c99 -Wall -I sw sw/buffer_muestras.c sw/pruebas/prueba_buffer_muestras.c -o sw/build/prueba_buffer_muestras
gcc -std=c99 -Wall -I sw sw/pr_discreto.c sw/pruebas/prueba_pr_discreto.c -lm -o sw/build/prueba_pr_discreto
gcc -std=c99 -Wall -I sw sw/ref_senoidal.c sw/pruebas/prueba_ref_senoidal.c -lm -o sw/build/prueba_ref_senoidal
gcc -std=c99 -Wall -I sw sw/supervisor_falla.c sw/pruebas/prueba_supervisor_falla.c -o sw/build/prueba_supervisor_falla
gcc -std=c99 -Wall -I sw sw/lazo_control.c sw/buffer_muestras.c sw/pr_discreto.c sw/ref_senoidal.c sw/supervisor_falla.c sw/pruebas/prueba_lazo_control.c -lm -o sw/build/prueba_lazo_control
gcc -std=c99 -Wall -I sw sw/buffer_muestras.c sw/exportador_uart.c sw/pruebas/prueba_exportador_uart.c -lm -o sw/build/prueba_exportador_uart
gcc -std=c99 -Wall -I sw sw/control_principal.c sw/lazo_control.c sw/exportador_uart.c sw/buffer_muestras.c sw/pr_discreto.c sw/ref_senoidal.c sw/supervisor_falla.c sw/pruebas/prueba_control_principal.c -lm -o sw/build/prueba_control_principal

for prueba in sw/build/prueba_*; do "$prueba" || break; done
```

Cada ejecutable informa cero errores. Esto valida la lógica probada. La compilación del
firmware completo, su ocupación de memoria y su temporización se comprueban aparte con Vitis.

### Receptor en Python y coeficientes del regulador

```sh
cd sw
python3 -m unittest pruebas.test_receptor_pc
cd ..
```

La prueba en Python no necesita el puerto serie ni la FPGA. `sw/generar_pr_params.m` regenera
`sw/pr_params.h` con los parámetros que se le pasan. No hace falta correrlo para compilar, porque
el header ya está versionado.

### Vivado, Vitis y programación

El Block Design lleva el PWM y la envoltura del XADC como módulos RTL de referencia.
`src/crear_proyecto.tcl` arma el proyecto con `src/design/*.sv`, `src/fpga/basys3.xdc` y
`src/bd/sistema.tcl`, así que no hace falta abrir la interfaz gráfica.

```sh
make bitstream
make vitis
make program
```

`make bitstream` deja el `.xsa` con bitstream en `vivado/regenerado/` y los reportes de recursos
y timing en `docs/informe/reportes/`.
`make vitis` arma la plataforma y compila `control_pr` desde ese `.xsa` con la configuración de
`sw/config_vitis/`, y `make program` carga el bitstream y corre el `.elf` por JTAG. Los
objetivos dependen de los fuentes de `src/` y `sw/`, así que un cambio en el RTL o en el C
regenera lo que corresponde.

Para que la placa arranque sola, `make bit_con_elf` mete el `.elf` en la BRAM del bitstream y
`make flash` lo graba en la flash QSPI con `openFPGALoader` (con JP1 en QSPI). `make clean`
borra `vivado/` y `vitis/`, que se regeneran desde `src/` y `sw/`.

## Ejecución en la Basys 3

El sistema arranca con el control deshabilitado. El orden de conexión y las mediciones previas
están en [`docs/guia_mediciones.md`](docs/guia_mediciones.md). Antes de cualquier ensayo
energizado se comprueban las compuertas y el tiempo muerto con la etapa de potencia apagada,
como pide el enunciado. Se enciende primero la Basys 3, después el sensor y su acondicionador, y
recién entonces se reinicia con `btnC` o se carga el programa, porque si el firmware arranca con
el sensor apagado LD2 queda enclavado. Al apagar va primero el sensor. El detalle está en
[`docs/uso_basys3.md`](docs/uso_basys3.md).

### Controles y estado

| Control | Acción |
|---|---|
| `btnC`, U18 | Reinicia la plataforma y borra la falla enclavada |
| `btnU`, T18 | Alterna la habilitación si no hay falla y `freq_sel = 01` |
| `btnD`, U17 | Congela el histórico y lo exporta por UART |
| `SW[1:0] = 00` | Referencia de 0 A |
| `SW[1:0] = 01` | Referencia de 0,2 A pico |
| `SW[1:0] = 10` | Referencia de 0,5 A pico |
| `SW[1:0] = 11` | Referencia de 1,0 A pico |
| LD0, U16 | Control habilitado |
| LD1, E19 | Sobrecorriente, corriente medida fuera de ±1,3 A |
| LD2, U19 | Cuenta del ADC fuera de escala, 16 o menos o 4079 o más |
| LD3, V19 | Más de tres interrupciones seguidas sin dato nuevo del XADC |
| LD4, W18 | Error de arranque, el XADC no avanzó durante el sondeo inicial |

LD1 a LD3 quedan enclavados hasta `btnC` y muestran solo la primera causa que disparó. El
firmware cierra el lazo solo a 20 kHz, aunque el PWM también genera 10 y 40 kHz, y la referencia
cambia con una rampa de 2,5 mA por muestra.

### Señales de conexión

| Señal | Puerto de la Basys 3 |
|---|---|
| `compuerta_a_alta` | JA10, G3 |
| `compuerta_a_baja` | JA9, H2 |
| `compuerta_b_alta` | JA8, K2 |
| `compuerta_b_baja` | JA7, H1 |
| Depuración de la ISR | JB1, A14 |
| Medición analógica positiva | JXADC pin 1, J3, `vauxp6` |
| Referencia analógica negativa | JXADC pin 7, K3, `vauxn6` |
| UART TX | A18, puente USB-UART de la placa |

La entrada del XADC se acondiciona a 0 a 1 V. `sw/lazo_control.h` convierte la cuenta a
corriente con un cero de 2569 cuentas y −1,292·10⁻³ A por cuenta, calibrados contra el
osciloscopio con el puente conmutando en los registros del 23 de noviembre. El valor nominal
del diseño era de 1,1118·10⁻³ A por cuenta, a partir de 0,2196 V/A.

### Exportar y analizar muestras

Con la aplicación corriendo en la placa, se abre el receptor y se presiona `btnD`:

```sh
make receptor
python3 sw/receptor_pc.py /dev/ttyUSB1 -o ensayo_05A.csv
python3 sw/receptor_pc.py COM5 -o ensayo_05A.csv
```

Sin puerto explícito, el receptor busca la Basys 3 por el FT2232. Guarda el histórico en CSV y
la trama binaria recibida, calcula amplitud y desfase de la fundamental y muestra las gráficas.
Una trama guardada se puede procesar otra vez:

```sh
python3 sw/receptor_pc.py ensayo_05A.bin -o ensayo_05A_reprocesado.csv
```

El buffer tiene 2048 registros, 102,4 ms a 20 kHz. Se congela durante la transmisión mientras el
control sigue corriendo. La trama ocupa 12 310 bytes y tarda unos 1,07 s a 115200 baudios, 8N1.

El histórico alcanza para calcular la fundamental sobre al menos cinco períodos completos. El
rizado de conmutación se mide aparte con el osciloscopio sobre la carga, porque el histórico
toma una sola muestra por período del PWM.
