#ifndef NUMERICO_H
#define NUMERICO_H

#include <stdint.h>

typedef float valor_t; // TODO: Revisar float contra punto fijo cuando se sepa si el MicroBlaze V lleva FPU, el cambio queda solo en este archivo

#define VALOR(x) ((valor_t)(x)) // pa escribir constantes sin que importe si es float o fijo

static inline valor_t valor_mul(valor_t a, valor_t b)
{ // en punto fijo acá iría el shift despues de multiplicar
  return a * b;
}

static inline int32_t valor_a_entero(valor_t v)
{
  return (int32_t)v; // trunca hacia 0, no redondea
}

#endif
