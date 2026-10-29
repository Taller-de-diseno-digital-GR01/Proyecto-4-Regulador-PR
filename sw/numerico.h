// Tipo numérico único del control, ver docs/diseño/modulos/ref_senoidal.md (formato numérico)
#ifndef NUMERICO_H
#define NUMERICO_H

#include <stdint.h>

// TODO: Revisar float contra punto fijo cuando se sepa si el MicroBlaze V lleva FPU, el cambio queda solo en este archivo
typedef float valor_t;

#define VALOR(x) ((valor_t)(x))

static inline valor_t valor_mul(valor_t a, valor_t b)
{
    return a * b;
}

static inline int32_t valor_a_entero(valor_t v)
{
    return (int32_t)v;
}

#endif
