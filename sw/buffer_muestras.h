#ifndef BUFFER_MUESTRAS_H
#define BUFFER_MUESTRAS_H

#include <stdint.h>

#define BUFFER_REGISTROS 2048u // TODO: Revisar cuando se enlace el programa completo y se sepa cuánto sobra de los 32 KB, tiene que ser potencia de dos

#define BANDERA_SATURADO (1u << 15) // el PR saturó el duty
#define BANDERA_DATO_AUSENTE (1u << 14) // el ADC no tenía dato nuevo
#define BANDERA_HABILITADO (1u << 13) // control encendido
#define BANDERA_FALLA (1u << 12)
#define CUENTA_MASCARA 0x0FFFu // los 12 bits de abajo son la cuenta del ADC

typedef struct {
  uint16_t cuenta_banderas; // cuenta en [11:0], banderas en [15:12]
  uint16_t duty_ref;
  int16_t i_ref_ma; // referencia en mA
} registro_t; // 6 bytes, igual que en la trama

void buffer_muestras_iniciar(void);
void buffer_muestras_guardar(const registro_t *registro);
void buffer_muestras_congelar(void);
void buffer_muestras_liberar(void);
uint32_t buffer_muestras_cantidad(void);
const registro_t *buffer_muestras_leer(uint32_t n);

#endif
