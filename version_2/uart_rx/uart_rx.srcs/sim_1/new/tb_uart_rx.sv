`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.11.2025 16:40:43
// Design Name: 
// Module Name: tb_uart_rx
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
 * Testbench para el módulo uart_rx
 */
module tb_uart_rx;

    // --- Parámetros de simulación ---
    localparam int CLK_PERIOD = 10;
    
    // Parámetros del DUT (Deben coincidir)
    localparam int BIT_TIME = 10417; // 100,000,000 / 9600
    
    // --- Señales de prueba ---
    logic        clk;
    logic        clr;
    logic        RxD_in; // Señal que *nosotros* controlamos (va al DUT)
    logic        rdrf_clr;
    
    logic [7:0]  rx_data; // Salida *del* DUT
    logic        rdrf;    // Salida *del* DUT
    logic        FE;      // Salida *del* DUT

    // --- Instanciación del DUT (Device Under Test) ---
    uart_rx #(
    .CLKS_PER_BIT(BIT_TIME)
    ) i_dut (
        .clk        (clk),
        .clr        (clr),
        .RxD        (RxD_in), // Conectamos nuestra entrada a la entrada del DUT
        .rdrf_clr   (rdrf_clr),
        .rx_data    (rx_data),
        .rdrf       (rdrf),
        .FE         (FE)
    );

    // --- Generador de Reloj (Clock) ---
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --- Tarea (Task) de Transmisión ---
    // Esta tarea simula un transmisor UART (como el módulo tx)
    task automatic send_serial_data(input [7:0] data_to_send);
        $display("[%0t ns] Test: Enviando '%c' (0x%h)...", $time, data_to_send, data_to_send);
        
        @(posedge clk);
        // 1. Bit de START
        RxD_in <= 1'b0;
        #(CLK_PERIOD * BIT_TIME);
        
        // 2. 8 Bits de Datos (LSB primero)
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            RxD_in <= data_to_send[i];
            #(CLK_PERIOD * BIT_TIME);
        end
        
        // 3. Bit de STOP
        @(posedge clk);
        RxD_in <= 1'b1;
        #(CLK_PERIOD * BIT_TIME);
        
        // 4. Volver a Idle (opcional pero bueno)
        @(posedge clk);
        RxD_in <= 1'b1;
        #(CLK_PERIOD * BIT_TIME);
    endtask


    // --- Secuencia de Prueba ---
    initial begin
        // 1. Inicialización y Reset
        $display("--- Simulación Iniciada ---");
        RxD_in   = 1'b1; // Línea inactiva (Mark)
        rdrf_clr = 1'b0;
        clr      = 1'b0; // Iniciar en bajo
        #(CLK_PERIOD * 2);
        clr      = 1'b1; // Activar Reset
        #(CLK_PERIOD * 5);
        clr = 1'b0;//Liberar Reset
        #(CLK_PERIOD * 10); // Esperar a que el módulo se estabilice
        
        // --- Prueba 1: Enviar 'C' (0x43) ---
        // 0x43 = 0b01000011
        fork
        send_serial_data(8'h43);
        join_none
        
        // Esperar a que el DUT indique que recibió el dato
        $display("[%0t ns] Test: Esperando bandera rdrf...", $time);
        @(posedge rdrf);
        $display("[%0t ns] Test: Bandera rdrf detectada!", $time);
        
        // Verificar los datos recibidos
        if (rx_data == 8'h43) begin
            $display("Monitor: OK! Se recibió 8'h%h ('%c')", rx_data, rx_data);
        end else begin
            $error("Monitor: ERROR! Se esperaba 8'h43, se recibió 8'h%h", rx_data);
        end
        
        // Verificar que no hubo error de framing
        if (FE == 1'b1) begin
            $error("Monitor: ERROR! Se detectó un Framing Error (FE)!");
        end
        
        // Limpiar la bandera para la siguiente recepción
        rdrf_clr <= 1'b1;
        @(posedge clk);
        rdrf_clr <= 1'b0;
        
        #(CLK_PERIOD * 20); // Pausa
        
        // --- Prueba 2: Enviar 'A' (0x41) ---
        // 0x41 = 0b01000001
        $display("[%0t ns] Test: Enviando 'A' (0x41)...", $time);
        fork
        send_serial_data(8'h41);
        join_none
        
        $display("[%0t ns] Test: Esperando bandera rdrf...", $time);
        @(posedge rdrf);
        $display("[%0t ns] Test: Bandera rdrf detectada!", $time);
        
        if (rx_data == 8'h41) begin
            $display("Monitor: OK! Se recibió 8'h%h ('%c')", rx_data, rx_data);
        end else begin
            $error("Monitor: ERROR! Se esperaba 8'h41, se recibió 8'h%h", rx_data);
        end
        
        #(CLK_PERIOD * 10);
        
        // Fin
        $display("--- Simulación Finalizada ---");
        $stop;
    end

endmodule
