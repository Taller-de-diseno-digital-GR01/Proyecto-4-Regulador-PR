# Pendientes del Proyecto 4

Revisión del 24 de noviembre de 2026 contra las rúbricas A.3 (informe de Taller) y B.4 (informe técnico de PEDP). No se vuelve al laboratorio, así que lo que dependía de medir pasa a limitaciones declaradas y el resto se hace con lo que ya hay en el repositorio.

## Limitaciones que se declaran, sin nueva medición

Cada una va escrita en `informe.md` y en `informe_tecnico_pedp.tex` como lo que no se midió, con su consecuencia para el criterio. La rúbrica pide discutir limitaciones y diferencias entre predicción y práctica, y eso se puede hacer sin dato nuevo.

- Pierna A del tiempo muerto. Los 1,23 µs y 430 ns salen de lo anotado en el banco y no hay captura. No existe en ninguna rama, y el CSV `scope_a2_piernaA_tiempo_muerto.csv` borrado en `81937cd` era idéntico al de rizado. Se presenta como medición anotada, no como evidencia archivada, y solo la pierna B tiene captura.
- Cambios de consigna 0,2 a 0,5 A y 0,5 a 1,0 A, y cambio de R a 0,5 A. Sin registro. Se cubren con la simulación (PLECS, Octave conmutado y modelo promediado) y con lo observado a ojo en el banco, dicho como tal. Solo hay evidencia del cambio 0,5 a 0,2 A y del cambio de carga a 1,0 A saturado, ambos como imagen con amplitudes leídas de la cuadrícula.
- Rizado sin consigna ni bus anotados, con dos puntas restadas. Los 0,25 a 0,66 A pp se reportan con ese alcance, y el 0,66 queda como discrepancia sin causa identificada.
- Ganancia del sensor sin calibración en el mismo minuto. El sesgo de 14,6 y 18,7 % queda como diferencia medida entre sensor y osciloscopio, con el sesgo del valle (3 a 10 % según el modelo) y la ganancia como causas posibles, sin repartir el resto.
- Cero del sensor con el puente conmutando. Queda la deducción de unas 2560 cuentas a partir del proporcional, y la causa del desplazamiento de 800 cuentas sin aislar.
- Segundo inductor y R en caliente o a cuatro hilos. Se supone el segundo igual al medido, 106,2 µH, y se dice.
- Tensión de bus en la captura de 1,0 A. La hipótesis del límite de fuente (0,47 A medios contra 0,52 A de límite con 12,5 V) queda como hipótesis.
- Ancho máximo y jitter de la ISR, precarga de 70 µs, último pulso truncado, fase ADC/Timer/PWM, filtro antialias y prueba de falla. Solo se afirma el período de 50 µs en JB1, y lo demás se marca como no medido.

## Se puede hacer sin laboratorio

- Simulación post-implementación temporizada del periférico PWM (Carlos). Necesita Vivado y no la tarjeta. Sintetizar e implementar `periferico_pwm` como top, `write_verilog -mode timesim` y `write_sdf`, correr el autochequeo en xsim y archivar comandos, log final y avisos de temporización. El procedimiento está en 18.3 de `informe.md`. Es el hueco más grande que queda en el rubro de simulación autoverificable.
- Regenerar los reportes de Vivado con las fuentes actuales de `develop` (`13dad7e`), que también solo necesita Vivado. Los de `informe.md` 12.7 son del 11 de noviembre. Clasificar o resolver `LUTAR-1`, `TIMING-9` y `TIMING-18`.
- Justificar por escrito la caché de instrucciones de 8 KB, o habilitarla.
- Octave conmutado con L de 212 µH (el inductor medido por dos) además de los 200 µH, unos 80 s con `simular_conmutado(11.8, 212.4e-6, 12.5, 18)`, para acotar cuánto cambia el rizado y el sesgo del valle.
- Reanalizar los datos que ya existen. Con las capturas de rizado de 0,1 µs (`rizado/scope_a2` a `a4`) se puede inferir en qué punto de la senoide de 50 Hz se tomaron, y con eso una consigna aproximada para cada una. Con `osc_*.csv` y los CSV del receptor se puede ajustar la ganancia por amplitud para ver si el cociente que crece con la corriente (1,14, 1,19 y 1,27) se explica por el rizado plegado.
- `informe.md`, secciones 3 a 11 sin revisar tras el cambio de carga y los datos de banco. Verificar que no queden cifras de 9 Ω y 18 V presentadas como actuales.
- `informe.md`, la carga aparece como 9 Ω (resumen, 12.4 a 12.9), 9,6 Ω (12.10) y 9,46 Ω con 11,8 Ω en total (12.8 y 12.12). Dejar una sola tabla de cargas y decir cuál usa cada análisis.
- `informe.md`, falta una figura para 12.12 y para el PLECS en lazo cerrado. La figura `conmutado_05A.png` sigue siendo la de 9 Ω y 18 V.
- Los coeficientes de `sw/pr_params.h` están normalizados con 18 V y el banco se hizo a 12,5 V. Decidir si se regeneran con `sw/generar_pr_params.m` o se deja documentado.
- Recompilar `informe_diseno_pedp` e `informe_tecnico_pedp` y copiar los PDF a `entregables/` y `entrega/` cada vez que cambie un `.tex`, y regenerar `entregables/informe_tecnico.zip`.

## Repositorio

- Los CSV y capturas están en tres copias (`muestras_Inversor/`, `entregables/evidencia/` y `entregables/informe_tecnico/evidencia/`), más `entrega/` con los PDF. Decidir cuál se queda para la entrega y borrar el resto.
- Merge de las ramas `feature/*` y `doc/*` hacia `develop`, y de `develop` hacia `main`, que hoy no reúne la implementación.
- Issues y pull requests abiertos al día, y el README con la estructura final.
- Confirmar con el TEC Digital la fecha vigente de entrega del informe, porque el enunciado indica 19 y 20 de noviembre.
