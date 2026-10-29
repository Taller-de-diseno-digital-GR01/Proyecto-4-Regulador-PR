# Genera sw/pr_params.h a partir del PR de PEDP, ver docs/diseño/modulos/pr_discreto.md
# Esqueleto, ningún valor del PR está acordado todavía y el script no inventa ninguno.

import argparse
from pathlib import Path

METODOS = ("tustin", "tustin_prewarp", "zoh", "impulso")
ESTRUCTURAS = ("ideal", "amortiguado")


def coeficientes_resonante(estructura, kr, frecuencia_muestreo_hz, metodo, amortiguamiento=None):
    """Devuelve (b0, b1, b2, a1, a2) del término resonante discretizado."""
    # TODO: Revisar con PEDP la estructura y el método, hasta entonces no hay fórmula que implementar
    raise NotImplementedError(f"resonante {estructura} con {metodo} sin definir")


def escribir_header(ruta, frecuencia_muestreo_hz, kp, coef, u_max):
    b0, b1, b2, a1, a2 = coef
    lineas = [
        "// Generado por sw/generar_pr_params.py, no editar a mano",
        "#ifndef PR_PARAMS_H",
        "#define PR_PARAMS_H",
        "",
        '#include "numerico.h"',
        "",
        f"#define PR_FRECUENCIA_MUESTREO_HZ {frecuencia_muestreo_hz}u",
        f"#define PR_KP VALOR({kp!r}f)",
        f"#define PR_B0 VALOR({b0!r}f)",
        f"#define PR_B1 VALOR({b1!r}f)",
        f"#define PR_B2 VALOR({b2!r}f)",
        f"#define PR_A1 VALOR({a1!r}f)",
        f"#define PR_A2 VALOR({a2!r}f)",
        f"#define PR_U_MAX VALOR({u_max!r}f)",
        "",
        "#endif",
        "",
    ]
    Path(ruta).write_text("\n".join(lineas))


def main():
    p = argparse.ArgumentParser(description="Coeficientes del PR discreto para el MicroBlaze V")
    p.add_argument("--estructura", choices=ESTRUCTURAS, required=True)
    p.add_argument("--metodo", choices=METODOS, required=True)
    p.add_argument("--kp", type=float, required=True, help="ganancia proporcional de PEDP, en V/A")
    p.add_argument("--kr", type=float, required=True, help="ganancia resonante de PEDP")
    p.add_argument("--amortiguamiento", type=float, help="solo con --estructura amortiguado")
    p.add_argument("--vdc", type=float, required=True, help="tensión del bus, el 1/Vdc se mete en los coeficientes")
    p.add_argument("--fs", type=int, required=True, help="frecuencia de muestreo en Hz")
    p.add_argument("--u-max", type=float, required=True, help="índice de modulación máximo, dentro del rango del PWM")
    p.add_argument("--salida", default=Path(__file__).with_name("pr_params.h"))
    a = p.parse_args()

    if a.estructura == "amortiguado" and a.amortiguamiento is None:
        p.error("--estructura amortiguado necesita --amortiguamiento")

    b0, b1, b2, a1, a2 = coeficientes_resonante(a.estructura, a.kr, a.fs, a.metodo, a.amortiguamiento)
    # El PR calcula tensión y el PWM recibe índice de modulación, así la interrupción no divide entre Vdc
    escala = 1.0 / a.vdc
    escribir_header(a.salida, a.fs, a.kp * escala, (b0 * escala, b1 * escala, b2 * escala, a1, a2), a.u_max)


if __name__ == "__main__":
    main()
