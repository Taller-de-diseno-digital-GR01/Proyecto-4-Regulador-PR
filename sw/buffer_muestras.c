#include "buffer_muestras.h"

#if (BUFFER_REGISTROS & (BUFFER_REGISTROS - 1)) != 0 // potencia de dos tiene un solo bit en 1
#error "BUFFER_REGISTROS tiene que ser potencia de dos"
#endif

static registro_t registros[BUFFER_REGISTROS]; // El arreglo no es volatile porque el lazo principal solo lo lee congelado, y ahí la interrupción ya no lo toca
static volatile uint32_t indice; // donde va la próxima muestra
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
  if(congelado) return; // se está exportando, la muestra se pierde

  registros[indice] = *registro;
  indice = (indice + 1) & (BUFFER_REGISTROS - 1); // da la vuelta sin %, por eso la potencia de dos
  if(llenos < BUFFER_REGISTROS) llenos++; // ya lleno se queda en el máximo
}

void buffer_muestras_congelar(void)
{
  congelado = 1;
}

void buffer_muestras_liberar(void)
{
  indice = 0; // Se vacía antes de soltar el congelado para que una exportación nueva no mezcle muestras viejas
  llenos = 0;
  congelado = 0;
}

uint32_t buffer_muestras_cantidad(void)
{
  return llenos;
}

const registro_t *buffer_muestras_leer(uint32_t n)
{
  uint32_t inicio = (llenos < BUFFER_REGISTROS) ? 0 : indice; // si ya dio la vuelta el más viejo está en indice
  return &registros[(inicio + n) & (BUFFER_REGISTROS - 1)]; // n = 0 es el más viejo
}
