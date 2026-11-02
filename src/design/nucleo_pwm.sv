// Núcleo del periférico PWM, especificado en docs/diseño/modulos/nucleo_pwm.md
// Por ahora solo tiene la portadora, el resto de las etapas se agrega después
module nucleo_pwm #(
    // Tiempo muerto en ciclos de clk
    parameter int unsigned DEAD_TIME_CICLOS = 100,
    // Máximo de la portadora por código de freq_sel, MAX_FREQ_00 tiene que ser el mayor
    parameter int unsigned MAX_FREQ_00 = 5000,
    parameter int unsigned MAX_FREQ_01 = 2500,
    parameter int unsigned MAX_FREQ_10 = 1250,
    parameter int unsigned MAX_FREQ_11 = 2500
) (
    input logic clk,
    input logic rst_n,
    input logic enable,
    input logic [1:0] freq_sel,
    // Q2.14 con signo, de -1 a +1
    input logic signed [15:0] duty_ref,
    output logic running,
    output logic compuerta_a_alta,
    output logic compuerta_a_baja,
    output logic compuerta_b_alta,
    output logic compuerta_b_baja,
    output logic pwm_trigger_o
);

    // Ancho del contador, sale del máximo más grande
    localparam int unsigned ANCHO_PORTADORA = $clog2(MAX_FREQ_00 + 1);

    logic [ANCHO_PORTADORA-1:0] max_entrada;
    logic [ANCHO_PORTADORA-1:0] max_sombra;
    logic [ANCHO_PORTADORA-1:0] portadora;
    logic contando_arriba;
    logic valle;

    // Tabla de MAX según freq_sel, el código 11 usa MAX_FREQ_11
    always_comb begin
        case (freq_sel)
            2'b00: max_entrada = ANCHO_PORTADORA'(MAX_FREQ_00);
            2'b01: max_entrada = ANCHO_PORTADORA'(MAX_FREQ_01);
            2'b10: max_entrada = ANCHO_PORTADORA'(MAX_FREQ_10);
            default: max_entrada = ANCHO_PORTADORA'(MAX_FREQ_11);
        endcase
    end

    // Un ciclo por período, cuando el contador vale 0
    assign valle = (portadora == '0);

    // El MAX nuevo solo entra en el valle, así ningún período mezcla dos frecuencias
    always_ff @(posedge clk) begin
        if (!rst_n) max_sombra <= ANCHO_PORTADORA'(MAX_FREQ_00);
        else if (valle) max_sombra <= max_entrada;
    end

    // Portadora triangular de 0 a max_sombra y de vuelta, 2·MAX ciclos por período
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            portadora <= '0;
            contando_arriba <= 1'b1;
        end
        else if (contando_arriba) begin
            portadora <= portadora + 1'b1;
            // Cambia de sentido al llegar a MAX, el >= cubre un max_sombra de 1
            if (portadora + 1'b1 >= max_sombra) contando_arriba <= 1'b0;
        end
        else begin
            portadora <= portadora - 1'b1;
            // Cambia de sentido al llegar a 0
            if (portadora == ANCHO_PORTADORA'(1)) contando_arriba <= 1'b1;
        end
    end

    // Pendiente, mientras no estén las demás etapas las salidas quedan en 0 y el puente apagado
    assign running = 1'b0;
    assign compuerta_a_alta = 1'b0;
    assign compuerta_a_baja = 1'b0;
    assign compuerta_b_alta = 1'b0;
    assign compuerta_b_baja = 1'b0;
    assign pwm_trigger_o = 1'b0;

endmodule
