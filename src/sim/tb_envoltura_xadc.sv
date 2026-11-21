// Testbench autoverificable de envoltura_xadc, con un modelo simple del XADC Wizard
`timescale 1ns/1ps
`default_nettype none

module tb_envoltura_xadc;

    // Divisor del reloj del ADC del wizard (h.6 del doc)
    localparam int D = 4;
    // Ciclos de la calibración al arrancar, con xadc_busy en 1 y sin eoc
    localparam int CICLOS_CALIBRACION = 300;
    // Ciclos entre den y drdy en el modelo del DRP
    localparam int LATENCIA_DRP = 3;
    // Canal de VAUX6, 16 + 6
    localparam logic [4:0] CANAL_VAUX6 = 5'd22;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic pwm_trigger_o = 1'b0;

    logic [3:0] s_axi_awaddr = '0;
    logic s_axi_awvalid = 1'b0;
    logic s_axi_awready;
    logic [31:0] s_axi_wdata = '0;
    logic [3:0] s_axi_wstrb = '0;
    logic s_axi_wvalid = 1'b0;
    logic s_axi_wready;
    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready = 1'b0;
    logic [3:0] s_axi_araddr = '0;
    logic s_axi_arvalid = 1'b0;
    logic s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid;
    logic s_axi_rready = 1'b0;

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

    int errores = 0;
    int convst_ignorados = 0;
    int conversiones_modelo = 0;
    // Valor crudo de 16 bits que el modelo deja en el registro de estado al terminar la próxima conversión
    logic [15:0] proxima_muestra = 16'h0000;
    logic [15:0] muestra_convertida = 16'h0000;
    realtime t_trigger;
    realtime t_convst;

    always #5 clk = ~clk;

    envoltura_xadc dut (.*);

    // Modelo del wizard. La calibración arranca con la simulación, como después de configurar la FPGA
    initial begin
        repeat (CICLOS_CALIBRACION) @(posedge clk);
        xadc_busy <= 1'b0;
    end

    // Un CONVST con xadc_busy en 1 lo ignora el XADC real, y la envoltura nunca debería mandarlo
    always @(posedge xadc_convst) begin
        if (xadc_busy) begin
            convst_ignorados++;
        end
    end

    // Conversión por eventos. busy sube en el flanco del reloj del ADC siguiente al muestreo, dura 22·D ciclos y eoc llega 16 ciclos después de que baja
    initial begin
        forever begin
            @(posedge xadc_convst);
            t_convst = $realtime;
            if (!xadc_busy) begin
                repeat ($urandom_range(1, D)) @(posedge clk);
                xadc_busy <= 1'b1;
                muestra_convertida = proxima_muestra;
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

    // Lectura por el DRP. Revisa la dirección y que sea una lectura
    initial begin
        forever begin
            @(posedge clk);
            if (xadc_den) begin
                if (xadc_dwe !== 1'b0) begin
                    $display("ERROR %0t: escritura por el DRP", $time);
                    errores++;
                end
                if (xadc_daddr !== {2'b00, CANAL_VAUX6}) begin
                    $display("ERROR %0t: daddr = 0x%02h, se esperaba 0x16", $time, xadc_daddr);
                    errores++;
                end
                repeat (LATENCIA_DRP - 1) @(posedge clk);
                xadc_do <= muestra_convertida;
                xadc_drdy <= 1'b1;
                @(posedge clk);
                xadc_drdy <= 1'b0;
                xadc_do <= 16'hDEAD;
            end
        end
    end

    // Monitores de protocolo. bvalid y rvalid se sostienen hasta su ready, rdata no cambia mientras rvalid espera y den dura un ciclo
    logic bvalid_previo = 1'b0;
    logic bready_previo = 1'b0;
    logic rvalid_previo = 1'b0;
    logic rready_previo = 1'b0;
    logic [31:0] rdata_previo = '0;
    logic den_previo = 1'b0;

    always @(posedge clk) begin
        if (rst_n) begin
            if (bvalid_previo && !bready_previo && !s_axi_bvalid) begin
                $display("ERROR %0t: bvalid bajó sin bready", $time);
                errores++;
            end
            if (rvalid_previo && !rready_previo && !s_axi_rvalid) begin
                $display("ERROR %0t: rvalid bajó sin rready", $time);
                errores++;
            end
            if (rvalid_previo && !rready_previo && s_axi_rdata !== rdata_previo) begin
                $display("ERROR %0t: rdata cambió con rvalid esperando", $time);
                errores++;
            end
            if (den_previo && xadc_den) begin
                $display("ERROR %0t: den duró más de un ciclo", $time);
                errores++;
            end
            if (s_axi_bvalid && s_axi_bresp !== 2'b00) begin
                $display("ERROR %0t: bresp distinto de OKAY", $time);
                errores++;
            end
            if (s_axi_rvalid && s_axi_rresp !== 2'b00) begin
                $display("ERROR %0t: rresp distinto de OKAY", $time);
                errores++;
            end
            if (xadc_dwe !== 1'b0 || xadc_di !== 16'h0000) begin
                $display("ERROR %0t: dwe o di distintos de cero", $time);
                errores++;
            end
        end
        bvalid_previo <= s_axi_bvalid;
        bready_previo <= s_axi_bready;
        rvalid_previo <= s_axi_rvalid;
        rready_previo <= s_axi_rready;
        rdata_previo <= s_axi_rdata;
        den_previo <= xadc_den;
    end

    // Maestro AXI4-Lite. Los retardos permiten presentar AW y W en cualquier orden y atrasar bready
    task automatic escribir(input logic [3:0] dir, input logic [31:0] dato, input logic [3:0] strb,
                            input int retardo_aw = 0, input int retardo_w = 0, input int retardo_b = 0);
        fork
            begin
                repeat (retardo_aw) @(posedge clk);
                s_axi_awaddr <= dir;
                s_axi_awvalid <= 1'b1;
                @(posedge clk);
                while (!s_axi_awready) @(posedge clk);
                s_axi_awvalid <= 1'b0;
            end
            begin
                repeat (retardo_w) @(posedge clk);
                s_axi_wdata <= dato;
                s_axi_wstrb <= strb;
                s_axi_wvalid <= 1'b1;
                @(posedge clk);
                while (!s_axi_wready) @(posedge clk);
                s_axi_wvalid <= 1'b0;
            end
        join
        repeat (retardo_b) @(posedge clk);
        s_axi_bready <= 1'b1;
        @(posedge clk);
        while (!s_axi_bvalid) @(posedge clk);
        s_axi_bready <= 1'b0;
    endtask

    task automatic leer(input logic [3:0] dir, output logic [31:0] dato, input int retardo_r = 0);
        s_axi_araddr <= dir;
        s_axi_arvalid <= 1'b1;
        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        s_axi_arvalid <= 1'b0;
        repeat (retardo_r) @(posedge clk);
        s_axi_rready <= 1'b1;
        @(posedge clk);
        while (!s_axi_rvalid) @(posedge clk);
        dato = s_axi_rdata;
        s_axi_rready <= 1'b0;
    endtask

    task automatic comparar(input string nombre, input logic [31:0] obtenido, input logic [31:0] esperado);
        if (obtenido !== esperado) begin
            $display("ERROR %0t: %s = 0x%08h, se esperaba 0x%08h", $time, nombre, obtenido, esperado);
            errores++;
        end else begin
            $display("ok    %s = 0x%08h", nombre, obtenido);
        end
    endtask

    // Pulso de un ciclo, como el del valle de nucleo_pwm
    task automatic pulso_valle();
        @(posedge clk);
        pwm_trigger_o <= 1'b1;
        t_trigger = $realtime;
        @(posedge clk);
        pwm_trigger_o <= 1'b0;
    endtask

    // Lee el registro de dato hasta que el contador sale de contador_previo, con un tiempo límite
    task automatic esperar_dato(input logic [1:0] contador_previo, output logic [31:0] dato);
        int vueltas;
        vueltas = 0;
        leer(4'h4, dato);
        while (dato[13:12] == contador_previo && vueltas < 100) begin
            repeat (10) @(posedge clk);
            leer(4'h4, dato);
            vueltas++;
        end
        if (dato[13:12] == contador_previo) begin
            $display("ERROR %0t: el contador no avanzó desde %0d", $time, contador_previo);
            errores++;
        end
    endtask

    logic [31:0] lectura;
    logic [1:0] contador_esperado;

    initial begin
        repeat (10) @(posedge clk);
        rst_n <= 1'b1;
        repeat (2) @(posedge clk);

        $display("1. Valores después del reinicio");
        leer(4'h0, lectura);
        comparar("control", lectura, 32'h0);
        leer(4'h4, lectura);
        comparar("dato", lectura, 32'h0);

        $display("2. Inicio por software durante la calibración, se ignora");
        if (!xadc_busy) begin
            $display("ERROR: la calibración del modelo terminó antes de la prueba");
            errores++;
        end
        escribir(4'h0, 32'h1, 4'hF);
        wait (!xadc_busy);
        repeat (300) @(posedge clk);
        leer(4'h4, lectura);
        comparar("dato tras inicio en calibración", lectura, 32'h0);

        $display("3. Inicio por software");
        proxima_muestra = 16'hABC7;
        escribir(4'h0, 32'h1, 4'hF, 0, 2, 3);
        esperar_dato(2'd0, lectura);
        comparar("dato", lectura, {18'b0, 2'd1, 12'hABC});
        leer(4'h0, lectura);
        comparar("control, inicio se lee en 0", lectura, 32'h0);

        $display("4. pwm_trigger_o con fuente en software, se ignora");
        pulso_valle();
        repeat (300) @(posedge clk);
        leer(4'h4, lectura);
        comparar("dato sin cambio", lectura[13:12], 32'd1);

        $display("5. Escritura a 0x00 sin wstrb[0], se ignora");
        escribir(4'h0, 32'h3, 4'b1110);
        repeat (300) @(posedge clk);
        leer(4'h0, lectura);
        comparar("control", lectura, 32'h0);
        leer(4'h4, lectura);
        comparar("contador sin cambio", lectura[13:12], 32'd1);

        $display("6. Direcciones sin registro y escritura al dato");
        escribir(4'h4, 32'hFFFF_FFFF, 4'hF);
        escribir(4'h8, 32'h3, 4'hF);
        escribir(4'hC, 32'h3, 4'hF);
        repeat (300) @(posedge clk);
        leer(4'h8, lectura);
        comparar("lectura de 0x08", lectura, 32'h0);
        leer(4'hC, lectura);
        comparar("lectura de 0x0C", lectura, 32'h0);
        leer(4'h0, lectura);
        comparar("control", lectura, 32'h0);
        leer(4'h4, lectura, 4);
        comparar("dato sin cambio", lectura, {18'b0, 2'd1, 12'hABC});

        $display("7. fuente en pwm_trigger_o, con AW antes que W");
        escribir(4'h0, 32'h2, 4'h1, 0, 3, 0);
        leer(4'h0, lectura);
        comparar("control", lectura, 32'h2);

        $display("8. Inicio por software con fuente en pwm_trigger_o, se ignora");
        escribir(4'h0, 32'h3, 4'h1);
        repeat (300) @(posedge clk);
        leer(4'h4, lectura);
        comparar("contador sin cambio", lectura[13:12], 32'd1);
        leer(4'h0, lectura);
        comparar("control", lectura, 32'h2);

        $display("9. Disparo por el valle, CONVST 20 ns después");
        proxima_muestra = 16'h123F;
        pulso_valle();
        esperar_dato(2'd1, lectura);
        comparar("dato", lectura, {18'b0, 2'd2, 12'h123});
        if (t_convst - t_trigger != 20.0) begin
            $display("ERROR: CONVST subió %0.1f ns después del valle, se esperaban 20", t_convst - t_trigger);
            errores++;
        end else begin
            $display("ok    CONVST %0.1f ns después del valle", t_convst - t_trigger);
        end

        $display("10. Un valle durante la conversión se ignora");
        proxima_muestra = 16'h0010;
        pulso_valle();
        repeat (30) @(posedge clk);
        pulso_valle();
        repeat (400) @(posedge clk);
        leer(4'h4, lectura);
        comparar("dato, una sola conversión", lectura, {18'b0, 2'd3, 12'h001});

        $display("11. El contador da la vuelta módulo 4");
        contador_esperado = 2'd3;
        for (int i = 0; i < 4; i++) begin
            proxima_muestra = 16'(16'hFFF0 - 16'(i) * 16'h0110);
            pulso_valle();
            esperar_dato(contador_esperado, lectura);
            contador_esperado = contador_esperado + 2'd1;
            comparar($sformatf("dato %0d", i), lectura, {18'b0, contador_esperado, proxima_muestra[15:4]});
        end

        $display("12. Vuelta a software, W antes que AW y dos inicios seguidos");
        escribir(4'h0, 32'h0, 4'h1, 3, 0, 2);
        proxima_muestra = 16'h7FF0;
        escribir(4'h0, 32'h1, 4'h1);
        escribir(4'h0, 32'h1, 4'h1);
        repeat (400) @(posedge clk);
        leer(4'h4, lectura, 5);
        comparar("dato, una sola conversión", lectura, {18'b0, contador_esperado + 2'd1, 12'h7FF});

        repeat (20) @(posedge clk);
        if (convst_ignorados != 0) begin
            $display("ERROR: %0d CONVST con xadc_busy en 1", convst_ignorados);
            errores++;
        end
        if (conversiones_modelo != 8) begin
            $display("ERROR: el modelo hizo %0d conversiones, se esperaban 8", conversiones_modelo);
            errores++;
        end

        if (errores == 0) begin
            $display("PASA: tb_envoltura_xadc sin errores");
        end else begin
            $display("FALLA: tb_envoltura_xadc con %0d errores", errores);
        end
        $finish;
    end

    // Tiempo límite global
    initial begin
        #2ms;
        $display("FALLA: tiempo límite");
        $finish;
    end

endmodule

`default_nettype wire
