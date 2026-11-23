// docs/diseño/modulos/lazo_control.md
#ifndef LAZO_CONTROL_H
#define LAZO_CONTROL_H

#include <stdint.h>
#include "numerico.h"

#define ADC_OFFSET_CUENTAS 2785u // 0 A medido en J3 = 0,68 V con multímetro el 23/11, afinar con una captura a 0 A
#define ADC_AMPERES_POR_CUENTA (-1.1118e-3f) // negativo porque la corriente entra al ACS712 al revés (correlación duty-corriente de -1 el 23/11), si se invierten los cables del primario vuelve a positivo. 1 V / (4096 * 0,2196 V/A), ganancia real Av=1,2 por sensor de 183 mV/A, float suelto porque exportador_uart lo manda tal cual en la cabecera

// Cada una tiene un solo escritor, por eso alcanza con volatile y 32 bits sin sección crítica
extern volatile uint32_t control_habilitado; // la escribe control_principal
extern volatile valor_t amplitud_ref; // A pico, la escribe control_principal
extern volatile uint32_t falla; // la escribe solo la ISR, de 1 no vuelve a 0 porque BTN_RST reinicia la plataforma

void lazo_control_isr(void *ref);
void lazo_control_reiniciar_rampa(void);

#endif
