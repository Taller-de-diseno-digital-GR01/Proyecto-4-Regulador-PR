# Ensayos en lazo cerrado sobre lazo_cerrado.plecs, con el PR de sw/pr_params.h en un C-Script
# Necesita PLECS abierto con la interfaz RPC activa en el puerto 1080
# Uso: python3 potencia/sim/lazo_cerrado.py, deja la tabla en pantalla y las formas de onda en potencia/sim/lazo_cerrado_*.csv
import csv
import math
import os
import xmlrpc.client

MODELO = "lazo_cerrado"
F_REF = 50.0
DT = 2e-6
T_FIN = 0.2 # diez períodos, el error se mide en los cinco últimos
N_PERIODOS = 5
R_MEDIDA = 11.8 # carga completa medida el 24.11
R_CAMBIO = 14.3 # con los 2,5 Ω del ensayo de cambio de carga

# Iref pico, Vdc, R; los de 1,0 A van con 18 V como en el banco
ENSAYOS = [
    (0.2, 12.5, R_MEDIDA),
    (0.5, 12.5, R_MEDIDA),
    (1.0, 12.5, R_MEDIDA),
    (1.0, 18.0, R_MEDIDA),
    (0.5, 12.5, R_CAMBIO),
    (1.0, 18.0, R_CAMBIO),
]


def fundamental(t, x, f):
    # Ajuste por mínimos cuadrados de a*cos + b*sen + c, igual que analizar_csv.m y receptor_pc.py
    w = 2 * math.pi * f
    n = len(x)
    sc = sum(math.cos(w * ti) for ti in t); ss = sum(math.sin(w * ti) for ti in t)
    scc = sum(math.cos(w * ti) ** 2 for ti in t); sss = sum(math.sin(w * ti) ** 2 for ti in t)
    scs = sum(math.cos(w * ti) * math.sin(w * ti) for ti in t)
    sxc = sum(xi * math.cos(w * ti) for ti, xi in zip(t, x)); sxs = sum(xi * math.sin(w * ti) for ti, xi in zip(t, x)); sx = sum(x)
    m = [[scc, scs, sc], [scs, sss, ss], [sc, ss, n]]
    v = [sxc, sxs, sx]
    for k in range(3): # eliminación de Gauss, el sistema es de 3x3
        for j in range(k + 1, 3):
            q = m[j][k] / m[k][k]
            m[j] = [mj - q * mk for mj, mk in zip(m[j], m[k])]
            v[j] -= q * v[k]
    c = v[2] / m[2][2]
    b = (v[1] - m[1][2] * c) / m[1][1]
    a = (v[0] - m[0][1] * b - m[0][2] * c) / m[0][0]
    return math.hypot(a, b), math.degrees(math.atan2(a, b)), c # x = A sen(wt + fase) + c


def main():
    rpc = xmlrpc.client.Server("http://localhost:1080/RPC2")
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), MODELO + ".plecs")
    try:
        rpc.plecs.close(MODELO)
    except xmlrpc.client.Fault:
        pass
    rpc.plecs.load(ruta)

    tiempos = [k * DT for k in range(round(T_FIN / DT) + 1)]
    t0 = T_FIN - N_PERIODOS / F_REF
    print("Iref [A]  Vdc [V]  R [ohm]  |i1| [A]  error [%]  desfase [°]  |d1|    d max  rizado pp [A]")
    for iref, vdc, r in ENSAYOS:
        opciones = {"ModelVars": {"Iref": iref, "Vdc": vdc, "R": r}, "SolverOpts": {"OutputTimes": tiempos, "TimeSpan": T_FIN}}
        res = rpc.plecs.simulate(MODELO, opciones)
        i, d = res["Values"][0], res["Values"][1]
        ventana = [k for k, ti in enumerate(tiempos) if ti >= t0]
        tv = [tiempos[k] for k in ventana]
        i_amp, i_fase, _ = fundamental(tv, [i[k] for k in ventana], F_REF)
        d_amp, _, _ = fundamental(tv, [d[k] for k in ventana], F_REF)
        error = (i_amp - iref) / iref * 100
        # rizado, pico a pico de la corriente menos su promedio móvil de un período de conmutación (50 µs)
        n_sw = round(50e-6 / DT)
        iv = [i[k] for k in ventana]
        prom = [sum(iv[k - n_sw:k]) / n_sw for k in range(n_sw, len(iv))]
        rizado = max(a - p for a, p in zip(iv[n_sw:], prom)) - min(a - p for a, p in zip(iv[n_sw:], prom))
        print(f"{iref:<9.1f} {vdc:<8.1f} {r:<8.1f} {i_amp:<9.4f} {error:<+10.2f} {i_fase:<+12.2f} {d_amp:<6.3f} {max(abs(x) for x in d):<6.3f} {rizado:.3f}")
        nombre = os.path.join(os.path.dirname(ruta), f"lazo_cerrado_{iref:.1f}A_{vdc:.1f}V_{r:.1f}ohm.csv")
        with open(nombre, "w", newline="") as archivo:
            escritor = csv.writer(archivo)
            escritor.writerow(["t_s", "corriente_a", "duty"])
            escritor.writerows(zip(tiempos, i, d))


if __name__ == "__main__":
    main()
