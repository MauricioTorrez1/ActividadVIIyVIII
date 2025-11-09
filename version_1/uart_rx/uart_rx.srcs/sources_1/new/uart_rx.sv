`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.10.2025 11:47:45
// Design Name: 
// Module Name: uart_rx
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
 * Módulo Receptor UART (uart_rx)
 * - Recibe 8 bits de datos, sin paridad, 1 bit de stop.
 * - Muestrea en el centro de cada bit.
 */
module uart_rx #(
    parameter int CLKS_PER_BIT = 10417 // 100MHz / 9600 baud
) (
    input  logic clk,
    input  logic clr,
    input  logic RxD,
    input logic rdrf_clr, // Pulso para limpiar rdrf
    
    output logic [7:0] rx_data,
    output logic rdrf, // Data Ready Flag
    output logic FE    // Framing Error
);

    typedef enum {
        MARK,
        START,
        SHIFT,
        STOP
    } state_t;

    state_t state_reg, state_next;
    
    logic [13:0] clk_count_reg, clk_count_next; // Contador de ciclos (hasta 10417)
    logic [3:0]  bit_index_reg, bit_index_next; // Contador de bits (0 a 7)
    logic [7:0]  rx_buffer_reg, rx_buffer_next;
    logic        rdrf_reg, rdrf_next;
    logic        fe_reg, fe_next;
    logic        rxd_sync_1, rxd_sync;
    
    // Sincronizador de 2 FFs para la entrada asíncrona RxD
    always_ff @(posedge clk) begin
        if (clr) begin
            rxd_sync_1 <= 1'b1;
            rxd_sync   <= 1'b1;
        end else begin
            rxd_sync_1 <= RxD;
            rxd_sync   <= rxd_sync_1;
        end
    end

    // Registros
    always_ff @(posedge clk) begin
        if (clr) begin
            state_reg     <= MARK;
            clk_count_reg <= '0;
            bit_index_reg <= '0;
            rx_buffer_reg <= '0;
            rdrf_reg      <= 1'b0;
            fe_reg        <= 1'b0;
        end else begin
            state_reg     <= state_next;
            clk_count_reg <= clk_count_next;
            bit_index_reg <= bit_index_next;
            rx_buffer_reg <= rx_buffer_next;
            rdrf_reg      <= rdrf_next;
            fe_reg        <= fe_next;
        end
    end

    // Lógica de Siguiente Estado y Datapath
    always_comb begin
        state_next     = state_reg;
        clk_count_next = clk_count_reg;
        bit_index_next = bit_index_reg;
        rx_buffer_next = rx_buffer_reg;
        rdrf_next      = rdrf_reg;
        fe_next        = fe_reg;

        if (rdrf_clr) begin
            rdrf_next = 1'b0;
        end

        case (state_reg)
            MARK: begin
                fe_next = 1'b0;
                if (!rxd_sync) begin // Detecta Start Bit (flanco de bajada)
                    state_next     = START;
                    clk_count_next = '0;
                end
            end
            
    START: begin
        // Espera 1.5 * BIT_TIME para muestrear en el centro del primer bit
        if (clk_count_reg == (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) - 1) begin
            state_next = SHIFT;
            clk_count_next = 0;
            bit_index_next = 1; // Prepara para leer el bit 1
            rx_buffer_next[0] = rxd_sync; // Muestrea Bit 0
        end else begin
            clk_count_next = clk_count_reg + 1;
        end
    end
    
    SHIFT: begin
        // Espera 1 * BIT_TIME
        if (clk_count_reg == CLKS_PER_BIT - 1) begin
            clk_count_next = 0;
            rx_buffer_next[bit_index_reg] = rxd_sync; // Muestrea Bit [1], [2], etc.
            
            if (bit_index_reg == 7) begin // Si acabamos de leer el bit 7
                state_next = STOP;
            end else begin
                bit_index_next = bit_index_reg + 1; // Prepara para leer el prox bit
            end
        end else begin
            clk_count_next = clk_count_reg + 1;
        end
    end
            
            STOP: begin
                // Espera 1 * BIT_TIME para el centro del Stop bit
                if (clk_count_reg == CLKS_PER_BIT - 1) begin
                    if (rxd_sync) begin // Stop bit debe ser '1'
                        rdrf_next = 1'b1; // Dato listo
                        fe_next   = 1'b0;
                    end else begin
                        rdrf_next = 1'b0; // Error, no poner flag
                        fe_next   = 1'b1; // Framing Error
                    end
                    state_next = MARK;
                end else begin
                    clk_count_next = clk_count_reg + 1;
                end
            end
        endcase
    end
    
    assign rx_data = rx_buffer_reg;
    assign rdrf    = rdrf_reg;
    assign FE      = fe_reg;

endmodule
