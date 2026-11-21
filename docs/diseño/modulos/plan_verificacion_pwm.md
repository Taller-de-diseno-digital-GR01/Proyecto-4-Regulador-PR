# Plan de verificación del periférico PWM

## Alcance de la entrega de diseño

Este documento especifica los casos de prueba y criterios de aceptación de [`interfaz_axi_pwm`](modulos/interfaz_axi_pwm.md) y [`periferico_pwm`](modulos/periferico_pwm.md), incluyendo el comportamiento del [`nucleo_pwm`](modulos/nucleo_pwm.md) que debe observarse desde la IP completa.

El plan define pruebas previstas para la etapa de diseño. La Persona B prepara el banco del periférico integrado y verifica la interfaz AXI4-Lite. La Persona A aporta las condiciones temporales del núcleo. Las pruebas de FPGA y de lazo cerrado se coordinan con quienes integran el XADC, el firmware y la etapa de potencia.

## Organización prevista del banco

El DUT de integración será `periferico_pwm`. Un agente maestro producirá accesos AXI4-Lite y podrá separar AW y W, detener la aceptación de respuestas y combinar lecturas con escrituras. Un modelo de registros independiente mantendrá las expectativas de lectura, escritura parcial y reset.

Los monitores observarán handshakes, respuestas, cuatro compuertas y trigger. Los casos registrarán número de comprobaciones y fallos; un fallo dará un mensaje identificable y un resultado final de error. La inspección visual de una forma de onda no sustituye el autochequeo.

Se utilizará un período de reloj de 10 ns. Para acelerar parte de las pruebas se podrán reducir MAX, tiempo muerto y precarga manteniendo las relaciones necesarias para cada prueba; los casos temporales finales se repetirán con los parámetros de 100 MHz y las frecuencias de operación.

Los timeouts del banco se aplicarán a tramos donde el maestro esté dispuesto a completar la transacción. No se declarará falla porque una respuesta se mantenga pendiente durante una contrapresión que el propio banco haya impuesto.

## Matriz de pruebas AXI y registros

| ID | Estímulo | Resultado esperado |
|---|---|---|
| AX01 | Reset mantenido varios ciclos | BVALID y RVALID en cero, capturas vacías y compuertas apagadas |
| AX02 | Leer después de liberar reset | `0x00=0x00000002` con núcleo detenido y `0x04=0` |
| AX03 | AW y W en el mismo flanco | Una escritura y una confirmación B |
| AX04 | AW varios ciclos antes de W | Se conserva AWADDR hasta recibir el dato correcto |
| AX05 | W varios ciclos antes de AW | Se conservan WDATA y WSTRB sin aplicarlos a una dirección equivocada |
| AX06 | Cambiar AWADDR o WDATA después de su handshake | Se utiliza exclusivamente el valor capturado |
| AX07 | Mantener BREADY en cero tras una escritura | BVALID y BRESP estables; no se repite la escritura ni se acepta otra AW o W |
| AX08 | Mantener RREADY en cero y modificar la configuración por escritura | RVALID, RDATA y RRESP de la lectura pendiente no cambian |
| AX09 | Presentar otra AR con una lectura pendiente | No se acepta hasta liberar la anterior |
| AX10 | Mantener VALID hasta que READY acepte cada canal | Un handshake produce una sola captura; el maestro retira o cambia el pedido después de la aceptación |
| AX11 | Realizar transacciones consecutivas | Mismo número de pedidos completos y respuestas; se permiten las burbujas documentadas |
| AX12 | Leer un registro en el mismo flanco de ejecución de escritura | La lectura devuelve el valor previo a la escritura |
| AX13 | Escribir campos RO y reservados | `running` sigue al núcleo y los reservados se leen cero |
| AX14 | `WSTRB=0000` | Respuesta OKAY y registros sin cambios |
| AX15 | Escribir solo el byte bajo de `duty_ref` | Se actualiza `[7:0]` y se conserva `[15:8]` |
| AX16 | Escribir solo el byte alto de `duty_ref` | Se actualiza `[15:8]` y se conserva `[7:0]` |
| AX17 | Activar únicamente WSTRB de los bytes superiores | No cambia ningún registro útil |
| AX18 | Escribir control con WSTRB del byte bajo desactivado | Se conservan `enable` y `freq_sel` |
| AX19 | Acceder a `0x08`, `0x0C` y un offset no alineado | Lectura cero, escritura sin efecto y respuesta OKAY, según la política elegida |
| AX20 | Reset después de aceptar solo AW o solo W | Se descarta la captura y no aparece una escritura fantasma al reiniciar |
| AX21 | Reset con BVALID o RVALID pendientes | Respuestas eliminadas y registros reiniciados |
| AX22 | Cambiar AWPROT y ARPROT | Sin diferencia funcional bajo la política sin restricciones definida |
| AX23 | Acceder por SmartConnect a `base + 0x10` y `base + 0x14` dentro del segmento de 4 KiB | Los cuatro bits bajos reproducen `0x00` y `0x04`. Probar por separado que los offsets locales `0x01`, `0x05`, `0x08` y `0x0C` carecen de registro en el esclavo PWM. |

Un ejemplo numérico para AX15 y AX16: desde `0x1234`, una escritura del byte bajo `0xAB` produce `0x12AB`; actualizar luego el byte alto con `0xCD` produce `0xCDAB`. La comprobación compara bits antes de interpretar el valor con signo.

## Matriz de pruebas de PWM integrado

| ID | Estímulo | Resultado esperado |
|---|---|---|
| PW01 | Mantener `enable=0` | Cuatro compuertas en cero; portadora y trigger siguen según el núcleo |
| PW02 | Habilitar a mitad de período | `running` sube en el ciclo 1 tras el valle. Ambas compuertas bajas arrancan en el ciclo 2 y se mantienen en 1 durante 7000 ciclos consecutivos con las altas apagadas. Luego cada pierna pasa por `MUERTO` antes de habilitar la salida según su comparación. |
| PW03 | Deshabilitar a mitad de período | `running` baja en el ciclo 1 tras el valle correspondiente y las cuatro compuertas quedan apagadas en el ciclo 2. Repetir el caso durante la precarga y durante modulación normal. |
| PW04 | Referencia cero | Referencias de ambas piernas iguales; tensión diferencial media ideal cero |
| PW05 | Referencia `0x2000` | A +0,5, referencias de comparación equivalentes a 75 % y 25 % antes del tiempo muerto |
| PW06 | Referencia `0xE000` | Se intercambia la actuación relativa de las piernas, conservando complementariedad |
| PW07 | Referencias `0x4000` y `0xC000` | Límites +1 y -1 sin desbordes ni solapamiento |
| PW08 | Valores fuera de rango `0x7FFF` y `0x8000` | Actuación limitada a +1 y -1; lectura AXI conserva el patrón solicitado |
| PW09 | Recorrer todos los códigos de frecuencia | MAX de 5000, 2500, 1250 y 2500, con períodos de 10 000, 5000, 2500 y 5000 ciclos. Aislar el primer período interno tras reset, que usa MAX = 5000 mientras el registro AXI ya solicita `01`. |
| PW10 | Cambiar referencia a mitad de período | La referencia activa no cambia hasta la frontera de actualización correspondiente |
| PW11 | Cambiar frecuencia y referencia próximas al valle | MAX y referencias activas pertenecen al mismo conjunto calculado |
| PW12 | Hacer que la orden ya registrada llegue a la entrada del núcleo a dos, uno y cero ciclos del valle | Si la primera etapa toma la orden dos ciclos antes, se aplica en ese valle. Si la toma un ciclo antes o en el valle, se aplica en el siguiente. Usar el flanco de captura del núcleo para el chequeo y registrar por separado la ejecución AXI. |
| PW13 | Observar conmutaciones en ambas direcciones | La salida de un transistor se apaga antes de habilitar el complementario |
| PW14 | Pedir pulsos más cortos que el tiempo muerto | Pulsos suprimidos o recortados según la máquina del núcleo, sin solapamiento |
| PW15 | Monitorizar trigger con PWM habilitado y deshabilitado | Un pulso registrado de un ciclo por valle, con la latencia documentada |
| PW16 | Aplicar reset en distintas fases de portadora | Apagado en la aplicación síncrona del reset y estados iniciales coherentes |
| PW17 | Mantener una respuesta AXI detenida | El PWM continúa con los registros ya escritos; la retención B no repite la escritura |

PW04 y PW05 comprueban la relación ideal de modulación; no deben exigir una tensión física exacta ignorando tiempo muerto y cuantización. Los criterios digitales concretos se formulan sobre referencias de comparación y eventos de compuerta, con el efecto del tiempo muerto separado.

## Comprobaciones permanentes

Durante toda simulación del DUT integrado se comprobará:

- Ausencia de activación simultánea de alta y baja de una misma pierna.
- Separación de al menos `DEAD_TIME_CICLOS` ciclos entre apagado y encendido complementario, bajo la definición de conteo acordada con el núcleo.
- Ausencia de estados desconocidos en respuestas y salidas tras el reset.
- Estabilidad de BVALID y BRESP durante espera de BREADY.
- Estabilidad de RVALID, RDATA y RRESP durante espera de RREADY.
- Una confirmación por escritura y una respuesta por lectura aceptadas, salvo transacciones descartadas por reset.
- Ausencia de efectos en registros a partir de un canal AW o W recibido de forma aislada.

Para comprobar salidas sin glitches se observarán también cambios fuera del flanco permitido. Un monitor que solo mire los valores en cada flanco podría pasar por alto un pulso entre flancos.

## Parámetros temporales y tolerancias

Con los parámetros nominales se esperan períodos de portadora de 10 000, 5000 y 2500 ciclos. La referencia temporal se toma del evento de valle o trigger definido por el núcleo, no de la periodicidad de una compuerta cualquiera: a algunas referencias una salida puede dejar de conmutar o tener pulsos suprimidos.

El trigger del núcleo se describe como un pulso registrado un ciclo después del valle. El banco debe distinguir el evento interno de valle del ciclo en que se observa el trigger. El tiempo desde una escritura AXI hasta la aplicación no es constante porque intervienen el flanco de escritura, la tubería y la próxima frontera de actualización.

La configuración nominal usa `DEAD_TIME_CICLOS = 100` (1 µs) y `PRECARGA_CICLOS = 7000` (70 µs) a 100 MHz. Para una petición estable se comprueba que transcurran exactamente 100 ciclos entre el apagado de una salida y el encendido de la complementaria. Si la comparación cambia durante la espera, el monitor comprueba que la cuenta se reinicie y que las dos salidas sigan apagadas.

## Simulación temporizada posterior

Una vez exista implementación, se generarán la netlist de simulación y el SDF con la herramienta correspondiente. Se utilizará el mismo contrato externo y un banco compatible con la jerarquía y anotación de retardos, evitando dependencias innecesarias de nombres internos.

La simulación temporizada comprobará el funcionamiento tras el reset, transacciones representativas, frecuencias, tiempo muerto y salidas. No se exigirán retardos de propagación de cero: el monitor contemplará las ventanas que correspondan al reloj y al SDF. La ausencia de solapamiento se comprobará sobre las señales temporizadas reales.

Esta fase queda prevista para cuando se genere la netlist y se disponga del SDF.

## Integración en FPGA

Estas pruebas complementan el banco del PWM y cubren los puntos de integración de la sección 6 del instructivo. La verificación de compuertas y tiempo muerto con la etapa de potencia desenergizada precede a los ensayos energizados, conforme a la sección 8.2.

| ID | Prueba | Criterio de aceptación |
|---|---|---|
| INT01 | Observar el valle o `pwm_trigger_o`, la publicación de la muestra del XADC, la lectura del ADC por la ISR y la escritura de `duty_ref`, a 20 kHz. Repetir tras reinicios. | La muestra del valle actual está publicada al leerla, y el núcleo captura la orden con margen para su tubería antes del siguiente valle. El contador de muestras avanza una vez entre lecturas consecutivas durante operación normal. |
| INT02 | Medir flancos de entrada de la ISR y duración del servicio en funcionamiento extendido, con y sin exportación UART. | Registrar período nominal de 50 µs, mínimo y máximo medidos, jitter pico a pico y peor latencia observada. La fase permanece dentro de la ventana válida de INT01 y se cumple el plazo de actualización en cada ciclo observado. |
| INT03 | Simular por separado una muestra de sobrecorriente y la ausencia sostenida de muestras, con la etapa de potencia desenergizada. Para la ausencia, probar primero una omisión aislada y luego alcanzar el umbral documentado. | La omisión aislada conserva la orden anterior y se registra. Al disparar cualquiera de las fallas se enclava el estado, se escribe `enable = 0` preservando `freq_sel`, se omite cualquier orden nueva del PR y se comprueba el apagado en la frontera del núcleo. |
| INT04 | Forzar una falla entre el chequeo inicial de habilitación y la escritura del registro de control. | Si la ISR ya enclavó la falla, el código principal conserva `enable = 0`. Un pedido posterior de habilitación se rechaza mientras siga enclavada. |
| INT05 | Solicitar exportación con el botón mientras corre la ISR y verificar el histórico recibido. | La trama contiene la cantidad esperada y conserva el orden y la integridad del histórico. Durante el envío se cumplen los criterios temporales de INT01 e INT02. |

Para observar las señales internas se usará ILA o salidas de depuración temporales. La fase se mide respecto al valle interno, o respecto a `pwm_trigger_o` corrigiendo su latencia documentada de un ciclo.

## Evidencia prevista y criterio de cierre

En implementación se conservarán comando de ejecución, versión de herramienta, parámetros, semilla cuando exista aleatoriedad, resumen por caso y formas de onda de los casos relevantes. Se considera aprobado el banco cuando los casos previstos terminan sin fallos, sin transacciones perdidas y sin violaciones de las comprobaciones permanentes.

Para la entrega de diseño, los casos quedan especificados con estímulo y criterio de aceptación. Registrar los resultados al ejecutar cada prueba.
