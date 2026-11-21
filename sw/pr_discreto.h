#ifndef PR_DISCRETO_H
#define PR_DISCRETO_H

#include <stdbool.h>
#include <stdint.h>
#include "numerico.h"

#define DUTY_ESCALA (1.0f / 16384.0f) // Q2.14 --> 1.0 = 0x4000 = 16384, lo fijó Jefferson
#define DUTY_CON_SIGNO 1u // complemento a 2, el receptor_pc lo lee de la cabecera

void pr_discreto_reiniciar(void);
uint16_t pr_discreto_calcular(valor_t i_ref, valor_t corriente, bool *saturado); // devuelve m_ref ya en Q2.14, listo pa duty_ref

#endif
