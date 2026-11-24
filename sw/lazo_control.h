// docs/diseño/modulos/lazo_control.md
#ifndef LAZO_CONTROL_H
#define LAZO_CONTROL_H

#include <stdint.h>
#include "numerico.h"

#define ADC_OFFSET_CUENTAS 2569u // calibrado contra el osciloscopio con el puente conmutando (registros del 23/11), con el puente apagado el cero se corre a unas 3300 y no sirve, antes 2808
#define ADC_AMPERES_POR_CUENTA (-1.292e-3f) // calibrado contra el osciloscopio a 0,2 y 0,5 A (23/11), el nominal 1 V / (4096 * 0,2196 V/A) = 1,1118e-3 se quedaba 16 % corto e incluye el sesgo de muestrear en el valle. Negativo porque la corriente entra al ACS712 al revés, si se invierten los cables del primario vuelve a positivo. Float suelto porque exportador_uart lo manda tal cual en la cabecera

// Cada una tiene un solo escritor, por eso alcanza con volatile y 32 bits sin sección crítica
extern volatile uint32_t control_habilitado; // la escribe control_principal
extern volatile valor_t amplitud_ref; // A pico, la escribe control_principal
extern volatile uint32_t falla; // la escribe solo la ISR, de 1 no vuelve a 0 porque BTN_RST reinicia la plataforma

void lazo_control_isr(void *ref);
void lazo_control_reiniciar_rampa(void);

#endif
