// docs/diseño/modulos/buffer_muestras.md
#include "buffer_muestras.h"

#if (BUFFER_REGISTROS & (BUFFER_REGISTROS - 1)) != 0
#error "BUFFER_REGISTROS tiene que ser potencia de dos"
#endif

// El arreglo no es volatile porque el lazo principal solo lo lee congelado, y ahí la interrupción ya no lo toca
static registro_t registros[BUFFER_REGISTROS];
static volatile uint32_t indice;
static volatile uint32_t llenos;
static volatile uint32_t congelado;

void buffer_muestras_iniciar(void)
{
    indice = 0;
    llenos = 0;
    congelado = 0;
}

void buffer_muestras_guardar(const registro_t *registro)
{
    if (congelado)
        return;

    registros[indice] = *registro;
    indice = (indice + 1) & (BUFFER_REGISTROS - 1);
    if (llenos < BUFFER_REGISTROS)
        llenos++;
}

void buffer_muestras_congelar(void)
{
    congelado = 1;
}

void buffer_muestras_liberar(void)
{
    congelado = 0;
}

uint32_t buffer_muestras_cantidad(void)
{
    return llenos;
}

const registro_t *buffer_muestras_leer(uint32_t n)
{
    uint32_t inicio = (llenos < BUFFER_REGISTROS) ? 0 : indice;
    return &registros[(inicio + n) & (BUFFER_REGISTROS - 1)];
}
