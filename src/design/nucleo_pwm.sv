// Núcleo del periférico PWM, especificado en docs/diseño/modulos/nucleo_pwm.md
// Por ahora tiene la portadora, el cálculo de las referencias y sus registros sombra, el resto de las etapas se agrega después
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
    // +1 y -1 en Q2.14
    localparam logic signed [15:0] DUTY_MAX = 16'sd16384;
    localparam logic signed [15:0] DUTY_MIN = -16'sd16384;
    // Referencia de reinicio, la de duty_ref = 0 con MAX_FREQ_00
    localparam logic [ANCHO_PORTADORA-1:0] REF_REINICIO = ANCHO_PORTADORA'((MAX_FREQ_00 * 16384) >> 15);

    logic [ANCHO_PORTADORA-1:0] max_entrada;
    logic signed [15:0] duty_sat;

    logic [ANCHO_PORTADORA-1:0] max_etapa1;
    logic signed [15:0] duty_sat_etapa1;

    logic [16:0] duty_desplazado;
    logic [ANCHO_PORTADORA+15:0] producto;
    logic [ANCHO_PORTADORA-1:0] ref_a_calculada;

    logic [ANCHO_PORTADORA-1:0] max_etapa2;
    logic [ANCHO_PORTADORA-1:0] ref_a_etapa2;
    logic [ANCHO_PORTADORA-1:0] ref_b_etapa2;

    logic [ANCHO_PORTADORA-1:0] max_sombra;
    logic [ANCHO_PORTADORA-1:0] ref_a_sombra;
    logic [ANCHO_PORTADORA-1:0] ref_b_sombra;
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

    // Saturación de duty_ref a -1 y +1, la comparación es con signo
    always_comb begin
        if (duty_ref > DUTY_MAX) duty_sat = DUTY_MAX;
        else if (duty_ref < DUTY_MIN) duty_sat = DUTY_MIN;
        else duty_sat = duty_ref;
    end

    // Etapa 1 del pipeline, guarda duty_sat junto con su MAX
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            max_etapa1 <= ANCHO_PORTADORA'(MAX_FREQ_00);
            duty_sat_etapa1 <= '0;
        end
        else begin
            max_etapa1 <= max_entrada;
            duty_sat_etapa1 <= duty_sat;
        end
    end

    // 16384 + duty_sat va de 0 a 32768, ya sin signo
    assign duty_desplazado = 17'(17'sd16384 + 17'(duty_sat_etapa1));
    // MAX · (16384 + duty_sat), menos de 2^28 con MAX = 5000, cabe en un DSP48E1
    assign producto = max_etapa1 * duty_desplazado[15:0];
    // Correr 15 bits divide entre 32768, así ref_a = MAX · (1 + d) / 2
    assign ref_a_calculada = producto[ANCHO_PORTADORA+14:15];

    // Etapa 2 del pipeline, ref_b sale de una resta para que ref_a + ref_b = MAX exacto
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            max_etapa2 <= ANCHO_PORTADORA'(MAX_FREQ_00);
            ref_a_etapa2 <= REF_REINICIO;
            ref_b_etapa2 <= ANCHO_PORTADORA'(MAX_FREQ_00) - REF_REINICIO;
        end
        else begin
            max_etapa2 <= max_etapa1;
            ref_a_etapa2 <= ref_a_calculada;
            ref_b_etapa2 <= max_etapa1 - ref_a_calculada;
        end
    end

    // Un ciclo por período, cuando el contador vale 0
    assign valle = (portadora == '0);

    // Registros sombra, solo se cargan en el valle y el resto del período conservan el valor
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            max_sombra <= ANCHO_PORTADORA'(MAX_FREQ_00);
            ref_a_sombra <= REF_REINICIO;
            ref_b_sombra <= ANCHO_PORTADORA'(MAX_FREQ_00) - REF_REINICIO;
        end
        // Los tres salen de la etapa 2, así el MAX entra junto con las referencias calculadas con él
        else if (valle) begin
            max_sombra <= max_etapa2;
            ref_a_sombra <= ref_a_etapa2;
            ref_b_sombra <= ref_b_etapa2;
        end
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
