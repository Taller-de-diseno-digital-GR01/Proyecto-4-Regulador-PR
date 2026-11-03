# python receptor_pc.py [puerto o trama.bin] [-o muestras.csv]
import argparse
import csv
import os
import struct
import sys
from collections import namedtuple

import numpy as np

import enlace

TRAMA_INICIO = 0xAA # igual que en el P3
CABECERA = struct.Struct("<HIfffB") # los 19 bytes después del 0xAA, little-endian como el MB V
SUMA = struct.Struct("<H") # uint16 al final
REGISTRO_BYTES = 6 # registro_t, 3 uint16
CUENTA_MASCARA = 0x0FFF # 12 bits del ADC, arriba van las banderas
BANDERAS = (("saturado", 15), ("dato_ausente", 14), ("habilitado", 13), ("falla", 12)) # bits 15 a 12, mismos que buffer_muestras.h
F_RED_HZ = 50.0
PERIODOS_MINIMOS = 5 # lo que pide el instructivo para el error

Cabecera = namedtuple("Cabecera", "cantidad frecuencia_muestreo_hz adc_offset_cuentas amperes_por_cuenta duty_escala duty_con_signo")
Fundamental = namedtuple("Fundamental", "fasor componente")


class TramaInvalida(Exception):
    pass


def _exacto(leer, n):
    datos = bytearray()
    while len(datos) < n: # el puerto puede devolver menos de lo pedido
        trozo = leer(n - len(datos))
        if not trozo: # se acabó el timeout o el archivo
            raise TramaInvalida("trama cortada, llegaron %d de %d bytes" % (len(datos), n))
        datos += trozo
    return bytes(datos)


def leer_trama(leer, esperar_inicio=True): # leer = read del puerto o del archivo
    descartadas = 0
    while True:
        byte = leer(1)
        if not byte: # timeout sin nada
            if esperar_inicio: # con el puerto se sigue esperando al botón
                continue
            raise TramaInvalida("no hay ninguna trama válida (%d descartadas)" % descartadas)
        if byte[0] != TRAMA_INICIO: # basura antes del inicio
            continue
        cabecera = _exacto(leer, CABECERA.size) # ojo, un 0xAA a media trama NO resincroniza como en el P3, los registros pueden traer 0xAA
        cantidad = CABECERA.unpack(cabecera)[0] # N, el primer campo
        resto = _exacto(leer, REGISTRO_BYTES * cantidad + SUMA.size)
        (suma,) = SUMA.unpack(resto[-SUMA.size:]) # los 2 últimos bytes
        if (sum(cabecera) + sum(resto[:-SUMA.size])) & 0xFFFF == suma: # módulo 2^16, sin el 0xAA
            return byte + cabecera + resto
        descartadas += 1 # suma mala, se tira entera y se busca otro 0xAA


def desempacar(trama):
    cabecera = Cabecera(*CABECERA.unpack_from(trama, 1)) # desde el 1 para saltarse el 0xAA
    duty_tipo = "<i2" if cabecera.duty_con_signo else "<u2" # Q2.14 viene con signo
    registros = np.frombuffer(trama, dtype=[("cuenta_banderas", "<u2"), ("duty_ref", duty_tipo), ("i_ref_ma", "<i2")],
                              count=cabecera.cantidad, offset=1 + CABECERA.size) # los registros arrancan en el byte 20
    cuenta = (registros["cuenta_banderas"] & CUENTA_MASCARA).astype(float) # se le quitan las banderas
    muestras = {
        "t_s": np.arange(cabecera.cantidad) / cabecera.frecuencia_muestreo_hz, # n / fs
        "corriente_a": (cuenta - cabecera.adc_offset_cuentas) * cabecera.amperes_por_cuenta,
        "i_ref_a": registros["i_ref_ma"] / 1000.0, # viene en mA
        "duty": registros["duty_ref"] * float(cabecera.duty_escala),
    }
    for nombre, bit in BANDERAS: # una columna 0/1 por bandera
        muestras[nombre] = (registros["cuenta_banderas"] >> bit) & 1
    return cabecera, muestras


def ventana(t): # últimos periodos enteros de 50 Hz, el final es lo más cerca del régimen
    periodos = int(np.floor((t[-1] - t[0]) * F_RED_HZ + 1e-9)) if len(t) > 1 else 0 # el 1e-9 es para que 4.9999999 cuente como 5
    if periodos < PERIODOS_MINIMOS: # con menos el error no vale
        raise ValueError("el histórico cubre %d períodos de 50 Hz y hacen falta %d" % (periodos, PERIODOS_MINIMOS))
    return t >= t[-1] - periodos / F_RED_HZ # máscara de las muestras que entran


def fundamental(t, x):
    w = 2 * np.pi * F_RED_HZ
    base = np.column_stack((np.cos(w * t), np.sin(w * t), np.ones_like(t))) # a cos + b sen + c, la c se come el offset
    (a, b, c), *_ = np.linalg.lstsq(base, x, rcond=None) # mínimos cuadrados, sirve aunque fs no sea múltiplo de 50
    return Fundamental(fasor=complex(a, -b), componente=base @ (a, b, c)) # a cos + b sen = Re{(a - jb) e^jwt}


def analizar(muestras):
    en = ventana(muestras["t_s"])
    t = muestras["t_s"][en]
    corriente = fundamental(t, muestras["corriente_a"][en])
    referencia = fundamental(t, muestras["i_ref_a"][en])
    i1, r1 = corriente.fasor, referencia.fasor
    residuo = muestras["corriente_a"][en] - corriente.componente # lo que queda sin la fundamental
    return {
        "periodos": round((t[-1] - t[0]) * F_RED_HZ),
        "amplitud_corriente_a": abs(i1),
        "fase_corriente_grados": np.degrees(np.angle(i1)),
        "amplitud_referencia_a": abs(r1),
        "fase_referencia_grados": np.degrees(np.angle(r1)),
        "error_amplitud_pct": (abs(i1) - abs(r1)) / abs(r1) * 100, # el criterio del 10 %
        "desfase_grados": np.degrees(np.angle(i1 / r1)), # ángulo del cociente = resta de fases, sin problema de dar la vuelta en 180
        "error_fasor_pct": abs(i1 - r1) / abs(r1) * 100, # mezcla amplitud y fase, solo de dato
        "residuo_pp_a": residuo.max() - residuo.min(),
        "fuera_de_regimen": bool(np.any(muestras["habilitado"][en] == 0) or np.any(muestras["falla"][en])),
    }


def escribir_csv(ruta, muestras):
    columnas = ["t_s", "corriente_a", "i_ref_a", "duty"] + [nombre for nombre, _ in BANDERAS]
    with open(ruta, "w", newline="") as archivo:
        escritor = csv.writer(archivo)
        escritor.writerow(columnas)
        escritor.writerows(zip(*(muestras[c].tolist() for c in columnas)))


def reportar(r):
    print("ventana de %d períodos de 50 Hz" % r["periodos"])
    print("corriente   %.4f A  %7.2f°" % (r["amplitud_corriente_a"], r["fase_corriente_grados"]))
    print("referencia  %.4f A  %7.2f°" % (r["amplitud_referencia_a"], r["fase_referencia_grados"]))
    print("error de amplitud de la fundamental %+.2f %% (límite 10 %%)" % r["error_amplitud_pct"])
    print("desfase %+.2f°" % r["desfase_grados"])
    print("error del fasor %.2f %%, dato extra" % r["error_fasor_pct"])
    print("residuo de baja frecuencia %.4f A pp, no es el rizado de conmutación, ese va con el osciloscopio" % r["residuo_pp_a"])
    if r["fuera_de_regimen"]: # hubo falla o control apagado en la ventana
        print("OJO, la ventana tiene iteraciones deshabilitadas o en falla, el resultado no es de un ensayo en régimen")


def graficar(muestras):
    import matplotlib.pyplot as plt # acá adentro para que las pruebas no lo necesiten

    t_ms = muestras["t_s"] * 1000
    marcadas = (muestras["saturado"] == 1) | (muestras["falla"] == 1) # las que se pintan con x

    _, eje = plt.subplots()
    eje.plot(t_ms, muestras["corriente_a"], label="corriente medida")
    eje.plot(t_ms, muestras["i_ref_a"], label="referencia")
    eje.plot(t_ms[marcadas], muestras["corriente_a"][marcadas], "rx", label="saturado o en falla")
    eje.set_xlabel("t [ms]")
    eje.set_ylabel("i [A]")
    eje.legend()
    eje.grid(True)

    _, eje = plt.subplots()
    eje.plot(t_ms, muestras["duty"], label="duty")
    eje.plot(t_ms[marcadas], muestras["duty"][marcadas], "rx", label="saturado o en falla")
    eje.set_xlabel("t [ms]")
    eje.set_ylabel("índice de modulación")
    eje.legend()
    eje.grid(True)
    plt.show()


def main():
    argumentos = argparse.ArgumentParser(description="Recibe y grafica el histórico de exportador_uart")
    argumentos.add_argument("origen", nargs="?", help="puerto serie o archivo con una trama guardada, sin nada detecta la Basys 3")
    argumentos.add_argument("-o", "--csv", default="muestras.csv")
    argumentos = argumentos.parse_args()

    if argumentos.origen and os.path.isfile(argumentos.origen): # si es un archivo es una trama guardada, si no un puerto
        with open(argumentos.origen, "rb") as archivo:
            trama = leer_trama(archivo.read, esperar_inicio=False) # en un archivo no tiene sentido esperar
    else:
        with enlace.abrir(argumentos.origen) as puerto:
            print("esperando la exportación, apretá el botón en la Basys 3")
            trama = leer_trama(puerto.read)
        with open(os.path.splitext(argumentos.csv)[0] + ".bin", "wb") as archivo: # la cruda, para repetir el análisis sin placa
            archivo.write(trama)

    _, muestras = desempacar(trama)
    escribir_csv(argumentos.csv, muestras)
    print("%d registros en %s" % (len(muestras["t_s"]), argumentos.csv))
    reportar(analizar(muestras))
    graficar(muestras)


if __name__ == "__main__":
    try:
        main()
    except (TramaInvalida, ValueError, enlace.ErrorEnlace) as error:
        sys.exit("receptor_pc, %s" % error)
