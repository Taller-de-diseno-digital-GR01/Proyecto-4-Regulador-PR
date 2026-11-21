module debounce (
    input logic clk,
    input logic rst,
    input logic button_in,
    output logic button_out
);

parameter N = 21;

reg [N-1:0] q_reg;
reg [N-1:0] q_next;
reg dff1, dff2;
wire q_add;
wire q_rst;

assign q_rst = (dff1 ^ dff2); //Revisa si cambia el estado del boton de un ciclo a otro
assign q_add = ~(q_reg[N-1]); //Le asigna 1 si el contador no ha llegado a su valor maximo


    always_comb begin
    case ({q_rst, q_add})
        2'b01: q_next = q_reg + 1; // no ha llegado al máximo -> incrementa
        2'b00: q_next = q_reg;     // ya llegó al máximo -> se mantiene
        default: q_next = {N{1'b0}};
    endcase 
end


    always_ff @(posedge clk) begin
        if (rst) begin
            dff1 <= 1'b0;
            dff2 <= 1'b0;
            q_reg <= '0;
            button_out <= 1'b0;
        end else begin
            dff1 <= button_in;
            dff2 <= dff1;
            q_reg <= q_next;

            if (q_reg[N-1]) begin
                button_out <= dff2;
            end
        end
    end
endmodule