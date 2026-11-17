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
- `src/crear_proyecto.tcl` crea el proyecto de Vivado desde cero con lo anterior.
- `docs/informe/reportes/` tiene los reportes de utilización y de timing de la implementación.
- `sw/` tiene el software en C para Vitis (drivers y aplicación de control PR).
- `potencia/` tiene los modelos de PLECS y los cálculos de la etapa de potencia (componente PEDP).

## Regenerar el proyecto de Vivado

Hace falta Vivado 2026.1, la versión con que se exportó el Block Design. Desde la raíz del repo, con Vivado en el `PATH`:

```
vivado -mode batch -source src/crear_proyecto.tcl
```

El script crea el proyecto en `vivado/regenerado/p4` con las fuentes de `src/design/`, `src/fpga/basys3.xdc` y el Block Design de `src/bd/sistema.tcl`, y corre síntesis, implementación y bitstream. Deja `vivado/regenerado/sistema_wrapper.xsa` con el bitstream incluido, para crear la plataforma en Vitis, y reescribe los reportes de `docs/informe/reportes/`. Tarda unos 10 minutos. Para usar otra carpeta de salida, por ejemplo una ruta corta si Windows se queja del largo, se agrega `-tclargs C:/vivado/p4r`. La carpeta `vivado/` no se versiona.
