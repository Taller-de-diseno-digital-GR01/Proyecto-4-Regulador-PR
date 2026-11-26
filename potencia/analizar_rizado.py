"""Rizado de conmutación a partir de un CSV del GW Instek (tensión sobre la resistencia de carga).

Uso desde la raíz del repo:
    python3 potencia/analizar_rizado.py <csv> <R_ohm> [figura.png] ["título"]
"""
import sys
import numpy as np

F_SW = 20e3
# Ventana de la mediana, 1 µs, para quitar los picos de conmutación de la punta
T_MEDIANA = 1e-6


def leer_gwinstek(ruta):
    lineas = open(ruta).read().splitlines()
    inicio = lineas.index("Waveform Data,") + 1
    datos = np.array([[float(x) for x in l.split(",")[:2]] for l in lineas[inicio:] if l.strip()])
    return datos[:, 0], datos[:, 1]


def mediana_movil(x, k):
    h = k // 2
    ventanas = np.lib.stride_tricks.sliding_window_view(np.pad(x, h, mode="edge"), k)
    return np.median(ventanas, axis=1)


def analizar(ruta, r_ohm):
    t, v = leer_gwinstek(ruta)
    dt = t[1] - t[0]
    k = int(round(T_MEDIANA / dt)) | 1
    v_filtrada = mediana_movil(v, k)
    # El promedio sobre un período de f_sw cancela el rizado de 2·f_sw y deja la componente de 50 Hz
    n = int(round(1 / F_SW / dt))
    baja = np.convolve(v_filtrada, np.ones(n) / n, mode="valid")
    t_baja = t[n // 2:n // 2 + len(baja)]
    rizado = v_filtrada[n // 2:n // 2 + len(baja)] - baja
    # Pico a pico por cada período de la tensión de salida (2·f_sw en unipolar)
    m = n // 2
    pp_periodo = [np.ptp(v_filtrada[a:a + m]) for a in range(0, len(v) - m + 1, m)]
    res = {
        "dt": dt,
        "muestras_mediana": k,
        "pp_crudo": np.ptp(v),
        "pp_sin_picos": np.ptp(v_filtrada),
        "baja_media": baja.mean(),
        "baja_deriva": np.ptp(baja),
        "rizado_pp": np.ptp(rizado),
        "pp_periodo": np.array(pp_periodo),
        "pico_max": np.max(np.abs(v - v_filtrada)),
    }
    return res, (t, v, v_filtrada, t_baja, baja)


def graficar(ruta_png, senales, res, r_ohm, titulo):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    t, v, v_filtrada, t_baja, baja = senales
    fig, eje = plt.subplots(figsize=(9, 4))
    eje.plot(1e6 * t, v / r_ohm, color="0.75", lw=0.6, label="medición cruda")
    eje.plot(1e6 * t, v_filtrada / r_ohm, lw=1, label="sin picos (mediana de 1 µs)")
    eje.plot(1e6 * t_baja, baja / r_ohm, "k--", lw=1, label="baja frecuencia (promedio de 50 µs)")
    eje.set_xlabel("t (µs)")
    eje.set_ylabel("i (A)")
    eje.set_title(f"{titulo}, rizado {res['rizado_pp'] / r_ohm:.3f} A pp".replace(".", ","))
    eje.grid(True)
    eje.legend(fontsize=8, loc="lower right")
    fig.tight_layout()
    fig.savefig(ruta_png, dpi=110)


if __name__ == "__main__":
    ruta = sys.argv[1]
    r_ohm = float(sys.argv[2])
    res, senales = analizar(ruta, r_ohm)
    print(f"Archivo {ruta}, R = {r_ohm} Ω, muestreo {res['dt'] * 1e9:.0f} ns, mediana de {res['muestras_mediana']} muestras")
    print(f"Pico a pico crudo {res['pp_crudo']:.2f} V, sin picos {res['pp_sin_picos']:.2f} V, picos de hasta {res['pico_max']:.2f} V")
    print(f"Baja frecuencia {res['baja_media']:.2f} V = {res['baja_media'] / r_ohm:.3f} A, deriva en la ventana {res['baja_deriva']:.2f} V")
    print(f"Rizado respecto de la baja frecuencia {res['rizado_pp']:.2f} V pp = {res['rizado_pp'] / r_ohm:.3f} A pp")
    print("Pico a pico por período de 25 µs (A):", np.round(res["pp_periodo"] / r_ohm, 3))
    if len(sys.argv) > 3:
        titulo = sys.argv[4] if len(sys.argv) > 4 else ruta
        graficar(sys.argv[3], senales, res, r_ohm, titulo)
