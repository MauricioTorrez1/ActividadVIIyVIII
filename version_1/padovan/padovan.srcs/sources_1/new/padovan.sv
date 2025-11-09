`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.11.2025 15:19:54
// Design Name: 
// Module Name: padovan
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


/*
 * FSMD para calcular la secuencia Padovan
 * P(0)=1, P(1)=1, P(2)=1
 * P(n) = P(n-2) + P(n-3) para n > 2
 */
module padovan (
    input  logic clk,
    input  logic clr,
    input  logic start,
    input  logic [7:0] n_in,      // Valor de n
    output logic [31:0] p_out,     // Resultado P(n)
    output logic  ready      // '1' cuando el resultado esta listo
);

    typedef enum logic [1:0] {
        IDLE,
        INIT, 
        CALC, 
        DONE
    } state_t;
    
    state_t state_reg, state_next;

    logic [31:0] p_n_1, p_n_2, p_n_3; // P(n-1), P(n-2), P(n-3)
    logic [7:0]  n_count;
    logic [31:0] p_out_reg;
    logic ready_reg;

    // FSM (Registros de estado)
    always_ff @(posedge clk) begin
        if (clr) 
        state_reg <= IDLE;
        else     
        state_reg <= state_next;
    end

    // Datapath (Registros)
    always_ff @(posedge clk) begin
        if (clr) begin
            p_n_1     <= '0;
            p_n_2     <= '0;
            p_n_3     <= '0;
            n_count   <= '0;
            p_out_reg <= '0;
            ready_reg <= 1'b0;
        end else begin
            
            ready_reg <= 1'b0; // Valor por defecto

            case (state_reg)
                IDLE: begin
                    if (start) begin
                        n_count <= n_in; // Carga n
                    end
                end

                INIT: begin
                    // Casos base
                    if (n_count == 0)     
                     p_out_reg <= 1;
                    else if (n_count == 1)
                     p_out_reg <= 1;
                    else if (n_count == 2) 
                    p_out_reg <= 1;
                    else begin
                        // Carga los registros para calcular P(3)
                        p_n_1   <= 1; // P(2)
                        p_n_2   <= 1; // P(1)
                        p_n_3   <= 1; // P(0)
                        n_count <= n_count - 2; // Iteraremos n-2 veces
                    end
                end

                CALC: begin
                        // Desplaza los registros
                        automatic logic [31:0] p_new = p_n_2 + p_n_3;
                        p_n_3   <= p_n_2;
                        p_n_2   <= p_n_1;
                        p_n_1   <= p_new; 
                        n_count <= n_count - 1;
                    if (n_count == 1) begin
                        // n_count es 0, el resultado es p_new
                        p_out_reg <= p_new;
                    end
                end
                
                DONE: begin
                    ready_reg <= 1'b1;
                end
            endcase
        end
    end
    

    // FSM (Logica de siguiente estado)
    always_comb begin
        state_next = state_reg;
        case (state_reg)
            IDLE: begin
                if (start) 
                state_next = INIT;
            end
            
            INIT: begin
                if (n_count <= 2) 
                state_next = DONE; // Casos base
                else              
                state_next = CALC; // Inicia calculo
            end
            
            CALC: begin
                if (n_count > 1) 
                state_next = CALC; // Sigue calculando
                else             
                state_next = DONE; // Termino
            end

            DONE: begin
                state_next = IDLE;
            end
        endcase
    end
    
    assign p_out = p_out_reg;
    assign ready = ready_reg;

endmodule

