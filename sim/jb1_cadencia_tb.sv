// Simulación standalone de la cadencia del AXI Timer y el pulso de depuración de la ISR en JB1.
// No verifica ningún módulo de src/design, es evidencia para mostrar la cadencia de 50 us con vvp +VCD en vez de un dibujo a mano.
// El período del tick es real (cuenta de ciclos igual a TIMER_TLR+2 de sw/control_principal.h).
// El ancho del pulso de JB1 SI es una estimación (ANCHO_CICLOS), no una medición de hardware, igual que antes.
`timescale 1ns/1ps
`default_nettype none

module jb1_cadencia_tb;

    localparam int RELOJ_HZ = 100_000_000;
    localparam int PR_FRECUENCIA_MUESTREO_HZ = 20_000;
    localparam int TIMER_TLR = RELOJ_HZ / PR_FRECUENCIA_MUESTREO_HZ - 2; // sw/control_principal.h
    localparam int CICLOS_POR_PERIODO = TIMER_TLR + 2; // 5000 ciclos, 50 us a 100 MHz
    localparam int ANCHO_CICLOS = 2000; // 20 us, punto medio del rango sin FPU de lazo_control.md (15 a 25 us), no medido
    localparam int PERIODOS = 6;

    logic clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    int cuenta = 0;
    logic tick = 1'b0;
    logic jb1 = 1'b0;
    int ciclos_en_isr = 0;
    logic en_isr = 1'b0;

    always_ff @(posedge clk) begin
        tick <= 1'b0;
        if (cuenta == CICLOS_POR_PERIODO - 1) begin
            cuenta <= 0;
            tick <= 1'b1;
        end else begin
            cuenta <= cuenta + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (tick) begin
            jb1 <= 1'b1;
            en_isr <= 1'b1;
            ciclos_en_isr <= 0;
        end else if (en_isr) begin
            if (ciclos_en_isr == ANCHO_CICLOS - 1) begin
                jb1 <= 1'b0;
                en_isr <= 1'b0;
            end else begin
                ciclos_en_isr <= ciclos_en_isr + 1;
            end
        end
    end

    initial begin
        if ($test$plusargs("VCD")) begin
            $dumpfile("jb1_cadencia.vcd"); $dumpvars(0, jb1_cadencia_tb);
        end
        repeat (PERIODOS * CICLOS_POR_PERIODO) @(posedge clk);
        $display("jb1_cadencia_tb: %0d periodos de %0d ns simulados", PERIODOS, CICLOS_POR_PERIODO * 10);
        $finish;
    end

endmodule
