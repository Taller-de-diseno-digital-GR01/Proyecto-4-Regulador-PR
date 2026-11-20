# Build y carga del sistema completo (Vivado + Vitis) sin abrir ninguna IDE
# vivado/ y vitis/ no se versionan, se regeneran desde src/bd y sw (ver .gitignore)
# Pide Vivado y Vitis 2025.1 en el PATH, y el cable JTAG de la Basys3 para programar

SALIDA_VIVADO := vivado/regenerado
XSA := $(SALIDA_VIVADO)/sistema_wrapper.xsa
BIT := $(SALIDA_VIVADO)/p4/p4.runs/impl_1/sistema_wrapper.bit
WS_VITIS := vitis/workspace
ELF := $(WS_VITIS)/control_pr/Debug/control_pr.elf

.DEFAULT_GOAL := help

.PHONY: help bitstream vitis program sim clean

help:
	@echo "make bitstream        sintetiza e implementa con Vivado, deja el .xsa con bitstream en $(SALIDA_VIVADO)"
	@echo "make vitis            arma la plataforma y compila control_pr en Vitis a partir del .xsa"
	@echo "make program          programa el bitstream y baja + corre el .elf en la Basys3 (bitstream + vitis)"
	@echo "make sim TB=<nombre>  compila y corre src/sim/tb_<nombre>.sv con iverilog"
	@echo "make clean            borra vivado/ y vitis/, se regeneran desde src/"

$(XSA):
	vivado -mode batch -source src/crear_proyecto.tcl -tclargs $(SALIDA_VIVADO)

bitstream: $(XSA)

$(ELF): $(XSA)
	vitis -s src/armar_vitis.py $(XSA) $(WS_VITIS)

vitis: $(ELF)

program: $(XSA) $(ELF)
	xsdb src/programar_vitis.tcl $(BIT) $(ELF)

sim:
	iverilog -g2012 -s tb_$(TB) -o /tmp/tb_$(TB).vvp src/design/*.sv src/sim/tb_$(TB).sv
	vvp /tmp/tb_$(TB).vvp

clean:
	rm -rf vivado vitis
