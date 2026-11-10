#include "ref_senoidal.h"
#include "tabla_seno.h" // constante y generada en Octave, calcularla con sinf al arrancar metía unos 5 KB de libm en los 32 KB

#ifndef FRECUENCIA_REF_HZ // el build de prueba con LEDs la baja a 1 Hz desde UserConfig.cmake, a 50 Hz el ojo no ve nada
#define FRECUENCIA_REF_HZ 50u
#endif
#define MUESTRAS_CUARTO TABLA_SENO_CUARTO // un cuarto de onda, el resto sale por simetría

_Static_assert(MUESTRAS_CUARTO == 256u, "ref_senoidal_siguiente saca el índice con 8 bits de la fase");

static uint32_t fase; // 32 bits = una vuelta completa, se desborda solo
static uint32_t incremento;

void ref_senoidal_iniciar(uint32_t frecuencia_muestreo_hz)
{ // 50 * 2^32 / fs partido en dos divisiones de 32 bits, con una de 64 se enlazaba __udivdi3 de libgcc
  uint32_t fs = frecuencia_muestreo_hz;
  uint32_t q = 0xFFFFFFFFu / fs;
  uint32_t r = 0xFFFFFFFFu - q * fs + 1u; // 2^32 = fs * q + r, con r entre 1 y fs
  incremento = FRECUENCIA_REF_HZ * q + (FRECUENCIA_REF_HZ * r + fs / 2u) / fs; // el + fs/2 es pa redondear
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
    case 0: seno = tabla_seno[i]; break;
    case 1: seno = tabla_seno[MUESTRAS_CUARTO - i]; break; // bajando, la 256 es sin(pi/2) y el segundo cuadrante empieza ahí al revés
    case 2: seno = -tabla_seno[i]; break; // negativo
    default: seno = -tabla_seno[MUESTRAS_CUARTO - i]; break;
  }

  fase += incremento; // el desborde es la vuelta, no hay que restar nada
  return valor_mul(amplitud_ref, seno);
}
