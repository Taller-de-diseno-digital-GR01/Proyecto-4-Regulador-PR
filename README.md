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

El procesador se comunica por AXI4-Lite con un periférico PWM personalizado en SystemVerilog,
una envoltura propia del XADC y las IP de Timer, UART y GPIO. El PWM genera cuatro señales de
compuerta con tiempo muerto y precarga de bootstrap. Su trigger sincroniza la conversión de
corriente. Una interrupción periódica calcula la nueva referencia de modulación y guarda un
histórico; al presionar un botón, ese histórico se exporta por UART para analizarlo en la PC.

El enunciado y las rúbricas están en
[`EL3313_proyecto4_2S2026.pdf`](EL3313_proyecto4_2S2026.pdf).

## Estado del proyecto y ramas

Estado documentado al 20 de noviembre de 2026. La rama de trabajo es
[`develop`](https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR/tree/develop).
`main` todavía no contiene la implementación final. Para trabajar con los fuentes descritos
en esta guía hay que usar `develop`; las incorporaciones pendientes se identifican aparte.

Las pruebas funcionales del PWM, la envoltura del XADC y los módulos de software pasan en PC.
Eso verifica los bloques probados, pero la validación experimental del sistema completo no está
cerrada: faltan resultados energizados, mediciones de período y jitter y la simulación
post-implementación temporizada del PWM.

La carga más reciente de diseño es de **9 Ω y 200 µH**, con PR de `Kp = 4,5 V/A` y
`Kr = 10000`. El header actual se genera para 18 V y 20 kHz. R y L son nominales y deben
contrastarse con el montaje. Con esta configuración, el análisis de
[`diseno_pr.md`](potencia/diseno_pr.md) prevé un rizado superior a 0,20 A pico a pico en los
puntos de 0,5 y 1,0 A; no se declara cumplimiento de ese requisito.

| Documento o herramienta | Ubicación y estado |
|---|---|
| Diseño y fuentes de trabajo | `develop` |
| Informe técnico de Taller | [PR #67, rama `doc/informe`](https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR/pull/67); usa todavía la carga anterior de 30 mH |
| Regeneración automática de Vivado y reportes | [PR #65](https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR/pull/65); agrega `src/crear_proyecto.tcl` |
| Modelo y resultados PLECS | [PR #64](https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR/pull/64) y [PR #68](https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR/pull/68); la validación disponible usa 12 Ω y 30 mH |
| Informe de PEDP | [PR #72](https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR/pull/72); debe actualizarse a la configuración final |

Los resultados de las cargas anteriores se conservan como antecedentes; no sustituyen la
validación del montaje final. La configuración vigente y las discrepancias conocidas están en
[`docs/diseño/inconsistencias.md`](docs/diseño/inconsistencias.md).

## Estructura del repositorio

- `EL3313_proyecto4_2S2026.pdf`: enunciado común, entregables y rúbricas de ambos cursos.
- `docs/diseño.md`: documento consolidado de diseño.
- `docs/diseño/diagramas/`: arquitectura y diagramas de los niveles 1 a 3.
- `docs/diseño/modulos/`: fichas de los módulos del cuarto nivel y plan de verificación del PWM.
- `docs/informe/`: destino del informe técnico de Taller, figuras y reportes; el contenido del
  informe está pendiente de integrar desde la PR #67.
- `docs/guia_mediciones.md` y `docs/pruebas_integracion.md`: procedimientos y criterios para el
  banco. Deben leerse junto con las discrepancias documentadas.
- `docs/uso_basys3.md`: botones, switches, LEDs, pines y exportación de muestras.
- `src/design/`: RTL de `nucleo_pwm`, `interfaz_axi_pwm`, `periferico_pwm`,
  `envoltura_xadc` y `debounce`.
- `src/sim/`: bancos autoverificables del periférico PWM y de la envoltura del XADC.
- `src/bd/sistema.tcl`: Block Design exportado con Vivado 2026.1.
- `src/bd/sistema_wrapper.xsa`: plataforma de hardware exportada para Vitis.
- `src/fpga/basys3.xdc`: reloj y asignación de pines de la Basys 3.
- `src/armar_vitis.py` y `src/programar_vitis.tcl`: automatización de compilación y carga del
  software. El script de Vitis conserva comprobaciones pendientes del entorno instalado.
- `sw/`: aplicación C, drivers, coeficientes del PR, tabla senoidal y receptor de PC.
- `sw/config_vitis/`: configuración de fuentes y linker script de la memoria local.
- `sw/pruebas/`: pruebas de los módulos C y del receptor Python.
- `potencia/`: diseño del puente H, regulador PR, scripts de análisis y hojas de datos.
- `Makefile`: accesos a simulación, compilación y programación. Su flujo de Vivado depende de
  `src/crear_proyecto.tcl`, pendiente de la PR #65.

## Diseño modular

El documento consolidado es [`docs/diseño.md`](docs/diseño.md). Las fichas individuales permiten
consultar interfaces y funcionamiento sin recorrer todo el documento.

### Investigación previa y diagramas

- [Investigación previa](docs/investigacion_previa.md)
- [Nivel 1: sistema completo](docs/diseño/diagramas/nivel01.md)
- [Nivel 2: bloques principales](docs/diseño/diagramas/nivel02.md)
- [Nivel 3: módulos e interfaces](docs/diseño/diagramas/nivel03.md)

### Nivel 4: plataforma y periféricos

- [Block Design, reloj, reset, direcciones y pines](docs/diseño/modulos/block_design.md)
- [Periférico PWM completo](docs/diseño/modulos/periferico_pwm.md)
- [Interfaz AXI4-Lite del PWM](docs/diseño/modulos/interfaz_axi_pwm.md)
- [Núcleo PWM, portadora, precarga y tiempo muerto](docs/diseño/modulos/nucleo_pwm.md)
- [Envoltura del XADC](docs/diseño/modulos/envoltura_xadc.md)
- [Plan de verificación del PWM](docs/diseño/modulos/plan_verificacion_pwm.md)

### Nivel 4: software

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
- `potencia/verificar_pr.m`: predicciones del regulador y márgenes del modelo.
- `potencia/aliasing_pr.m`: efecto del instante de captura sobre la corriente regulada.

## Dependencias

### Hardware

- Basys 3, XC7A35T-1CPG236, y cable USB de datos para JTAG y UART.
- Para la integración: puente H, drivers y aislamiento, carga RL, sensor y acondicionamiento
  de corriente a 0–1 V, según la documentación de potencia y el montaje final confirmado.
- Para validar: osciloscopio y medición de corriente, fuente con límite de corriente y
  analizador lógico cuando corresponda.

### Software

- **Vivado 2026.1**, versión exigida por el Tcl exportado del Block Design. El enunciado menciona
  2025.1, pero el script versionado comprueba 2026.1 y rechaza una versión diferente.
- **Vitis y XSDB compatibles con esa plataforma**, para compilar y ejecutar la aplicación.
  Los comentarios de algunos scripts todavía mencionan 2025.1; la automatización de Vitis
  debe comprobarse en la instalación utilizada.
- Archivos de placa de Digilent para `digilentinc.com:basys3:part0:1.2`.
- **Icarus Verilog 12 o posterior**, `iverilog` y `vvp`, para los dos bancos actuales.
- **GCC** o compilador C equivalente, para las pruebas de software en PC.
- **Python 3**, `pyserial`, `numpy` y `matplotlib`, definidos en `sw/requirements.txt`.
- **GNU Make**, para los targets del `Makefile`.
- **Octave** o MATLAB para los scripts `.m`; **PLECS** para el modelo conmutado de potencia.
  PLECS no es necesario para ejecutar los testbenches RTL ni las pruebas unitarias C/Python.

## Instalación

Los comandos de consola siguientes usan GNU/Linux o WSL. El receptor Python también puede
usarse en Windows indicando, por ejemplo, `COM5`.

```sh
git clone https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR.git
cd Proyecto-4-Regulador-PR
git switch develop
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r sw/requirements.txt
```

En PowerShell, la activación del entorno es `.venv\Scripts\Activate.ps1` y puede usarse
`python` en lugar de `python3`. Las herramientas de AMD deben estar disponibles en el entorno
desde el que se ejecutan los comandos de compilación.

## Compilación y simulación

### Periféricos SystemVerilog

Desde la raíz del repositorio:

```sh
make sim TB=periferico_pwm
make sim TB=envoltura_xadc
```

El banco del PWM usa por defecto parámetros reducidos. Para repetirlo con reloj de 10 ns,
tiempo muerto de 100 ciclos, precarga de 7000 y MAX de 5000, 2500 y 1250:

```sh
mkdir -p sw/build
iverilog -g2012 -s tb_periferico_pwm -Ptb_periferico_pwm.RAPIDO=0 \
  -o sw/build/tb_pwm_nominal.vvp src/design/*.sv src/sim/tb_periferico_pwm.sv
vvp sw/build/tb_pwm_nominal.vvp
```

El resultado esperado es `errores=0` y `PWM: APROBADO`. El banco del XADC termina con
`PASA: tb_envoltura_xadc sin errores`. Su modelo representa el comportamiento del Wizard;
no reemplaza la comprobación de la adquisición analógica real.

La simulación post-implementación con netlist y SDF sigue pendiente. El repositorio actual
no tiene un target `sim-post`; las simulaciones anteriores son funcionales RTL.

### Software C en la PC

Estas pruebas sustituyen los accesos de hardware por dobles de prueba y no requieren Vitis
ni la tarjeta. Desde la raíz:

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

Cada ejecutable debe informar cero errores. El compilador de PC valida la lógica probada;
la compilación del firmware completo, su ocupación de memoria y su temporización se comprueban
aparte con el BSP y la plataforma de Vitis.

### Receptor Python y cálculos del regulador

```sh
cd sw
python3 -m unittest pruebas.test_receptor_pc
cd ..
octave --no-gui --eval "addpath('potencia'); verificar_pr"
```

La prueba Python no necesita el puerto serie ni la FPGA. Los resultados de `verificar_pr`
corresponden a los parámetros escritos en el script; deben identificarse al comparar con
figuras de informes anteriores. `sw/generar_pr_params.m` regenera el header del controlador
con parámetros explícitos; no es necesario ejecutarlo para compilar el header ya versionado.

### Vivado, Vitis y programación

El Block Design contiene el PWM y el XADC como **módulos RTL de referencia**. Se deben agregar
`src/design/*.sv` y `src/fpga/basys3.xdc` al proyecto antes de cargar `src/bd/sistema.tcl`;
después se genera el wrapper y se selecciona `sistema_wrapper` como tope.

El flujo automático completo queda disponible al integrar `src/crear_proyecto.tcl` de la
[PR #65](https://github.com/Taller-de-diseno-digital-GR01/Proyecto-4-Regulador-PR/pull/65).
En una copia que ya contenga ese archivo:

```sh
make bitstream
make vitis
make program
```

`make bitstream` deja el XSA con bitstream en `vivado/regenerado/`. `make vitis` usa ese XSA
y la configuración de `sw/config_vitis/`; `make program` carga el bitstream y ejecuta el ELF
por JTAG. El script de Vitis conserva un TODO sobre el identificador de la plantilla de
aplicación, por lo que este flujo debe comprobarse con la versión instalada.

En `develop`, antes de integrar la PR #65, `make bitstream` falla por la ausencia de
`src/crear_proyecto.tcl`. Además, las reglas actuales no enumeran todos los fuentes como
dependencias: después de cambiar RTL o C, un `make` normal puede reutilizar artefactos viejos.
Hasta corregir esas dependencias, forzar la regeneración con `make -B program`, una vez que
el flujo completo esté disponible y configurado.

## Ejecución en la Basys 3

El sistema arranca con el control deshabilitado. El orden de conexión y las mediciones previas
están en [`docs/guia_mediciones.md`](docs/guia_mediciones.md). Para la demostración, el enunciado
exige comprobar compuertas y tiempo muerto con la etapa de potencia desenergizada antes de
los ensayos energizados.

### Controles y estado

| Control | Acción |
|---|---|
| `btnC`, U18 | Reinicia la plataforma; borra la falla enclavada |
| `btnU`, T18 | Alterna habilitación si no hay falla y `freq_sel=01` |
| `btnD`, U17 | Congela el histórico y solicita exportación UART |
| `SW[1:0]=00` | Referencia de 0 A |
| `SW[1:0]=01` | Referencia de 0,2 A pico |
| `SW[1:0]=10` | Referencia de 0,5 A pico |
| `SW[1:0]=11` | Referencia de 1,0 A pico |
| LD0, U16 | Control habilitado |
| LD1, E19 | Falla enclavada o error de arranque |

El firmware opera el lazo cerrado solo a 20 kHz, aunque el PWM también soporte 10 y 40 kHz.
La referencia cambia con una rampa de 2,5 mA por muestra. La falla se enclava ante corriente
fuera de ±1,3 A, cuenta del ADC en los extremos definidos o más de tres muestras consecutivas
ausentes. La descripción completa está en [`docs/uso_basys3.md`](docs/uso_basys3.md).

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
| UART TX | A18, puente USB-UART de la tarjeta |

La entrada del XADC se acondiciona a 0–1 V. La conversión actual usa offset de 2048 cuentas
y `6,6705e-3 A/cuenta`, calculados a partir de 0,0366 V/A (sensor de 183 mV/A por el divisor 12k/3k). La calibración de extremo a extremo
debe quedar asociada a cada ensayo.

### Exportar y analizar muestras

Con la aplicación de la FPGA ejecutándose, abrir el receptor y presionar `btnD`:

```sh
python3 sw/receptor_pc.py
python3 sw/receptor_pc.py /dev/ttyUSB1 -o ensayo_05A.csv
python3 sw/receptor_pc.py COM5 -o ensayo_05A.csv
```

Sin puerto explícito, el receptor busca la Basys 3 mediante el FT2232. Guarda el histórico
en CSV y la trama binaria recibida, calcula amplitud y desfase de la fundamental y muestra
las gráficas. Una trama guardada puede procesarse otra vez:

```sh
python3 sw/receptor_pc.py ensayo_05A.bin -o ensayo_05A_reprocesado.csv
```

El buffer tiene 2048 registros, equivalentes a 102,4 ms a 20 kHz. Se congela durante la
transmisión, mientras el control continúa. La trama completa ocupa 12310 bytes y tarda
aproximadamente 1,07 s a 115200 baudios, 8N1.

El histórico permite calcular la fundamental sobre al menos cinco períodos completos. El
rizado de conmutación se mide aparte con el osciloscopio sobre la corriente de la carga:
no se obtiene del residuo del histórico muestreado una vez por período PWM.

## Validación requerida para el cierre

El seguimiento nominal debe presentar error de amplitud fundamental no mayor de 10 % en
0,2, 0,5 y 1,0 A pico, sobre una ventana de al menos cinco períodos de 50 Hz. El desfase
se reporta y el rizado de conmutación no debe superar 0,20 A pico a pico.

También se requieren los cambios de amplitud de 0,2 a 0,5 A y de 0,5 a 1,0 A, y un cambio
de la resistencia externa de al menos 25 % con referencia de 0,5 A. En los transitorios se
evalúan establecimiento y límites eléctricos por separado; el límite estacionario de 10 %
no se impone a cada instante del cambio.

La evidencia final debe identificar montaje, R, L, Vdc, frecuencia, coeficientes, instrumentos,
escalas y versión de fuentes, y contrastar teoría, PLECS y medición. Los documentos de diseño,
el informe y el código deben usar la misma configuración final antes de integrar la entrega
en `main`.
