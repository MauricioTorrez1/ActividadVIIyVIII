`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 22:10:10
// Design Name: 
// Module Name: debouncer_v2
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
 * Debouncer de Botón (CORREGIDO)
 * - Reloj de entrada: 100MHz
 * - Crea un pulso limpio de 1 ciclo en 'btn_pulse'
 */
module debouncer_v2 ( 
    input  logic clk,
    input  logic clr,
    input  logic btn_in,      // Señal ruidosa del botón
    output logic btn_pulse    // Pulso limpio de 1 ciclo
);

    localparam int DEBOUNCE_TIME = 20000; // 200us
    
    logic [15:0] count_reg, count_next;
    logic q1_reg, q1_next;
    logic q2_reg, q2_next;
    logic btn_clean;

    // --- Lógica de Siguiente Estado (CORREGIDA) ---
    always_comb begin
        q1_next = btn_in;
        q2_next = q1_reg;
        
        // Si la señal es INESTABLE (rebotando), resetea el contador.
        if (q1_reg != q2_reg) begin
            count_next = 0;
        end else begin
            // Si la señal es ESTABLE, incrementa el contador.
            count_next = count_reg + 1;
        end
    end

    // --- Lógica Secuencial (CORREGIDA) ---
    always_ff @(posedge clk) begin
        if (clr) begin
            q1_reg    <= 1'b0;
            q2_reg    <= 1'b0;
            count_reg <= '0;
            btn_clean <= 1'b0;
        end else begin
            q1_reg    <= q1_next;
            q2_reg    <= q2_next;
            count_reg <= count_next;
            
            // Si el contador ALCANZA el tiempo de debounce...
            // (Usamos count_next para evitar un ciclo de retardo)
            if (count_next == DEBOUNCE_TIME) begin
                btn_clean <= q2_reg; // ...asigna el valor estable.
            end
        end
    end

    // --- Detector de Flanco (Sin cambios, ya era correcto) ---
    logic btn_clean_prev;
    always_ff @(posedge clk) begin
        if (clr) begin
            btn_clean_prev <= 1'b0;
            btn_pulse      <= 1'b0;
        end else begin
            btn_clean_prev <= btn_clean;
            
            // Genera pulso cuando btn_clean pasa de 0 a 1
            if (~btn_clean_prev & btn_clean) begin
                btn_pulse <= 1'b1;
            end else begin
                btn_pulse <= 1'b0;
            end
        end
    end

endmodule
