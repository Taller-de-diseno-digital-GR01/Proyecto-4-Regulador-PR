// Prueba en la PC de supervisor_falla, ver docs/diseño/modulos/supervisor_falla.md
// gcc -std=c99 -Wall -I sw sw/supervisor_falla.c sw/pruebas/prueba_supervisor_falla.c -o sw/build/prueba_supervisor_falla
#include <stdio.h>
#include "supervisor_falla.h"

#define CUENTA_NORMAL 2048u

static int errores;

static void revisar(int condicion, const char *que)
{
    if (!condicion) {
        printf("FALLA, %s\n", que);
        errores++;
    }
}

int main(void)
{
    supervisor_falla_iniciar();
    revisar(!supervisor_falla_revisar(CUENTA_NORMAL, VALOR(0.0f)), "falla con medición normal");
    revisar(!supervisor_falla_revisar(CUENTA_NORMAL, UMBRAL_SOBRECORRIENTE), "falla justo en el umbral positivo");
    revisar(!supervisor_falla_revisar(CUENTA_NORMAL, -UMBRAL_SOBRECORRIENTE), "falla justo en el umbral negativo");

    supervisor_falla_iniciar();
    revisar(supervisor_falla_revisar(CUENTA_NORMAL, VALOR(1.31f)), "no detecta sobrecorriente positiva");
    revisar(supervisor_falla_revisar(CUENTA_NORMAL, VALOR(0.0f)), "la falla no quedó enclavada");
    revisar(supervisor_falla_activa(), "supervisor_falla_activa no ve la falla");

    supervisor_falla_iniciar();
    revisar(supervisor_falla_revisar(CUENTA_NORMAL, VALOR(-1.31f)), "no detecta sobrecorriente negativa");

    supervisor_falla_iniciar();
    revisar(!supervisor_falla_revisar(CUENTA_ADC_MIN + 1, VALOR(0.0f)), "falla una cuenta arriba del mínimo");
    revisar(supervisor_falla_revisar(CUENTA_ADC_MIN, VALOR(0.0f)), "no detecta la cuenta en el mínimo");

    supervisor_falla_iniciar();
    revisar(!supervisor_falla_revisar(CUENTA_ADC_MAX - 1, VALOR(0.0f)), "falla una cuenta abajo del máximo");
    revisar(supervisor_falla_revisar(CUENTA_ADC_MAX, VALOR(0.0f)), "no detecta la cuenta en el máximo");

    supervisor_falla_iniciar();
    for (uint32_t k = 0; k < ITERACIONES_SIN_DATO_MAX; k++)
        revisar(!supervisor_falla_sin_dato(), "falla antes de pasar el máximo sin dato");
    revisar(supervisor_falla_sin_dato(), "no detecta demasiadas iteraciones sin dato");

    // Iteraciones aisladas sin dato no deben sumar si en medio llega una muestra
    supervisor_falla_iniciar();
    for (uint32_t k = 0; k < 10u * ITERACIONES_SIN_DATO_MAX; k++) {
        supervisor_falla_sin_dato();
        supervisor_falla_revisar(CUENTA_NORMAL, VALOR(0.0f));
    }
    revisar(!supervisor_falla_activa(), "iteraciones aisladas sin dato terminaron en falla");

    printf("prueba_supervisor_falla, %d errores\n", errores);
    return errores != 0;
}
