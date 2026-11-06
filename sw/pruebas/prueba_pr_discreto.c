// cc -std=c99 -Wall -I sw sw/pr_discreto.c sw/pruebas/prueba_pr_discreto.c -lm -o sw/build/prueba_pr_discreto
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "pr_discreto.h"
#include "pr_params.h"

static int errores;

static void revisar(int condicion, const char *que)
{
  if(!condicion) {
    printf("FALLA, %s\n", que);
    errores++;
  }
}

static int16_t calcular(float e, bool *saturado)
{ // corriente en 0 para que i_ref sea directamente el error
  return (int16_t)pr_discreto_calcular(VALOR(e), VALOR(0.0f), saturado); // int16 pa ver el signo
}

static int maximo_en_periodo(float frecuencia_hz, float amplitud, uint32_t desde, uint32_t muestras)
{
  bool saturado;
  int maximo = 0;
  for(uint32_t k = 0; k < desde + muestras; k++) { // corre desde 0 pero solo mide la ventana del final
    int d = calcular(amplitud * sinf(2.0f * 3.14159265f * frecuencia_hz * (float)k / (float)PR_FRECUENCIA_MUESTREO_HZ), &saturado); // sin(2*pi*f*k/fs)
    if(k >= desde && abs(d) > maximo) maximo = abs(d);
  }
  return maximo;
}

int main(void)
{
  const uint32_t por_periodo = PR_FRECUENCIA_MUESTREO_HZ / 50; // 400 muestras a 20 kHz
  const int16_t tope = (int16_t)lroundf((float)PR_U_MAX / DUTY_ESCALA); // 0.98 * 16384 = 16056
  bool saturado;

  pr_discreto_reiniciar();
  revisar(calcular(0.0f, &saturado) == 0 && !saturado, "sin error la salida no es cero");

  pr_discreto_reiniciar();
  revisar(calcular(0.1f, &saturado) == (int16_t)lroundf((float)(PR_KP + PR_B0) * 0.1f / DUTY_ESCALA), "la primera iteración no es KP más B0"); // con estados en 0 solo quedan KP y B0

  pr_discreto_reiniciar();
  revisar(calcular(10.0f, &saturado) == tope && saturado, "no satura arriba en PR_U_MAX"); // 10 A no se alcanza nunca con 18 V
  pr_discreto_reiniciar();
  revisar(calcular(-10.0f, &saturado) == -tope && saturado, "no satura abajo en -PR_U_MAX");
  pr_discreto_reiniciar();
  revisar(pr_discreto_calcular(VALOR(-10.0f), VALOR(0.0f), &saturado) == (uint16_t)(-tope), "-PR_U_MAX no sale en complemento a dos"); // 65536 - 16056

  // Resonante, a 50 Hz crece y a 1 kHz no
  pr_discreto_reiniciar();
  int primero = maximo_en_periodo(50.0f, 0.01f, 0, por_periodo);
  pr_discreto_reiniciar();
  int quinto = maximo_en_periodo(50.0f, 0.01f, 4 * por_periodo, por_periodo);
  revisar(quinto > 2 * primero, "el resonante no acumula ganancia en 50 Hz"); // en el modelo da como 3.4 veces
  pr_discreto_reiniciar();
  int al_inicio = maximo_en_periodo(1000.0f, 0.01f, 0, por_periodo);
  pr_discreto_reiniciar();
  int al_final = maximo_en_periodo(1000.0f, 0.01f, 4 * por_periodo, por_periodo);
  revisar(al_final < al_inicio * 6 / 5, "el resonante crece fuera de 50 Hz"); // margen de 20%

  // Anti-windup
  pr_discreto_reiniciar();
  for(int k = 0; k < 10; k++) calcular(10.0f, &saturado); // saturación corta
  int16_t tras_corta = calcular(0.0f, &saturado);
  pr_discreto_reiniciar();
  for(int k = 0; k < 1000; k++) calcular(10.0f, &saturado); // 1000 muestras = 50 ms saturado
  int16_t tras_larga = calcular(0.0f, &saturado);
  revisar(tras_corta == tras_larga, "el resonante acumula durante la saturación"); // sin anti-windup tras_larga sale mucho más grande

  printf("prueba_pr_discreto, %d errores\n", errores);
  return errores != 0; // pa que make o el script vea que falló
}
