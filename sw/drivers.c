// docs/diseño/modulos/drivers.md
#include "drivers.h"
#include "xil_io.h"
#include "xparameters.h"

// TODO: Revisar los nombres contra el xparameters.h generado cuando esté el .xsa, solo se ajustan acá
#define PWM_BASE XPAR_PERIFERICO_PWM_0_BASEADDR
#define ADC_BASE XPAR_ENVOLTURA_XADC_0_BASEADDR

#define PWM_CONTROL 0x00u
#define PWM_DUTY 0x04u
#define PWM_ENABLE (1u << 0)
#define PWM_FREQ_SEL_DESPL 1u
#define PWM_FREQ_SEL_MASCARA 0x3u
#define PWM_RUNNING (1u << 3)

#define ADC_CONTROL 0x00u
#define ADC_DATO 0x04u
#define ADC_INICIO (1u << 0)
#define ADC_FUENTE_TRIGGER (1u << 1)
#define ADC_MUESTRA_MASCARA 0xFFFu
#define ADC_CONTADOR_DESPL 12u
#define ADC_CONTADOR_MASCARA 0x3u

static uint16_t adc_muestra;
static uint32_t adc_contador_anterior; // la envoltura arranca el contador en 0

static void pwm_cambiar_enable(bool habilitar)
{ // enable comparte registro con freq_sel, por eso se lee antes de escribir
  uint32_t control = Xil_In32(PWM_BASE + PWM_CONTROL);
  control = habilitar ? (control | PWM_ENABLE) : (control & ~PWM_ENABLE);
  Xil_Out32(PWM_BASE + PWM_CONTROL, control);
}

void drivers_pwm_configurar(uint32_t freq_sel)
{
  Xil_Out32(PWM_BASE + PWM_CONTROL, (freq_sel & PWM_FREQ_SEL_MASCARA) << PWM_FREQ_SEL_DESPL); // enable queda en 0
}

void drivers_pwm_habilitar(bool habilitar)
{ // la ISR puede apagar enable a mitad de la lectura-escritura y esta lo volvería a subir
  drivers_interrupciones_deshabilitar();
  pwm_cambiar_enable(habilitar);
  drivers_interrupciones_habilitar();
}

void drivers_pwm_apagar(void)
{ // solo desde la ISR, que no se interrumpe a sí misma y por eso no toca las interrupciones
  pwm_cambiar_enable(false);
}

void drivers_pwm_escribir_duty(uint16_t duty_ref)
{
  Xil_Out32(PWM_BASE + PWM_DUTY, duty_ref);
}

bool drivers_pwm_running(void)
{
  return (Xil_In32(PWM_BASE + PWM_CONTROL) & PWM_RUNNING) != 0;
}

bool drivers_adc_dato_nuevo(void)
{ // una sola lectura, muestra y contador tienen que salir del mismo dato
  uint32_t dato = Xil_In32(ADC_BASE + ADC_DATO);
  uint32_t contador = (dato >> ADC_CONTADOR_DESPL) & ADC_CONTADOR_MASCARA;
  bool nuevo = contador != adc_contador_anterior;

  adc_muestra = (uint16_t)(dato & ADC_MUESTRA_MASCARA);
  adc_contador_anterior = contador;
  return nuevo;
}

uint16_t drivers_adc_leer(void)
{
  return adc_muestra;
}

void drivers_adc_iniciar_por_software(void)
{
  uint32_t antes = (Xil_In32(ADC_BASE + ADC_DATO) >> ADC_CONTADOR_DESPL) & ADC_CONTADOR_MASCARA;
  Xil_Out32(ADC_BASE + ADC_CONTROL, ADC_INICIO);
  while(((Xil_In32(ADC_BASE + ADC_DATO) >> ADC_CONTADOR_DESPL) & ADC_CONTADOR_MASCARA) == antes) {} // la envoltura ignora otro inicio mientras convierte
}

void drivers_adc_configurar(void)
{
  Xil_Out32(ADC_BASE + ADC_CONTROL, ADC_FUENTE_TRIGGER);
}
