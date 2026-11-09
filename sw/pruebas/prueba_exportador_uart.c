// gcc -std=c99 -Wall -I sw sw/buffer_muestras.c sw/exportador_uart.c sw/pruebas/prueba_exportador_uart.c -lm -o sw/build/prueba_exportador_uart
// con una ruta de argumento guarda la trama ahí, sirve para probar receptor_pc sin placa
#include <math.h>
#include <stdio.h>
#include <string.h>
#include "buffer_muestras.h"
#include "drivers.h"
#include "exportador_uart.h"

#define FIFO_BYTES 16u // la FIFO de tx de la UART Lite

static int errores;
static uint8_t trama[22 + 6 * BUFFER_REGISTROS]; // la trama más larga posible
static uint32_t largo;
static uint32_t en_fifo;
static uint32_t llamadas;

static void revisar(int condicion, const char *que)
{
  if(!condicion) {
    printf("FALLA, %s\n", que);
    errores++;
  }
}

bool drivers_uart_enviar(uint8_t byte) // reemplaza al driver real, escribe en trama[]
{
  if(en_fifo == FIFO_BYTES || ++llamadas % 7 == 0) return false; // cada 7 llamadas finge FIFO llena, corta la trama en lugares raros
  en_fifo++;
  trama[largo++] = byte;
  return true;
}

static uint32_t exportar(void)
{
  uint32_t vueltas = 0;
  largo = 0;
  exportador_uart_pedir();
  while(exportador_uart_ocupado() && vueltas < 100000) { // el tope es por si se queda pegado
    exportador_uart_pedir(); // pedido repetido a media trama, no debería reiniciar nada
    en_fifo = 0; // como si la UART hubiera vaciado la FIFO entre vueltas
    exportador_uart_avanzar();
    revisar(en_fifo <= FIFO_BYTES, "una llamada mandó más que la FIFO");
    vueltas++;
  }
  return vueltas;
}

static void revisar_trama(uint32_t n)
{
  uint16_t cantidad, suma_rx, suma = 0;
  uint32_t frecuencia;
  float offset, ganancia, escala;

  revisar(largo == 22 + 6 * n, "largo distinto de 22 + 6N");
  revisar(trama[0] == 0xAA, "falta el 0xAA");
  memcpy(&cantidad, &trama[1], 2); // mismos offsets que en exportador_uart.c
  memcpy(&frecuencia, &trama[3], 4);
  memcpy(&offset, &trama[7], 4);
  memcpy(&ganancia, &trama[11], 4);
  memcpy(&escala, &trama[15], 4);
  revisar(cantidad == n, "cantidad");
  revisar(frecuencia == 20000u, "frecuencia de muestreo");
  revisar(offset == 2048.0f, "offset del ADC");
  revisar(fabsf(ganancia - 8.138e-4f) < 1e-9f, "amperes por cuenta"); // float, no se compara exacto
  revisar(escala == 1.0f / 16384.0f, "escala de duty"); // Q2.14
  revisar(trama[19] == 1, "duty con signo");

  for(uint32_t k = 0; k < n; k++) { // cada registro tiene que ser el k-ésimo que se guardó
    registro_t r;
    memcpy(&r, &trama[20 + 6 * k], 6);
    if(r.duty_ref != (uint16_t)(1000 + k) || r.i_ref_ma != (int16_t)(-(int32_t)k) || r.cuenta_banderas != (uint16_t)((k & CUENTA_MASCARA) | BANDERA_HABILITADO)) { // lo mismo que arma llenar()
      revisar(0, "registro fuera de orden o corrido");
      break;
    }
  }

  for(uint32_t p = 1; p < largo - 2; p++) suma += trama[p]; // del byte 1 hasta antes de la suma
  memcpy(&suma_rx, &trama[largo - 2], 2);
  revisar(suma == suma_rx, "suma de verificación");
}

static void llenar(uint32_t n)
{
  for(uint32_t k = 0; k < n; k++) {
    registro_t r = { (uint16_t)((k & CUENTA_MASCARA) | BANDERA_HABILITADO), (uint16_t)(1000 + k), (int16_t)(-(int32_t)k) }; // valores que dependen de k para ver el orden
    buffer_muestras_guardar(&r);
  }
}

int main(int argc, char **argv)
{
  buffer_muestras_iniciar();
  exportar();
  revisar_trama(0); // buffer vacío, solo cabecera y suma

  llenar(37);
  exportar();
  revisar_trama(37);
  revisar(buffer_muestras_cantidad() == 0, "el buffer no quedó liberado");

  for(uint32_t k = 0; k < 500; k++) { // basura para que el índice no arranque en 0
    registro_t basura = { 0, 0xFFFF, 0 };
    buffer_muestras_guardar(&basura);
  }
  buffer_muestras_liberar();
  llenar(BUFFER_REGISTROS); // buffer lleno
  exportar();
  revisar_trama(BUFFER_REGISTROS);
  revisar(!exportador_uart_ocupado(), "quedó ocupado al terminar");

  if(argc > 1) { // solo si se pidió guardar la trama
    buffer_muestras_liberar(); // senoidal conocida, ref 0,5 A y corriente 0,45 A
    for(uint32_t k = 0; k < BUFFER_REGISTROS; k++) {
      double fase = 2.0 * 3.14159265358979 * 50.0 * k / 20000.0; // 50 Hz muestreado a 20 kHz
      int16_t i_ref_ma = (int16_t)lround(500.0 * sin(fase));
      uint16_t cuenta = (uint16_t)lround(2048.0 + 0.45 * sin(fase - 0.05) / 8.138e-4); // 0,45 A atrasada 0,05 rad, pasada a cuentas
      int16_t duty = (int16_t)lround(0.6 * 16384.0 * sin(fase + 0.3)); // 0,6 en Q2.14
      registro_t r = { (uint16_t)(cuenta | BANDERA_HABILITADO), (uint16_t)duty, i_ref_ma };
      buffer_muestras_guardar(&r);
    }
    exportar();
    FILE *f = fopen(argv[1], "wb");
    if(f) {
      fwrite(trama, 1, largo, f);
      fclose(f);
    }
    revisar(f != NULL, "no se pudo escribir la trama");
  }

  printf("%d errores\n", errores);
  return errores != 0; // 1 si algo falló
}
