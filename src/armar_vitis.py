import os
import shutil
import sys
import vitis

# Arma la plataforma y compila control_pr en Vitis a partir del .xsa que deja Vivado
# Uso: vitis -s src/armar_vitis.py <xsa> <carpeta_workspace>
# Pide Vitis 2025.1 unificado (API por Python, ya no XSCT)

xsa = sys.argv[1]
workspace = sys.argv[2]

cliente = vitis.create_client()
cliente.set_workspace(path=workspace)

plataforma = cliente.create_platform_component(name="plataforma", hw_design=xsa)
# El CPU es microblaze_riscv_0 por como lo arma src/bd/sistema.tcl, coincide con lscript.ld
plataforma.add_domain(name="dominio_mb", cpu="microblaze_riscv_0", os="standalone")
plataforma.build()

# TODO: Revisar el id de template contra el Vitis instalado, "empty_application" es lo esperado en 2025.1 pero no se confirmo sin la IDE a mano
app = cliente.create_app_component(
    name="control_pr",
    platform=os.path.join(workspace, "plataforma", "export", "plataforma", "plataforma.xpfm"),
    domain="dominio_mb",
    template="empty_application",
)

# UserConfig.cmake y lscript.ld versionados ya traen los .c de sw/ y el mapa de memoria real, pisan los que genera la plantilla
destino = os.path.join(workspace, "control_pr")
shutil.copy("sw/config_vitis/UserConfig.cmake", os.path.join(destino, "UserConfig.cmake"))
shutil.copy("sw/config_vitis/lscript.ld", os.path.join(destino, "lscript.ld"))

app.build()
cliente.dispose()
