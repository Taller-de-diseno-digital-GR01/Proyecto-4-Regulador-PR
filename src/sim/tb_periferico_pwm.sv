`timescale 1ns/1ps
`default_nettype none

// Solo requiere la frontera publica de periferico_pwm; no usa force ni nombres internos del nucleo.
module tb_periferico_pwm #(
    parameter bit RAPIDO = 1'b1,
    parameter int ALEATORIAS = 120
);
    localparam int DT = RAPIDO ? 3 : 100;
    localparam int PC = RAPIDO ? 7 : 7000;
    localparam int M00 = RAPIDO ? 64 : 5000;
    localparam int M01 = RAPIDO ? 32 : 2500;
    localparam int M10 = RAPIDO ? 16 : 1250;
    localparam int M11 = M01;
    localparam int TIMEOUT = 100;

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst_n = 1'b0;
    logic [3:0] awaddr = '0, araddr = '0;
    logic [2:0] awprot = '0, arprot = '0;
    logic awvalid = 0, wvalid = 0, bready = 0, arvalid = 0, rready = 0;
    logic [31:0] wdata = '0;
    logic [3:0] wstrb = '0;
    wire awready, wready, bvalid, arready, rvalid;
    wire [1:0] bresp, rresp;
    wire [31:0] rdata;
    wire ah, al, bh, bl, trigger;

    periferico_pwm #(
        .DEAD_TIME_CICLOS(DT), .PRECARGA_CICLOS(PC),
        .MAX_FREQ_00(M00), .MAX_FREQ_01(M01), .MAX_FREQ_10(M10), .MAX_FREQ_11(M11)
    ) dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .compuerta_a_alta(ah), .compuerta_a_baja(al),
        .compuerta_b_alta(bh), .compuerta_b_baja(bl), .pwm_trigger_o(trigger)
    );

    integer errores = 0, comprobaciones = 0, grupos = 0, ciclo = 0;
    integer aw_total = 0, w_total = 0, b_total = 0, ar_total = 0, r_total = 0;
    integer trigger_total = 0, encendidos_total = 0, reinicios = 0;
    integer aw_canceladas = 0, w_canceladas = 0, ar_canceladas = 0;
    string caso = "inicio";
    integer errores_al_inicio = 0;
    logic monitor_activo = 0;
    realtime ultimo_flanco = 0;
    logic retenia_b = 0, retenia_r = 0;
    logic [31:0] lectura_retenida = '0;
    logic [1:0] bresp_retenida = '0, rresp_retenida = '0;

    task automatic verificar(input bit condicion, input string mensaje);
        comprobaciones++;
        if (!condicion) begin
            errores++;
            if (errores <= 25) $display("ERROR [%s] ciclo=%0d: %s", caso, ciclo, mensaje);
            if (errores == 100) $fatal(1, "Demasiados errores; se detiene la simulacion");
        end
    endtask

    task automatic iniciar(input string nombre);
        if (grupos > 0)
            $display("%s [%s]", (errores == errores_al_inicio) ? "PASS" : "FAIL", caso);
        caso = nombre;
        errores_al_inicio = errores;
        grupos++;
        $display("PRUEBA %s", nombre);
    endtask

    task automatic ticks(input int n);
        repeat (n) begin @(posedge clk); #2; end
    endtask

    task automatic enviar_aw(input logic [3:0] direccion, input int demora = 0);
        int espera;
        repeat (demora) @(negedge clk);
        @(negedge clk);
        awaddr = direccion;
        awvalid = 1;
        espera = 0;
        do begin
            @(posedge clk);
            espera++;
            if (espera > TIMEOUT) $fatal(1, "Timeout AW en %s", caso);
        end while (!awready);
        @(negedge clk);
        awvalid = 0;
        awaddr = ~direccion; // Tras el handshake la direccion ya no pertenece al pedido.
    endtask

    task automatic enviar_w(input logic [31:0] dato, input logic [3:0] mascara,
                             input int demora = 0);
        int espera;
        repeat (demora) @(negedge clk);
        @(negedge clk);
        wdata = dato;
        wstrb = mascara;
        wvalid = 1;
        espera = 0;
        do begin
            @(posedge clk);
            espera++;
            if (espera > TIMEOUT) $fatal(1, "Timeout W en %s", caso);
        end while (!wready);
        @(negedge clk);
        wvalid = 0;
        wdata = ~dato;
        wstrb = ~mascara;
    endtask

    task automatic terminar_b(input int detener = 0);
        int espera;
        espera = 0;
        while (!bvalid) begin
            ticks(1);
            espera++;
            if (espera > TIMEOUT) $fatal(1, "Timeout BVALID en %s", caso);
        end
        ticks(detener);
        @(negedge clk); bready = 1;
        @(posedge clk);
        verificar(bvalid && bresp == 0, "confirmacion B ausente o incorrecta");
        @(negedge clk); bready = 0;
    endtask

    task automatic escribir(input logic [3:0] direccion, input logic [31:0] dato,
                             input logic [3:0] mascara = 4'hf,
                             input int demora_aw = 0, input int demora_w = 0,
                             input int detener_b = 0);
        fork
            enviar_aw(direccion, demora_aw);
            enviar_w(dato, mascara, demora_w);
        join
        terminar_b(detener_b);
    endtask

    task automatic enviar_ar(input logic [3:0] direccion);
        int espera;
        @(negedge clk);
        araddr = direccion; arvalid = 1;
        espera = 0;
        do begin
            @(posedge clk);
            espera++;
            if (espera > TIMEOUT) $fatal(1, "Timeout AR en %s", caso);
        end while (!arready);
        @(negedge clk);
        arvalid = 0; araddr = ~direccion;
    endtask

    task automatic terminar_r(output logic [31:0] dato, input int detener = 0);
        int espera;
        espera = 0;
        while (!rvalid) begin
            ticks(1);
            espera++;
            if (espera > TIMEOUT) $fatal(1, "Timeout RVALID en %s", caso);
        end
        ticks(detener);
        dato = rdata;
        @(negedge clk); rready = 1;
        @(posedge clk);
        verificar(rvalid && rresp == 0, "respuesta R ausente o incorrecta");
        @(negedge clk); rready = 0;
    endtask

    task automatic leer(input logic [3:0] direccion, output logic [31:0] dato,
                         input int detener = 0);
        enviar_ar(direccion);
        terminar_r(dato, detener);
    endtask

    task automatic leer_igual(input logic [3:0] direccion, input logic [31:0] esperado);
        logic [31:0] dato;
        leer(direccion, dato);
        verificar(dato === esperado,
            $sformatf("registro %h: esperado=%h obtenido=%h", direccion, esperado, dato));
    endtask

    task automatic reiniciar;
        @(negedge clk);
        rst_n = 0;
        awvalid = 0; wvalid = 0; arvalid = 0; bready = 0; rready = 0;
        ticks(4);
        verificar(!awready && !wready && !arready, "READY durante reset");
        @(negedge clk); rst_n = 1;
        ticks(3);
        reinicios++;
    endtask

    // Modelo de registros AXI, separado de los estados y registros privados del DUT.
    logic m_enable = 0;
    logic [1:0] m_freq = 1;
    logic [15:0] m_duty = 0;
    bit tiene_aw = 0, tiene_w = 0, aplicada = 0, lectura_pendiente = 0;
    logic [3:0] direccion_guardada;
    logic [31:0] dato_guardado, lectura_esperada;
    logic [3:0] mascara_guardada;

    // Modelo matematico de la portadora y su tuberia. Nunca consulta la jerarquia del DUT.
    int m_portadora = 0, m_max = M00, m_ref_a = M00/2, m_ref_b = M00-M00/2;
    int m_p1_max = M00, m_p1_duty = 0;
    int m_p2_max = M00, m_p2_a = M00/2, m_p2_b = M00-M00/2;
    bit m_subiendo = 1, m_running = 0, m_trigger = 0;
    bit m_iniciada = 0, m_precarga = 0;
    int m_precarga_restante = 0;
    bit m_alta[2], m_baja[2], m_objetivo[2];
    int m_plazo[2];

    function automatic int maximo(input logic [1:0] seleccion);
        case (seleccion)
            0: return M00;
            1: return M01;
            2: return M10;
            default: return M11;
        endcase
    endfunction

    task automatic avanzar_modelo;
        bit peticion[2];
        int siguiente_portadora, d;
        bit siguiente_sentido;
        peticion[0] = m_portadora < m_ref_a;
        peticion[1] = m_portadora < m_ref_b;

        // Una solicitud estable obtiene permiso de encendido en un plazo absoluto.
        // Cambiarla reinicia ese plazo; esto comprueba el tiempo muerto sin copiar su FSM.
        if (!m_running) begin
            m_iniciada = 0; m_precarga = 0; m_precarga_restante = 0;
            for (int p=0; p<2; p++) begin
                m_alta[p]=0; m_baja[p]=0; m_objetivo[p]=0; m_plazo[p]=0;
            end
        end else if (!m_iniciada) begin
            m_iniciada = 1; m_precarga = 1; m_precarga_restante = PC-1;
            for (int p=0; p<2; p++) begin m_alta[p]=0; m_baja[p]=1; end
        end else if (m_precarga && m_precarga_restante > 0) begin
            m_precarga_restante--;
        end else if (m_precarga) begin
            m_precarga = 0;
            for (int p=0; p<2; p++) begin
                m_alta[p]=0; m_baja[p]=0; m_objetivo[p]=peticion[p]; m_plazo[p]=ciclo+DT;
            end
        end else begin
            for (int p=0; p<2; p++) begin
                if ((m_alta[p] && !peticion[p]) || (m_baja[p] && peticion[p])) begin
                    m_alta[p]=0; m_baja[p]=0;
                    m_objetivo[p]=peticion[p]; m_plazo[p]=ciclo+DT;
                end else if (!m_alta[p] && !m_baja[p]) begin
                    if (peticion[p] != m_objetivo[p]) begin
                        m_objetivo[p]=peticion[p]; m_plazo[p]=ciclo+DT;
                    end else if (ciclo >= m_plazo[p]) begin
                        m_alta[p]=peticion[p]; m_baja[p]=!peticion[p];
                    end
                end
            end
        end

        siguiente_portadora = m_portadora + (m_subiendo ? 1 : -1);
        siguiente_sentido = m_subiendo;
        if (siguiente_portadora == m_max) siguiente_sentido = 0;
        if (siguiente_portadora == 0) siguiente_sentido = 1;
        m_trigger = (m_portadora == 0);
        if (m_portadora == 0) begin
            m_running = m_enable;
            m_max = m_p2_max; m_ref_a = m_p2_a; m_ref_b = m_p2_b;
        end
        m_portadora = siguiente_portadora; m_subiendo = siguiente_sentido;
        m_p2_max = m_p1_max;
        m_p2_a = (m_p1_max * (16384 + m_p1_duty)) / 32768;
        m_p2_b = m_p1_max - m_p2_a;
        d = int'($signed(m_duty));
        if (d > 16384) d = 16384;
        if (d < -16384) d = -16384;
        m_p1_duty = d; m_p1_max = maximo(m_freq);
    endtask

    // El monitor captura los handshakes antes del NBA y comprueba las salidas despues.
    always @(posedge clk) begin : monitor
        bit confirma_b, confirma_r;
        ciclo++;
        ultimo_flanco = $realtime;
        if (!rst_n) begin
            if (tiene_aw) aw_canceladas++;
            if (tiene_w) w_canceladas++;
            if (lectura_pendiente) ar_canceladas++;
            tiene_aw=0; tiene_w=0; aplicada=0; lectura_pendiente=0;
            m_enable=0; m_freq=1; m_duty=0;
            m_portadora=0; m_max=M00; m_ref_a=M00/2; m_ref_b=M00-M00/2;
            m_p1_max=M00; m_p1_duty=0; m_p2_max=M00;
            m_p2_a=M00/2; m_p2_b=M00-M00/2;
            m_subiendo=1; m_running=0; m_trigger=0;
            m_iniciada=0; m_precarga=0; m_precarga_restante=0;
            for (int p=0; p<2; p++) begin
                m_alta[p]=0; m_baja[p]=0; m_objetivo[p]=0; m_plazo[p]=0;
            end
            retenia_b=0; retenia_r=0;
            #1;
            verificar(!bvalid && !rvalid && rdata==0, "respuestas durante reset");
            verificar({ah,al,bh,bl,trigger} === 5'b0, "salidas durante reset");
            monitor_activo=1;
        end else begin
            if (retenia_b) verificar(bvalid && bresp==bresp_retenida, "B no estable durante contrapresion");
            if (retenia_r) verificar(rvalid && rdata===lectura_retenida && rresp==rresp_retenida,
                                      "R no estable durante contrapresion");
            retenia_b=bvalid && !bready; bresp_retenida=bresp;
            retenia_r=rvalid && !rready; lectura_retenida=rdata; rresp_retenida=rresp;
            confirma_b=bvalid && bready;
            confirma_r=rvalid && rready;
            if (bvalid) verificar(!awready && !wready, "acepta escritura con B pendiente");
            if (rvalid) verificar(!arready, "acepta AR con R pendiente");
            if (awvalid && awready) begin
                verificar(!tiene_aw, "direccion AW duplicada");
                direccion_guardada=awaddr; tiene_aw=1; aw_total++;
            end
            if (wvalid && wready) begin
                verificar(!tiene_w, "dato W duplicado");
                dato_guardado=wdata; mascara_guardada=wstrb; tiene_w=1; w_total++;
            end
            if (confirma_r) begin
                verificar(lectura_pendiente, "R sin AR"); lectura_pendiente=0; r_total++;
            end
            if (arvalid && arready) begin
                verificar(!lectura_pendiente, "lectura duplicada");
                case (araddr)
                    0: lectura_esperada={28'b0,m_running,m_freq,m_enable};
                    4: lectura_esperada={16'b0,m_duty};
                    default: lectura_esperada=0;
                endcase
                lectura_pendiente=1; ar_total++;
            end
            avanzar_modelo();
            #1;
            // La primera aparicion de B confirma que hubo exactamente una escritura.
            if (bvalid && !aplicada) begin
                verificar(tiene_aw && tiene_w, "B sin AW y W completos");
                case (direccion_guardada)
                    0: if (mascara_guardada[0]) begin
                        m_enable=dato_guardado[0]; m_freq=dato_guardado[2:1];
                    end
                    4: begin
                        if (mascara_guardada[0]) m_duty[7:0]=dato_guardado[7:0];
                        if (mascara_guardada[1]) m_duty[15:8]=dato_guardado[15:8];
                    end
                    default: begin end
                endcase
                aplicada=1;
            end
            if (confirma_b) begin
                verificar(aplicada && tiene_aw && tiene_w, "confirmacion B duplicada");
                tiene_aw=0; tiene_w=0; aplicada=0; b_total++;
            end
            verificar(rvalid === lectura_pendiente, "numero de respuestas R incorrecto");
            if (rvalid) verificar(rdata===lectura_esperada && rresp==0, "instantanea de lectura incorrecta");
            verificar(bresp==0, "BRESP distinto de OKAY");
            verificar((^{ah,al,bh,bl,trigger,bvalid,rvalid,rdata,awready,wready,arready}) !== 1'bx,
                      "salidas desconocidas");
            verificar(!(ah && al) && !(bh && bl), "solapamiento de compuertas");
            verificar(trigger === m_trigger, "trigger fuera del valle o de ancho incorrecto");
            verificar({ah,al,bh,bl} === {m_alta[0],m_baja[0],m_alta[1],m_baja[1]},
                $sformatf("PWM: esperado=%b%b%b%b obtenido=%b%b%b%b",
                    m_alta[0],m_baja[0],m_alta[1],m_baja[1],ah,al,bh,bl));
            if (trigger) trigger_total++;
            if (ah || al || bh || bl) encendidos_total++;
        end
    end

    // Tambien se observan transiciones entre flancos; el monitor por ciclos no basta para glitches.
    always @(ah or al or bh or bl or trigger) begin
        if (monitor_activo && rst_n)
            verificar($realtime == ultimo_flanco && clk, "salida PWM cambio fuera del flanco ascendente");
    end

    task automatic esperar_valle;
        int espera;
        espera=0;
        while (m_portadora != 0) begin
            ticks(1); espera++;
            if (espera > 2*M00+5) $fatal(1, "Timeout de valle");
        end
    endtask

    task automatic periodo_igual(input int esperado);
        int inicio, espera;
        espera=0;
        do begin ticks(1); espera++; end while (!trigger && espera < 2*M00+5);
        verificar(trigger, "no llega trigger de inicio");
        inicio=ciclo; espera=0;
        do begin ticks(1); espera++; end while (!trigger && espera < 2*M00+5);
        verificar(trigger && ciclo-inicio==esperado,
                  $sformatf("periodo esperado=%0d obtenido=%0d", esperado, ciclo-inicio));
    endtask

    int unsigned rng = 32'h5eed1234;
    function automatic int unsigned aleatorio;
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    initial begin : estimulos
        logic [31:0] dato, antes;
        logic [3:0] dir, mask;
        logic [31:0] valor;
        int aw_d, w_d, b_d;
        int ciclos_precarga, inicio_b, inicio_r, proximo_valle;
        if ($value$plusargs("SEED=%d", rng)) begin end
        if ($test$plusargs("VCD")) begin
            $dumpfile("pwm.vcd"); $dumpvars(0,tb_periferico_pwm);
        end
        $display("PWM: RAPIDO=%0d DT=%0d PRECARGA=%0d MAX=%0d/%0d/%0d SEED=%0d",
                  RAPIDO,DT,PC,M00,M01,M10,rng);

        iniciar("AX01 AX02 / reset y valores iniciales");
        reiniciar(); leer_igual(0,32'h2); leer_igual(4,0);

        iniciar("AX03 AX04 AX05 AX06 AX10 AX11 / orden de AW y W");
        escribir(4,32'h1234); leer_igual(4,32'h1234);
        escribir(4,32'h5678,15,0,6); leer_igual(4,32'h5678);
        escribir(4,32'h9abc,15,6,0); leer_igual(4,32'h9abc);
        // Canales aislados no deben escribir ni generar B.
        enviar_aw(4); ticks(5); verificar(!bvalid,"B con solo AW");
        leer_igual(4,32'h9abc); enviar_w(32'h2345,15); terminar_b(); leer_igual(4,32'h2345);
        enviar_w(32'h3456,15); ticks(5); verificar(!bvalid,"B con solo W");
        leer_igual(4,32'h2345); enviar_aw(4); terminar_b(); leer_igual(4,32'h3456);

        iniciar("AX / maestro con BREADY y RREADY anticipados");
        inicio_b=b_total;
        @(negedge clk); bready=1;
        fork enviar_aw(4); enviar_w(32'h1357,15); join
        ticks(4);
        verificar(b_total==inicio_b+1 && !bvalid,"B con READY anticipado");
        @(negedge clk); bready=0;
        inicio_r=r_total;
        @(negedge clk); rready=1;
        enviar_ar(4); ticks(3);
        verificar(r_total==inicio_r+1 && !rvalid,"R con READY anticipado");
        @(negedge clk); rready=0;
        leer_igual(4,32'h1357);

        iniciar("AX07 PW17 / B retenida y siguiente escritura esperando");
        fork enviar_aw(4); enviar_w(32'h4567,15); join
        while (!bvalid) ticks(1);
        fork
            begin ticks(12); terminar_b(); end
            begin
                fork enviar_aw(4); enviar_w(32'h5678,15); join
            end
        join
        terminar_b(4); leer_igual(4,32'h5678);

        iniciar("AX08 AX09 / instantanea R y segunda AR bloqueada");
        enviar_ar(4);
        antes=rdata;
        escribir(4,32'h6789);
        verificar(rvalid && rdata===antes,"R cambio por una escritura concurrente");
        fork
            begin ticks(8); terminar_r(dato); verificar(dato==32'h5678,"instantanea retenida"); end
            enviar_ar(4);
        join
        terminar_r(dato,3); verificar(dato==32'h6789,"segunda lectura");

        iniciar("AX12 / lectura en el flanco de ejecucion de escritura");
        escribir(4,32'h1111);
        fork enviar_aw(4); enviar_w(32'h2222,15); join
        // AW/W ya se aceptaron; la proxima subida ejecuta la escritura.
        araddr=4; arvalid=1;
        @(posedge clk); verificar(arready,"AR no disponible en colision");
        @(negedge clk); arvalid=0;
        terminar_r(dato); verificar(dato==32'h1111,"la colision no devolvio el valor anterior");
        terminar_b(); leer_igual(4,32'h2222);

        iniciar("AX13 AX14 AX15 AX16 AX17 AX18 / mascara y campos reservados");
        escribir(0,32'hfffffff8); leer_igual(0,0);
        escribir(4,32'h1234); escribir(4,32'hdeadbeab,1); leer_igual(4,32'h12ab);
        escribir(4,32'h0000cd00,2); leer_igual(4,32'hcdab);
        escribir(4,32'hffffffff,12); leer_igual(4,32'hcdab);
        escribir(4,0,0); leer_igual(4,32'hcdab);
        escribir(0,32'h2); escribir(0,32'h7,14); leer_igual(0,2);
        for (int i=0; i<16; i++) begin
            escribir(4,32'h1234);
            escribir(4,32'hfedcba98,4'(i));
            leer_igual(4,{16'b0,((i&2)!=0) ? 8'hba : 8'h12,((i&1)!=0) ? 8'h98 : 8'h34});
        end
        escribir(4,32'hcdab);

        iniciar("AX19 / todos los offsets sin registro y no alineados");
        for (int i=0; i<16; i++) if (i!=0 && i!=4) begin
            escribir(4'(i),32'hffffffff); leer_igual(4'(i),0);
        end
        leer_igual(0,2); leer_igual(4,32'hcdab);

        iniciar("AX20 / reset con AW aislada y W aislada");
        enviar_aw(4); reiniciar(); ticks(8); verificar(!bvalid,"escritura fantasma AW");
        enviar_w(32'hffff,15); reiniciar(); ticks(8); verificar(!bvalid,"escritura fantasma W");
        leer_igual(0,2); leer_igual(4,0);

        iniciar("AX21 / reset con respuestas B y R pendientes");
        fork enviar_aw(4); enviar_w(32'habcd,15); join
        while (!bvalid) ticks(1);
        enviar_ar(4); verificar(rvalid,"falta lectura antes del reset");
        reiniciar(); leer_igual(4,0);

        iniciar("AX22 / atributos de proteccion");
        for (int i=0; i<8; i++) begin
            @(negedge clk); awprot=3'(i); arprot=3'(7-i);
            escribir(4,32'(i)); leer_igual(4,32'(i));
        end

        iniciar("PW01 PW09 PW15 / frecuencias y trigger con puente apagado");
        for (int f=0; f<4; f++) begin
            escribir(0,32'(f<<1)); ticks(4*M00+5);
            periodo_igual(2*maximo(2'(f)));
            verificar({ah,al,bh,bl}==0,"compuertas con enable=0");
        end

        iniciar("PW02 / running y precarga exacta de ambas piernas");
        escribir(0,2); ticks(4*M00+5);
        escribir(0,3);
        while (!(al && bl)) ticks(1);
        ciclos_precarga=0;
        while (al && bl) begin
            verificar(!ah && !bh,"alta durante precarga");
            ciclos_precarga++; ticks(1);
            if (ciclos_precarga>PC+1) $fatal(1,"Precarga no termina");
        end
        verificar(ciclos_precarga==PC,"duracion de precarga incorrecta");
        ticks(PC+4*M00+DT);
        leer(0,dato); verificar(dato[3],"running no subio");

        iniciar("PW17 / PWM activo con B retenida por varios periodos");
        fork
            escribir(4,32'h2000,15,0,0,4*M00);
            begin ticks(12); leer(0,dato,7); verificar(dato[3],"running durante B retenida"); end
        join
        leer_igual(4,32'h2000);

        iniciar("AX08 / lectura de running retenida durante apagado");
        enviar_ar(0); antes=rdata;
        escribir(0,2); ticks(2*M00+5);
        verificar(rvalid && rdata===antes && antes[3],"instantanea de running cambio");
        terminar_r(dato); leer_igual(0,2);
        escribir(0,3); ticks(PC+4*M00+DT);

        iniciar("PW04 PW05 PW06 PW07 PW08 / referencias, signo y saturacion");
        for (int i=0; i<7; i++) begin
            case (i)
                0: valor=32'h0000; 1: valor=32'h2000; 2: valor=32'he000;
                3: valor=32'h4000; 4: valor=32'hc000;
                5: valor=32'h7fff; default: valor=32'h8000;
            endcase
            escribir(4,valor); leer_igual(4,valor); ticks(6*M00+DT);
        end

        iniciar("PW03 / deshabilitacion durante modulacion y durante precarga");
        escribir(0,2); ticks(2*M00+5); leer_igual(0,2);
        verificar({ah,al,bh,bl}==0,"no se apago el puente");
        escribir(0,3);
        while (!(al && bl)) ticks(1);
        escribir(0,2); ticks(2*M00+5);
        verificar({ah,al,bh,bl}==0,"no se apago durante arranque");

        iniciar("PW09 PW10 PW11 / cambios conjuntos de frecuencia y referencia");
        escribir(0,3); ticks(PC+4*M00);
        for (int f=0; f<4; f++) begin
            escribir(4,32'h2000); escribir(0,32'((f<<1)|1));
            ticks(PC+4*M00+5); periodo_igual(2*maximo(2'(f)));
            escribir(4,32'he000); ticks(4*M00+5);
        end

        iniciar("PW12 / escrituras a dos, uno y cero ciclos del valle");
        // Con AW/W juntos: el registro cambia en el flanco posterior a su captura;
        // el nucleo lo ve un flanco despues. Se alinean tres ejecuciones AXI.
        escribir(0,3); ticks(4*M00+5);
        for (int margen=2; margen>=0; margen--) begin
            esperar_valle();
            proximo_valle=ciclo+2*M01+1;
            // El siguiente trigger registrado esta a 2*M01+1 flancos de esta observacion.
            ticks(2*M01-margen-2);
            fork enviar_aw(4); enviar_w(32'((margen+1)*4096),15); join
            terminar_b();
            verificar(proximo_valle-ciclo==margen,"estimulo no alineado al margen declarado");
            ticks(4*M00+5);
        end

        iniciar("PW13 PW14 / conmutaciones y pulsos menores al tiempo muerto");
        escribir(0,5); ticks(4*M00+5);
        escribir(4,32'h3fff); ticks(8*M00+DT);
        escribir(4,32'hc001); ticks(8*M00+DT);
        escribir(4,32'h0001); ticks(8*M00+DT);

        iniciar("PW16 / reset en varias fases y con compuertas activas");
        for (int i=0; i<4; i++) begin
            escribir(0,3); ticks(PC+2*M00+11*i+3);
            reiniciar(); leer_igual(0,2);
        end

        iniciar("AX / accesos aleatorios concurrentes con PWM habilitado");
        escribir(0,3); ticks(PC+4*M00);
        for (int i=0; i<ALEATORIAS; i++) begin
            dir=4'(aleatorio()%16); mask=4'(aleatorio()%16); valor=aleatorio();
            aw_d=int'(aleatorio()%7); w_d=int'(aleatorio()%7); b_d=int'(aleatorio()%9);
            // Una lectura y una escritura pueden progresar en paralelo.
            fork
                escribir(dir,valor,mask,aw_d,w_d,b_d);
                leer((i%2==0) ? 4'h0 : 4'h4,dato, int'(i%5));
            join
            leer(dir,dato);
        end

        iniciar("cierre / respuestas completas y cobertura no vacia");
        escribir(0,2); ticks(2*M00+10);
        verificar(!tiene_aw && !tiene_w && !aplicada && !lectura_pendiente,"transacciones pendientes");
        verificar(!bvalid && !rvalid,"respuestas pendientes al terminar");
        verificar(trigger_total>20 && encendidos_total>PC,"estimulos PWM insuficientes");
        verificar(aw_total==b_total+aw_canceladas && w_total==b_total+w_canceladas &&
                  ar_total==r_total+ar_canceladas,"pedidos perdidos o respuestas duplicadas");
        inicio_b=b_total; inicio_r=r_total;
        ticks(20);
        verificar(b_total==inicio_b && r_total==inicio_r,"respuestas espontaneas");
        $display("%s [%s]", (errores==errores_al_inicio) ? "PASS" : "FAIL",caso);
        $display("RESUMEN grupos=%0d comprobaciones=%0d errores=%0d AW=%0d W=%0d B=%0d AR=%0d R=%0d triggers=%0d resets=%0d",
            grupos,comprobaciones,errores,aw_total,w_total,b_total,ar_total,r_total,trigger_total,reinicios);
        if (errores != 0) $fatal(1,"PWM: FALLIDO");
        $display("PWM: APROBADO");
        $finish;
    end

    initial begin
        // Limite global independiente de los timeouts de cada canal y de la contrapresion.
        #100000000;
        $fatal(1,"Watchdog global de 100 ms");
    end
endmodule

`default_nettype wire
