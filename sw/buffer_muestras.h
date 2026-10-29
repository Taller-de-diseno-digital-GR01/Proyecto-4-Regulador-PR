// docs/diseño/modulos/buffer_muestras.md
#ifndef BUFFER_MUESTRAS_H
#define BUFFER_MUESTRAS_H

#include <stdint.h>

// TODO: Revisar cuando se enlace el programa completo y se sepa cuánto sobra de los 32 KB, tiene que ser potencia de dos
#define BUFFER_REGISTROS 1024u

#define BANDERA_SATURADO     (1u << 15)
#define BANDERA_DATO_AUSENTE (1u << 14)
#define BANDERA_HABILITADO   (1u << 13)
#define BANDERA_FALLA        (1u << 12)
#define CUENTA_MASCARA       0x0FFFu

typedef struct {
    uint16_t cuenta_banderas;
    uint16_t duty_ref;
    int16_t i_ref_ma;
} registro_t;

void buffer_muestras_iniciar(void);
void buffer_muestras_guardar(const registro_t *registro);
void buffer_muestras_congelar(void);
void buffer_muestras_liberar(void);
uint32_t buffer_muestras_cantidad(void);
const registro_t *buffer_muestras_leer(uint32_t n);

#endif
