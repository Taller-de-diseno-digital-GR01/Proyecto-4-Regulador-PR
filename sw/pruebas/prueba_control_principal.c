// Prueba en la PC de control_principal, ver docs/diseño/modulos/control_principal.md
// gcc -std=c99 -Wall -I sw sw/control_principal.c sw/lazo_control.c sw/exportador_uart.c sw/buffer_muestras.c sw/pr_discreto.c sw/ref_senoidal.c sw/supervisor_falla.c sw/pruebas/prueba_control_principal.c -lm -o sw/build/prueba_control_principal
#include <stdio.h>
#include "control_principal.h"
#include "drivers.h"
#include "exportador_uart.h"
#include "lazo_control.h"
#include "ref_senoidal.h"

#define LED_HABILITADO 1u
#define LED_FALLA 2u

static int errores;
static uint32_t pwm_freq, pwm_enable, pwm_encendidas, leds, entradas;
static uint32_t adc_cada, adc_llamadas, adc_avances, adc_trigger;
static uint32_t timer_tlr, timer_corriendo, avances_al_arrancar;
static void (*rutina_registrada)(void *);
static bool en_seccion, isr_justo_antes;
static uint32_t secciones;

static void revisar(int condicion, const char *que)
{
  if(!condicion) {
    printf("FALLA, %s\n", que);
    errores++;
  }
}

// Reemplazan a drivers.c
void drivers_pwm_configurar(uint32_t freq_sel) { pwm_freq = freq_sel; pwm_enable = 0; }
uint32_t drivers_pwm_freq_sel(void) { return pwm_freq; }
void drivers_pwm_apagar(void) { pwm_enable = 0; }
void drivers_pwm_escribir_duty(uint16_t duty_ref) { (void)duty_ref; }
void drivers_adc_configurar(void) { adc_trigger = 1; }
uint16_t drivers_adc_leer(void) { return 2048u; }
void drivers_gpio_leds(uint32_t l) { leds = l; }
uint32_t drivers_gpio_entradas(void) { return entradas; }
void drivers_depuracion(bool nivel) { (void)nivel; }
bool drivers_uart_enviar(uint8_t byte) { (void)byte; return false; } // FIFO siempre llena, así la exportación queda en curso
void drivers_timer_preparar(uint32_t tlr) { timer_tlr = tlr; timer_corriendo = 0; }
void drivers_timer_reconocer(void) {}
void drivers_interrupciones_iniciar(void (*rutina)(void *)) { rutina_registrada = rutina; }

void drivers_pwm_habilitar(bool habilitar)
{
  revisar(en_seccion, "cambió enable fuera de la sección crítica");
  pwm_enable = habilitar;
  if(habilitar) pwm_encendidas++;
}

bool drivers_adc_dato_nuevo(void)
{ // el contador avanza cada adc_cada lecturas, con 0 el XADC nunca publica
  adc_llamadas++;
  if(adc_cada == 0 || adc_llamadas % adc_cada != 0) return false;
  adc_avances++;
  return true;
}

void drivers_timer_arrancar(void)
{
  revisar(rutina_registrada == lazo_control_isr, "arrancó el Timer sin la ISR registrada");
  avances_al_arrancar = adc_avances;
  timer_corriendo = 1;
}

uint32_t drivers_interrupciones_guardar_y_deshabilitar(void)
{
  revisar(!en_seccion, "sección crítica anidada");
  en_seccion = true;
  secciones++;
  if(isr_justo_antes) falla = 1; // la ISR enclavó la falla entre la lectura de la vuelta y el enmascarado
  return 8u;
}

void drivers_interrupciones_restaurar(uint32_t estado)
{
  revisar(estado == 8u, "restauró un estado distinto al guardado");
  en_seccion = false;
}

static void pulsar(uint32_t boton)
{ // una vuelta con el botón apretado y otra suelto
  entradas |= boton;
  control_principal_vuelta();
  entradas &= ~boton;
  control_principal_vuelta();
}

int main(void)
{
  uint32_t antes;

  adc_cada = 0;
  control_principal_arrancar();
  revisar(adc_llamadas == 1 + SONDEO_MAX_LECTURAS, "el sondeo no se cortó en SONDEO_MAX_LECTURAS");
  revisar(!timer_corriendo, "con el XADC sin publicar el Timer arrancó igual");
  control_principal_vuelta();
  revisar(leds == LED_FALLA, "error de arranque sin LED de falla");
  pulsar(1u);
  revisar(control_habilitado == 0 && pwm_enable == 0, "con error de arranque se pudo habilitar");

  adc_cada = 50;
  adc_llamadas = adc_avances = 0;
  control_principal_arrancar();
  revisar(timer_corriendo, "el Timer no arrancó con el XADC publicando");
  revisar(avances_al_arrancar == 2 && adc_llamadas == 100, "el Timer no arrancó justo en el segundo avance del contador");
  revisar(timer_tlr == 4998u, "TLR distinto de 4998 a 20 kHz");
  revisar(pwm_freq == FREQ_SEL_INICIAL && pwm_enable == 0 && adc_trigger, "el PWM o el XADC no quedaron como pide el arranque");
  control_principal_vuelta();
  revisar(leds == 0u, "arranque correcto con algún LED encendido");

  const valor_t esperadas[4] = {VALOR(0.0f), VALOR(0.2f), VALOR(0.5f), VALOR(1.0f)};
  for(uint32_t sw = 0; sw < 4; sw++) {
    entradas = sw << 2;
    control_principal_vuelta();
    revisar(amplitud_ref == esperadas[sw], "amplitud_ref no corresponde a SW[1:0]");
  }
  entradas = 0;

  for(uint32_t k = 0; k < 7; k++) ref_senoidal_siguiente(VALOR(1.0f)); // corre la fase para ver que habilitar la reinicia
  antes = secciones;
  entradas = 1u;
  control_principal_vuelta();
  revisar(control_habilitado == 1 && pwm_enable == 1 && leds == LED_HABILITADO, "el flanco de BTN_HABILITAR no habilitó");
  revisar(secciones == antes + 1 && !en_seccion, "habilitar no usó exactamente una sección crítica");
  revisar(ref_senoidal_siguiente(VALOR(1.0f)) == VALOR(0.0f), "habilitar no reinició la fase de la referencia");
  control_principal_vuelta();
  revisar(control_habilitado == 1 && pwm_encendidas == 1, "el botón sostenido dio otro flanco");
  entradas = 0;
  control_principal_vuelta();
  pulsar(1u);
  revisar(control_habilitado == 0 && pwm_enable == 0 && leds == 0u, "el segundo flanco no deshabilitó");

  pwm_freq = 2u; // como si se hubiera cambiado a 40 kHz desde el depurador
  pulsar(1u);
  revisar(control_habilitado == 0 && pwm_encendidas == 1, "habilitó con freq_sel distinto de 01");
  pwm_freq = FREQ_SEL_INICIAL;

  isr_justo_antes = true;
  pulsar(1u);
  revisar(control_habilitado == 0 && pwm_encendidas == 1, "habilitó con una falla enclavada dentro de la sección crítica");
  revisar(leds == LED_FALLA, "falla sin LED de falla");
  isr_justo_antes = false;
  falla = 0;

  pulsar(1u);
  revisar(control_habilitado == 1, "no volvió a habilitar después de limpiar la falla de la prueba");
  falla = 1; // como la ISR, que ya bajó enable
  control_principal_vuelta();
  revisar(control_habilitado == 0 && leds == LED_FALLA, "la falla no bajó control_habilitado o no encendió led[1]");
  antes = pwm_encendidas;
  pulsar(1u);
  revisar(control_habilitado == 0 && pwm_encendidas == antes, "en falla el botón volvió a habilitar");

  pulsar(2u);
  revisar(exportador_uart_ocupado(), "BTN_EXPORTAR no arrancó la exportación");

  printf("prueba_control_principal, %d errores\n", errores);
  return errores != 0;
}
