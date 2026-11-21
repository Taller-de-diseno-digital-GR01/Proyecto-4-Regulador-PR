# ref_senoidal

## a) Nombre del módulo

`ref_senoidal`, en `sw/ref_senoidal.c` y `sw/ref_senoidal.h`, con la tabla en `sw/tabla_seno.h`, que genera `sw/generar_tabla_seno.m`. Es parte del software del MicroBlaze V del [nivel 3](../diagramas/nivel03.md).

## b) Diagrama modular

```mermaid
flowchart LR
    LC_IN(["lazo_control"]) -->|"amplitud_ref"| REF["ref_senoidal<br/>acumulador de fase<br/>y tabla de un cuarto de seno"]
    LC_IN -->|"avance de fase"| REF
    CP(["control_principal"]) -->|"reinicio de fase"| REF
    REF -->|"i_ref"| LC_OUT(["lazo_control"])
```

## c) Objetivo del módulo

Entrega en cada iteración del control la muestra de la referencia sinusoidal de 50 Hz que toca, escalada a la amplitud pedida.

## d) Entradas

- `frecuencia_muestreo_hz`, una sola vez al iniciar, para calcular cuánto avanza la fase por iteración. Sale de `PR_FRECUENCIA_MUESTREO_HZ` en `pr_params.h`.
- `amplitud_ref`, en cada llamada, en amperes pico y como `valor_t`.
- Orden de reinicio de fase, desde [`control_principal`](control_principal.md) al habilitar el control.

## e) Salidas

- `i_ref`, la muestra de la referencia en amperes, como `valor_t`.

## f) Explicación de la relación con otros módulos

Solo lo llama [`lazo_control`](lazo_control.md), una vez por interrupción y únicamente con el control habilitado. `control_principal` lo inicia en el arranque y le reinicia la fase al habilitar, mientras la interrupción todavía no lo usa. El `i_ref` que devuelve entra a [`pr_discreto`](pr_discreto.md) y también queda guardado en [`buffer_muestras`](buffer_muestras.md).

## g) Explicación de funcionamiento

Lleva la fase de la senoidal en un acumulador de 32 bits, donde una vuelta completa del acumulador es un período de 50 Hz. En cada llamada lee el seno de la fase actual en una tabla, lo multiplica por `amplitud_ref` y después suma a la fase un incremento fijo. La primera muestra después de un reinicio es cero, así que la referencia arranca sin escalón.

El cambio de amplitud entra en la muestra siguiente sin tocar la fase, que es lo que pide el ensayo de cambio de amplitud de la sección 4.3.

## h) Diseño

### h.1) Por qué un acumulador de fase

En el nivel 3 quedaron dos caminos, una tabla de un período exacto si la frecuencia de muestreo es múltiplo de 50 Hz, o un acumulador si no. El acumulador sirve en los dos casos, así que se elige. Los 20 kHz de partida son múltiplo de 50 Hz, con 400 muestras por período, y una tabla exacta serviría, pero el acumulador deja al módulo sin atarse a esa frecuencia si cambia.

El incremento por iteración es

`incremento = round(50 · 2^32 / frecuencia_muestreo_hz)`

y se calcula una vez en `ref_senoidal_iniciar`. El cálculo directo necesita una división de 64 bits, y en el MicroBlaze V eso enlaza `__udivdi3` de libgcc, que ocupa 1,2 KB. Por eso se parte en dos divisiones de 32 bits, que el procesador hace en hardware. Se escribe `2^32 = frecuencia_muestreo_hz · q + r`, con `q = (2^32 - 1) / frecuencia_muestreo_hz` y `r` entre 1 y `frecuencia_muestreo_hz`, y queda

`incremento = 50 · q + (50 · r + frecuencia_muestreo_hz / 2) / frecuencia_muestreo_hz`

que da el mismo resultado exacto que la división de 64 bits mientras `50 · r` quepa en 32 bits, o sea para cualquier frecuencia de muestreo por debajo de unos 85 MHz. Se comparó contra la versión de 64 bits para todas las frecuencias entre 51 Hz y 5 MHz, sin una sola diferencia.

El error de frecuencia que deja el redondeo es como mucho `frecuencia_muestreo_hz / 2^33`, del orden de microhertz para cualquier frecuencia de muestreo razonable, y la fase no acumula error porque el acumulador desborda solo al completar la vuelta.

### h.2) Tabla de un cuarto de onda

Con 32 KB para programa, datos e histórico, una tabla de un período completo con buena resolución no cabe. Se guarda solo el primer cuarto, de 0 a π/2, en 257 entradas, y los otros tres cuadrantes salen por simetría. La entrada 256 es sin(π/2) = 1 y hace falta para que el segundo cuadrante, que recorre la tabla al revés, empiece exacto.

La fase se corta en sus 10 bits altos, lo que da 1024 posiciones por período.

- `fase[31:30]`, cuadrante.
- `fase[29:22]`, índice `i` dentro del cuarto, de 0 a 255.

| Cuadrante | Muestra |
| --- | --- |
| `00` | `tabla[i]` |
| `01` | `tabla[256 - i]` |
| `10` | `-tabla[i]` |
| `11` | `-tabla[256 - i]` |

Cortar la fase a 1024 posiciones produce un error de amplitud de a lo sumo 2π/1024, un 0,6 % del pico, que aparece como armónicos de alto orden y no como error de la fundamental. Si en el nivel de pruebas resulta poco, se agrega interpolación lineal entre dos entradas vecinas sin cambiar la interfaz.

La tabla es un arreglo constante, `tabla_seno` en `sw/tabla_seno.h`, que genera `sw/generar_tabla_seno.m` en Octave con `sin` en doble precisión y cada valor escrito con 9 cifras, lo que alcanza para el `float`. Al principio se llenaba en `ref_senoidal_iniciar` con `sinf`, pero `sinf` arrastra de libm la reducción de argumento para ángulos grandes, unos 5 KB que nunca se usan porque el ángulo siempre está entre 0 y π/2. Con eso y la división de 64 bits de h.1, el programa no cabía en los 32 KB. Los valores nuevos difieren de los que daba `sinf` en menos de 6·10^-8.

Con `valor_t` en punto flotante ocupa 257 · 4 = 1028 bytes, ahora en memoria de solo lectura en vez de datos. `ref_senoidal.c` revisa con `_Static_assert` que el cuarto tenga 256 entradas, porque el índice sale de 8 bits de la fase. Si se cambia la tabla, se regenera el header corriendo `generar_tabla_seno` desde `sw/`, nunca a mano.

### h.3) Formato numérico

La amplitud, la tabla y la salida son `valor_t`, el tipo único que define `sw/numerico.h`. Hoy es `float`, y el MicroBlaze V del Block Design lleva FPU de precisión simple (#44). Si se pasa a punto fijo, el cambio queda en `numerico.h`, en la multiplicación de este módulo, que usa `valor_mul`, y en el generador de la tabla, cuyos valores salen envueltos en `VALOR`.

### h.4) Interfaz en C

- `void ref_senoidal_iniciar(uint32_t frecuencia_muestreo_hz)`, calcula el incremento y deja la fase en cero.
- `void ref_senoidal_reiniciar_fase(void)`, deja la fase en cero.
- `valor_t ref_senoidal_siguiente(valor_t amplitud_ref)`, devuelve la muestra de la fase actual y avanza la fase.

El estado es la fase y el incremento, los dos `static` dentro de `ref_senoidal.c`. La tabla es `static const` en `tabla_seno.h`, que solo incluye `ref_senoidal.c`. La fase la escribe solo la interrupción, salvo en el reinicio, que `control_principal` hace con el control deshabilitado.

### h.5) Prueba en la PC

`sw/pruebas/prueba_ref_senoidal.c` se compila con gcc y revisa que la primera muestra sea cero, que un período tenga la cantidad de muestras esperada, que los picos lleguen a la amplitud y que un cambio de amplitud no mueva la fase.

## i) Diagrama esquemático detallado del diseño

No aplica, el módulo es una función en C que corre en el MicroBlaze V y no tiene compuertas propias que dibujar.

## j) Diagrama completo de conexiones eléctricas del diseño

No aplica, el módulo no tiene pines ni conexiones eléctricas, solo vive en la memoria del procesador.
