#ifndef SUPERVISOR_FALLA_H
#define SUPERVISOR_FALLA_H

#include <stdbool.h>
#include <stdint.h>
#include "numerico.h"

#define UMBRAL_SOBRECORRIENTE VALOR(1.3f) // TODO: Revisar con la etapa de potencia, provisional en 1,0 A pico de los ensayos más margen para el rizado
#define CUENTA_ADC_MIN 16u // TODO: Revisar con la ganancia y el offset medidos del acondicionamiento
#define CUENTA_ADC_MAX 4079u // 4095 - 16, mismo margen arriba que abajo
#define ITERACIONES_SIN_DATO_MAX 3u // TODO: Revisar cuando se fije la relación entre el período del Timer y el disparo del PWM

void supervisor_falla_iniciar(void);
bool supervisor_falla_revisar(uint16_t cuenta, valor_t corriente);
bool supervisor_falla_sin_dato(void);
bool supervisor_falla_activa(void);

#endif
