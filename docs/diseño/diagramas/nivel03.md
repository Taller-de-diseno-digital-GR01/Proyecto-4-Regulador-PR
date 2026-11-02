# Nivel 3

## Software del MicroBlaze V

El bloque 2 del nivel 2 ejecuta todo el programa en C. Acá se abre en nueve módulos con nombre. Ocho viven en el MicroBlaze V y uno, `receptor_pc`, corre en la computadora. El objetivo, las entradas, las salidas y el funcionamiento de cada uno están en su propio archivo de `docs/diseño/modulos/`, que en el nivel 4 se completa con el detalle.

```mermaid
flowchart TD
    subgraph HW["Periféricos del nivel 2"]
        TMR["AXI Timer"]
        ADC["Interfaz ADC/XADC"]
        PWM["Periférico PWM"]
        GPIO["AXI GPIO"]
        UART["AXI UART Lite"]
    end

    subgraph SW["Programa en C del MicroBlaze V"]
        CP["control_principal<br/>lazo principal"]
        LC["lazo_control<br/>rutina de interrupción"]
        PR["pr_discreto"]
        REF["ref_senoidal"]
        SF["supervisor_falla"]
        BUF["buffer_muestras"]
        EXP["exportador_uart"]
        DRV["drivers"]

        CP -->|"control_habilitado, amplitud_ref"| LC
        LC -->|"falla"| CP
        LC -->|"i_ref, corriente"| PR
        PR -->|"duty_ref, saturado"| LC
        LC -->|"avance de fase"| REF
        REF -->|"i_ref"| LC
        LC -->|"corriente, dato_ausente"| SF
        SF -->|"falla"| LC
        LC -->|"corriente, duty_ref, saturado"| BUF
        CP -->|"exportar"| EXP
        EXP -->|"congelar y liberar"| BUF
        BUF -->|"registros congelados"| EXP
        CP --> DRV
        LC --> DRV
        EXP --> DRV
    end

    PC["receptor_pc<br/>script de Python en la PC"]

    TMR -->|"interrupción periódica"| LC
    DRV <-->|"AXI4-Lite"| ADC
    DRV <-->|"AXI4-Lite"| PWM
    DRV <-->|"AXI4-Lite"| GPIO
    DRV <-->|"AXI4-Lite"| UART
    DRV <-->|"AXI4-Lite"| TMR
    UART -->|"tx, 115200 baudios, 8N1"| PC
```

### Módulos

- [`control_principal`](../modulos/control_principal.md), arranque del sistema, botones, switches de amplitud, LEDs y pedido de exportación.
- [`lazo_control`](../modulos/lazo_control.md), rutina de interrupción del Timer con una iteración del control.
- [`pr_discreto`](../modulos/pr_discreto.md), ecuación en diferencias del PR con saturación y anti-windup.
- [`ref_senoidal`](../modulos/ref_senoidal.md), referencia sinusoidal de 50 Hz.
- [`drivers`](../modulos/drivers.md), única capa que toca registros de periféricos.
- [`buffer_muestras`](../modulos/buffer_muestras.md), histórico circular en la BRAM local.
- [`exportador_uart`](../modulos/exportador_uart.md), envío del histórico sin bloquear el lazo principal.
- [`supervisor_falla`](../modulos/supervisor_falla.md), apagado del puente por sobrecorriente o falta de dato.
- [`receptor_pc`](../modulos/receptor_pc.md), recepción y gráficas en la computadora.

### Contextos de ejecución

El programa tiene dos contextos. `lazo_control` corre dentro de la interrupción del Timer y es lo único con plazo fijo, junto con lo que llama (`ref_senoidal`, `pr_discreto`, `supervisor_falla` y la escritura en `buffer_muestras`). `control_principal` y `exportador_uart` corren en el lazo principal, que nunca bloquea y puede ser interrumpido en cualquier punto. Ningún acceso que espere a un periférico lento, como la UART, entra a la interrupción.

Los dos contextos comparten pocas variables, cada una de 32 bits y declarada `volatile`, con un solo escritor. `control_principal` escribe `control_habilitado` y `amplitud_ref`, y la interrupción solo las lee. La interrupción escribe `falla` y el lazo principal solo la lee. Así ninguna necesita candado.

## Periférico PWM

El bloque 6 del nivel 2 se abre en dos módulos de SystemVerilog dentro de `periferico_pwm`, que es el módulo superior que se empaqueta como IP. `interfaz_axi_pwm` atiende el bus y guarda los registros, y `nucleo_pwm` genera la portadora, las compuertas y el disparo del ADC. Van en archivos separados para que cada uno se trabaje en su rama sin pisarse.

```mermaid
flowchart LR
    AXI(["Interconexión AXI"])
    CR(["clk y rst_n"])

    subgraph PER["periferico_pwm"]
        IF["interfaz_axi_pwm<br/>registros 0x00 y 0x04"]
        NUC["nucleo_pwm<br/>portadora, comparadores,<br/>tiempo muerto y trigger"]

        IF -->|"enable, freq_sel, duty_ref"| NUC
        NUC -->|"running"| IF
    end

    ADC(["Interfaz ADC/XADC"])
    PH(["Drivers del puente H"])

    AXI <-->|"AXI4-Lite"| IF
    CR --> IF
    CR --> NUC
    NUC -->|"pwm_trigger_o"| ADC
    NUC -->|"compuerta_a_alta, compuerta_a_baja,<br/>compuerta_b_alta, compuerta_b_baja"| PH
```

### Módulos

- `interfaz_axi_pwm`, esclavo AXI4-Lite con el registro de control y estado y el de `duty_ref`.
- [`nucleo_pwm`](../modulos/nucleo_pwm.md), portadora triangular, modulación unipolar, tiempo muerto y `pwm_trigger_o`.

### Registros

- `0x00`, control y estado. `enable` en el bit 0, `freq_sel` en los bits [2:1] y `running` en el bit 3, de solo lectura.
- `0x04`, `duty_ref` en los bits [15:0], en Q2.14 con signo.

### Reparto de funciones

La interfaz guarda lo que escribe el software y lo pasa tal cual al núcleo. Los registros sombra, la saturación de `duty_ref` y la espera al valle están en el núcleo, así que la interfaz no necesita saber nada de la portadora. `running` va en sentido contrario, lo produce el núcleo y la interfaz solo lo expone en lectura.

El tiempo muerto no pasa por la interfaz. Es el `parameter` `DEAD_TIME_CICLOS` de `nucleo_pwm`, que `periferico_pwm` expone como parámetro de la IP para fijarlo al armar el Block Design.

Los dos módulos usan el reloj y el reinicio del bus, así que no hay cruce de dominios de reloj entre la interfaz y el núcleo.
