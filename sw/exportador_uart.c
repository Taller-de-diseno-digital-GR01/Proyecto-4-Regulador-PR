#include <string.h>
#include "exportador_uart.h"
#include "buffer_muestras.h"
#include "drivers.h"
#include "lazo_control.h"
#include "pr_discreto.h"
#include "pr_params.h"

#define CABECERA_BYTES 20u // 0xAA + 19 de cabecera
#define REGISTRO_BYTES 6u // lo que mide registro_t
#define SUMA_BYTES 2u // uint16 al final

_Static_assert(sizeof(registro_t) == REGISTRO_BYTES, "byte_en lee registro_t byte por byte, con relleno la trama sale corrida"); // C11, el gcc de Vitis lo acepta también en c99

static uint8_t cabecera[CABECERA_BYTES];
static uint32_t posicion; // siguiente byte a mandar
static uint32_t total; // 22 + 6N
static uint16_t suma;
static bool ocupado;

void exportador_uart_pedir(void)
{
  if(ocupado) return; // si ya hay una exportación se ignora el botón

  buffer_muestras_congelar(); // la ISR deja de escribir mientras se manda
  uint16_t cantidad = (uint16_t)buffer_muestras_cantidad(); // 2048 max, cabe en 16 bits
  uint32_t frecuencia = PR_FRECUENCIA_MUESTREO_HZ;
  float offset = (float)ADC_OFFSET_CUENTAS;
  float ganancia = (float)ADC_AMPERES_POR_CUENTA;
  float escala = (float)DUTY_ESCALA;

  cabecera[0] = 0xAA; // mismo inicio que en el P3
  memcpy(&cabecera[1], &cantidad, 2); // bytes 1-2, memcpy porque quedan desalineados
  memcpy(&cabecera[3], &frecuencia, 4); // bytes 3-6
  memcpy(&cabecera[7], &offset, 4); // 7-10
  memcpy(&cabecera[11], &ganancia, 4); // 11-14
  memcpy(&cabecera[15], &escala, 4); // 15-18, el MB V ya es little-endian así que va directo
  cabecera[19] = DUTY_CON_SIGNO;

  total = CABECERA_BYTES + REGISTRO_BYTES * cantidad + SUMA_BYTES;
  posicion = 0;
  suma = 0;
  ocupado = true;
}

static uint8_t byte_en(uint32_t p)
{
  uint32_t fin_registros = total - SUMA_BYTES; // donde arranca la suma

  if(p < CABECERA_BYTES) return cabecera[p];
  if(p < fin_registros) { // estamos en los registros
    uint32_t d = p - CABECERA_BYTES;
    return ((const uint8_t *)buffer_muestras_leer(d / REGISTRO_BYTES))[d % REGISTRO_BYTES]; // registro d/6, byte d%6 dentro de él
  }
  return (p == fin_registros) ? (uint8_t)suma : (uint8_t)(suma >> 8); // suma en little-endian, primero el byte bajo
}

void exportador_uart_avanzar(void)
{
  if(!ocupado) return;

  while(posicion < total) { // sale solo cuando la FIFO se llena, nunca espera
    uint8_t b = byte_en(posicion);
    if(!drivers_uart_enviar(b)) return; // FIFO llena, se sigue en la próxima vuelta del lazo
    if(posicion > 0 && posicion < total - SUMA_BYTES) suma += b; // el 0xAA no entra en la suma, ni la suma misma
    posicion++;
  }

  buffer_muestras_liberar(); // ya salió todo, la ISR puede volver a guardar
  ocupado = false;
}

bool exportador_uart_ocupado(void)
{
  return ocupado;
}
