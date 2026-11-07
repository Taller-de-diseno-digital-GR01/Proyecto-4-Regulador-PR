// docs/diseño/modulos/lazo_control.md
#include "lazo_control.h"
#include "buffer_muestras.h"
#include "drivers.h"
#include "pr_discreto.h"
#include "ref_senoidal.h"
#include "supervisor_falla.h"

volatile uint32_t control_habilitado;
volatile valor_t amplitud_ref;
volatile uint32_t falla;

// Solo los toca la ISR entre una iteración y la siguiente, por eso no llevan volatile
static uint16_t cuenta = ADC_OFFSET_CUENTAS; // si la primera iteración no trae dato se registra 0 A y no una cuenta inventada
static uint16_t duty_ref; // el último escrito al PWM, arranca en 0 igual que el registro del periférico
static bool saturado;

void lazo_control_isr(void *ref)
{
  (void)ref; // la firma la pide el registro de excepciones del BSP, no hay nada que pasarle
}
