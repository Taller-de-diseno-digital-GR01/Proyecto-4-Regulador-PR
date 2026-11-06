#include <math.h>
#include "ref_senoidal.h"

#define FRECUENCIA_REF_HZ 50u
#define MUESTRAS_CUARTO 256u // un cuarto de onda, el resto sale por simetría

static valor_t tabla[MUESTRAS_CUARTO + 1]; // +1 porque la 256 es sin(pi/2), el segundo cuadrante empieza ahí al revés
static uint32_t fase; // 32 bits = una vuelta completa, se desborda solo
static uint32_t incremento;

void ref_senoidal_iniciar(uint32_t frecuencia_muestreo_hz)
{
  for(uint32_t i = 0; i <= MUESTRAS_CUARTO; i++) // <= pa incluir el pico
    tabla[i] = VALOR(sinf((float)i * 1.57079632679f / (float)MUESTRAS_CUARTO)); // 1.5707... = pi/2

  incremento = (uint32_t)((((uint64_t)FRECUENCIA_REF_HZ << 32) + frecuencia_muestreo_hz / 2) / frecuencia_muestreo_hz); // 50 * 2^32 / fs, el + fs/2 es pa redondear
  fase = 0;
}

void ref_senoidal_reiniciar_fase(void)
{ // pa que el seno arranque en 0 al habilitar
  fase = 0;
}

valor_t ref_senoidal_siguiente(valor_t amplitud_ref)
{
  uint32_t cuadrante = fase >> 30; // los 2 bits de arriba
  uint32_t i = (fase >> 22) & (MUESTRAS_CUARTO - 1); // los 8 siguientes, indice dentro del cuarto
  valor_t seno;

  switch(cuadrante) {
    case 0: seno = tabla[i]; break;
    case 1: seno = tabla[MUESTRAS_CUARTO - i]; break; // bajando
    case 2: seno = -tabla[i]; break; // negativo
    default: seno = -tabla[MUESTRAS_CUARTO - i]; break;
  }

  fase += incremento; // el desborde es la vuelta, no hay que restar nada
  return valor_mul(amplitud_ref, seno);
}
