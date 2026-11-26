# Rizado a 18 V y 0,5 A pico

Captura del 25 de noviembre con el bus en 18 V, consigna de 0,5 A pico y la punta del canal 1 sobre la resistencia de carga de 9,6 Ω. Se adquirió a 20 µs/div y 50 MSa/s, una muestra cada 20 ns y unas 1250 por período de 25 µs, en una sola adquisición de 200 µs a 2 V/div (0,08 V por nivel, unos 8 mA).

- `rizado_18V_0.5A_9p6ohm.csv`, datos del osciloscopio (`DS0005.CSV` en la USB).
- `rizado_18V_0.5A_9p6ohm_pantalla.png`, pantalla con varias pasadas superpuestas, solo de respaldo (`DS0002.PNG`).
- `docs/informe/figuras/rizado_18V_05A.png`, figura generada desde el CSV.

Se procesa desde la raíz con

```
python3 potencia/analizar_rizado.py "muestras_Inversor/Muestras Osciloscopio/rizado/rizado_18V_0.5A_9p6ohm.csv" 9.6 docs/informe/figuras/rizado_18V_05A.png "18 V, consigna 0,5 A pico, 9,6 Ω"
```

## Cómo se separó el rizado

En cada flanco del puente aparecen picos de hasta 3,2 V que duran menos de 1 µs. Una corriente que pasa por la bobina no puede saltar así, así que son de la medición y no de la carga, probablemente el dv/dt del puente acoplado en la punta y su cable de tierra. Se quitan con una mediana móvil de 1 µs (51 muestras). Con los picos el pico a pico crudo da 7,92 V y sin ellos 4,56 V.

La componente de baja frecuencia se obtiene con un promedio móvil de 50 µs, un período de la f_sw de 20 kHz. Ese promedio cancela el rizado de 40 kHz y deja la de 50 Hz, que en la ventana vale −4,01 V (−0,417 A) y cambia solo 0,11 V en los 200 µs. La captura cayó cerca del pico negativo de la senoide.

El rizado es la señal sin picos menos esa componente.

## Resultado

- Rizado de 4,47 V pp, que con 9,6 Ω son 0,465 A pp.
- Por período de 25 µs, entre 0,442 y 0,458 A pp en los 8 períodos de la captura.
- Valles cada 25,0 µs, 40 kHz, el doble de la f_sw como corresponde al PWM unipolar.

El criterio de 0,20 A pp del enunciado no se cumple. El resultado coincide con lo esperado. La simulación conmutada a 18 V y 0,5 A da 0,483 A pp de rizado máximo (12.9), un 4 % más que lo medido. Con el balance de voltios por segundo del unipolar, despreciando R, ΔI_pp ≈ Vdc·|m|(1−|m|)/(2·L·f_sw). En la captura la corriente era de 0,42 A, que con unos 11,8 Ω de R total pide |m| ≈ 0,28, y con 212 µH eso da unos 0,43 A pp.

El rizado crece con |m| hasta 0,5, y a 0,5 A |m| no pasa de unos 0,33. Por eso la captura cerca del pico de la senoide representa el rizado máximo de este punto. Bajarlo por debajo de 0,20 A pp pide más inductancia o más f_sw, y ninguna mejora de la medición lo cambia.

## Pendiente de confirmar

- Dónde estaba la tierra de la punta. Si un extremo de la resistencia quedó a la tierra del osciloscopio, eso explica los picos.
- La R total del circuito. Solo afecta la estimación de |m|, no el rizado medido.
