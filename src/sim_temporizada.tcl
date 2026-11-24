# Simulación post-implementación temporizada de periferico_pwm, sin placa
# Uso, desde la raíz del repo: vivado -mode batch -source src/sim_temporizada.tcl
# Deja netlist, SDF, logs y reportes en vivado/timesim

set raiz [file normalize [file join [file dirname [info script]] ..]]
set salida [file join $raiz vivado timesim]
file mkdir $salida
cd $salida

set parte xc7a35tcpg236-1

read_verilog -sv [list \
  [file join $raiz src design interfaz_axi_pwm.sv] \
  [file join $raiz src design nucleo_pwm.sv] \
  [file join $raiz src design periferico_pwm.sv]]

# Fuera de contexto porque el periférico se evalúa solo, sin el resto del BD, y con el reloj de 100 MHz del diseño. La jerarquía se aplana para que los nombres del netlist coincidan con los del SDF
synth_design -top periferico_pwm -part $parte -mode out_of_context -flatten_hierarchy full
create_clock -period 10.000 -name s_axi_aclk [get_ports s_axi_aclk]
opt_design
place_design
route_design

report_timing_summary -max_paths 10 -file timing_pwm.rpt
report_utilization -file utilizacion_pwm.rpt
report_methodology -file metodologia_pwm.rpt
report_drc -file drc_pwm.rpt

write_verilog -mode timesim -sdf_anno true -force -file periferico_pwm_timesim.v
write_sdf -force -file periferico_pwm_timesim.sdf

# Banco del PWM adaptado al netlist, que no trae parámetros ni se ve en el mismo instante que el RTL
# Se quita el mapa de parámetros (el netlist ya viene con los nominales), se espera el GSR de 100 ns de glbl, las salidas se leen 4 ns después del flanco por los retardos del SDF y se quita el volcado de ondas
set f [open [file join $raiz src sim tb_periferico_pwm.sv] r]
fconfigure $f -encoding utf-8
set tb [read $f]
close $f
regsub {\n    periferico_pwm #\(.*?\) dut \(} $tb "\n    periferico_pwm dut (" tb
regsub -all {#1;} $tb {#4;} tb
regsub -all {@\(posedge clk\); #2;} $tb {@(posedge clk); #4;} tb
regsub {verificar\(\$realtime == ultimo_flanco && clk,} $tb {verificar($realtime >= ultimo_flanco \&\& $realtime - ultimo_flanco <= 4.0 \&\& clk,} tb
regsub {\$dumpfile\("pwm.vcd"\); \$dumpvars\(0,tb_periferico_pwm\);} $tb {} tb
regsub {        iniciar\("AX01 AX02 / reset y valores iniciales"\);} $tb "        #150;\n        iniciar(\"AX01 AX02 / reset y valores iniciales\");" tb
set f [open tb_periferico_pwm_timesim.sv w]
fconfigure $f -encoding utf-8
puts -nonewline $f $tb
close $f

# Simulación con xsim, el netlist ya trae su propio glbl y su $sdf_annotate, y se usa la biblioteca simprims por los retardos
exec xvlog -sv periferico_pwm_timesim.v tb_periferico_pwm_timesim.sv -log xvlog.log
exec xelab -debug off -L simprims_ver -timescale 1ns/1ps -generic_top "RAPIDO=0" tb_periferico_pwm glbl -s sim_t -log xelab.log
exec xsim sim_t -runall -log xsim.log
