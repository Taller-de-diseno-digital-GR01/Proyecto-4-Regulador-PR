// Envoltura AXI4-Lite del XADC, especificada en docs/diseño/modulos/envoltura_xadc.md
`timescale 1ns/1ps

module envoltura_xadc (
    // Los atributos asocian clk y rst_n a las interfaces s_axi y m_drp, porque sus nombres no son los de AXI
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK",
       X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axi:m_drp, ASSOCIATED_RESET rst_n, FREQ_HZ 100000000" *)
    input logic clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST",
       X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW" *)
    input logic rst_n,
    // Disparo del valle desde nucleo_pwm
    input logic pwm_trigger_o,
    // Esclavo AXI4-Lite, Vivado lo infiere por el prefijo s_axi_
    input logic [3:0] s_axi_awaddr,
    input logic s_axi_awvalid,
    output logic s_axi_awready,
    input logic [31:0] s_axi_wdata,
    input logic [3:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,
    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,
    input logic [3:0] s_axi_araddr,
    input logic s_axi_arvalid,
    output logic s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready,
    // Hacia el XADC Wizard, el DRP va como interfaz maestra para conectarlo con un solo cable al s_drp del wizard
    output logic xadc_convst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:drp:1.0 m_drp DEN" *)
    output logic xadc_den,
    (* X_INTERFACE_INFO = "xilinx.com:interface:drp:1.0 m_drp DWE" *)
    output logic xadc_dwe,
    (* X_INTERFACE_INFO = "xilinx.com:interface:drp:1.0 m_drp DADDR" *)
    output logic [6:0] xadc_daddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:drp:1.0 m_drp DI" *)
    output logic [15:0] xadc_di,
    (* X_INTERFACE_INFO = "xilinx.com:interface:drp:1.0 m_drp DO" *)
    input logic [15:0] xadc_do,
    (* X_INTERFACE_INFO = "xilinx.com:interface:drp:1.0 m_drp DRDY" *)
    input logic xadc_drdy,
    input logic xadc_busy,
    input logic xadc_eoc,
    input logic [4:0] xadc_channel
);

    // Registros elegidos con los bits [3:2] de la dirección (h.2)
    localparam logic [1:0] REG_CONTROL = 2'b00;
    localparam logic [1:0] REG_DATO = 2'b01;

    typedef enum logic [1:0] {
        LIBRE,
        DISPARANDO,
        CONVIRTIENDO,
        LEYENDO
    } estado_t;

    estado_t estado;

    logic fuente;
    logic pulso_inicio;
    logic trigger_r;
    logic disparo;
    logic [11:0] muestra;
    logic [1:0] contador;

    // Una escritura se acepta en el ciclo en que awready y wready están en 1
    logic escribe;
    logic [31:0] dato_lectura;

    // Respuestas siempre OKAY
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // La envoltura solo lee por el DRP
    assign xadc_dwe = 1'b0;
    assign xadc_di = 16'h0000;

    // Escritura. awready y wready suben juntos un ciclo con las dos validaciones y sin respuesta pendiente
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
        end else if (s_axi_awvalid && s_axi_wvalid && !s_axi_awready && !s_axi_bvalid) begin
            s_axi_awready <= 1'b1;
            s_axi_wready <= 1'b1;
        end else begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
        end
    end

    assign escribe = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;

    // bvalid sube al ciclo siguiente de la escritura y se sostiene hasta bready
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
        end else if (escribe) begin
            s_axi_bvalid <= 1'b1;
        end else if (s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end

    // Registro de control. inicio no se guarda, solo deja pulso_inicio en 1 durante el ciclo siguiente
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            fuente <= 1'b0;
            pulso_inicio <= 1'b0;
        end else begin
            pulso_inicio <= 1'b0;
            if (escribe && s_axi_awaddr[3:2] == REG_CONTROL && s_axi_wstrb[0]) begin
                fuente <= s_axi_wdata[1];
                pulso_inicio <= s_axi_wdata[0];
            end
        end
    end

    // Lectura. arready sube un ciclo con arvalid y sin dato pendiente
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
        end else if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
            s_axi_arready <= 1'b1;
        end else begin
            s_axi_arready <= 1'b0;
        end
    end

    // inicio se lee siempre en 0
    always_comb begin
        case (s_axi_araddr[3:2])
            REG_CONTROL: dato_lectura = {30'b0, fuente, 1'b0};
            REG_DATO: dato_lectura = {18'b0, contador, muestra};
            default: dato_lectura = 32'b0;
        endcase
    end

    // rdata toma el valor del ciclo en que se acepta la dirección y rvalid se sostiene hasta rready
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 32'b0;
        end else if (s_axi_arready && s_axi_arvalid) begin
            s_axi_rvalid <= 1'b1;
            s_axi_rdata <= dato_lectura;
        end else if (s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

    // pwm_trigger_o pasa por un flip-flop, así CONVST sube dos ciclos después del valle (h.4)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            trigger_r <= 1'b0;
        end else begin
            trigger_r <= pwm_trigger_o;
        end
    end

    // La fuente no elegida se ignora
    assign disparo = fuente ? trigger_r : pulso_inicio;

    // Máquina de conversión (h.5)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            estado <= LIBRE;
            xadc_convst <= 1'b0;
            xadc_den <= 1'b0;
            xadc_daddr <= 7'b0;
            muestra <= 12'b0;
            contador <= 2'b0;
        end else begin
            xadc_den <= 1'b0;
            case (estado)
                LIBRE: begin
                    // Con xadc_busy en 1 el XADC está ocupado, por ejemplo calibrando al salir del reinicio, y el disparo se ignora como uno durante una conversión
                    if (disparo && !xadc_busy) begin
                        xadc_convst <= 1'b1;
                        estado <= DISPARANDO;
                    end
                end
                DISPARANDO: begin
                    if (xadc_busy) begin
                        xadc_convst <= 1'b0;
                        estado <= CONVIRTIENDO;
                    end
                end
                CONVIRTIENDO: begin
                    // El resultado del canal está en el registro de estado con la dirección igual al número de canal
                    if (xadc_eoc) begin
                        xadc_den <= 1'b1;
                        xadc_daddr <= {2'b00, xadc_channel};
                        estado <= LEYENDO;
                    end
                end
                LEYENDO: begin
                    // Los 12 bits del resultado ocupan los bits altos del registro de 16
                    if (xadc_drdy) begin
                        muestra <= xadc_do[15:4];
                        contador <= contador + 2'd1;
                        estado <= LIBRE;
                    end
                end
                default: begin
                    xadc_convst <= 1'b0;
                    estado <= LIBRE;
                end
            endcase
        end
    end

endmodule
