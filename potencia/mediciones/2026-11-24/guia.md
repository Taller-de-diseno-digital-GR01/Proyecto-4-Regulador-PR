# Mediciones del 24 de noviembre

Lista corta de lo que falta medir para los dos informes de PEDP, en el orden en que conviene hacerlo. Los códigos (0.1, A1, B2, D3 y demás) son los de `docs/guia_mediciones.md`, donde está el detalle de cada medición. Acá va solo lo que falta después de la sesión del 23.11 y lo que esa sesión dejó en duda.

## Qué dejó la sesión del 23.11

Ajuste de la fundamental en 5 períodos de los CSV de `muestras_Inversor/`, con Vdc de 12,5 V.

- 0,2 y 0,5 A siguen la referencia según el sensor, con +0,46 y +0,17 % de error y menos de 0,05° de desfase.
- 1,0 A satura (31 muestras con `saturado` en 1) y da −34,8 % y +21,6°. Con 12,5 V no alcanza.
- Los cuatro CSV traen unos +0,2 A de continua, también el de 0 A. O se tomaron antes del offset de 2808 cuentas (`e9299a6`), o el cero sigue corrido.
- Las capturas del osciloscopio tienen un punto cada 100 µs. Sirven para la fundamental, pero no para el rizado de 20 kHz.
- `F1` es la tensión sobre las dos resistencias de 4,7 Ω (9,6 Ω medidos), con un cable BNC con caimanes 1:1. Dividida entre 9,6 Ω da 0,225, 0,584 y 0,816 A de fundamental, contra 0,200, 0,500 y 0,651 A del sensor. Si las dos capturas son del mismo ensayo, la corriente real queda 12,5 y 16,8 % arriba de la referencia en 0,2 y 0,5 A, fuera del 10 %, y el sensor lee de menos. Por eso A2 va antes que cualquier ensayo.

## Antes de empezar

- Vdc. 0,2 A, 0,5 A y el cambio de carga van con 12,5 V, y 1,0 A se intenta con 18 V. Con los coeficientes de hoy (`PR_KP = 0,25` normalizado) la ganancia física es `0,25 · Vdc`, 3,1 V/A con 12,5 V y 4,5 V/A con 18 V, que es el valor de diseño de `diseno_pr.md`. Para pasar a 18 V se deshabilita el control, se sube Vdc con el límite de la fuente puesto y se vuelve a habilitar. Todos los ensayos van con el mismo firmware, anotando Vdc en cada fila.
- Anotar el commit del firmware que corre (`git log -1 --format=%h` en `sw/`), los modelos de la fuente, del osciloscopio y de las puntas, y la atenuación de cada punta.
- Roles fijos, una persona en la fuente y la seguridad, otra operando la Basys 3 y otra en el osciloscopio y las anotaciones.

## Puntas del osciloscopio y tierras

Con los VO3120 el lado de la Basys 3 y el del puente tienen tierras separadas, y el caimán de tierra de las dos puntas está unido por dentro del osciloscopio a la tierra del enchufe.

- Los dos caimanes de tierra van al mismo nodo, la tierra de potencia. Nunca un caimán en un nodo y el otro en otro, porque eso cortocircuita los dos nodos a través del osciloscopio.
- El cable BNC con caimanes en paralelo a las dos resistencias, como el 23.11, sirve solo si es lo único conectado al lado de potencia, porque su caimán negro fija ese nodo a la tierra del enchufe.
- Si hay que medir algo más a la vez, la tensión sobre las resistencias se mide con CH1 y CH2 en sus dos extremos, los dos caimanes en la tierra de potencia, y `F1 = CH1 − CH2` en el menú Math.
- JB1 (la rutina de control) es del lado de la Basys 3. Esa captura se hace aparte, con las puntas del lado de potencia desconectadas, para no unir las dos tierras por el osciloscopio.
- Si las resistencias de 4,7 Ω son de alambre (las de cemento de 5 W suelen serlo), tienen algo de inductancia propia. Puede deformar el rizado que se ve sobre ellas, y se anota su tipo.

## 1. Carga y fuentes, con Vdc apagado (0.1, 0.2 y 0.3)

- Las dos de 4,7 Ω dieron 9,6 Ω juntas, y es la R que se usa para pasar `F1` a corriente. Falta medir cada inductor y la carga total con el cableado, restando las puntas en corto. Los 9,6 Ω que usan `parametros.m` y los scripts de Mattio son solo las resistencias, así que la R total es algo mayor.
- La de 2,7 Ω, medida sola. Sobre 9,6 Ω es un cambio de 28,1 %. Se anota su potencia nominal.
- Con 1,0 A pico cada resistencia de 4,7 Ω disipa 2,35 W, el 47 % de sus 5 W.
- L de cada inductor con LCR a 1 kHz, si hay LCR. Si no hay, se anota que L queda con su valor nominal y se contrasta con la pendiente del rizado.
- Vdc con la carga conectada, `VCC` del sensor y el riel de 3,3 V del Pmod.

## 2. Cero y ganancia del sensor (A1 y A2)

- A1. Con Vdc apagado, el sensor alimentado y el control deshabilitado, se exporta un CSV a 0 A. La media de `corriente_a` tiene que quedar a unos pocos mA de cero. Si vuelven a salir +0,2 A, el offset del firmware no es el de la placa y se corrige antes de seguir, porque todo lo demás hereda ese error.
- A2. Con el PR a 0,5 A se toman en el mismo minuto un CSV y una captura de `F1` sobre la R externa, de al menos 100 ms. El cociente entre la fundamental de `F1 / R_ext` y la del CSV es el factor que le falta a la ganancia del sensor. Si no da 1, se corrige `ADC_AMPERES_POR_CUENTA` antes de los ensayos, porque el PR sigue al sensor y no a la corriente real. Conviene repetirlo con 0,2 y 1,0 A para ver si el factor es el mismo en toda la escala.

## 3. Compuertas con la potencia apagada (B2 y B3)

Las capturas del 16.11 no están en ninguna rama, solo la descripción en el informe de Mattio, así que se repiten. Es condición del enunciado para la demostración. Con Vdc apagado y los 15 V puestos se guarda una captura de una pierna con alta y baja, donde se vea el tiempo muerto de 1 µs con su escala, otra de la precarga al habilitar y otra del último pulso al deshabilitar.

## 4. Seguimiento nominal (D3, ensayo 1 del enunciado)

Se hace con 0,2, 0,5 y 1,0 A pico. El enunciado (4.3.5) pide en cada ensayo la referencia, la corriente medida, la tensión aplicada a la carga y evidencia del PWM. Con dos canales y los caimanes en la misma tierra no entran la R externa y la carga en una sola captura, así que cada punto lleva dos.

- El CSV del receptor ya en régimen, unos segundos después de habilitar o de cambiar el switch. Trae la referencia y la corriente según el sensor.
- Corriente. Una captura larga de `F1 = CH1 − CH2` sobre la R externa, con al menos 5 períodos de 50 Hz (20 ms/div da 200 ms), guardada en CSV con la mayor cantidad de puntos que deje el osciloscopio. Con ella se sacan la fundamental, su valor pico y el RMS total de la corriente.
- Rizado. Otra captura de `F1` sobre la R externa, de unos 20 µs/div (4 períodos de conmutación), centrada en el pico de la corriente de 50 Hz, que es donde el rizado es mayor. Se separa de la fundamental restando el promedio de cada período de conmutación, igual que `potencia/sim/rizado.py`.
- Tensión y PWM. CH1 en la salida de la pierna A, CH2 en la de B, los dos caimanes en la tierra de potencia y `F1 = CH1 − CH2`, que es la tensión sobre la carga con sus tres niveles. Una captura corta muestra los pulsos y una larga la fundamental de la tensión.
- Vdc, si hubo saturación (LED o la columna `saturado`) y la corriente que marca la fuente.

Para comparar, el modelo conmutado de Mattio con 9,6 Ω, 200 µH y 12 V da 0,26, 0,39 y 0,40 A pp de rizado (`docs/informe/informe.md`, 12.10, en `doc/informe-resultados`). Lo que se mida se anota tal cual, aunque pase de 0,20 A.

## 5. Cambios de amplitud (D4, ensayo 2)

- De 0,2 a 0,5 A y de 0,5 a 1,0 A, cambiando el switch con el control andando y con la misma Vdc del punto de llegada.
- El transitorio se toma con el osciloscopio en Single, con una ventana de 50 ms/div (500 ms), moviendo el switch durante la captura.
- El CSV congela las últimas 2048 muestras (102 ms) al apretar exportar, así que hay que exportar apenas se mueve el switch. Si no entra el cambio, queda la captura del osciloscopio como registro.

## 6. Cambio de carga del 25 % (D5, ensayo 3)

Con 0,5 A pico, la misma L y la misma Vdc.

- La resistencia extra va en serie con la carga y con un interruptor o puente en paralelo que la cortocircuita. Con el puente cerrado la carga es la nominal, y al abrirlo entra la R extra sin cortar la corriente. Nunca se abre un interruptor en serie con la carga con corriente, porque la L levanta un pico de tensión.
- Primero el régimen con la carga nominal (CSV y captura larga), después se abre el puente durante una captura en Single de 500 ms, y al final el régimen con la carga nueva (CSV, captura larga y captura de rizado).
- Con la de 2,7 Ω las resistencias suman unos 12,3 Ω más los devanados, y con 0,4 Ω de `RDS(on)` y los 0,64 V de fundamental del tiempo muerto con 12,5 V (`modelo_planta.md`) hacen falta unos 7 V para 0,5 A. El índice queda cerca de 0,56, así que no debería saturar. La R extra disipa 0,125 W por cada ohm con 0,5 A pico.
- Se anotan la R externa antes y después y el porcentaje de cambio, contra la R externa y contra la total.

## 7. Lazo en tiempo real (C1 a C3)

Con Vdc apagado y las puntas del lado de potencia desconectadas, JB1 con el control habilitado y deshabilitado, y con la medición del período, del ancho máximo y del jitter (modo persistencia o estadísticas del osciloscopio).

## 8. Falla y temperaturas (D6)

- Temperatura de los MOSFET, de la R externa y de los inductores después de unos minutos a 1,0 A, con termómetro o cámara térmica si hay. Si no hay, se anota que no se midió. El enunciado pide margen de disipación en las resistencias de 5 W a 1,0 A, así que se anota también la potencia nominal de cada una.
- El límite de corriente de la fuente con que se corrió cada ensayo, que el enunciado pide documentar junto al accionamiento de compuertas y la desconexión ante falla.
- La desconexión ante falla se documenta con una captura de una compuerta y del LED de falla en el momento en que salta. Cómo provocar la falla de forma segura se decide con el equipo antes de la sesión.

## Nombres de archivo

Todo va a `potencia/mediciones/2026-11-24/`, con el código del ensayo, el punto y la R, por ejemplo `D3_05A_Rnom.csv`, `D3_05A_Rnom_osc_largo.csv`, `D3_05A_Rnom_osc_rizado.csv` y `D5_05A_cambio_osc.csv`. Junto a los archivos va un `registro.md` con una línea por captura (hora, ensayo, Vdc, R, escala de tiempo y de tensión, atenuación de la punta y quién la tomó).
