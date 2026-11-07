// docs/diseño/modulos/control_principal.md
#include "control_principal.h"
#include "buffer_muestras.h"
#include "drivers.h"
#include "lazo_control.h"
#include "pr_discreto.h"
#include "ref_senoidal.h"
#include "supervisor_falla.h"

static bool arranque_correcto; // solo lo toca el lazo principal, sin volatile

static bool esperar_avance(void)
{ // misma función que la ISR, así el contador que queda guardado en drivers es la base de la primera iteración
  for(uint32_t n = 0; n < SONDEO_MAX_LECTURAS; n++)
    if(drivers_adc_dato_nuevo()) return true;
  return false;
}

void control_principal_arrancar(void)
{
  drivers_pwm_configurar(FREQ_SEL_INICIAL); // deja enable en 0
  drivers_adc_configurar();
  drivers_gpio_leds(0u);
  drivers_depuracion(false);

  pr_discreto_reiniciar();
  ref_senoidal_iniciar(PR_FRECUENCIA_MUESTREO_HZ);
  supervisor_falla_iniciar();
  buffer_muestras_iniciar();

  control_habilitado = 0;
  amplitud_ref = VALOR(0.0f);
  falla = 0;
  drivers_timer_preparar(TIMER_TLR);
  drivers_interrupciones_iniciar(lazo_control_isr); // con el Timer detenido todavía no llega ninguna

  (void)drivers_adc_dato_nuevo(); // toma el contador actual como punto de partida
  arranque_correcto = esperar_avance() && esperar_avance(); // el primer avance puede venir de un período anterior a freq_sel, se descarta
  if(!arranque_correcto) return; // Timer detenido y enable en 0, el LED de falla lo enciende la primera vuelta

  for(volatile uint32_t i = 0; i < MARGEN_ARRANQUE_VUELTAS; i++) {} // volatile para que el compilador no borre la espera
  drivers_timer_arrancar();
}
