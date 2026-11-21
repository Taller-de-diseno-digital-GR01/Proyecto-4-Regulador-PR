// docs/diseño/modulos/supervisor_falla.md
#ifndef SUPERVISOR_FALLA_H
#define SUPERVISOR_FALLA_H

#include <stdbool.h>
#include <stdint.h>
#include "numerico.h"

// TODO: Revisar con la etapa de potencia, provisional en 1,0 A pico de los ensayos más margen para el rizado
#define UMBRAL_SOBRECORRIENTE VALOR(1.3f)
// TODO: Revisar con la ganancia y el offset medidos del acondicionamiento
#define CUENTA_ADC_MIN 16u
#define CUENTA_ADC_MAX 4079u
// TODO: Revisar cuando se fije la relación entre el período del Timer y el disparo del PWM
#define ITERACIONES_SIN_DATO_MAX 3u

void supervisor_falla_iniciar(void);
bool supervisor_falla_revisar(uint16_t cuenta, valor_t corriente);
bool supervisor_falla_sin_dato(void);
bool supervisor_falla_activa(void);

#endif
