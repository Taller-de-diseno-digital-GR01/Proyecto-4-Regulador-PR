// Prueba en la PC de lazo_control, ver docs/diseño/modulos/lazo_control.md
// gcc -std=c99 -Wall -I sw sw/lazo_control.c sw/buffer_muestras.c sw/pr_discreto.c sw/ref_senoidal.c sw/supervisor_falla.c sw/pruebas/prueba_lazo_control.c -lm -o sw/build/prueba_lazo_control
#include <stdio.h>
#include "buffer_muestras.h"
#include "drivers.h"
#include "lazo_control.h"
#include "pr_discreto.h"
#include "pr_params.h"
#include "ref_senoidal.h"
#include "supervisor_falla.h"

static int errores;
static bool adc_hay;
static uint16_t adc_cuenta;
static bool depuracion_alta;
static uint32_t subidas, bajadas, reconocidos, escrituras, apagados, llamadas;
static uint16_t duty_escrito;

static void revisar(int condicion, const char *que)
{
  if(!condicion) {
    printf("FALLA, %s\n", que);
    errores++;
  }
}

// Reemplazan a drivers.c, la ISR solo usa estas
bool drivers_adc_dato_nuevo(void) { return adc_hay; }
uint16_t drivers_adc_leer(void) { return adc_cuenta; }

void drivers_depuracion(bool nivel)
{
  revisar(nivel != depuracion_alta, "la depuración se escribió dos veces con el mismo nivel");
  depuracion_alta = nivel;
  if(nivel) subidas++; else bajadas++;
}

void drivers_timer_reconocer(void)
{
  revisar(depuracion_alta, "reconoció el Timer con la depuración abajo");
  reconocidos++;
}

void drivers_pwm_escribir_duty(uint16_t duty_ref)
{
  revisar(depuracion_alta, "escribió duty_ref con la depuración abajo");
  duty_escrito = duty_ref;
  escrituras++;
}

void drivers_pwm_apagar(void)
{
  revisar(depuracion_alta, "apagó el PWM con la depuración abajo");
  apagados++;
}

static registro_t iterar(bool hay, uint16_t cuenta)
{ // una interrupción y devuelve lo que guardó, liberar deja el buffer vacío para la siguiente
  registro_t registro;
  adc_hay = hay;
  adc_cuenta = cuenta;
  lazo_control_isr(NULL);
  llamadas++;
  revisar(!depuracion_alta, "la ISR salió con la depuración arriba");
  buffer_muestras_congelar();
  revisar(buffer_muestras_cantidad() == 1, "la ISR no guardó exactamente un registro");
  registro = *buffer_muestras_leer(0);
  buffer_muestras_liberar();
  return registro;
}

static void habilitar(valor_t amplitud)
{ // el orden de control_principal.md h.2, sin la sección crítica que acá no hace falta
  pr_discreto_reiniciar();
  ref_senoidal_reiniciar_fase();
  lazo_control_reiniciar_rampa();
  amplitud_ref = amplitud;
  control_habilitado = 1;
}

int main(void)
{
  registro_t r;
  uint32_t antes;

  buffer_muestras_iniciar();
  supervisor_falla_iniciar();
  ref_senoidal_iniciar(PR_FRECUENCIA_MUESTREO_HZ);

  r = iterar(true, ADC_OFFSET_CUENTAS);
  revisar(r.cuenta_banderas == ADC_OFFSET_CUENTAS, "control apagado, la cuenta o las banderas no son las esperadas");
  revisar(r.i_ref_ma == 0, "control apagado con i_ref distinta de 0");
  revisar(escrituras == 0, "control apagado y el PR escribió duty_ref");

  habilitar(VALOR(0.0f));
  r = iterar(true, ADC_OFFSET_CUENTAS - 100u);
  revisar((r.cuenta_banderas & 0x7000u) == 0x2000u, "habilitado sin falla, los bits 14 a 12 no dan 010");
  revisar((int16_t)duty_escrito > 0, "corriente negativa y el PR no empujó hacia arriba, ¿la resta dio la vuelta en uint16?");
  revisar(r.duty_ref == duty_escrito, "el registro no trae el duty_ref escrito");

  habilitar(VALOR(1.0f));
  r = iterar(true, ADC_OFFSET_CUENTAS);
  revisar(r.i_ref_ma == 0, "la referencia no arrancó en 0 después de reiniciar la fase");
  antes = escrituras;
  r = iterar(false, 0u);
  revisar(escrituras == antes, "sin dato el PR volvió a escribir duty_ref");
  revisar(r.duty_ref == duty_escrito, "sin dato el registro no repite el último duty_ref");
  revisar((r.cuenta_banderas & CUENTA_MASCARA) == ADC_OFFSET_CUENTAS, "sin dato no se quedó con la última cuenta válida");
  revisar((r.cuenta_banderas & 0x7000u) == 0x6000u, "sin dato los bits 14 a 12 no dan 110");
  for(uint32_t k = 2; k < 100; k++) iterar(true, ADC_OFFSET_CUENTAS);
  r = iterar(true, ADC_OFFSET_CUENTAS);
  revisar(r.i_ref_ma == 252, "a un cuarto de período la referencia no está en el pico"); // con AMPLITUD_PASO_MAX la rampa va a un cuarto de camino (0,25 de 1,0) a los 100 muestras, por eso no son los 999 de la amplitud ya asentada
  r = iterar(false, 0u);
  revisar(r.i_ref_ma == 254 && r.i_ref_ma != 252, "sin dato la fase no avanzó"); // un paso más de fase y de rampa sin dato nuevo, por eso no repite el 252 de arriba

  r = iterar(true, ADC_OFFSET_CUENTAS - 1500u); // -1,22 A contra 1 A de referencia, el proporcional solo ya pasa PR_U_MAX
  revisar((r.cuenta_banderas & BANDERA_SATURADO) != 0, "con 2,2 A de error el PR no saturó");
  control_habilitado = 0;
  r = iterar(true, ADC_OFFSET_CUENTAS);
  revisar(r.duty_ref == 0, "deshabilitado y el registro arrastra el duty_ref de la sesión anterior");
  revisar((r.cuenta_banderas & BANDERA_SATURADO) == 0, "deshabilitado y el registro arrastra la saturación de la sesión anterior");
  control_habilitado = 1; // lo de abajo espera el control andando

  for(uint32_t k = 0; k < ITERACIONES_SIN_DATO_MAX; k++) iterar(false, 0u);
  revisar(falla == 0, "falla antes de pasar ITERACIONES_SIN_DATO_MAX");
  antes = escrituras;
  r = iterar(false, 0u);
  revisar(falla == 1, "no publicó la falla por datos ausentes");
  revisar(apagados == 1, "la falla no apagó el PWM");
  revisar((r.cuenta_banderas & BANDERA_FALLA) != 0, "el registro no trae la bandera de falla");
  revisar(r.i_ref_ma == 0, "en falla la referencia no es 0");
  for(uint32_t k = 0; k < 5; k++) r = iterar(true, ADC_OFFSET_CUENTAS);
  revisar(apagados == 1, "el apagado se repitió con la falla ya enclavada");
  revisar(escrituras == antes, "en falla el PR siguió escribiendo");
  revisar((r.cuenta_banderas & 0x7000u) == 0x3000u, "en falla con dato los bits 14 a 12 no dan 011");

  supervisor_falla_iniciar(); // en la placa esto y falla = 0 solo pasan con el reinicio de BTN_RST
  falla = 0;
  habilitar(VALOR(1.0f));
  antes = escrituras;
  iterar(true, ADC_OFFSET_CUENTAS + 1700u); // 1700 * 8,138e-4 = 1,38 A, arriba del umbral de 1,3 A
  revisar(falla == 1, "no publicó la falla por sobrecorriente");
  revisar(apagados == 2, "la sobrecorriente no apagó el PWM");
  revisar(escrituras == antes, "con sobrecorriente el PR escribió en la misma iteración");

  revisar(subidas == llamadas && bajadas == llamadas, "la depuración no subió y bajó una vez por iteración");
  revisar(reconocidos == llamadas, "el Timer no se reconoció una vez por iteración");

  printf("prueba_lazo_control, %d errores\n", errores);
  return errores != 0;
}
