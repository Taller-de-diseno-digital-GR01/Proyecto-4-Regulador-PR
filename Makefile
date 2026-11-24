# Build y carga del sistema completo (Vivado + Vitis) sin abrir ninguna IDE
# vivado/ y vitis/ no se versionan, se regeneran desde src/bd y sw (ver .gitignore)
# Pide Vivado y Vitis 2025.1 en el PATH, y el cable JTAG de la Basys3 para programar

SALIDA_VIVADO := vivado/regenerado
XSA := $(SALIDA_VIVADO)/sistema_wrapper.xsa
BIT := $(SALIDA_VIVADO)/p4/p4.runs/impl_1/sistema_wrapper.bit
WS_VITIS := vitis/workspace
ELF := $(WS_VITIS)/control_pr/build/control_pr.elf
FUENTES_HW != ls src/crear_proyecto.tcl src/bd/sistema.tcl src/fpga/basys3.xdc src/design/*.sv
FUENTES_SW != ls src/armar_vitis.py sw/*.c sw/*.h sw/config_vitis/*

.DEFAULT_GOAL := help

.PHONY: help bitstream vitis program sim clean receptor

help:
	@echo "make bitstream        sintetiza e implementa con Vivado, deja el .xsa con bitstream en $(SALIDA_VIVADO)"
	@echo "make vitis            arma la plataforma y compila control_pr en Vitis a partir del .xsa"
	@echo "make program          programa el bitstream y baja + corre el .elf en la Basys3 (bitstream + vitis)"
	@echo "make sim TB=<nombre>  compila y corre src/sim/tb_<nombre>.sv con iverilog"
	@echo "make clean            borra vivado/ y vitis/, se regeneran desde src/"
	@echo "make receptor         recibe el histórico de la Basys3 con sw/receptor_pc.py, opcional PUERTO=<puerto> CSV=<archivo> CENTRAR=1"

$(XSA): $(FUENTES_HW) # sin esto un .xsa viejo se reusaba aunque cambiara el RTL o el Block Design
	vivado -mode batch -source src/crear_proyecto.tcl -tclargs $(SALIDA_VIVADO)

bitstream: $(XSA)

$(ELF): $(XSA) $(FUENTES_SW) # sin sw/ acá, make program bajaba el .elf anterior aunque cambiaran los .c
	rm -rf $(WS_VITIS) # armar_vitis.py crea la plataforma desde cero y falla si el workspace ya existe
	vitis -s src/armar_vitis.py $(XSA) $(WS_VITIS)

vitis: $(ELF)

program: $(XSA) $(ELF)
	xsdb src/programar_vitis.tcl $(BIT) $(ELF)

sim:
	iverilog -g2012 -s tb_$(TB) -o /tmp/tb_$(TB).vvp src/design/*.sv src/sim/tb_$(TB).sv
	vvp /tmp/tb_$(TB).vvp

clean:
	rm -rf vivado vitis

PYTHON ?= python3
CSV ?= muestras.csv

receptor: # sin PUERTO receptor_pc.py busca la Basys3 sola por el VID/PID del FT2232
	$(PYTHON) sw/receptor_pc.py $(PUERTO) -o $(CSV) $(if $(CENTRAR),--centrar)
