# Crea el proyecto de Vivado desde cero con lo versionado en src/, implementa, exporta el .xsa con bitstream y escribe los reportes
# Uso, desde la raíz del repo: vivado -mode batch -source src/crear_proyecto.tcl
# Opcional, otra carpeta de salida: vivado -mode batch -source src/crear_proyecto.tcl -tclargs <carpeta>
# Pide Vivado 2026.1, la versión con que se exportó src/bd/sistema.tcl

set raiz [file normalize [file join [file dirname [info script]] ..]]
set salida [file join $raiz vivado regenerado]
if {[llength $argv] > 0} {
  set salida [file normalize [lindex $argv 0]]
}
set reportes [file join $raiz docs informe reportes]

set proyecto p4
set parte xc7a35tcpg236-1
set placa digilentinc.com:basys3:part0:1.2

# -force borra un proyecto anterior en la misma carpeta, por eso la salida por defecto queda aparte de vivado/p4
create_project $proyecto [file join $salida $proyecto] -part $parte -force
set_property board_part $placa [current_project]

# Los módulos de referencia del BD (periferico_pwm, envoltura_xadc, debounce) tienen que estar en el proyecto antes de cargar sistema.tcl
add_files -norecurse [glob [file join $raiz src design *.sv]]
# add_files toma la ruta como lista, así que una ruta con espacios va dentro de list para que no se corte
add_files -fileset constrs_1 -norecurse [list [file join $raiz src fpga basys3.xdc]]
update_compile_order -fileset sources_1

# sistema.tcl arma, valida y guarda el BD, y ante un error (versión de Vivado, BD repetido) sale con return sin cortar este script
source [file join $raiz src bd sistema.tcl]
set bd [get_files -quiet sistema.bd]
if {$bd eq ""} {
  error "sistema.tcl no creó el Block Design, revisar el mensaje anterior en el log"
}

# Envoltorio HDL del BD como tope del diseño
add_files -norecurse [make_wrapper -files $bd -top]
set_property top sistema_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Síntesis (con las corridas fuera de contexto de cada IP), implementación y bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "La implementación no terminó, revisar [get_property DIRECTORY [get_runs impl_1]]"
}

# Plataforma para Vitis con el bitstream incluido, en la carpeta de salida y no en src/bd
write_hw_platform -fixed -include_bit -force -file [file join $salida sistema_wrapper.xsa]

# Reportes para el informe, sobre el diseño ruteado
# Se escriben desde su carpeta con nombre relativo, porque el encabezado de cada reporte copia el comando y así no lleva la ruta local
open_run impl_1
file mkdir $reportes
set carpeta_previa [pwd]
cd $reportes
report_utilization -file utilizacion.rpt
report_utilization -hierarchical -file utilizacion_jerarquica.rpt
report_timing_summary -max_paths 10 -file timing.rpt
cd $carpeta_previa

puts "Proyecto en [file join $salida $proyecto], .xsa en $salida y reportes en $reportes"
