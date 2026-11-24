"""Números del informe técnico de PEDP que salen de los registros de banco del 23 y 24/11.

Pico y RMS, armónicas, tensión aplicada estimada, corriente calibrada, deriva del cero y nivel de las capturas de rizado.
Se corre desde la raíz del repo con python3 potencia/analizar_registros.py
"""
import glob
import os

import numpy as np

CARPETA = "muestras_Inversor"
OSC = os.path.join(CARPETA, "Muestras Osciloscopio")
R_MEDIDA = 9.46  # ohm, resistencias sobre las que mide el osciloscopio
R_TOTAL = 11.8  # ohm, carga con devanados y cables
R_EXTRA = 2.5  # ohm, la del ensayo de cambio de carga
L_TOTAL = 212e-6  # H, un inductor medido y el otro supuesto igual
F_SW = 20e3
VDC = 12.5  # V nominal, el bus no se registró
K_FW, C0_FW = -1.1118e-3, 2808  # constantes con que se tomaron los registros, vienen en la cabecera
K_CAL, C0_CAL = -1.292e-3, 2569  # calibración contra el osciloscopio
KP_V = 0.25  # PR_KP, índice por ampere
W0 = 2 * np.pi * 50


def ajustar(t, y, armonica=1):
    """Senoidal de 50 Hz por la armónica más continua, por mínimos cuadrados."""
    m = np.c_[np.sin(armonica * W0 * t), np.cos(armonica * W0 * t), np.ones_like(t)]
    k = np.linalg.lstsq(m, y, rcond=None)[0]
    return np.hypot(k[0], k[1]), np.degrees(np.arctan2(k[1], k[0])), k[2], m @ k


def periodos_enteros(t):
    n = int(np.floor((t[-1] - t[0]) * 50 + 1e-9))
    return t <= t[0] + n / 50 + 1e-12


def leer_csv(ruta):
    d = np.genfromtxt(ruta, delimiter=",", names=True)
    sel = d["t_s"] >= d["t_s"][-1] - 0.1 + 1e-9  # últimos cinco períodos, igual que analizar_csv.m
    return {c: d[c][sel] for c in d.dtype.names}


def corriente_calibrada(i_fw):
    cuenta = i_fw / K_FW + C0_FW
    return (cuenta - C0_CAL) * K_CAL


def osciloscopio():
    print("Osciloscopio, corriente física")
    for nombre in ("0A", "0.2A", "0.5A", "1A"):
        o = np.genfromtxt(os.path.join(OSC, f"osc_{nombre}.csv"), delimiter=",", skip_header=2)
        t, i = o[:, 0], o[:, 1] / R_MEDIDA
        s = periodos_enteros(t)
        pico, _, dc, modelo = ajustar(t[s], i[s])
        resto = i[s] - modelo
        arm = [ajustar(t[s], resto, n)[0] for n in (3, 5, 7)]
        thd = np.sqrt(sum(a * a for a in arm)) / pico * 100 if pico > 0.05 else float("nan")
        print(f"  {nombre:5s} pico {pico:.4f} A | RMS fund {pico / np.sqrt(2):.4f} A | RMS total {np.sqrt(np.mean(i[s] ** 2)):.4f} A"
              f" | continua {dc:+.4f} A | h3 {arm[0]:.4f} h5 {arm[1]:.4f} h7 {arm[2]:.4f} A | THD hasta la 7.a {thd:.1f} %")


def tension_aplicada():
    print("Tensión aplicada estimada, fundamental del índice por Vdc (ideal, sin tiempo muerto)")
    registros = [("0.2A_18-52", R_TOTAL, VDC), ("0.5A_18-53", R_TOTAL, VDC), ("1A_18-55", R_TOTAL, VDC),
                 ("muestras_recorte/1A_10-22", R_TOTAL, 18.0),
                 ("muestras_prueba_25/0.2A_10-15", R_TOTAL + R_EXTRA, VDC),
                 ("muestras_prueba_25/0.5A_10-15", R_TOTAL + R_EXTRA, VDC),
                 ("muestras_prueba_25/1A_10-16", R_TOTAL + R_EXTRA, VDC)]
    res = {}
    for nombre, r, vdc in registros:
        d = leer_csv(os.path.join(CARPETA, nombre + ".csv"))
        m1 = ajustar(d["t_s"], d["duty"])[0]
        i_s = ajustar(d["t_s"], d["corriente_a"])[0]
        i_cal, _, dc_cal, _ = ajustar(d["t_s"], corriente_calibrada(d["corriente_a"]))
        ref = ajustar(d["t_s"], d["i_ref_a"])[0]
        res[nombre] = (m1, m1 * vdc, i_cal)
        print(f"  {nombre:30s} R {r:.1f} ohm, Vdc {vdc:.1f} V | m1 {m1:.3f} | V1 {m1 * vdc:5.2f} V | sensor {i_s:.4f} A"
              f" | calibrada {i_cal:.4f} A ({(i_cal - ref) / ref * 100:+.1f} %) | continua calibrada {dc_cal:+.3f} A | saturadas {int(d['saturado'].sum())}")
    return res


def recta(res, osc_02, osc_05):
    print("Recta V1 = Z I1 + V0 con los puntos de 0,2 y 0,5 A")
    v = np.array([res["0.2A_18-52"][1], res["0.5A_18-53"][1]])
    z = (v[1] - v[0]) / (osc_05 - osc_02)
    print(f"  carga nominal con el osciloscopio, Z {z:.2f} ohm, V0 {v[0] - z * osc_02:.2f} V")
    v = np.array([res["muestras_prueba_25/0.2A_10-15"][1], res["muestras_prueba_25/0.5A_10-15"][1]])
    i = np.array([res["muestras_prueba_25/0.2A_10-15"][2], res["muestras_prueba_25/0.5A_10-15"][2]])
    z = (v[1] - v[0]) / (i[1] - i[0])
    print(f"  +2,5 ohm con la corriente calibrada, Z {z:.2f} ohm, V0 {v[0] - z * i[0]:.2f} V")
    m_nom, m_25 = res["0.5A_18-53"][0], res["muestras_prueba_25/0.5A_10-15"][0]
    print(f"  a 0,5 A el índice sube {m_25 / m_nom:.3f} veces y la resistencia {(R_TOTAL + R_EXTRA) / R_TOTAL:.3f}")
    print(f"  fundamental de la pérdida por tiempo muerto, (4/pi) 2 td fsw Vdc = {4 / np.pi * 2 * 1e-6 * F_SW * VDC:.2f} V")


def deriva_cero():
    print("Cero implícito en lazo cerrado con referencia nula, modelo del proporcional")
    for nombre, r in (("0A_18-50", R_TOTAL), ("muestras_prueba_25/0A_10-14", R_TOTAL + R_EXTRA)):
        d = leer_csv(os.path.join(CARPETA, nombre + ".csv"))
        i_s = d["corriente_a"].mean()
        i_p = -KP_V * VDC / r * i_s  # el proporcional aplica tensión continua contra el error del sensor
        c0 = C0_FW - (i_s - i_p * K_FW / K_CAL) / -K_FW  # I_s = I_p k/k' + (c0_fw - c0) |k|
        print(f"  {nombre:30s} continua del sensor {i_s:+.3f} A | física estimada {i_p:+.3f} A | cero {c0:.0f} cuentas")


def rizado():
    print(f"Capturas de rizado, Vdc {VDC} V y L {L_TOTAL * 1e6:.0f} uH")
    for ruta in sorted(glob.glob(os.path.join(OSC, "rizado", "scope_a*.csv"))):
        o = np.genfromtxt(ruta, delimiter=",", skip_header=2)
        v = o[:, 1][~np.isnan(o[:, 1])]
        i = np.mean(v) / R_MEDIDA
        m = R_TOTAL * abs(i) / VDC
        teo = VDC * m * (1 - m) / (2 * L_TOTAL * F_SW)  # unipolar, Vdc m (1 - m) Ts / (2 L)
        print(f"  {os.path.basename(ruta):12s} nivel {i:+.3f} A | m {m:.3f} | rizado teórico {teo:.3f} A pp")
    print(f"  máximo teórico en m = 0,5, {VDC / (8 * L_TOTAL * F_SW):.3f} A pp")


if __name__ == "__main__":
    osciloscopio()
    res = tension_aplicada()
    recta(res, 0.2284, 0.5928)
    deriva_cero()
    rizado()
