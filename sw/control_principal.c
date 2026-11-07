// docs/diseño/modulos/control_principal.md
#include "control_principal.h"
#include "buffer_muestras.h"
#include "drivers.h"
#include "exportador_uart.h"
#include "lazo_control.h"
#include "pr_discreto.h"
#include "ref_senoidal.h"
#include "supervisor_falla.h"

#define BTN_HABILITAR (1u << 0)
#define BTN_EXPORTAR (1u << 1)
#define SW_DESPL 2u
#define SW_MASCARA 0x3u
#define LED_HABILITADO (1u << 0)
#define LED_FALLA (1u << 1)

static const valor_t amplitudes[4] = {VALOR(0.0f), VALOR(0.2f), VALOR(0.5f), VALOR(1.0f)}; // A pico por código de SW[1:0], h.3

// Solo los toca el lazo principal, por eso no llevan volatile
static bool arranque_correcto;
static uint32_t entradas_anterior;

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

void control_principal_vuelta(void)
{
  uint32_t entradas = drivers_gpio_entradas();
  uint32_t flancos = entradas & ~entradas_anterior; // el antirrebote ya viene del hardware, una pulsación da un solo flanco
  uint32_t en_falla = falla; // una sola lectura, así LEDs y decisiones de esta vuelta ven lo mismo
  entradas_anterior = entradas;

  amplitud_ref = amplitudes[(entradas >> SW_DESPL) & SW_MASCARA];

  if(en_falla && control_habilitado) control_habilitado = 0; // enable ya lo bajó la ISR

  if(flancos & BTN_EXPORTAR) exportador_uart_pedir();
  exportador_uart_avanzar();

  drivers_gpio_leds((control_habilitado ? LED_HABILITADO : 0u) | ((en_falla || !arranque_correcto) ? LED_FALLA : 0u));
}
