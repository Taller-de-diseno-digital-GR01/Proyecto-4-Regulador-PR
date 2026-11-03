#include "supervisor_falla.h"

static volatile bool falla; // solo pasa de 0 a 1, la única salida es BTN_RST que vuelve a llamar supervisor_falla_iniciar
static uint32_t sin_dato; // iteraciones seguidas sin muestra nueva

void supervisor_falla_iniciar(void)
{
  falla = false;
  sin_dato = 0;
}

bool supervisor_falla_revisar(uint16_t cuenta, valor_t corriente)
{
  sin_dato = 0; // llegó muestra, se reinicia la cuenta

  if(!(corriente <= UMBRAL_SOBRECORRIENTE && corriente >= -UMBRAL_SOBRECORRIENTE)) falla = true; // en negativo pa que un NaN también dispare, con NaN cualquier comparación da falso
  else if(cuenta <= CUENTA_ADC_MIN || cuenta >= CUENTA_ADC_MAX) falla = true; // ADC pegado a un riel --> sensor desconectado o saturado

  return falla; // enclavada, aunque esta muestra esté bien
}

bool supervisor_falla_sin_dato(void)
{
  if(sin_dato < ITERACIONES_SIN_DATO_MAX) sin_dato++; // se tolera perder unas pocas
  else falla = true;

  return falla;
}

bool supervisor_falla_activa(void)
{
  return falla;
}
