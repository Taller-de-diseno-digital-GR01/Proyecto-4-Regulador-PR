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

## Escribir las limitaciones en los documentos

Todavía no están escritas, solo listadas arriba. Cada una va en la sección de resultados que la usa y en las conclusiones.

- `informe.md`, 12.8 (tabla de ensayos) y 12.8.4. Ya dicen que la pierna A no tiene captura y que los cambios de consigna y de R no tienen registro. Falta una subsección corta al final de 12.8 que junte todas las limitaciones de la lista de arriba y diga qué criterio del enunciado queda sin demostrar por cada una.
- `informe.md`, 13.3 a 13.6 (análisis). Citar las limitaciones al explicar las diferencias entre sensor y osciloscopio, el rizado de 0,66 A pp y la saturación de 1,0 A.
- `informe.md`, 15 y 16. El análisis crítico y las conclusiones deben nombrar lo que no se pudo demostrar y por qué no se repitió.
- `informe_tecnico_pedp.tex`, la sección de discusión y las conclusiones, mismo contenido. La rúbrica B.4 pesa 40 % en resultados y reproducibilidad, así que conviene que la tabla de archivos diga qué evidencia existe y qué se anotó sin respaldo.
- `informe_diseno_pedp.tex`, la planificación de ensayos, aclarando cuáles se ejecutaron.

## Qué se encontró en la revisión y ya quedó corregido

Sirve de contexto para no repetirlo.

- Los nombres de las capturas de compuertas cambiaron en `e8954b0`. Ya se actualizaron la tabla de archivos del `.tex`, la tabla 12.8 y la figura 7.
- El `.tex` decía que el rizado medido caía en el rango de la simulación. Los 0,66 A pp superan las simulaciones a 12,5 V (0,26 a 0,40) y a 18 V (0,56 a 0,60). Corregido en el `.tex` y en 12.8.5.
- `informe.md` se contradecía, con PENDIENTE en §1, 13.6, 13.7, 14 y 16 sobre cosas que 12.8 ya reporta. Sincronizado.
- La referencia [1] citaba el anexo B y la rúbrica de Taller es el anexo A. Corregido.
- La saturación de 1,0 A con 12,5 V se explicaba por los 11,8 Ω. La simulación con la carga medida da solo 7 a 9 % de error y el banco 35 %. Se agregó la hipótesis del límite de la fuente de 0,52 A, sin confirmar.
- Se agregó 12.12 (Octave conmutado con 11,8 Ω y 12,5 V) y la tabla de PLECS en lazo cerrado en 12.11.
- Rúbrica A.3 de Taller, pesos del informe. Fundamentación 20 %, presentación de resultados 30 %, análisis 25 %, conclusiones 15 %. La rúbrica B.4 de PEDP pesa rigor técnico 30 %, resultados y reproducibilidad 40 %, discusión 20 % y presentación 10 %.

## Cómo retomar en Windows

- Rama `doc/informe-resultados`, último commit `cb60584`, ya en el remoto. Hacer `git pull` antes de tocar nada. Jefferson empuja a `develop`, así que revisar `git log origin/develop` por novedades y traerlas con merge.
- El commit `36d5ec2`, con mensaje `.`, trae los intermedios de biber (`informe_pedp.bbl`, `.bcf`, `.blg`, `.out`, `.run.xml`, `.thm`). Ya está publicado. Quitarlo requiere force push, decidir si vale la pena.
- Compilar los informes de PEDP desde `potencia/informe/`. El `make` por defecto falla porque intenta compilar `fig/puente_h.tex`. Compilar cada uno con `pdflatex`, `biber`, `pdflatex`, `pdflatex` sobre `informe_tecnico_pedp` y `informe_diseno_pedp`. Necesita `pdflatex` y `biber` (MiKTeX o TeX Live).
- Los cálculos de Octave se corren desde la raíz con `octave --eval "addpath('potencia'); simular_conmutado(11.8, 200e-6, 12.5, 18)"`. Tarda unos 80 s y reescribe `docs/informe/evidencia/modelo_conmutado.txt` y `docs/informe/figuras/conmutado_05A.png`. Copiar la salida a otro nombre y restaurar los originales con `git checkout`, como se hizo con `modelo_conmutado_11p8ohm_12p5V_pr18V.txt`.
- Vivado y Vitis 2025.1 son los de la máquina del laboratorio. La simulación temporizada y los reportes se hacen donde esté Vivado, y no hace falta la Basys3 conectada.

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
