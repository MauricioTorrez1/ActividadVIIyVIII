`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.11.2025 17:12:14
// Design Name: 
// Module Name: tb_top_controller
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
 * Testbench Robusto (Estilo Monitor) para top_controller
 *
 * Este testbench utiliza dos procesos paralelos:
 * 1. Un "Driver" que envía comandos al DUT.
 * 2. Un "Monitor" que recibe e imprime de forma asíncrona todo
 * lo que el DUT transmite.
 *
 * Esto evita deadlocks y facilita la depuración.
 */
module tb_top_controller;

    // --- Parámetros de Simulación ---
    localparam int CLK_PERIOD = 10;    // 100MHz
    localparam int BIT_TIME   = 10417; // 100MHz / 9600 baud
    
    // --- Señales ---
    logic clk;
    logic clr;
    logic tb_txd; // Testbench Transmit -> DUT Receive (RxD)
    logic tb_rxd; // Testbench Receive <- DUT Transmit (TxD)

    // --- Instancia del DUT ---
    top_controller i_dut (
        .clk(clk),
        .clr(clr),
        .RxD(tb_txd),
        .TxD(tb_rxd) 
    );

    // --- Generador de Reloj ---
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --- TAREA: Enviar un byte al DUT (Versión síncrona correcta) ---
    task automatic send_byte_to_dut(input [7:0] data);
        $display("[%0t ns] TB > SEND: '%c' (0x%h)", $time, data, data);
        tb_txd <= 1'b1;
        @(posedge clk);
        
        // Start bit
        tb_txd <= 1'b0;
        repeat (BIT_TIME) @(posedge clk);
        
        // 8 Data bits
        for (int i = 0; i < 8; i++) begin
            tb_txd <= data[i];
            repeat (BIT_TIME) @(posedge clk);
        end
        
        // Stop bit
        tb_txd <= 1'b1;
        repeat (BIT_TIME) @(posedge clk);
        
        // Pequeña espera entre bytes para evitar problemas
        repeat (BIT_TIME) @(posedge clk); 
    endtask

    // --- PROCESO 1: El Monitor de Recepción (Asíncrono) ---
    initial begin
        logic [7:0] received_data;
        $display("--- Monitor UART RX iniciado ---");
        forever begin
            // Esperar el bit de inicio
            @(negedge tb_rxd); 
            
            // Esperar 1.5 bit times para muestrear en el centro del primer bit
            repeat (BIT_TIME + (BIT_TIME / 2)) @(posedge clk);
            received_data[0] = tb_rxd;
            
            // Muestrear los 7 bits restantes
            for (int i = 1; i < 8; i++) begin
                repeat (BIT_TIME) @(posedge clk);
                received_data[i] = tb_rxd;
            end
            
            // Imprimir el byte recibido
            $write("[%0t ns] TB < RECV: '%c'\n", $time, received_data);
            
            // Esperar el bit de stop
            repeat (BIT_TIME) @(posedge clk);
        end
    end

    // --- PROCESO 2: La Secuencia de Prueba Principal (Driver) ---
    initial begin
        $display("--- Secuencia de Prueba Iniciada ---");
        
        // 1. Reset
        tb_txd <= 1'b1; // Línea inactiva
        clr    <= 1'b1;
        repeat(5) @(posedge clk);
        clr    <= 1'b0;
        
        // 2. Esperar a que el DUT envíe su mensaje de bienvenida.
        // El monitor se encargará de recibirlo. Le damos tiempo de sobra.
        // 33 caracteres * 10 bits/char * 10417 ciclos/bit * 10ns/ciclo ~= 35ms
        $display("Test: Esperando Mensaje de Bienvenida...");
        #(40_000_000); // Esperamos 40ms

        // 3. PRUEBA PADOVAN P(5)
        $display("\nTest: Iniciando prueba Padovan(5)...");
        send_byte_to_dut("P");
        send_byte_to_dut("5");
        send_byte_to_dut(8'h0D); // Enter
        
        // Esperar el resultado. (10 digitos "0x...3" + \r\n = 12 chars)
        $display("Test: Comando P(5) enviado. Esperando resultado...");
        #(20_000_000); // Esperamos 20ms

        // 4. Esperar el segundo mensaje de bienvenida
        $display("\nTest: Esperando segundo Mensaje de Bienvenida...");
        #(40_000_000); // Esperamos 40ms

        // 5. PRUEBA MOSER M(6)
        $display("\nTest: Iniciando prueba Moser(6)...");
        send_byte_to_dut("M");
        send_byte_to_dut("6");
        send_byte_to_dut(8'h0D); // Enter
        
        $display("Test: Comando M(6) enviado. Esperando resultado...");
        #(20_000_000); // Esperamos 20ms

        $display("\n--- Simulacion Finalizada ---");
        $stop;
    end

endmodule