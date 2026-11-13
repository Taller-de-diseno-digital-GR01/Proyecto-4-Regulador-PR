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

#define AMPLITUD_PASO_MAX VALOR(0.005f) // A por muestra, 1 A tarda 200 muestras (10 ms, medio período de 50 Hz) en alcanzarse, diseno_pr.md sección de saturación

// Solo los toca la ISR entre una iteración y la siguiente, por eso no llevan volatile
static uint16_t cuenta = ADC_OFFSET_CUENTAS; // si la primera iteración no trae dato se registra 0 A y no una cuenta inventada
static uint16_t duty_ref; // el último escrito al PWM, arranca en 0 igual que el registro del periférico
static bool saturado;
static valor_t amplitud_actual; // rampea hacia amplitud_ref, así un cambio de switch no pega un escalón completo en el PR

void lazo_control_reiniciar_rampa(void)
{ // control_principal llama esto al habilitar, para arrancar la amplitud desde 0 y no pegar un escalón completo
  amplitud_actual = VALOR(0.0f);
}

#ifdef PLANTA_SIMULADA // build de prueba sin potencia, la cuenta del ADC se cambia por la de una carga RL calculada acá
#define PLANTA_A 0.980198673f // exp(-R*Ts/L) con 12 ohm, 30 mH y 50 us, ZOH exacto como en diseno_pr.md
#define PLANTA_B 0.029701990f // (Vdc/R)*(1 - PLANTA_A) con 18 V, amperes por unidad de índice de modulación
static valor_t planta_corriente;
static valor_t planta_u; // el índice que rigió durante el período que acaba de terminar

static uint16_t planta_simulada(void)
{ // duty_ref es lo que escribió la ISR anterior y el periférico recién lo carga en este valle, por eso entra a la planta una muestra tarde
  planta_corriente = valor_mul(VALOR(PLANTA_A), planta_corriente) + valor_mul(VALOR(PLANTA_B), planta_u);
  planta_u = valor_mul(VALOR((int16_t)duty_ref), VALOR(DUTY_ESCALA));
  int32_t c = valor_a_entero(valor_mul(planta_corriente, VALOR(1.0f / ADC_AMPERES_POR_CUENTA)) + VALOR(ADC_OFFSET_CUENTAS) + VALOR(0.5f));
  if(c < 0) c = 0; // satura igual que el XADC, así el supervisor ve lo mismo que vería con el sensor
  else if(c > (int32_t)CUENTA_MASCARA) c = (int32_t)CUENTA_MASCARA;
  return (uint16_t)c;
}
#endif

void lazo_control_isr(void *ref)
{
  (void)ref; // la firma la pide el registro de excepciones del BSP, no hay nada que pasarle
  drivers_depuracion(true); // lo primero, para que el ancho del pulso en el osciloscopio sea todo el servicio
  drivers_timer_reconocer(); // al principio, si un día la ISR dura más que el período la siguiente queda pendiente en vez de perderse

  uint32_t habilitado = control_habilitado; // una sola lectura, así toda la iteración ve lo mismo aunque control_principal la cambie a la mitad
  valor_t amplitud = amplitud_ref;
  bool hay_dato = drivers_adc_dato_nuevo();
  bool en_falla;
  valor_t corriente = VALOR(0.0f);
  valor_t i_ref = VALOR(0.0f);
  registro_t registro;

  if(hay_dato) {
#ifdef PLANTA_SIMULADA
    cuenta = planta_simulada(); // el ADC se sigue leyendo arriba, de él sale hay_dato y con eso la fase con el PWM
#else
    cuenta = drivers_adc_leer();
#endif
    corriente = valor_mul(VALOR((int32_t)cuenta - (int32_t)ADC_OFFSET_CUENTAS), VALOR(ADC_AMPERES_POR_CUENTA)); // a int32 antes de restar, en uint16 una cuenta bajo el offset daría la vuelta
    en_falla = supervisor_falla_revisar(cuenta, corriente);
  }
  else en_falla = supervisor_falla_sin_dato(); // cuenta se queda con la última válida

  if(en_falla && !falla) { // falla publicada hace de estado anterior, así solo la primera iteración apaga
    drivers_pwm_apagar();
    falla = 1;
  }

  if(habilitado && !en_falla) {
    if(amplitud_actual < amplitud) { // rampa también sin dato, junto con la fase
      amplitud_actual += AMPLITUD_PASO_MAX;
      if(amplitud_actual > amplitud) amplitud_actual = amplitud;
    }
    else if(amplitud_actual > amplitud) {
      amplitud_actual -= AMPLITUD_PASO_MAX;
      if(amplitud_actual < amplitud) amplitud_actual = amplitud;
    }
    i_ref = ref_senoidal_siguiente(amplitud_actual); // avanza también sin dato, para que la fase no se atrase
    if(hay_dato) {
      duty_ref = pr_discreto_calcular(i_ref, corriente, &saturado);
      drivers_pwm_escribir_duty(duty_ref);
    } // sin dato el PR no avanza y el PWM se queda con el duty_ref anterior
  }
  else { // el puente no aplica ninguna orden, así el histórico no arrastra la de la sesión anterior
    duty_ref = 0;
    saturado = false;
  }

  registro.cuenta_banderas = (uint16_t)((cuenta & CUENTA_MASCARA) | (saturado ? BANDERA_SATURADO : 0u) | (hay_dato ? 0u : BANDERA_DATO_AUSENTE) | (habilitado ? BANDERA_HABILITADO : 0u) | (en_falla ? BANDERA_FALLA : 0u));
  registro.duty_ref = duty_ref;
  registro.i_ref_ma = (int16_t)valor_a_entero(valor_mul(i_ref, VALOR(1000.0f)));
  buffer_muestras_guardar(&registro); // lo copia, así que registro puede vivir en la pila de la ISR

  drivers_depuracion(false);
}
