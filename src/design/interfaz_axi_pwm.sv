`timescale 1ns/1ps
`default_nettype none

module interfaz_axi_pwm (
    input  wire               clk,
    input  wire               rst_n,
    input  wire [3:0]         s_axi_awaddr,
    input  wire [2:0]         s_axi_awprot,
    input  wire               s_axi_awvalid,
    output wire               s_axi_awready,
    input  wire [31:0]        s_axi_wdata,
    input  wire [3:0]         s_axi_wstrb,
    input  wire               s_axi_wvalid,
    output wire               s_axi_wready,
    output wire [1:0]         s_axi_bresp,
    output logic              s_axi_bvalid,
    input  wire               s_axi_bready,
    input  wire [3:0]         s_axi_araddr,
    input  wire [2:0]         s_axi_arprot,
    input  wire               s_axi_arvalid,
    output wire               s_axi_arready,
    output logic [31:0]       s_axi_rdata,
    output wire [1:0]         s_axi_rresp,
    output logic              s_axi_rvalid,
    input  wire               s_axi_rready,
    input  wire               running,
    output logic              enable,
    output logic [1:0]        freq_sel,
    output logic signed [15:0] duty_ref
);
    typedef enum logic [1:0] {CAPTURA, EJECUTA, RESPONDE} estado_escritura_t;
    estado_escritura_t estado_escritura;
    logic [3:0] awaddr_reg;
    logic [31:0] wdata_reg;
    logic [3:0] wstrb_reg;
    logic aw_pendiente, w_pendiente;
    wire acepta_aw = s_axi_awvalid && s_axi_awready;
    wire acepta_w  = s_axi_wvalid  && s_axi_wready;

    assign s_axi_awready = rst_n && (estado_escritura == CAPTURA) && !aw_pendiente;
    assign s_axi_wready  = rst_n && (estado_escritura == CAPTURA) && !w_pendiente;
    assign s_axi_arready = rst_n && !s_axi_rvalid;
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // AW y W se guardan por separado. Solo EJECUTA modifica la configuracion.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            estado_escritura <= CAPTURA;
            awaddr_reg <= '0;
            wdata_reg <= '0;
            wstrb_reg <= '0;
            aw_pendiente <= 1'b0;
            w_pendiente <= 1'b0;
            s_axi_bvalid <= 1'b0;
            enable <= 1'b0;
            freq_sel <= 2'b01;
            duty_ref <= '0;
        end else begin
            case (estado_escritura)
                CAPTURA: begin
                    if (acepta_aw) begin
                        awaddr_reg <= s_axi_awaddr;
                        aw_pendiente <= 1'b1;
                    end
                    if (acepta_w) begin
                        wdata_reg <= s_axi_wdata;
                        wstrb_reg <= s_axi_wstrb;
                        w_pendiente <= 1'b1;
                    end
                    if ((aw_pendiente || acepta_aw) && (w_pendiente || acepta_w))
                        estado_escritura <= EJECUTA;
                end
                EJECUTA: begin
                    // Comparar los cuatro bits impide alias entre 0x0, 0x8 y offsets no alineados.
                    case (awaddr_reg)
                        4'h0: if (wstrb_reg[0]) begin
                            enable <= wdata_reg[0];
                            freq_sel <= wdata_reg[2:1];
                        end
                        4'h4: begin
                            if (wstrb_reg[0]) duty_ref[7:0] <= wdata_reg[7:0];
                            if (wstrb_reg[1]) duty_ref[15:8] <= wdata_reg[15:8];
                        end
                        default: begin end
                    endcase
                    s_axi_bvalid <= 1'b1;
                    estado_escritura <= RESPONDE;
                end
                RESPONDE: if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    aw_pendiente <= 1'b0;
                    w_pendiente <= 1'b0;
                    estado_escritura <= CAPTURA;
                end
                default: begin
                    estado_escritura <= CAPTURA;
                    aw_pendiente <= 1'b0;
                    w_pendiente <= 1'b0;
                    s_axi_bvalid <= 1'b0;
                end
            endcase
        end
    end

    // Instantanea de lectura. En una lectura/escritura simultanea se lee el valor previo.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= '0;
        end else if (s_axi_arvalid && s_axi_arready) begin
            case (s_axi_araddr)
                4'h0: s_axi_rdata <= {28'b0, running, freq_sel, enable};
                4'h4: s_axi_rdata <= {16'b0, duty_ref};
                default: s_axi_rdata <= '0;
            endcase
            s_axi_rvalid <= 1'b1;
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

    // AWPROT/ARPROT se aceptan sin restricciones, de acuerdo con el contrato de la IP.
endmodule

`default_nettype wire
