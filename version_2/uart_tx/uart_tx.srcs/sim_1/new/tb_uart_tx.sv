`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.11.2025 15:00:12
// Design Name: 
// Module Name: tb_uart_tx
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
 * Testbench para el módulo uart_tx 
 */
module tb_uart_tx;

    // --- Parámetros de simulación ---
    
    // 100MHz clock (Período de 10ns)
    localparam int CLK_PERIOD = 10;
    
    // Parámetros del DUT (Deben coincidir)
    localparam int DUT_BIT_TIME = 10417; // 100,000,000 / 9600
    
    // --- Señales de prueba ---
    logic        clk;
    logic        clr;
    logic [7:0]  tx_data;
    logic        ready;
    logic        TxD;
    logic        tdre;

    // --- Instanciación del DUT (Device Under Test) ---
    // Asegúrate de que el nombre "uart_tx" coincide con tu módulo.
    uart_tx #(
        .BIT_TIME(DUT_BIT_TIME)
 ) i_dut (
        .clk        (clk),
        .clr        (clr),
        .tx_data    (tx_data),
        .ready      (ready),
        .TxD        (TxD),
        .tdre       (tdre)
    );

    // --- Generador de Reloj (Clock) ---
    initial begin
        clk = 1'b0;
        // Genera un pulso de reloj de 100MHz para siempre
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --- Tarea (Task) de Verificación ---
    // Esta tarea actúa como un receptor UART para verificar la salida TxD.
    task automatic send_byte(input [7:0] data_to_send);
    $display("[%0t ns] Test: Esperando que 'tdre' este listo...", $time);
        
        // 1. Esperar el bit de inicio (flanco de bajada)
        wait (tdre == 1'b1);
        @(posedge clk);
        
        // 2. Aplicar los datos y el puso 'ready'
        $display("[%0t ns] Test: 'tdre' detectado. Enviando '%c' (0x%h)", $time, data_to_send, data_to_send);
        @(posedge clk);
        tx_data <= data_to_send;
        ready <= 1'b1;
        
        // 3. Mantener 'ready' por un ciclo y luego bajarlo
        @(posedge clk);
        ready <= 1'b0;
        
        //4. Esperar a que el transmisor acepte el dato (tdre baja)
        
        @(negedge tdre);
         $display("[%0t ns] Test: Transmision de '%c' iniciada (tdre bajo).", $time, data_to_send);
    endtask


    // --- Secuencia de Prueba ---
    initial begin
        // 1. Inicialización y Reset
        $display("--- Simulación Iniciada ---");
        tx_data = 8'h00;
        ready   = 1'b0;
        clr     = 1'b1; // Poner en reset
        #(CLK_PERIOD * 5);
        clr     = 1'b0; // Liberar reset
        
        // 2. Ejecutar pruebas en paralelo
        // 'fork...join' permite que el monitor (check_serial_data)
        // se ejecute al mismo tiempo que el estímulo de prueba.
        //Prueba 1: Enviar H (0x48)
        fork
            send_byte(8'h48);
        join_none
        
        //Esperar a que termine el envio
        @(posedge tdre);
        $display("[%0t ns] Test: Transmision de 'H' completada (tdre alto).", $time);
        
        #(CLK_PERIOD * 100); //Pausa entre transimisiones
        
        //Prueba 2: Enviar 'i' (0x69)
        fork
        send_byte(8'h69);
        join_none
        
        //Esperar a que termine el envio
        @(posedge tdre);
        $display("[%0t ns] Test: Transmision de 'i' completada (tdre alto).", $time);

        #(CLK_PERIOD * 200);
        
        // Fin
        $display("--- Simulación Finalizada ---");
        $stop;
    end
endmodule
