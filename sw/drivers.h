// docs/diseño/modulos/drivers.md
#ifndef DRIVERS_H
#define DRIVERS_H

#include <stdbool.h>
#include <stdint.h>

void drivers_pwm_configurar(uint32_t freq_sel);
void drivers_pwm_habilitar(bool habilitar);
void drivers_pwm_apagar(void);
void drivers_pwm_escribir_duty(uint16_t duty_ref);
bool drivers_pwm_running(void);

bool drivers_adc_dato_nuevo(void);
uint16_t drivers_adc_leer(void);
void drivers_adc_iniciar_por_software(void);
void drivers_adc_configurar(void);

uint32_t drivers_gpio_entradas(void);
void drivers_gpio_leds(uint32_t leds);
void drivers_depuracion(bool nivel);

bool drivers_uart_enviar(uint8_t byte);

void drivers_timer_preparar(uint32_t tlr);
void drivers_timer_arrancar(void);
void drivers_timer_reconocer(void);
void drivers_interrupciones_iniciar(void (*rutina)(void *));
uint32_t drivers_interrupciones_guardar_y_deshabilitar(void);
void drivers_interrupciones_restaurar(uint32_t estado);

#endif
