# Registro de mediciones del 24.11

Lo que se anotó en el banco. Las capturas y los CSV que faltan los sube Jefferson.

## Carga

- Resistencias de la carga original, 9,46 Ω. Inductancia nominal de 200 µH.
- Resistencia total de la carga con inductores y cables, 11,8 Ω.
- La carga del +25 % agrega 2,5 Ω en serie. Sobre las resistencias es +26 %, sobre la total +21 %.

## Fuente

- Límite de corriente de 1 A con 18 V.
- Límite de corriente de 0,52 A con 12,5 V.

## Compuertas, con Vdc apagado

- Pierna A, tiempo muerto de 1,23 µs en subida y 430 ns en bajada. No hay captura de compuertas de esta pierna en ninguna rama. `scope_a2` es el CSV de rizado, y su copia `scope_a2_piernaA_tiempo_muerto.csv` se borró en `81937cd` por ser idéntica.
- Pierna B, tiempo muerto de 1 µs en subida y 1 µs en bajada (`scope_a1`).
- Habilitar y deshabilitar en `scope_a6.png`.

## Lazo

- JB1 se repite cada 50 µs, o sea 20 kHz.
- Rizado de 3,27 V pp sobre las resistencias, unos 0,35 A pp con 9,46 Ω. Probablemente con 12,5 V, no quedó anotada la corriente.
- 1 A con 18 V, rizados y cambio de amplitud hechos, los datos los tiene Jefferson.

## No se midió

- Temperaturas. La disipación se justifica con cuenta, unos 2,4 W por cada resistencia de 4,7 Ω a 1 A pico.
- Tensión sobre la carga, se calcula después.
- Inductores y resistencias por separado con el multímetro, queda por decidir.
