// docs/diseño/modulos/lazo_control.md
#ifndef LAZO_CONTROL_H
#define LAZO_CONTROL_H

#include <stdint.h>
#include "numerico.h"

// TODO: Revisar con el sensor montado (#32), por ahora los teóricos de lazo_control.md h.6
#define ADC_OFFSET_CUENTAS 2048u // 0 A en 0,5 V, mitad de los 12 bits
#define ADC_AMPERES_POR_CUENTA 8.138e-4f // 1 V / (4096 * 0,3 V/A), float suelto porque exportador_uart lo manda tal cual en la cabecera

// Cada una tiene un solo escritor, por eso alcanza con volatile y 32 bits sin sección crítica
extern volatile uint32_t control_habilitado; // la escribe control_principal
extern volatile valor_t amplitud_ref; // A pico, la escribe control_principal
extern volatile uint32_t falla; // la escribe solo la ISR, de 1 no vuelve a 0 porque BTN_RST reinicia la plataforma

void lazo_control_isr(void *ref);

#endif
