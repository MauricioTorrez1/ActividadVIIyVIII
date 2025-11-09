`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 21:20:48
// Design Name: 
// Module Name: x7segmux_v2
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


module x7segmux_v2(
/*
 * Controlador de Display 7-Segmentos (Multiplexado)
 * - Reloj de entrada: 100MHz (de la Basys 3)
 * - Entradas: 4 dígitos hexadecimales (hex_data[15:0])
 * - Salidas: Ánodos y Cátodos para la Basys 3.
 */
    input  logic clk,
    input  logic clr,
    input  logic [15:0] hex_data, // 4 dígitos de 4 bits. [15:12] = Dig3, ..., [3:0] = Dig0
    
    output logic [3:0]  anodes,   // Ánodos (activo en bajo)
    output logic [7:0]  cathodes  // Cátodos (activo en bajo)
);

    // --- Divisor de Reloj para Tasa de Refresco (~1kHz) ---
    // 100MHz / 100,000 = 1kHz
    localparam int REFRESH_DIV = 100_000;
    logic [16:0] refresh_count;
    logic refresh_tick;
    
    always_ff @(posedge clk) begin
        if (clr) begin
            refresh_count <= 0;
            refresh_tick <= 0;
        end else if (refresh_count == REFRESH_DIV - 1) begin
            refresh_count <= 0;
            refresh_tick <= 1'b1;
        end else begin
            refresh_count <= refresh_count + 1;
            refresh_tick <= 1'b0;
        end
    end

    // --- Multiplexor de Display ---
    logic [1:0] digit_select; // 0, 1, 2, 3
    logic [3:0] current_digit_hex;

    always_ff @(posedge clk) begin
        if (clr) begin
            digit_select <= 0;
        end else if (refresh_tick) begin
            digit_select <= digit_select + 1;
        end
    end

    // Selecciona el dígito a mostrar
    always_comb begin
        case (digit_select)
            2'b00: begin
                anodes = 4'b1110; // Activa Ánodo 0
                current_digit_hex = hex_data[3:0];
            end
            2'b01: begin
                anodes = 4'b1101; // Activa Ánodo 1
                current_digit_hex = hex_data[7:4];
            end
            2'b10: begin
                anodes = 4'b1011; // Activa Ánodo 2
                current_digit_hex = hex_data[11:8];
            end
            2'b11: begin
                anodes = 4'b0111; // Activa Ánodo 3
                current_digit_hex = hex_data[15:12];
            end
            default: begin
                anodes = 4'b1111; // Apagado
                current_digit_hex = 4'hF;
            end
        endcase
    end
    
    // --- Decodificador Hex-a-7-Segmentos ---
    // Cátodos (g, f, e, d, c, b, a, dp) - dp no se usa
    always_comb begin
        case (current_digit_hex)
            4'h0:    cathodes = 8'b10000010; // 0 (gfedcba)
            4'h1:    cathodes = 8'b11011110; // 1
            4'h2:    cathodes = 8'b01001010; // 2
            4'h3:    cathodes = 8'b01011010; // 3
            4'h4:    cathodes = 8'b00011110; // 4
            4'h5:    cathodes = 8'b00111010; // 5
            4'h6:    cathodes = 8'b00100010; // 6
            4'h7:    cathodes = 8'b11011010; // 7
            4'h8:    cathodes = 8'b00000010; // 8
            4'h9:    cathodes = 8'b00011010; // 9
            4'hA:    cathodes = 8'b00001010; // A
            4'hB:    cathodes = 8'b00100110; // b
            4'hC:    cathodes = 8'b10100110; // C
            4'hD:    cathodes = 8'b01001110; // d
            4'hE:    cathodes = 8'b00100010; // E (usa el 6)
            4'hF:    cathodes = 8'b00101110; // F
            default: cathodes = 8'b11111110; // Apagado (o caracter de error)
        endcase
    end
    
endmodule
