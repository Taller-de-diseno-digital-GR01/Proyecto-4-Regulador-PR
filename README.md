# Proyecto 4, Control de corriente en un inversor monofásico con regulador PR sobre MicroBlaze V, EL3313 Taller de Diseño Digital y EL4201 Procesamiento Electrónico de Potencia

Profesores:
  Dr.-Ing. Jeferson González-Gómez, PhD. Yeiner Arias-Esquivel, Ing. Rolen Coto Calderón

Integrantes:
- Carlos Castro Villegas
- Jefferson Chinchilla Quesada
- Mattio Coghi Quirós
- Nicolás Mena Valerio

II Semestre 2026

## Estructura del repo

- `docs/diseño/` tiene el documento de diseño, las specs por módulo y los diagramas.
- `docs/informe/` tiene el informe técnico final.
- `src/design/` tiene el periférico PWM AXI4-Lite en SystemVerilog, un archivo por módulo.
- `src/sim/` tiene los testbenches autoverificables.
- `src/fpga/` tiene los constraints de la Basys3 (XDC).
- `src/bd/` tiene el Block Design del MicroBlaze V exportado como `.tcl`, para regenerar el proyecto de Vivado.
- `sw/` tiene el software en C para Vitis (drivers y aplicación de control PR).
- `potencia/` tiene los modelos de PLECS y los cálculos de la etapa de potencia (componente PEDP).
