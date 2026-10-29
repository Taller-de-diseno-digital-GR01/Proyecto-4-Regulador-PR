// docs/diseño/modulos/ref_senoidal.md
#ifndef REF_SENOIDAL_H
#define REF_SENOIDAL_H

#include <stdint.h>
#include "numerico.h"

void ref_senoidal_iniciar(uint32_t frecuencia_muestreo_hz);
void ref_senoidal_reiniciar_fase(void);
valor_t ref_senoidal_siguiente(valor_t amplitud_ref);

#endif
