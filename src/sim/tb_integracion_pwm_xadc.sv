// Testbench de integración de periferico_pwm con envoltura_xadc, con pwm_trigger_o real y el modelo del XADC Wizard de tb_envoltura_xadc
`timescale 1ns/1ps
`default_nettype none

// Maestro AXI4-Lite mínimo, uno por periférico
interface axi_lite_bus (input wire logic clk);
    localparam int TIMEOUT = 1000;

    logic [3:0] awaddr = '0;
    logic [2:0] awprot = '0;
    logic awvalid = 1'b0;
    logic awready;
    logic [31:0] wdata = '0;
    logic [3:0] wstrb = '0;
    logic wvalid = 1'b0;
    logic wready;
    logic [1:0] bresp;
    logic bvalid;
    logic bready = 1'b0;
    logic [3:0] araddr = '0;
    logic [2:0] arprot = '0;
    logic arvalid = 1'b0;
    logic arready;
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready = 1'b0;

    // Espera un flanco con la condición en 1 antes de él, que es cuando se da el handshake
    task automatic esperar_handshake(ref logic senal, input string nombre);
        int espera = 0;
        do begin
            @(posedge clk);
            espera++;
            if (espera > TIMEOUT) $fatal(1, "Timeout esperando %s", nombre);
        end while (!senal);
    endtask

    task automatic escribir(input logic [3:0] direccion, input logic [31:0] dato);
        @(negedge clk);
        awaddr = direccion;
        awvalid = 1'b1;
        wdata = dato;
        wstrb = 4'hF;
        wvalid = 1'b1;
        bready = 1'b1;
        fork
            begin esperar_handshake(awready, "AWREADY"); @(negedge clk); awvalid = 1'b0; end
            begin esperar_handshake(wready, "WREADY"); @(negedge clk); wvalid = 1'b0; end
        join
        if (!bvalid) esperar_handshake(bvalid, "BVALID");
        if (bresp !== 2'b00) $error("BRESP distinto de OKAY");
        @(negedge clk);
        bready = 1'b0;
    endtask

    task automatic leer(input logic [3:0] direccion, output logic [31:0] dato);
        @(negedge clk);
        araddr = direccion;
        arvalid = 1'b1;
        rready = 1'b1;
        esperar_handshake(arready, "ARREADY");
        @(negedge clk);
        arvalid = 1'b0;
        if (!rvalid) esperar_handshake(rvalid, "RVALID");
        dato = rdata;
        @(negedge clk);
        rready = 1'b0;
    endtask
endinterface

module tb_integracion_pwm_xadc #(
    parameter int DT = 100,
    parameter int PC = 7000,
    parameter int M00 = 5000,
    parameter int M01 = 2500,
    parameter int M10 = 1250,
    parameter int M11 = 2500,
    // Margen mínimo entre CONVST y la conmutación más cercana. Es un criterio por acordar con C, por defecto un tiempo muerto
    parameter int MARGEN_MIN_CICLOS = DT,
    // El margen solo se exige con |duty| hasta acá. 9830 es 0,6 en Q2.14, arriba del índice de 0,557 con 1,0 A de verificar_pr.m
    parameter int DUTY_MAX_OPERACION = 9830,
    // Paso del barrido de duty en Q2.14
    parameter int PASO_DUTY = 512
);
    // Parámetros del modelo del wizard, los mismos de tb_envoltura_xadc
    localparam int D = 4;
    localparam int CICLOS_CALIBRACION = 300;
    localparam int LATENCIA_DRP = 3;
    localparam logic [4:0] CANAL_VAUX6 = 5'd22;

    localparam int PASOS_DUTY = 2 * 16384 / PASO_DUTY + 1;
    localparam int SIN_CAMBIO = 1_000_000;

    // Registros de los dos periféricos
    localparam logic [3:0] PWM_CONTROL = 4'h0;
    localparam logic [3:0] PWM_DUTY = 4'h4;
    localparam logic [3:0] ADC_CONTROL = 4'h0;
    localparam logic [3:0] ADC_DATO = 4'h4;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    axi_lite_bus bus_pwm (clk);
    axi_lite_bus bus_adc (clk);

    wire ah, al, bh, bl, trigger;

    logic xadc_convst;
    logic xadc_den;
    logic xadc_dwe;
    logic [6:0] xadc_daddr;
    logic [15:0] xadc_di;
    logic [15:0] xadc_do = '0;
    logic xadc_drdy = 1'b0;
    logic xadc_busy = 1'b1;
    logic xadc_eoc = 1'b0;
    logic [4:0] xadc_channel = '0;

    periferico_pwm #(
        .DEAD_TIME_CICLOS(DT), .PRECARGA_CICLOS(PC),
        .MAX_FREQ_00(M00), .MAX_FREQ_01(M01), .MAX_FREQ_10(M10), .MAX_FREQ_11(M11)
    ) pwm (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(bus_pwm.awaddr), .s_axi_awprot(bus_pwm.awprot),
        .s_axi_awvalid(bus_pwm.awvalid), .s_axi_awready(bus_pwm.awready),
        .s_axi_wdata(bus_pwm.wdata), .s_axi_wstrb(bus_pwm.wstrb),
        .s_axi_wvalid(bus_pwm.wvalid), .s_axi_wready(bus_pwm.wready),
        .s_axi_bresp(bus_pwm.bresp), .s_axi_bvalid(bus_pwm.bvalid), .s_axi_bready(bus_pwm.bready),
        .s_axi_araddr(bus_pwm.araddr), .s_axi_arprot(bus_pwm.arprot),
        .s_axi_arvalid(bus_pwm.arvalid), .s_axi_arready(bus_pwm.arready),
        .s_axi_rdata(bus_pwm.rdata), .s_axi_rresp(bus_pwm.rresp),
        .s_axi_rvalid(bus_pwm.rvalid), .s_axi_rready(bus_pwm.rready),
        .compuerta_a_alta(ah), .compuerta_a_baja(al),
        .compuerta_b_alta(bh), .compuerta_b_baja(bl), .pwm_trigger_o(trigger)
    );

    envoltura_xadc adc (
        .clk(clk), .rst_n(rst_n), .pwm_trigger_o(trigger),
        .s_axi_awaddr(bus_adc.awaddr), .s_axi_awvalid(bus_adc.awvalid), .s_axi_awready(bus_adc.awready),
        .s_axi_wdata(bus_adc.wdata), .s_axi_wstrb(bus_adc.wstrb),
        .s_axi_wvalid(bus_adc.wvalid), .s_axi_wready(bus_adc.wready),
        .s_axi_bresp(bus_adc.bresp), .s_axi_bvalid(bus_adc.bvalid), .s_axi_bready(bus_adc.bready),
        .s_axi_araddr(bus_adc.araddr), .s_axi_arvalid(bus_adc.arvalid), .s_axi_arready(bus_adc.arready),
        .s_axi_rdata(bus_adc.rdata), .s_axi_rresp(bus_adc.rresp),
        .s_axi_rvalid(bus_adc.rvalid), .s_axi_rready(bus_adc.rready),
        .xadc_convst(xadc_convst), .xadc_den(xadc_den), .xadc_dwe(xadc_dwe),
        .xadc_daddr(xadc_daddr), .xadc_di(xadc_di), .xadc_do(xadc_do), .xadc_drdy(xadc_drdy),
        .xadc_busy(xadc_busy), .xadc_eoc(xadc_eoc), .xadc_channel(xadc_channel)
    );

    int errores = 0;
    string caso = "inicio";

    task automatic verificar(input bit condicion, input string mensaje);
        if (!condicion) begin
            errores++;
            if (errores <= 30) $display("ERROR [%s] %0t: %s", caso, $time, mensaje);
        end
    endtask

    // Modelo del wizard. Cada conversión devuelve su número de orden, así un valle perdido se nota en el dato
    int conversiones_modelo = 0;
    int convst_con_busy = 0;
    logic [15:0] muestra_convertida = '0;

    initial begin
        repeat (CICLOS_CALIBRACION) @(posedge clk);
        xadc_busy <= 1'b0;
    end

    always @(posedge xadc_convst) begin
        if (xadc_busy) convst_con_busy++;
    end

    initial begin
        forever begin
            @(posedge xadc_convst);
            if (!xadc_busy) begin
                repeat ($urandom_range(1, D)) @(posedge clk);
                xadc_busy <= 1'b1;
                muestra_convertida = 16'((conversiones_modelo + 1) << 4);
                repeat (22 * D) @(posedge clk);
                xadc_busy <= 1'b0;
                repeat (16) @(posedge clk);
                xadc_channel <= CANAL_VAUX6;
                xadc_eoc <= 1'b1;
                conversiones_modelo++;
                @(posedge clk);
                xadc_eoc <= 1'b0;
            end
        end
    end

    initial begin
        forever begin
            @(posedge clk);
            if (xadc_den) begin
                repeat (LATENCIA_DRP - 1) @(posedge clk);
                xadc_do <= muestra_convertida;
                xadc_drdy <= 1'b1;
                @(posedge clk);
                xadc_drdy <= 1'b0;
                xadc_do <= 16'hDEAD;
            end
        end
    end

    // Monitor por ciclos. Mide después del NBA, así ve los valores que dejó el flanco
    int ciclo = 0;
    int valles = 0;
    int convst_total = 0;
    int ciclos_encendidas = 0;
    int ultimo_cambio = -SIN_CAMBIO;
    int ciclo_valle = 0;
    int ciclo_valle_convertido = 0;
    int ciclo_convst = 0;
    int margen_antes = 0;
    int margen_min_ventana = SIN_CAMBIO;
    int latencia_convst = 0;
    int latencia_dato = 0;
    int latencia_dato_max = 0;
    bit exigir_conversion = 0;
    bit valle_pendiente = 0;
    bit esperando_despues = 0;
    logic [3:0] compuertas_previas = '0;
    logic trigger_previo = 1'b0;
    logic convst_previo = 1'b0;
    logic drdy_previo = 1'b0;

    function automatic int minimo(input int a, input int b);
        return (a < b) ? a : b;
    endfunction

    // Cierra la medición del último CONVST con la distancia hasta la conmutación siguiente
    task automatic cerrar_margen(input int margen_despues);
        margen_min_ventana = minimo(margen_min_ventana, minimo(margen_antes, margen_despues));
        esperando_despues = 0;
    endtask

    always @(posedge clk) begin
        #1;
        ciclo++;
        if (!rst_n) begin
            verificar({ah, al, bh, bl} === 4'b0, "compuertas encendidas durante el reset");
        end else begin
            if ({ah, al, bh, bl} !== compuertas_previas) begin
                if (esperando_despues) cerrar_margen(ciclo - ciclo_convst);
                ultimo_cambio = ciclo;
            end
            if (ah || al || bh || bl) ciclos_encendidas++;

            if (trigger && !trigger_previo) begin
                valles++;
                if (exigir_conversion) verificar(!valle_pendiente, "un valle quedó sin conversión");
                valle_pendiente = 1;
                ciclo_valle = ciclo;
            end

            if (xadc_convst && !convst_previo) begin
                convst_total++;
                if (exigir_conversion) verificar(valle_pendiente, "CONVST sin valle que lo dispare");
                valle_pendiente = 0;
                latencia_convst = ciclo - ciclo_valle;
                ciclo_valle_convertido = ciclo_valle;
                // Si no hubo conmutación desde el CONVST anterior, su margen posterior es todo el intervalo
                if (esperando_despues) cerrar_margen(ciclo - ciclo_convst);
                ciclo_convst = ciclo;
                margen_antes = ciclo - ultimo_cambio;
                esperando_despues = 1;
            end

            // La envoltura guarda el dato en el flanco con drdy en 1 y se puede leer desde el ciclo siguiente
            if (xadc_drdy && !drdy_previo) begin
                latencia_dato = ciclo - ciclo_valle_convertido + 1;
                if (latencia_dato > latencia_dato_max) latencia_dato_max = latencia_dato;
            end
        end
        compuertas_previas = {ah, al, bh, bl};
        trigger_previo = trigger;
        convst_previo = xadc_convst;
        drdy_previo = xadc_drdy;
    end

    function automatic int maximo_portadora(input int seleccion);
        case (seleccion)
            0: return M00;
            1: return M01;
            2: return M10;
            default: return M11;
        endcase
    endfunction

    task automatic esperar_valles(input int n);
        int objetivo;
        objetivo = valles + n;
        wait (valles >= objetivo);
    endtask

    task automatic iniciar(input string nombre);
        caso = nombre;
        $display("PRUEBA %s", nombre);
    endtask

    // Lee el registro de dato y lo compara con la última conversión del modelo
    task automatic verificar_dato();
        logic [31:0] dato;
        bus_adc.leer(ADC_DATO, dato);
        verificar(dato[11:0] == 12'(conversiones_modelo),
            $sformatf("dato %0d, se esperaba la conversión %0d", dato[11:0], 12'(conversiones_modelo)));
        verificar(dato[13:12] == 2'(conversiones_modelo),
            $sformatf("contador %0d, se esperaba %0d", dato[13:12], 2'(conversiones_modelo)));
    endtask

    int margenes[3][PASOS_DUTY];

    initial begin : estimulos
        int valles_inicio, convst_inicio, duty, periodo;
        int margen_operacion[3];
        string fila;

        $display("INTEGRACION: DT=%0d PRECARGA=%0d MAX=%0d/%0d/%0d/%0d MARGEN_MIN=%0d DUTY_MAX=%0d",
                 DT, PC, M00, M01, M10, M11, MARGEN_MIN_CICLOS, DUTY_MAX_OPERACION);
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        iniciar("arranque, compuertas apagadas y valles ignorados durante la calibración");
        // La fuente pasa al valle con el XADC todavía calibrando
        bus_adc.escribir(ADC_CONTROL, 32'h2);
        wait (!xadc_busy);
        verificar(ciclos_encendidas == 0, "compuertas encendidas sin enable");
        verificar(valles > 0, "no hubo valles durante la calibración, la prueba no ejercitó nada");
        verificar(conversiones_modelo == 0 && convst_con_busy == 0, "CONVST durante la calibración");
        // Desde la primera conversión cada valle debe tener la suya
        @(posedge xadc_convst);
        @(negedge clk);
        exigir_conversion = 1;

        iniciar("puente apagado, una muestra por valle para medir el offset");
        for (int f = 0; f < 4; f++) begin
            bus_pwm.escribir(PWM_CONTROL, 32'(f << 1));
            esperar_valles(2);
            // La cuenta arranca después del CONVST de ese valle, si no sobra una conversión
            repeat (200) @(posedge clk);
            valles_inicio = valles;
            convst_inicio = convst_total;
            ciclos_encendidas = 0;
            esperar_valles(5);
            repeat (200) @(posedge clk);
            verificar(ciclos_encendidas == 0, $sformatf("compuertas encendidas con enable=0, freq_sel=%0d", f));
            verificar(convst_total - convst_inicio == valles - valles_inicio,
                $sformatf("freq_sel=%0d, %0d valles y %0d conversiones", f,
                          valles - valles_inicio, convst_total - convst_inicio));
            verificar_dato();
        end

        iniciar("PWM activo, una conversión por valle y latencia del valle al dato");
        bus_pwm.escribir(PWM_DUTY, 32'h1333);
        bus_pwm.escribir(PWM_CONTROL, 32'h3);
        repeat (PC) @(posedge clk);
        for (int f = 0; f < 4; f++) begin
            bus_pwm.escribir(PWM_CONTROL, 32'((f << 1) | 1));
            esperar_valles(3);
            repeat (200) @(posedge clk);
            valles_inicio = valles;
            convst_inicio = convst_total;
            latencia_dato_max = 0;
            esperar_valles(6);
            repeat (200) @(posedge clk);
            periodo = 2 * maximo_portadora(f);
            verificar(convst_total - convst_inicio == valles - valles_inicio,
                $sformatf("freq_sel=%0d, %0d valles y %0d conversiones", f,
                          valles - valles_inicio, convst_total - convst_inicio));
            verificar(latencia_dato_max < periodo, "el dato llega después del valle siguiente");
            verificar_dato();
            $display("  freq_sel=%0d periodo=%0d ciclos, CONVST a %0d ciclos de pwm_trigger_o, dato listo a %0d ciclos (%0.2f %% del periodo)",
                     f, periodo, latencia_convst, latencia_dato_max, 100.0 * latencia_dato_max / periodo);
        end

        iniciar("margen entre CONVST y la conmutación más cercana, barrido de duty");
        for (int f = 0; f < 3; f++) begin
            margen_operacion[f] = SIN_CAMBIO;
            bus_pwm.escribir(PWM_CONTROL, 32'((f << 1) | 1));
            for (int k = 0; k < PASOS_DUTY; k++) begin
                duty = -16384 + k * PASO_DUTY;
                bus_pwm.escribir(PWM_DUTY, 32'(16'(duty)));
                // El duty nuevo pasa al registro sombra en un valle, se dejan pasar dos antes de medir
                esperar_valles(3);
                margen_min_ventana = SIN_CAMBIO;
                esperar_valles(3);
                margenes[f][k] = margen_min_ventana;
                if (duty <= DUTY_MAX_OPERACION && duty >= -DUTY_MAX_OPERACION) begin
                    margen_operacion[f] = minimo(margen_operacion[f], margen_min_ventana);
                    verificar(margen_min_ventana >= MARGEN_MIN_CICLOS,
                        $sformatf("freq_sel=%0d duty=%0d, margen de %0d ciclos", f, duty, margen_min_ventana));
                end
            end
        end
        $display("  margen en ciclos de 10 ns, '-' es sin conmutación en el período y '*' es menor a %0d", MARGEN_MIN_CICLOS);
        $display("  duty_q214   duty     freq_sel=0  freq_sel=1  freq_sel=2");
        for (int k = 0; k < PASOS_DUTY; k++) begin
            duty = -16384 + k * PASO_DUTY;
            fila = $sformatf("  %9d  %7.3f", duty, duty / 16384.0);
            for (int f = 0; f < 3; f++) begin
                if (margenes[f][k] >= 2 * maximo_portadora(f))
                    fila = {fila, "           -"};
                else
                    fila = {fila, $sformatf("  %9d%s", margenes[f][k],
                                            (margenes[f][k] < MARGEN_MIN_CICLOS) ? "*" : " ")};
            end
            $display("%s", fila);
        end
        for (int f = 0; f < 3; f++)
            $display("  freq_sel=%0d, margen mínimo con |duty| <= %0.3f: %0d ciclos",
                     f, DUTY_MAX_OPERACION / 16384.0, margen_operacion[f]);

        iniciar("cierre");
        bus_pwm.escribir(PWM_CONTROL, 32'h2);
        esperar_valles(2);
        repeat (200) @(posedge clk);
        verificar({ah, al, bh, bl} === 4'b0, "compuertas encendidas tras bajar enable");
        verificar(convst_con_busy == 0, "CONVST con el XADC ocupado");
        $display("RESUMEN valles=%0d conversiones=%0d errores=%0d", valles, conversiones_modelo, errores);
        if (errores != 0) $fatal(1, "INTEGRACION: FALLIDO");
        $display("INTEGRACION: APROBADO");
        $finish;
    end

    initial begin
        #500ms;
        $fatal(1, "Watchdog global de 500 ms");
    end
endmodule

`default_nettype wire
