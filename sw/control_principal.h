// docs/diseño/modulos/control_principal.md
#ifndef CONTROL_PRINCIPAL_H
#define CONTROL_PRINCIPAL_H

#include "pr_params.h"

#define FREQ_SEL_INICIAL 1u // 01 = 20 kHz, la única con la que se cierra el lazo
#define RELOJ_HZ 100000000u
#define TIMER_TLR (RELOJ_HZ / PR_FRECUENCIA_MUESTREO_HZ - 2u) // el AXI Timer cuenta tlr + 2 ciclos por período

// TODO: Revisar en integración con la salida de depuración, provisionales de control_principal.md h.6
#define SONDEO_MAX_LECTURAS 100000u
#define MARGEN_ARRANQUE_VUELTAS 40u

void control_principal_arrancar(void);
void control_principal_vuelta(void);

#endif
