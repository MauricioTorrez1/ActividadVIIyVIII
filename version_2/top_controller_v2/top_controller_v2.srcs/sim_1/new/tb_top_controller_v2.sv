`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 22:59:02
// Design Name: 
// Module Name: tb_top_controller_v2
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
 * Testbench para top_controller_v2
 *
 * Prueba 1: Modo UART (SW15=0). Envía "P5" y "M6" vía UART.
 * Prueba 2: Modo Manual (SW15=1). Envía "P7" vía switches.
 */
module tb_top_controller_v2;

    // --- Parámetros de Simulación ---
    localparam int CLK_PERIOD = 10;    // 100MHz
    localparam int BIT_TIME   = 10417; // 100MHz / 9600 baud
    
    // --- Señales ---
    logic clk;
    logic clr;
    
    // Puertos V1 (UART)
    logic tb_txd; // Testbench Transmit -> DUT Receive (RxD)
    logic tb_rxd; // Testbench Receive <- DUT Transmit (TxD)
    
    // Puertos V2 (Hardware)
    logic [15:0] sw;
    logic btnr;
    logic [3:0]  anodes;
    logic [7:0]  cathodes;


    // --- Instancia del DUT (V2) ---
    top_controller_v2 i_dut (
        .clk(clk),
        .clr(clr),
        .RxD(tb_txd),
        .TxD(tb_rxd),
        .sw(sw),
        .btnr(btnr),
        .anodes(anodes),
        .cathodes(cathodes)
    );

    // --- Generador de Reloj ---
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --- TAREA: Enviar un byte al DUT (V1, sin cambios) ---
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
        
        repeat (BIT_TIME) @(posedge clk); 
    endtask

    // --- PROCESO 1: Monitor de Recepción (V1, sin cambios) ---
    initial begin
        logic [7:0] received_data;
        $display("--- Monitor UART RX iniciado ---");
        forever begin
            @(negedge tb_rxd); 
            repeat (BIT_TIME + (BIT_TIME / 2)) @(posedge clk);
            received_data[0] = tb_rxd;
            for (int i = 1; i < 8; i++) begin
                repeat (BIT_TIME) @(posedge clk);
                received_data[i] = tb_rxd;
            end
            $write("[%0t ns] TB < RECV: '%c'\n", $time, received_data);
            repeat (BIT_TIME) @(posedge clk);
        end
    end

    // --- PROCESO 2: Secuencia de Prueba V2 (Driver) ---
    initial begin
        $display("--- Secuencia de Prueba V2 Iniciada ---");
        
        // 1. Reset e inicialización de V2
        tb_txd <= 1'b1; // Línea inactiva
        sw     <= 16'h0000;
        btnr   <= 1'b0;
        clr    <= 1'b1;
        repeat(5) @(posedge clk);
        clr    <= 1'b0;
        
        // --------------------------------------------------
        $display("\n--- PRUEBA 1: MODO UART (SW15 = 0) ---");
        sw[15] <= 1'b0; // Poner en modo UART
        // --------------------------------------------------
        
        // 2. Esperar Mensaje de Bienvenida
        $display("Test: Esperando Mensaje de Bienvenida...");
        #(40_000_000); // 40ms

        // 3. PRUEBA PADOVAN P(5) via UART
        $display("\nTest: Iniciando prueba Padovan(5) via UART...");
        send_byte_to_dut("P");
        send_byte_to_dut("5");
        send_byte_to_dut(8'h0D); // Enter
        $display("Test: Comando P(5) enviado. Esperando resultado...");
        #(20_000_000); // 20ms

        // 4. Esperar segundo Mensaje de Bienvenida
        $display("\nTest: Esperando segundo Mensaje de Bienvenida...");
        #(40_000_000); // 40ms

        // 5. PRUEBA MOSER M(6) via UART
        $display("\nTest: Iniciando prueba Moser(6) via UART...");
        send_byte_to_dut("M");
        send_byte_to_dut("6");
        send_byte_to_dut(8'h0D); // Enter
        $display("Test: Comando M(6) enviado. Esperando resultado...");
        #(20_000_000); // 20ms

        // --------------------------------------------------
        $display("\n--- PRUEBA 2: MODO MANUAL (SW15 = 1) ---");
        sw[15] <= 1'b1; // Poner en modo Manual
        // --------------------------------------------------
        
        // 6. Esperar Mensaje de Bienvenida (de nuevo)
        $display("\nTest: Esperando tercer Mensaje de Bienvenida...");
        #(40_000_000); // 40ms
        
        // 7. PRUEBA PADOVAN P(7) via Switches
        $display("\nTest: Configurando Padovan(7) en switches...");
        sw[14] <= 1'b0; // 'P'
        sw[3:0] <= 4'h7; // n=7
        
        $display("Test: Switches configurados (P, 7).");
        #(1_000_000); // 1ms (solo para que se vea en la simulación)

        $display("Test: Presionando BTNR...");
        btnr <= 1'b1; // Presionar botón
        repeat(25000)@(posedge clk); 
        btnr <= 1'b0; // Soltar botón

        $display("Test: Comando P(7) enviado. Esperando resultado...");
        #(40_000_000); // 40ms

        $display("\n--- Simulacion Finalizada ---");
        $stop;
    end

endmodule
