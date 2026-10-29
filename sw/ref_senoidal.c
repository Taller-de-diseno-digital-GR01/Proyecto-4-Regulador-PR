// docs/diseño/modulos/ref_senoidal.md
#include <math.h>
#include "ref_senoidal.h"

#define FRECUENCIA_REF_HZ 50u
#define MUESTRAS_CUARTO 256u

// La entrada 256 es sin(pi/2), el segundo cuadrante recorre la tabla al revés y empieza ahí
static valor_t tabla[MUESTRAS_CUARTO + 1];
static uint32_t fase;
static uint32_t incremento;

void ref_senoidal_iniciar(uint32_t frecuencia_muestreo_hz)
{
    for (uint32_t i = 0; i <= MUESTRAS_CUARTO; i++)
        tabla[i] = VALOR(sinf((float)i * 1.57079632679f / (float)MUESTRAS_CUARTO));

    incremento = (uint32_t)((((uint64_t)FRECUENCIA_REF_HZ << 32) + frecuencia_muestreo_hz / 2) / frecuencia_muestreo_hz);
    fase = 0;
}

void ref_senoidal_reiniciar_fase(void)
{
    fase = 0;
}

valor_t ref_senoidal_siguiente(valor_t amplitud_ref)
{
    uint32_t cuadrante = fase >> 30;
    uint32_t i = (fase >> 22) & (MUESTRAS_CUARTO - 1);
    valor_t seno;

    switch (cuadrante) {
    case 0:  seno = tabla[i]; break;
    case 1:  seno = tabla[MUESTRAS_CUARTO - i]; break;
    case 2:  seno = -tabla[i]; break;
    default: seno = -tabla[MUESTRAS_CUARTO - i]; break;
    }

    fase += incremento;
    return valor_mul(amplitud_ref, seno);
}
