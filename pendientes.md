# Pendientes del Proyecto 4

Revisión del 24 de noviembre de 2026 contra las rúbricas A.3 (informe de Taller) y B.4 (informe técnico de PEDP). Cada ítem dice qué archivo o dato falta y dónde se cita.

## Capturas y mediciones de banco

- Captura de compuertas de la pierna A (Jefferson). Debe mostrar CH1 y CH2 con cursores en los dos flancos, para respaldar los 1,23 µs y los 430 ns anotados en `registro.md`. Va en `muestras_Inversor/Muestras Compuertas/` con nombre `scope_aN_piernaA_*.png`. No existe en ninguna rama, y el CSV `scope_a2_piernaA_tiempo_muerto.csv` que se borró en `81937cd` era idéntico al de rizado, no una captura de compuertas. Se cita en la tabla de archivos y en la sección de compuertas de `informe_tecnico_pedp.tex`, y en 12.8 y 12.8.4 de `informe.md`.
- Cambio de consigna de 0,2 a 0,5 A y de 0,5 a 1,0 A. Hoy solo hay 0,5 a 0,2 A, como imagen con acople de alterna y amplitudes leídas de la cuadrícula. Guardar CSV de la tensión sobre las resistencias, con acople de continua y en alta resolución, y el CSV del receptor del mismo ensayo.
- Cambio de R a 0,5 A con 2,5 Ω añadidos. El transitorio guardado es a 1,0 A con 18 V y la acción saturada, y el de 0,5 A no se guardó. Es el ensayo que pide el enunciado.
- Rizado con la consigna y el bus anotados en cada captura, a 0,2, 0,5 y 1,0 A. Medir con una punta diferencial o con el cable BNC solo, sin restar dos puntas. Los 0,66 A pp actuales superan todas las simulaciones y no tienen causa identificada.
- Calibración de la ganancia del sensor contra el osciloscopio en el mismo minuto que el CSV, con al menos 1 MS/s para que el rizado de 20 kHz no se pliegue. Hoy el osciloscopio da entre 14,6 y 18,7 % más corriente física que el sensor.
- Cero del sensor con el puente conmutando y la referencia nula. Se mueve unas 800 cuentas entre puente apagado y conmutando y la causa no se aisló.
- Segundo inductor con LCR a 1 kHz. Solo se midió uno, 106,2 µH. La resistencia total de 11,8 Ω se midió a dos hilos y en frío, queda pendiente en caliente o a cuatro hilos.
- Repetir 1,0 A con 12,5 V subiendo el límite de la fuente por encima de 0,52 A, y registrar la tensión del bus durante la captura. Confirma o descarta que la saturación sea por la fuente y no por los 11,8 Ω.
- Ancho máximo y jitter de la ISR con el pin JB1, medidos en el osciloscopio. Hoy solo está el período de 50 µs.
- Precarga de 70 µs y último pulso truncado al apagar. Las capturas de habilitar y deshabilitar son a 50 ms/div y no las resuelven, hay que repetirlas a unos 10 µs/div.
- Fase entre ADC, Timer y PWM, y el filtro antialias (issue #29).
- Prueba de falla con desconexión, para documentar la limitación de corriente y la desconexión ante fallas que pide la condición de demostración.

## Simulación y Vivado

- Simulación post-implementación temporizada del periférico PWM (Carlos). Sintetizar e implementar `periferico_pwm` como top, `write_verilog -mode timesim` y `write_sdf`, correr el autochequeo en xsim y archivar comandos, log final y avisos de temporización. El procedimiento está en 18.3 de `informe.md` y todavía no hay log.
- Regenerar los reportes de Vivado con las fuentes actuales de `develop` (`13dad7e`). Los de `informe.md` 12.7 son del 11 de noviembre. Clasificar o resolver `LUTAR-1`, `TIMING-9` y `TIMING-18`.
- Justificar por escrito la caché de instrucciones de 8 KB, o habilitarla, ya que el código corre desde la BRAM local.
- Confirmar que el `.elf` actual corre en la placa con `make bit_con_elf` y `make flash`, y anotar la revisión del bitstream usado en los ensayos.

## Documentos

- `informe.md`, secciones 3 a 11 sin revisar tras el cambio de carga y los datos de banco. Verificar que no queden cifras de 9 Ω y 18 V presentadas como actuales.
- `informe.md`, la carga aparece como 9 Ω (resumen, 12.4 a 12.9), 9,6 Ω (12.10) y 9,46 Ω con 11,8 Ω en total (12.8 y 12.12). Dejar una sola tabla de cargas y decir cuál usa cada análisis.
- `informe.md`, falta una figura para 12.12 y para el PLECS en lazo cerrado. La figura `conmutado_05A.png` sigue siendo la de 9 Ω y 18 V.
- Los coeficientes de `sw/pr_params.h` están normalizados con 18 V y el banco se hizo a 12,5 V. Decidir si se regeneran con `sw/generar_pr_params.m` o se deja documentado.
- Modelos con la inductancia medida. PLECS y Octave usan 200 µH nominales, y un inductor midió 106,2 µH.
- Causa del 0,66 A pp de rizado y de la diferencia de 14 a 19 % entre sensor y osciloscopio, una vez hechas las mediciones de arriba. Actualizar el resumen y las conclusiones de `informe.md` y de `informe_tecnico_pedp.tex` con lo que salga.
- Recompilar `informe_diseno_pedp` e `informe_tecnico_pedp` y copiar los PDF a `entregables/` y `entrega/` cada vez que cambie un `.tex`, y regenerar `entregables/informe_tecnico.zip`.

## Repositorio

- Los CSV y capturas están en cuatro copias (`muestras_Inversor/`, `entregables/evidencia/`, `entregables/informe_tecnico/evidencia/` y `entrega/` solo con PDF). Decidir cuál se queda para la entrega y borrar el resto.
- Merge de las ramas `feature/*` y `doc/*` hacia `develop`, y de `develop` hacia `main`, que hoy no reúne la implementación.
- Issues y pull requests abiertos al día, y el README con la estructura final.
- Confirmar con el TEC Digital la fecha vigente de entrega del informe, porque el enunciado indica 19 y 20 de noviembre.
