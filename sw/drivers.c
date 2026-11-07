// docs/diseño/modulos/drivers.md
#include "drivers.h"
#include "xil_exception.h"
#include "xil_io.h"
#include "xparameters.h"

// TODO: Revisar los nombres contra el xparameters.h generado cuando esté el .xsa, solo se ajustan acá
#define PWM_BASE XPAR_PERIFERICO_PWM_0_BASEADDR
#define ADC_BASE XPAR_ENVOLTURA_XADC_0_BASEADDR
#define GPIO_BASE XPAR_AXI_GPIO_0_BASEADDR
#define GPIO_DEPURACION_BASE XPAR_AXI_GPIO_1_BASEADDR
#define UART_BASE XPAR_AXI_UARTLITE_0_BASEADDR
#define TIMER_BASE XPAR_AXI_TIMER_0_BASEADDR

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

#define GPIO_DATO_CANAL1 0x00u
#define GPIO_DATO_CANAL2 0x08u
#define GPIO_ENTRADAS_MASCARA 0xFu
#define GPIO_LEDS_MASCARA 0x3u

#define UART_TX 0x04u
#define UART_ESTADO 0x08u
#define UART_TX_LLENA (1u << 3)

#define TIMER_CONTROL 0x00u
#define TIMER_RECARGA 0x04u
#define TIMER_GENERACION (1u << 0)
#define TIMER_CUENTA_ABAJO (1u << 1)
#define TIMER_AUTORRECARGA (1u << 4)
#define TIMER_CARGAR (1u << 5)
#define TIMER_INTERRUPCION_HAB (1u << 6)
#define TIMER_ARRANCAR (1u << 7)
#define TIMER_INTERRUPCION (1u << 8)
#define TIMER_MODO (TIMER_GENERACION | TIMER_CUENTA_ABAJO | TIMER_AUTORRECARGA | TIMER_INTERRUPCION_HAB)

#define MSTATUS_MIE (1u << 3) // habilitación global de interrupciones en modo máquina de RISC-V

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
{ // solo dentro de la sección crítica de control_principal, si no la ISR puede apagar enable a mitad de la lectura-escritura y esta lo volvería a subir
  pwm_cambiar_enable(habilitar);
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

uint32_t drivers_pwm_freq_sel(void)
{
  return (Xil_In32(PWM_BASE + PWM_CONTROL) >> PWM_FREQ_SEL_DESPL) & PWM_FREQ_SEL_MASCARA;
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

uint32_t drivers_gpio_entradas(void)
{
  return Xil_In32(GPIO_BASE + GPIO_DATO_CANAL1) & GPIO_ENTRADAS_MASCARA;
}

void drivers_gpio_leds(uint32_t leds)
{
  Xil_Out32(GPIO_BASE + GPIO_DATO_CANAL2, leds & GPIO_LEDS_MASCARA);
}

void drivers_depuracion(bool nivel)
{ // la escribe solo la ISR, sin leer antes porque el registro tiene un solo bit
  Xil_Out32(GPIO_DEPURACION_BASE + GPIO_DATO_CANAL1, nivel ? 1u : 0u);
}

bool drivers_uart_enviar(uint8_t byte)
{ // XUartLite_SendByte espera a que haya lugar, acá se devuelve falso y el lazo principal reintenta
  if(Xil_In32(UART_BASE + UART_ESTADO) & UART_TX_LLENA) return false;
  Xil_Out32(UART_BASE + UART_TX, byte);
  return true;
}

void drivers_timer_preparar(uint32_t tlr)
{
  Xil_Out32(TIMER_BASE + TIMER_RECARGA, tlr);
  Xil_Out32(TIMER_BASE + TIMER_CONTROL, TIMER_MODO | TIMER_CARGAR | TIMER_INTERRUPCION); // carga tlr y limpia una interrupción vieja que quedara pendiente
  Xil_Out32(TIMER_BASE + TIMER_CONTROL, TIMER_MODO); // CARGAR tiene que bajar antes de arrancar, si no el contador se queda en tlr
}

void drivers_timer_arrancar(void)
{
  Xil_Out32(TIMER_BASE + TIMER_CONTROL, TIMER_MODO | TIMER_ARRANCAR);
}

void drivers_timer_reconocer(void)
{ // el bit se limpia escribiéndole uno, se lee antes para no apagar los demás bits
  Xil_Out32(TIMER_BASE + TIMER_CONTROL, Xil_In32(TIMER_BASE + TIMER_CONTROL) | TIMER_INTERRUPCION);
}

void drivers_interrupciones_iniciar(void (*rutina)(void *))
{ // TODO: Revisar los nombres de xil_exception.h del BSP de MicroBlaze V cuando esté el .xsa
  Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, rutina, NULL);
  Xil_ExceptionEnable();
}

uint32_t drivers_interrupciones_guardar_y_deshabilitar(void)
{ // csrrci lee y limpia MIE en una sola instrucción, y el "memory" impide que el compilador saque lecturas o escrituras de la sección crítica
  uint32_t mstatus;
  __asm__ volatile("csrrci %0, mstatus, %1" : "=r"(mstatus) : "i"(MSTATUS_MIE) : "memory");
  return mstatus & MSTATUS_MIE;
}

void drivers_interrupciones_restaurar(uint32_t estado)
{ // csrs con 0 no cambia nada, así que si ya estaban enmascaradas al entrar siguen así
  __asm__ volatile("csrs mstatus, %0" : : "r"(estado & MSTATUS_MIE) : "memory");
}
