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

  uint32_t habilitado = control_habilitado; // una sola lectura, así toda la iteración ve lo mismo aunque control_principal la cambie a la mitad
  valor_t amplitud = amplitud_ref;
  bool hay_dato = drivers_adc_dato_nuevo();
  bool en_falla;
  valor_t corriente = VALOR(0.0f);
  valor_t i_ref = VALOR(0.0f);
  registro_t registro;

  if(hay_dato) {
    cuenta = drivers_adc_leer();
    corriente = valor_mul(VALOR((int32_t)cuenta - (int32_t)ADC_OFFSET_CUENTAS), VALOR(ADC_AMPERES_POR_CUENTA)); // a int32 antes de restar, en uint16 una cuenta bajo el offset daría la vuelta
    en_falla = supervisor_falla_revisar(cuenta, corriente);
  }
  else en_falla = supervisor_falla_sin_dato(); // cuenta se queda con la última válida

  if(en_falla && !falla) { // falla publicada hace de estado anterior, así solo la primera iteración apaga
    drivers_pwm_apagar();
    falla = 1;
  }

  if(habilitado && !en_falla) {
    i_ref = ref_senoidal_siguiente(amplitud); // avanza también sin dato, para que la fase no se atrase
    if(hay_dato) {
      duty_ref = pr_discreto_calcular(i_ref, corriente, &saturado);
      drivers_pwm_escribir_duty(duty_ref);
    } // sin dato el PR no avanza y el PWM se queda con el duty_ref anterior
  }

  registro.cuenta_banderas = (uint16_t)((cuenta & CUENTA_MASCARA) | (saturado ? BANDERA_SATURADO : 0u) | (hay_dato ? 0u : BANDERA_DATO_AUSENTE) | (habilitado ? BANDERA_HABILITADO : 0u) | (en_falla ? BANDERA_FALLA : 0u));
  registro.duty_ref = duty_ref;
  registro.i_ref_ma = (int16_t)valor_a_entero(valor_mul(i_ref, VALOR(1000.0f)));
  buffer_muestras_guardar(&registro); // lo copia, así que registro puede vivir en la pila de la ISR
}
