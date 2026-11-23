# Para la instancia de Claude en la máquina Linux

Esto es para ti, la sesión de Claude Code que corre en la máquina con Vivado y Vitis. Mattio lo dejó para que regeneres el sistema después del cambio de LEDs. Lee también el `CLAUDE.md` del repo si lo tienes, las reglas de estilo y de commits siguen aplicando.

## Qué cambió en develop

Antes LD1 juntaba todas las fallas. Ahora hay un LED por causa, y eso tocó hardware y firmware.

- `src/bd/sistema.tcl`, el canal 2 del `axi_gpio_0` (`C_GPIO2_WIDTH`) y el puerto `led` pasan de 2 a 5 bits.
- `src/fpga/basys3.xdc`, se descomentaron `led[2]` a `led[4]` (U19, V19, W18).
- `sw/supervisor_falla.c` y `.h`, ahora recuerdan cuál causa disparó primero (`supervisor_falla_causa()`).
- `sw/control_principal.c` y `sw/drivers.c`, la máscara de LEDs pasa a `0x1F` y cada causa va a su LED.

Commits `8713431`, `eb15d06` y `e455479`. Las pruebas de `supervisor_falla` y `control_principal` ya pasaron con 0 errores en la otra máquina.

## Qué tienes que hacer

No abras el Block Design viejo ni generes el bitstream sobre un proyecto de Vivado que ya exista. Ese proyecto tiene el BD de 2 bits, el cambio vive en `sistema.tcl` y solo entra si el proyecto se rearma desde ahí. Tampoco le des run en Vitis sobre la plataforma anterior, el `.elf` saldría compilado contra el `.xsa` viejo.

Desde la raíz del repo, en `develop`:

```
git switch develop
git pull
make clean
make program
```

`make program` corre Vivado en batch con `src/crear_proyecto.tcl` (rearma el BD desde `sistema.tcl` y deja `vivado/regenerado/sistema_wrapper.xsa` con el bitstream), después borra el workspace de Vitis y arma la plataforma y `control_pr` desde ese `.xsa` con `src/armar_vitis.py`, y al final programa la Basys3 y baja el `.elf` con `xsdb`. Necesita `vivado`, `vitis` y `xsdb` en el PATH y la Basys3 conectada por USB. Tarda varios minutos, sobre todo la implementación.

Si `make program` falla, no edites `sistema.tcl` ni el Makefile para salir del paso. Pásale a Mattio las últimas líneas del log (`vivado.log` o la salida de Vitis) y espera. Si el error es de JTAG ocupado, revisa que no haya un `hw_server` u `openFPGALoader` colgado de antes.

## Cómo verificar en la placa

Con la potencia apagada, al arrancar debería quedar todo apagado salvo LD0 cuando se habilita el control. Los LEDs significan esto.

- LD0, control habilitado.
- LD1, sobrecorriente.
- LD2, cuenta del ADC fuera de escala.
- LD3, falta de dato nuevo del ADC.
- LD4, error de arranque (incluye el offset medido fuera de tolerancia).

LD1 a LD3 marcan solo la primera causa que disparó, aunque después se sumen otras. Si se enciende alguno sin haber energizado nada, avísale a Mattio cuál fue, porque es justo lo que este cambio quería dejar ver.

## Qué no hacer

- No commitees nada de `vivado/` ni `vitis/`, se regeneran y están en el `.gitignore`.
- No toques código de `sw/` ni de `src/` por tu cuenta, esto es solo regenerar y cargar.
- Si Mattio te pide commitear algo, nada de `Co-Authored-By` ni menciones a Claude en el mensaje.
