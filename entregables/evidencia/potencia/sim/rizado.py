# Rizado de conmutación sobre el modelo de PLECS en lazo abierto, para cada Iref, comparado con la fórmula del promedio unipolar
# Necesita PLECS abierto con la interfaz RPC activa en el puerto 1080
import bisect
import math
import os
import re
import xmlrpc.client

MODELO = "modelo-planta"
CORRIENTES = [1.0, 0.5, 0.2]

# Un período de 50 Hz ya en régimen (τ = L/R es 0,2 ms)
T_INICIO = 0.04
T_FIN = 0.06

CARPETA = os.path.dirname(os.path.abspath(__file__))


def leer_parametros(ruta):
    # Evalúa las asignaciones simples de parametros.m en orden, así L, Vdc y fsw salen del mismo archivo que usa el modelo
    p = {}
    with open(ruta, encoding="utf-8") as f:
        for linea in f:
            linea = linea.split("%")[0].strip()
            m = re.fullmatch(r"(\w+)\s*=\s*([^;]+);", linea)
            if m:
                p[m.group(1)] = eval(m.group(2), {"__builtins__": {}}, p)
    return p


def promedio(t, x, ta, tb):
    # Promedio de x entre ta y tb con trapecios sobre los pasos del solver
    k0 = bisect.bisect_left(t, ta)
    k1 = bisect.bisect_right(t, tb)
    area = sum((t[k + 1] - t[k]) * (x[k] + x[k + 1]) / 2 for k in range(k0, k1 - 1))
    return area / (t[k1 - 1] - t[k0])


def rizado_por_periodo(t, i, ts):
    # Resta la componente lenta (promedio de cada período interpolado entre centros) y toma máximo menos mínimo en cada período
    n = int((T_FIN - T_INICIO) / ts + 1e-9)
    bordes = [T_INICIO + k * ts for k in range(n + 1)]
    centros = [b + ts / 2 for b in bordes[:-1]]
    medias = [promedio(t, i, bordes[k], bordes[k + 1]) for k in range(n)]
    pp = []
    for k in range(1, n - 1):
        lo = bisect.bisect_left(t, bordes[k])
        hi = bisect.bisect_right(t, bordes[k + 1])
        resto = []
        for j in range(lo, hi):
            c = centros[k - 1] if t[j] < centros[k] else centros[k]
            m0 = medias[k - 1] if t[j] < centros[k] else medias[k]
            m1 = medias[k] if t[j] < centros[k] else medias[k + 1]
            lenta = m0 + (m1 - m0) * (t[j] - c) / ts
            resto.append(i[j] - lenta)
        pp.append((bordes[k], max(resto) - min(resto)))
    return pp


def main():
    p = leer_parametros(os.path.join(CARPETA, "parametros.m"))
    vdc, L, R, fsw, ts = p["Vdc"], p["L"], p["R"], p["fsw"], p["Ts"]
    zabs = abs(complex(R, 2 * math.pi * p["fref"] * L))

    rpc = xmlrpc.client.Server("http://localhost:1080/RPC2")
    ruta = os.path.join(CARPETA, MODELO + ".plecs")
    # Se cierra y se vuelve a cargar para que PLECS lea el archivo del disco
    try:
        rpc.plecs.close(MODELO)
    except xmlrpc.client.Fault:
        pass
    rpc.plecs.load(ruta)

    # En lazo abierto el tiempo muerto le resta 2·TM·fsw al d que llega a la carga
    dd = 2 * p["TM"] * fsw

    def delta_i(d):
        # Δi = Vdc·d·(1 − d)/(2·L·fsw), el máximo del ciclo está en el pico de d o en 0,5 si d pasa por ahí
        d = min(max(d, 0.0), 0.5)
        return vdc * d * (1 - d) / (2 * L * fsw)

    print(f"Vdc = {vdc} V, L = {L * 1e3} mH, fsw = {fsw / 1e3} kHz, pérdida del tiempo muerto {dd:.3f} en d")
    print("Iref [A]   m        teoría con m [A]   teoría con m - Δd [A]   PLECS [A]   diferencia   instante del máximo [ms]")
    for iref in CORRIENTES:
        # Sin OutputTimes PLECS devuelve los pasos del solver, que caen en las conmutaciones donde están los extremos
        res = rpc.plecs.simulate(MODELO, {"ModelVars": {"Iref": iref}})
        t = res["Time"]
        i = res["Values"][0]
        pp = rizado_por_periodo(t, i, ts)
        t_max, pp_max = max(pp, key=lambda e: e[1])
        m = zabs * iref / vdc
        ideal = delta_i(m)
        con_tm = delta_i(m - dd)
        print(f"{iref:<10.1f} {m:<8.3f} {ideal:<18.4f} {con_tm:<23.4f} {pp_max:<11.4f} {100 * (pp_max / con_tm - 1):+.1f} %       {t_max * 1e3:.2f}")


if __name__ == "__main__":
    main()
