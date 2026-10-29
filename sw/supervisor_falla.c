// docs/diseño/modulos/supervisor_falla.md
#include "supervisor_falla.h"

// Solo pasa de cero a uno, la única salida es BTN_RST que vuelve a correr supervisor_falla_iniciar
static bool falla;
static uint32_t sin_dato;

void supervisor_falla_iniciar(void)
{
    falla = false;
    sin_dato = 0;
}

bool supervisor_falla_revisar(uint16_t cuenta, valor_t corriente)
{
    sin_dato = 0;

    if (corriente > UMBRAL_SOBRECORRIENTE || corriente < -UMBRAL_SOBRECORRIENTE)
        falla = true;
    else if (cuenta <= CUENTA_ADC_MIN || cuenta >= CUENTA_ADC_MAX)
        falla = true;

    return falla;
}

bool supervisor_falla_sin_dato(void)
{
    if (sin_dato < ITERACIONES_SIN_DATO_MAX)
        sin_dato++;
    else
        falla = true;

    return falla;
}

bool supervisor_falla_activa(void)
{
    return falla;
}
