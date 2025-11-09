`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.10.2025 12:13:00
// Design Name: 
// Module Name: uart_tx
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
 * Módulo Transmisor UART (uart_tx)
 * - Envía 8 bits de datos, sin paridad, 1 bit de stop.
 */
module uart_tx #(
    parameter int BIT_TIME = 10417 // 100MHz / 9600 baud
) (
    input  logic clk,
    input  logic clr,
    input  logic [7:0] tx_data,
    input  logic ready, // Pulso para iniciar
    
    output logic TxD,
    output logic tdre // Transmit Data Register Empty
);

    typedef enum {
        MARK,
        START,
        SHIFT,
        STOP
    } state_t;

    state_t state_reg, state_next;

    logic [13:0] clk_count_reg, clk_count_next; // Contador de ciclos
    logic [3:0]  bit_index_reg, bit_index_next; // Contador de bits
    logic [7:0]  tx_buffer_reg, tx_buffer_next;
    logic        txd_reg, txd_next;
    logic        tdre_reg, tdre_next;
    
    always_ff @(posedge clk) begin
        if (clr) begin
            state_reg     <= MARK;
            clk_count_reg <= '0;
            bit_index_reg <= '0;
            tx_buffer_reg <= '0;
            txd_reg       <= 1'b1; // Línea inactiva
            tdre_reg      <= 1'b1; // Listo para transmitir
        end else begin
            state_reg     <= state_next;
            clk_count_reg <= clk_count_next;
            bit_index_reg <= bit_index_next;
            tx_buffer_reg <= tx_buffer_next;
            txd_reg       <= txd_next;
            tdre_reg      <= tdre_next;
        end
    end

    always_comb begin
        state_next     = state_reg;
        clk_count_next = clk_count_reg;
        bit_index_next = bit_index_reg;
        tx_buffer_next = tx_buffer_reg;
        txd_next       = txd_reg;
        tdre_next      = tdre_reg;

        case (state_reg)
            MARK: begin
                txd_next = 1'b1;  // Línea inactiva
                tdre_next = 1'b1; // Listo para datos
                if (ready) begin  // Iniciar transmisión
                    state_next     = START;
                    tx_buffer_next = tx_data;
                    clk_count_next = '0;
                    tdre_next      = 1'b0; // Ocupado
                end
            end
            
            START: begin
                txd_next = 1'b0; // Start bit
                if (clk_count_reg == BIT_TIME - 1) begin
                    state_next     = SHIFT;
                    clk_count_next = '0;
                    bit_index_next = 0;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end
            
            SHIFT: begin
                txd_next = tx_buffer_reg[bit_index_reg]; // Envía bit LSB primero
                if (clk_count_reg == BIT_TIME - 1) begin
                    clk_count_next = '0;
                    
                    if (bit_index_reg == 7) begin
                        state_next = STOP;
                    end else begin
                        bit_index_next = bit_index_reg + 1;
                    end
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end
            
            STOP: begin
                txd_next = 1'b1; // Stop bit
                if (clk_count_reg == BIT_TIME - 1) begin
                    state_next = MARK;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end
        endcase
    end
    
    assign TxD  = txd_reg;
    assign tdre = tdre_reg;

endmodule