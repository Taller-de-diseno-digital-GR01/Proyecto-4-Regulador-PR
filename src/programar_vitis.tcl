# Programa el bitstream y baja + corre el .elf de control_pr en la Basys3 por JTAG
# Uso: xsdb src/programar_vitis.tcl <bitstream.bit> <control_pr.elf>

set bit [lindex $argv 0]
set elf [lindex $argv 1]

connect
fpga -file $bit
targets -set -filter {name =~ "*MicroBlaze*" || name =~ "Hart*"} ;# en 2026.1 el MicroBlaze V aparece como Hart #0
catch {stop} ;# con el hart corriendo dow no encuentra el PC
dow $elf
con
