import csv
import matplotlib
matplotlib.use("Agg") # sin ventana, solo el png del informe
import matplotlib.pyplot as plt

# Mediciones finales del 25.11 con 18 V, columna izquierda carga original y derecha carga +25 %
CARPETA = "muestras_Inversor/mediciones_finales/"
ENSAYOS = [
    (CARPETA + "0.2A.csv", "0,2 A, carga original"),
    (CARPETA + "carga25_0.2A.csv", "0,2 A, carga +25 %"),
    (CARPETA + "0.5A.csv", "0,5 A, carga original"),
    (CARPETA + "carga25_0.5A.csv", "0,5 A, carga +25 %"),
    (CARPETA + "1.0A.csv", "1,0 A, carga original"),
    (CARPETA + "carga25_1.0A.csv", "1,0 A, carga +25 %"),
]

fig, ejes = plt.subplots(3, 2, figsize=(10, 8), sharex=True)
for (ruta, titulo), eje in zip(ENSAYOS, ejes.flat):
    filas = list(csv.DictReader(open(ruta)))
    t = [1e3 * float(f["t_s"]) for f in filas]
    eje.plot(t, [float(f["i_ref_a"]) for f in filas], label="referencia")
    eje.plot(t, [float(f["corriente_a"]) for f in filas], label="corriente del CSV")
    sat = [(x, float(f["corriente_a"])) for x, f in zip(t, filas) if f["saturado"] == "1"]
    if sat: eje.plot(*zip(*sat), "k.", ms=3, label="saturado")
    eje.set_title(titulo, fontsize=9)
    eje.grid(True)
for eje in ejes[-1]: eje.set_xlabel("t (ms)")
for eje in ejes[:, 0]: eje.set_ylabel("i (A)")
ejes[0, 0].legend(fontsize=8)
fig.tight_layout()
fig.savefig("docs/informe/figuras/banco_regimen.png", dpi=110)
