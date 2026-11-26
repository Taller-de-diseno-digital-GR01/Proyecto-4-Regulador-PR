# Mediciones finales del 25 de noviembre

Firmware de `arreglo-final` con el autocero del offset y el AD822 del acondicionador a 10 V. Cada CSV sale de `make receptor CSV=...` y viene con su `.bin` crudo.

## Condiciones

- Bus de 18 V con límite de la fuente en 0,74 A en todas las mediciones.
- R total de la carga original, 11,8 Ω con multímetro. El segundo inductor dio igual que el primero con el LCR.
- R total de la carga +25 %, 18,7 Ω con multímetro.
- Salida del AD822 medida en 0,74 V.

## Carga original

- `0A.csv`, consigna 0. Continua de +0,002 A, 0,023 A RMS de ruido.
- `0.2A.csv`, 0,2002 A contra 0,1993 A, error 0,42 %, fase −0,02°, continua +0,010 A.
- `0.5A.csv`, 0,4997 A contra 0,4993 A, error 0,08 %, fase +0,02°, continua −0,003 A. El primer intento llegó con la trama cortada (7378 de 118358 bytes) y se repitió.
- `1.0A.csv`, 1,0001 A contra 0,9994 A, error 0,07 %, fase +0,01°, continua +0,010 A.

Ninguno tiene muestras saturadas, datos ausentes ni falla. Error y fase según el sensor, sobre los últimos cinco períodos.

## Carga +25 %, con 2,5 Ω en serie

- `carga25_0.2A.csv`, 0,2000 A contra 0,1994 A, error 0,33 %, fase −0,01°, continua +0,015 A. El primer intento salió con el control deshabilitado y está en `descartadas/`.
- `carga25_0.5A.csv`, 0,5002 A contra 0,4993 A, error 0,17 %, fase 0,00°, continua +0,008 A.
- `carga25_1.0A.csv`, 0,9132 A contra 0,9994 A, error −8,62 %, fase +13,91°, continua +0,020 A. 20 muestras saturadas, 11 en el semiciclo positivo y 9 en el negativo, con la acción en ±0,92. Los picos llegan a +1,003 y −1,034 A.

## Transitorios con el osciloscopio

En `transitorios/`, CSV y pantalla de cada uno, con la punta sobre la resistencia de 9,6 Ω. La fundamental sale de ajustar seno, coseno y continua en ventanas de 20 ms.

- `arranque_0-0.2A`, de 0 a unos 0,27 A en los 50 ms de la ventana. Era `DS0004`; el otro intento (`DS0001`) está en `descartadas/`.
- `escalon_0.2-0.5A`, de 0,19 a 0,48 A, pasando por unos 30 ms en cero.
- `escalon_0.5-1.0A`, de 0,485 a 0,97 A, establecido en unos 30 ms.
- `cambio_R_0.5A`, 0,48 A en toda la ventana de 50 ms.

## Rizado

En `muestras_Inversor/Muestras Osciloscopio/rizado/`, procesado con `potencia/analizar_rizado.py` y R = 9,6 Ω.

- 0,2 A, 0,275 A pp con 0,18 A de baja frecuencia y 0,176 A pp con 0,09 A.
- 0,5 A, 0,465 A pp con −0,42 A.
- 1,0 A, 0,526 A pp con −0,66 A y 0,294 A pp con −0,21 A.

## Descartadas

En `descartadas/` quedan los intentos que no sirven, sin borrar.

- `carga25_0.2A_deshabilitado`, con el control apagado.
- `arranque_0-0.2A_DS0001`, el arranque que no se usa.
- `previa_1.0A_25-11_16-11`, la prueba de 1,0 A de antes de la sesión, que estaba suelta en la raíz como `muestras.csv`.
- `prueba_21-11`, una exportación del 21 de noviembre con referencia nula que estaba suelta en `sw/`.
