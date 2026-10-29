// Prueba en la PC de buffer_muestras, ver docs/diseño/modulos/buffer_muestras.md
// gcc -std=c99 -Wall -I sw sw/buffer_muestras.c sw/pruebas/prueba_buffer_muestras.c -o sw/build/prueba_buffer_muestras
#include <stdio.h>
#include "buffer_muestras.h"

static int errores;

static void revisar(int condicion, const char *que)
{
    if (!condicion) {
        printf("FALLA, %s\n", que);
        errores++;
    }
}

static void guardar(uint32_t k)
{
    registro_t r = { (uint16_t)(k & CUENTA_MASCARA), (uint16_t)k, (int16_t)(k & 0x7FFF) };
    buffer_muestras_guardar(&r);
}

// Revisa que el histórico congelado sea exactamente primero, primero + 1, ... en orden
static int en_orden(uint32_t primero, uint32_t cantidad)
{
    if (buffer_muestras_cantidad() != cantidad)
        return 0;
    for (uint32_t n = 0; n < cantidad; n++)
        if (buffer_muestras_leer(n)->duty_ref != (uint16_t)(primero + n))
            return 0;
    return 1;
}

int main(void)
{
    revisar(sizeof(registro_t) == 6, "registro_t no mide 6 bytes");

    buffer_muestras_iniciar();
    for (uint32_t k = 0; k < 10; k++)
        guardar(k);
    buffer_muestras_congelar();
    revisar(en_orden(0, 10), "orden incorrecto antes de dar la vuelta");
    buffer_muestras_liberar();

    buffer_muestras_iniciar();
    for (uint32_t k = 0; k < BUFFER_REGISTROS + 37; k++)
        guardar(k);
    buffer_muestras_congelar();
    revisar(en_orden(37, BUFFER_REGISTROS), "orden incorrecto después de dar la vuelta");

    for (uint32_t k = 5000; k < 5100; k++)
        guardar(k);
    revisar(en_orden(37, BUFFER_REGISTROS), "se escribió con el buffer congelado");

    buffer_muestras_liberar();
    guardar(9000);
    buffer_muestras_congelar();
    revisar(buffer_muestras_leer(BUFFER_REGISTROS - 1)->duty_ref == 9000, "al liberar no siguió desde donde quedó");
    revisar(buffer_muestras_leer(0)->duty_ref == 38, "al liberar no pisó el registro más viejo");

    uint16_t cb = (uint16_t)(BANDERA_SATURADO | BANDERA_FALLA | 0x0ABC);
    revisar((cb & CUENTA_MASCARA) == 0x0ABC, "las banderas pisan la cuenta");
    revisar((cb & BANDERA_SATURADO) && !(cb & BANDERA_DATO_AUSENTE), "las banderas se cruzan entre sí");

    printf("prueba_buffer_muestras, %d errores\n", errores);
    return errores != 0;
}
