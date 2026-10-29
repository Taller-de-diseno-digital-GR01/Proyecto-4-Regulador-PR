// Prueba en la PC de ref_senoidal, ver docs/diseño/modulos/ref_senoidal.md
// gcc -std=c99 -Wall -I sw sw/ref_senoidal.c sw/pruebas/prueba_ref_senoidal.c -lm -o sw/build/prueba_ref_senoidal
#include <math.h>
#include <stdio.h>
#include "ref_senoidal.h"

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
    // 10 kHz es solo para la prueba, la frecuencia real todavía no está acordada
    const uint32_t fs = 10000;
    const uint32_t por_periodo = fs / 50;

    ref_senoidal_iniciar(fs);
    revisar(ref_senoidal_siguiente(VALOR(1.0f)) == VALOR(0.0f), "la primera muestra tras iniciar no es cero");

    ref_senoidal_reiniciar_fase();
    float maximo = 0.0f, minimo = 0.0f;
    for (uint32_t k = 0; k < por_periodo; k++) {
        float m = (float)ref_senoidal_siguiente(VALOR(0.5f));
        if (m > maximo) maximo = m;
        if (m < minimo) minimo = m;
    }
    revisar(fabsf(maximo - 0.5f) < 0.005f, "el pico positivo no llega a la amplitud");
    revisar(fabsf(minimo + 0.5f) < 0.005f, "el pico negativo no llega a la amplitud");
    revisar(fabsf((float)ref_senoidal_siguiente(VALOR(0.5f))) < 0.005f, "tras un período la fase no volvió a cero");

    // Un cuarto de período a 0,2 A y otro a 1,0 A tienen que seguir la misma senoidal, solo cambia la escala
    ref_senoidal_reiniciar_fase();
    for (uint32_t k = 0; k < por_periodo / 4; k++)
        ref_senoidal_siguiente(VALOR(0.2f));
    revisar(fabsf((float)ref_senoidal_siguiente(VALOR(1.0f)) - 1.0f) < 0.005f, "el cambio de amplitud movió la fase");

    // Una frecuencia que no es múltiplo de 50 Hz no debe acumular error en muchos períodos
    ref_senoidal_iniciar(9973);
    float error_max = 0.0f;
    for (uint32_t k = 0; k < 9973u * 10u; k++) {
        float esperado = sinf(2.0f * 3.14159265f * 50.0f * (float)k / 9973.0f);
        float e = fabsf((float)ref_senoidal_siguiente(VALOR(1.0f)) - esperado);
        if (e > error_max) error_max = e;
    }
    revisar(error_max < 0.01f, "con 9973 Hz el error pasa del 1 % en 10 s");

    printf("prueba_ref_senoidal, %d errores\n", errores);
    return errores != 0;
}
