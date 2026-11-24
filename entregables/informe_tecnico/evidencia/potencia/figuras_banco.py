import csv
import matplotlib
matplotlib.use("Agg") # sin ventana, solo el png del informe
import matplotlib.pyplot as plt

ENSAYOS = [
    ("muestras_Inversor/0.2A_18-52.csv", "0,2 A, carga original"),
    ("muestras_Inversor/0.5A_18-53.csv", "0,5 A, carga original"),
    ("muestras_Inversor/1A_18-55.csv", "1,0 A, carga original, 12,5 V"),
    ("muestras_Inversor/muestras_recorte/1A_10-22.csv", "1,0 A, carga original, 18 V"),
    ("muestras_Inversor/muestras_prueba_25/0.5A_10-15.csv", "0,5 A, carga +2,5 Ω"),
    ("muestras_Inversor/muestras_prueba_25/1A_10-16.csv", "1,0 A, carga +2,5 Ω, 12,5 V"),
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
