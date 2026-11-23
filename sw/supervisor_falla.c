// docs/diseño/modulos/supervisor_falla.md
#include "supervisor_falla.h"

// Solo pasa de cero a uno, la única salida es BTN_RST que vuelve a correr supervisor_falla_iniciar
static volatile uint32_t causa; // solo la primera que disparó, para que los LEDs digan cuál fue y no lo que vino después
static uint32_t sin_dato;

void supervisor_falla_iniciar(void)
{
    causa = 0;
    sin_dato = 0;
}

bool supervisor_falla_revisar(uint16_t cuenta, valor_t corriente)
{
    sin_dato = 0;
    if (causa)
        return true;

    // Escrito en negativo para que un NaN también dispare falla, las comparaciones directas con NaN dan falso
    if (!(corriente <= UMBRAL_SOBRECORRIENTE && corriente >= -UMBRAL_SOBRECORRIENTE))
        causa = FALLA_SOBRECORRIENTE;
    else if (cuenta <= CUENTA_ADC_MIN || cuenta >= CUENTA_ADC_MAX)
        causa = FALLA_FUERA_ESCALA;

    return causa != 0;
}

bool supervisor_falla_sin_dato(void)
{
    if (sin_dato < ITERACIONES_SIN_DATO_MAX)
        sin_dato++;
    else if (!causa)
        causa = FALLA_SIN_DATO;

    return causa != 0;
}

bool supervisor_falla_activa(void)
{
    return causa != 0;
}

uint32_t supervisor_falla_causa(void)
{
    return causa;
}
