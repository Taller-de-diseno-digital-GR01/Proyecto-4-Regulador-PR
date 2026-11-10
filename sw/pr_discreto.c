#include "pr_discreto.h"
#include "pr_params.h"

static valor_t e1, e2, r1, r2; // e[k-1], e[k-2], r[k-1], r[k-2]

void pr_discreto_reiniciar(void)
{ // control_principal llama esto al habilitar
  e1 = e2 = r1 = r2 = VALOR(0.0f);
}

uint16_t pr_discreto_calcular(valor_t i_ref, valor_t corriente, bool *saturado)
{
  valor_t e = i_ref - corriente;
  valor_t u_p = valor_mul(PR_KP, e); // proporcional, ya viene dividido entre Vdc
  valor_t r = valor_mul(PR_B0, e) + valor_mul(PR_B1, e1) + valor_mul(PR_B2, e2) - valor_mul(PR_A1, r1) - valor_mul(PR_A2, r2); // resonante, B1 es 0 con tustin pero se deja igual
  valor_t u = u_p + r; // m_ref, el indice de modulacion de -1 a 1 (en el registro del PWM se llama duty_ref)

  *saturado = false;
  // Saturación
  if(u > PR_U_MAX) { // PR_U_MAX < 1 por el tiempo muerto
    u = PR_U_MAX;
    *saturado = true;
  }
  else if(u < -PR_U_MAX) {
    u = -PR_U_MAX;
    *saturado = true;
  }

  if(*saturado) r = u - u_p; // anti-windup --> r queda con lo que de verdad aplicó el puente

  e2 = e1; // corre los estados una muestra
  e1 = e;
  r2 = r1;
  r1 = r;

  valor_t cuentas = valor_mul(u, VALOR(1.0f / DUTY_ESCALA)); // u * 16384, se multiplica pa no dividir en la ISR
  int32_t duty = valor_a_entero(cuentas >= VALOR(0.0f) ? cuentas + VALOR(0.5f) : cuentas - VALOR(0.5f)); //valor_a_entero solo trunca, el 0.5 es pa redondear
  return (uint16_t)duty; // el cast deja el negativo en complemento a 2, que es lo que espera el PWM
}
