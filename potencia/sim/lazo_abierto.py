# Ensayo en lazo abierto sobre el modelo de PLECS, corre cada Iref y saca la fundamental de la corriente
# Necesita PLECS abierto con la interfaz RPC activa en el puerto 1080
import math
import os
import xmlrpc.client

MODELO = "modelo-planta"
CORRIENTES = [1.0, 0.5, 0.2]
F_REF = 50.0

# Ventana de cuatro períodos de 50 Hz después del arranque, muestreada cada 1 µs
T_INICIO = 0.02
N_PERIODOS = 4
DT = 1e-6


def fundamental(x, f, dt):
    # Proyección de x sobre seno y coseno de f, x tiene que cubrir un número entero de períodos con paso dt
    n = len(x)
    a = sum(v * math.cos(2 * math.pi * f * k * dt) for k, v in enumerate(x)) * 2 / n
    b = sum(v * math.sin(2 * math.pi * f * k * dt) for k, v in enumerate(x)) * 2 / n
    # x = A*sin(w*t + fase), con b = A*cos(fase) y a = A*sin(fase)
    return math.hypot(a, b), math.degrees(math.atan2(a, b))


def main():
    rpc = xmlrpc.client.Server("http://localhost:1080/RPC2")
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), MODELO + ".plecs")
    # Se cierra y se vuelve a cargar para que PLECS lea el archivo del disco
    try:
        rpc.plecs.close(MODELO)
    except xmlrpc.client.Fault:
        pass
    rpc.plecs.load(ruta)

    n = round(N_PERIODOS / F_REF / DT)
    tiempos = [T_INICIO + k * DT for k in range(n)]
    print("Iref [A]   |d1|      |i1| [A]   desfase de i respecto de d [°]")
    for iref in CORRIENTES:
        opciones = {"ModelVars": {"Iref": iref}, "SolverOpts": {"OutputTimes": tiempos}}
        res = rpc.plecs.simulate(MODELO, opciones)
        i_amp, i_fase = fundamental(res["Values"][0], F_REF, DT)
        d_amp, d_fase = fundamental(res["Values"][1], F_REF, DT)
        print(f"{iref:<10.1f} {d_amp:<9.4f} {i_amp:<10.4f} {i_fase - d_fase:.2f}")


if __name__ == "__main__":
    main()
