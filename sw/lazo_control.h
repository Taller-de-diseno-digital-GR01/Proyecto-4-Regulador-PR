// docs/diseño/modulos/lazo_control.md
#ifndef LAZO_CONTROL_H
#define LAZO_CONTROL_H

#include <stdint.h>
#include "numerico.h"

#define ADC_OFFSET_CUENTAS 2048u // 0 A nominal en 0,5 V, el real lo mide control_principal al arrancar
#define ADC_AMPERES_POR_CUENTA 1.1118e-3f // 1 V / (4096 * 0,2196 V/A), ganancia real Av=1,2 por sensor de 183 mV/A, float suelto porque exportador_uart lo manda tal cual en la cabecera

// Cada una tiene un solo escritor, por eso alcanza con volatile y 32 bits sin sección crítica
extern volatile uint32_t control_habilitado; // la escribe control_principal
extern volatile valor_t amplitud_ref; // A pico, la escribe control_principal
extern uint16_t adc_offset_cuentas; // cuenta de 0 A, la escribe control_principal antes de arrancar el Timer y después solo se lee
extern volatile uint32_t falla; // la escribe solo la ISR, de 1 no vuelve a 0 porque BTN_RST reinicia la plataforma

void lazo_control_isr(void *ref);
void lazo_control_reiniciar_rampa(void);

#endif
