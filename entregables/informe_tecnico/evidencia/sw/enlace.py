# AQUÍ se hace la conexión con la fpga. Queda pendiente verificar que esta conexión funcione bien con mi FreeBSD porque hay una situación de drivers rara.
# En linux funciona bien :+1:

import serial
from serial.tools import list_ports

BAUDIOS = 115200
VID_FTDI = 0x0403
PID_FT2232 = 0x6010


class ErrorEnlace(Exception): # Custom, es para cuando NO se conecta. Probablemente lo conectemos con el make
    pass


def puertos_de_la_tarjeta():
    """Los puertos que expone el FT2232 de la Basys 3, ordenados por interfaz."""
    hallados = [p for p in list_ports.comports()
                if p.vid == VID_FTDI and p.pid == PID_FT2232]
    return sorted(hallados, key=lambda p: (p.location or "", p.device))


def detectar_puerto():
    puertos = puertos_de_la_tarjeta()
    if not puertos:
        raise ErrorEnlace(
            "no aparece ninguna Basys 3 conectada.\n"
            "Revisá que el cable sea de datos, que SW16 esté en ON, y en FreeBSD que el\n"
            "módulo uftdi esté cargado (si venís de programar, hay que volver a cargarlo)."
        )
    # el FT2232 saca dos canales, el primero es el del JTAG y el segundo el del puente USB-UART
    return puertos[-1].device


def abrir(puerto=None, baudios=BAUDIOS, espera_s=2.0):
    if puerto is None:
        puerto = detectar_puerto()
    try:
        return serial.Serial(puerto, baudios, timeout=espera_s) # con timeout, si la trama se corta no se queda pegado
    except serial.SerialException as error:
        raise ErrorEnlace("no se pudo abrir %s, %s" % (puerto, error))
