# Cambios al informe por las mediciones del 25 de noviembre

Lista de lo que hay que cambiar en `docs/informe/informe.md` y en `potencia/informe/informe_tecnico_pedp.tex` con las mediciones finales. Se aplicó el 26 de noviembre en los dos informes, con el PDF y `entregables/informe_tecnico_pedp.zip` regenerados. Los datos crudos y lo anotado en banco están en `registro.md`, en esta misma carpeta.

## Qué cambió en el montaje y el firmware

- Firmware de `arreglo-final` con el autocero. El offset se mide al habilitar con el puente conmutando, y ya no es la constante de 2808 cuentas.
- AD822 del acondicionador alimentado a 10 V. A 5 V recortaba el lado positivo.
- Bus de 18 V con límite de la fuente en 0,74 A en todas las mediciones.
- R total de la carga original de 11,8 Ω con multímetro, igual que antes. El segundo inductor dio igual que el primero con el LCR.
- R total de la carga +25 % de 18,7 Ω con multímetro (ver la discrepancia más abajo).
- La punta del osciloscopio mide sobre la resistencia de 9,6 Ω. Antes se restaban dos puntas sobre 9,46 Ω.

## Seguimiento en régimen según el sensor

Reemplaza la tabla de 12.8.1 y la de la sección de seguimiento del `.tex`. Fundamental y fase sobre los últimos cinco períodos de cada CSV. La tensión aplicada es la acción de control por 18 V, una estimación que no descuenta tiempo muerto ni caídas del puente.

| Archivo | Carga | Ref pico (A) | Medida pico (A) | Error (%) | Fase (°) | Continua (A) | Acción pico | V aplicada pico (V) | Saturadas |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `0A.csv` | original | 0 | 0,0002 | | | +0,002 | | | 0 |
| `0.2A.csv` | original | 0,1993 | 0,2002 | 0,42 | −0,02 | +0,010 | 0,172 | 3,09 | 0 |
| `0.5A.csv` | original | 0,4993 | 0,4997 | 0,08 | +0,02 | −0,003 | 0,368 | 6,63 | 0 |
| `1.0A.csv` | original | 0,9994 | 1,0001 | 0,07 | +0,01 | +0,010 | 0,714 | 12,85 | 0 |
| `carga25_0.2A.csv` | +25 % | 0,1994 | 0,2000 | 0,33 | −0,01 | +0,015 | 0,233 | 4,19 | 0 |
| `carga25_0.5A.csv` | +25 % | 0,4993 | 0,5002 | 0,17 | 0,00 | +0,008 | 0,495 | 8,90 | 0 |
| `carga25_1.0A.csv` | +25 % | 0,9994 | 0,9132 | −8,62 | +13,91 | +0,020 | 0,860 | 15,49 | 20 |

- Con la carga original, el punto de 1,0 A ya se alcanza sin saturar. Hay que borrar el texto de 12.8.1 que atribuía el recorte al límite de la fuente, y el que lo atribuía al bus de 18 V con 1 A de límite.
- La continua queda dentro de ±0,02 A en todos los puntos, contra 0,12 a 0,33 A antes. Es el efecto del autocero.
- A 1,0 A con la carga +25 % la acción llega a ±0,92 en 20 muestras, 11 en el semiciclo positivo y 9 en el negativo. El error cumple el 10 % por poco y la fase se corre 14°. Se deja así, explicado en la sección de saturación de abajo.
- Los RMS salen de dividir el pico entre √2, porque la corriente es senoidal. Son 0,142, 0,353 y 0,707 A con la carga original. El enunciado pide distinguir pico y RMS.

## Corriente física con el osciloscopio

Reemplaza 12.8.3 y la tabla de ganancia del `.tex`. Sale de los tramos estables de las capturas de `transitorios/`, ajustando seno, coseno y continua en ventanas de 20 ms y dividiendo entre 9,6 Ω.

| Consigna | Captura | Osciloscopio, pico (A) | Error respecto de la consigna |
|---|---|---:|---:|
| 0,2 A | `escalon_0.2-0.5A`, antes del cambio | 0,19 | −4 % |
| 0,5 A | `escalon_0.2-0.5A` y `escalon_0.5-1.0A` | 0,48 | −4 % |
| 1,0 A | `escalon_0.5-1.0A`, después del cambio | 0,97 | −3 % |
| 0,5 A, carga +25 % | `cambio_R_0.5A` | 0,48 | −4 % |

- La corriente física queda dentro del 10 % en los tres puntos. Antes daba +14,6 y +18,7 %. Esto cambia el resumen, 13.3, la tabla de 13.6, la de 13.7, las conclusiones y la discusión del `.tex`.
- Las capturas no son del mismo minuto que los CSV, pero sí de la misma sesión, con el mismo firmware y el mismo montaje. Hay que decirlo.
- El sesgo cambió de signo. La simulación (12.9) predice que la corriente física queda 1 a 5 % por encima de la muestreada en el valle, y en banco queda unos 4 % por debajo. Las causas posibles son la R real de la resistencia donde va la punta y la ganancia del sensor. No se aisló cuál pesa más, y eso va como diferencia entre predicción y práctica.
- La sección de calibración a posteriori del `.tex` (constantes calibradas contra las capturas del 23 de noviembre) queda reemplazada por el autocero y esta comparación.

## Cero del sensor

12.8.2 se reduce a decir que el autocero deja la continua en +0,002 A con consigna 0 y dentro de ±0,02 A en todos los regímenes. La tabla vieja, con las 800 cuentas de diferencia entre control deshabilitado y lazo cerrado, queda como antecedente que motivó el autocero, o se mueve a 14 (problemas encontrados).

En 9.3 y 9.4 hay que cambiar la ecuación con N_0 = 2808 por la descripción del autocero, y anotar el AD822 a 10 V con el motivo. La salida del AD822 se midió en 0,74 V.

## Rizado

Reemplaza 12.8.5 y la sección de rizado del `.tex`. Mismo procedimiento en los tres puntos, documentado en `Muestras Osciloscopio/rizado/rizado_18V_0.5A.md`. Primero una mediana de 1 µs quita los picos de conmutación, después un promedio de 50 µs saca la baja frecuencia, y el rizado es el pico a pico de lo que queda.

| Consigna | Captura | Corriente de baja frecuencia (A) | Rizado (A pp) | Octave 18 V, 12.9 (A pp) |
|---|---|---:|---:|---:|
| 0,2 A | `rizado_18V_0.2A_9p6ohm_i0.18A` | 0,18 | 0,275 | 0,268 |
| 0,2 A | `rizado_18V_0.2A_9p6ohm_i0.09A` | 0,09 | 0,176 | |
| 0,5 A | `rizado_18V_0.5A_9p6ohm` | −0,42 | 0,465 | 0,483 |
| 1,0 A | `rizado_18V_1.0A_9p6ohm_i0.66A` | −0,66 | 0,526 | 0,597 |
| 1,0 A | `rizado_18V_1.0A_9p6ohm_i0.21A` | −0,21 | 0,294 | |

- El valor que se reporta en cada punto es el de la captura más cercana al máximo de |m|, es decir 0,275, 0,465 y 0,526 A pp. Los tres superan 0,20 A pp y el criterio no se cumple, como predecían el análisis y la simulación.
- La concordancia con Octave queda en 3 %, 4 % y 12 %. La simulación de 12.9 es con 9 Ω y 200 µH, y la carga real tiene 11,8 Ω y 212 µH.
- La fórmula del unipolar, ΔI_pp ≈ Vdc·|m|(1−|m|)/(2·L·f_sw), con 18 V y 212 µH da 0,22, 0,43 y 0,52 A pp en el punto de cada captura principal.
- Hay que borrar la discrepancia de 0,66 A pp sin causa, porque las capturas viejas restaban dos puntas y no tenían la consigna anotada. Pasan a antecedente o se quitan.
- Figuras nuevas en `docs/informe/figuras/`, `rizado_18V_02A.png`, `rizado_18V_05A.png` y `rizado_18V_10A.png`.

## Transitorios

Va en 12.8, con una subsección nueva o dentro de la tabla de ensayos, y en 13.4 y en el `.tex`. Una imagen por ensayo, desde `transitorios/`.

- `escalon_0.5-1.0A`, de 0,485 a 0,97 A. Se establece en unos 30 ms, un poco más de un período. Encaja con la rampa de la referencia, que limita el cambio a 1 A cada 20 ms (`AMPLITUD_PASO_MAX` en `sw/lazo_control.c`), más la respuesta del PR.
- `escalon_0.2-0.5A`, de 0,19 a 0,48 A, pasando unos 30 ms por cero. La amplitud se elige con SW[1:0] (`sw/control_principal.c`), donde 01 es 0,2 A y 10 es 0,5 A. Al bajar SW0 antes de subir SW1 se pasa por 00, que es 0 A. Desde cero llega a 0,48 A en unos 30 ms.
- `cambio_R_0.5A`, 0,48 A en toda la ventana de 50 ms, sin transitorio visible a esa escala. El PR trata el cambio de R como una perturbación de 50 Hz y la rechaza. Que la R cambió se ve en la acción del CSV a 0,5 A, que pasa de 0,368 a 0,495, un 34 % más con la misma corriente.
- `arranque_0-0.2A`, de 0 a unos 0,27 A en los 50 ms de la ventana. Queda por encima de la consigna y la ventana termina antes de que se establezca. El enunciado no pide este ensayo, así que puede ir como dato adicional o quedarse fuera.
- Hay que borrar de 12.8.6, 13.4, 15 y 16 que los cambios de consigna y de R no tienen registro.

## Saturación a 1,0 A con la carga +25 %

Reemplaza la discusión de saturación y fuente del `.tex` y el párrafo de 12.8.1.

Con 18 V, el tope de acción de 0,92 da 16,6 V. Para 1,0 A pico hacen falta R·1 A más las pérdidas del puente, y eso supera lo disponible con la carga +25 %. La corriente máxima alcanzable queda cerca de los 0,91 A que dio el sensor, así que la saturación la explica la carga y no hace falta la hipótesis del límite de la fuente.

De la acción de los CSV a 0,2 y 0,5 A sale una relación V/I que baja con la corriente, señal de una caída casi constante en el puente. Ajustando R más una caída fija, la carga original da unos 12,2 Ω con 0,65 V de caída, cerca de los 11,8 Ω medidos. La carga +25 % da unos 15,7 Ω con 1,0 V. Con esos números, 1,0 A pide unos 16,7 V, justo por encima de los 16,6 V disponibles.

## R de la carga +25 %

Hay tres valores para la misma carga.

- 11,8 Ω más los 2,5 Ω agregados dan 14,3 Ω, un 21 % más, que no llega al 25 %.
- El multímetro dio 18,7 Ω a dos hilos.
- La acción de control da unos 15,7 Ω, un 29 % más que los 12,2 Ω que da el mismo método con la carga original.

Se decidió el 26 de noviembre usar los 15,7 Ω. Es el valor compatible con la tensión aplicada a 0,2 y 0,5 A y con la saturación a 1,0 A, y cumple el 25 %. La lectura del multímetro no se usa, porque con 18,7 Ω la acción a 0,5 A habría tenido que llegar a unos 10,4 V y llegó a 8,9 V.

## Limitaciones (12.8.6 y la sección del `.tex`)

Ya no son limitación, se borran:
- La ganancia del sensor sin calibrar contra el osciloscopio.
- Los cambios de consigna y de R sin registro.
- El rizado sin consigna ni bus, medido restando dos puntas.
- El segundo inductor sin medir.
- El bus sin anotar y el punto de 1,0 A sin alcanzar.
- El cero del sensor con el puente conmutando.

Siguen como limitación:
- La pierna A del tiempo muerto sin captura.
- El ancho máximo y el jitter de la ISR, la precarga, el último pulso truncado y la fase ADC/Timer/PWM.
- El filtro antialias y la prueba de falla.
- La R sin medir a cuatro hilos ni en caliente.

Se agregan:
- La discrepancia de la R de la carga +25 %.
- El sesgo de unos −4 % entre la corriente física y la referencia, con signo contrario al que predice la simulación.
- Las capturas del osciloscopio no son del mismo minuto que los CSV.

## Otras secciones

- Resumen (1) y estado de la evidencia. Actualizar el cumplimiento. El error de la fundamental cumple en los tres puntos según el sensor y según el osciloscopio, salvo 1,0 A con la carga +25 %, que cumple por poco y satura. El rizado no cumple.
- 9.2. R total de 11,8 Ω confirmada y el segundo inductor igual al primero, así que la L total es de unos 212 µH. Agregar los 18,7 Ω de la carga +25 %.
- 13.6. En la tabla de comparación, cambiar las filas de fundamental física, saturación a 1,0 A y rizado por los valores nuevos.
- 13.7. Cambiar las filas de error de fundamental y de rizado.
- 14. Agregar el autocero y el AD822 a 10 V como problemas resueltos.
- 16. Rehacer las conclusiones 6 y 7 con los números nuevos.
- 18.5 y la tabla de archivos del `.tex`. Agregar `muestras_Inversor/mediciones_finales/`, `transitorios/`, las capturas nuevas de rizado y `potencia/analizar_rizado.py`.
- `potencia/figuras_banco.py`. Cambiar la lista de ensayos a los CSV de `mediciones_finales/` y regenerar `banco_regimen.png`.
- Parámetros medidos del `.tex`. Cambiar el límite de la fuente a 0,74 A con 18 V y quitar la fila de 12,5 V.
- Después de editar el `.tex`, recompilar `informe_tecnico_pedp`, copiar el PDF a `entregables/` y `entrega/` y regenerar `entregables/informe_tecnico.zip`.
