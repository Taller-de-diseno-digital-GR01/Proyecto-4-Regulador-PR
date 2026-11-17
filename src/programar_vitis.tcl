# Programa el bitstream y baja + corre el .elf de control_pr en la Basys3 por JTAG
# Uso: xsdb src/programar_vitis.tcl <bitstream.bit> <control_pr.elf>

set bit [lindex $argv 0]
set elf [lindex $argv 1]

connect
fpga -file $bit
targets -set -filter {name =~ "*MicroBlaze*"}
dow $elf
con
