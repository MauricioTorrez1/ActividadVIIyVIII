`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.11.2025 17:00:08
// Design Name: 
// Module Name: tb_moser
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
 * Testbench for algorithm_moser 
 * Verifica la conversión a base-4.
 */
module tb_moser;

    // --- Clock simulation ---
    localparam CLK_PERIOD = 10; // 100MHz
    logic clk;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --- DUT Signals ---
    logic        clr;
    logic        start;
    logic [7:0]  n_in;
    logic [31:0] s_out;
    logic        ready;
    
    // --- Instantiate DUT 
    moser i_dut (
        .clk(clk),
        .clr(clr),
        .start(start),
        .n_in(n_in),
        .s_out(s_out),
        .ready(ready)
    );

    // --- Test Task (CORREGIDA) ---
    task automatic check_moser(input [7:0] n, input [31:0] expected_result);
        $display("[%0t ns] Test: Starting Moser(%0d)...", $time, n);
        
        // 1. Load inputs
        n_in <= n;
        
        // 2. Pulso de 'start' robusto 
        @(posedge clk);       // Alinear al reloj
        start <= 1'b1;     // Subir 'start'
        @(posedge clk);       // Mantener 'start' alto por un ciclo completo
        start <= 1'b0;     // Bajar 'start'
        
        // 3. Wait for 'ready' pulse
//        (como la de padovan) sería:
        // while (ready == 1'b0) begin
        //     @(posedge clk);
        // end
        
        @(posedge ready); // Espera a que 'ready' suba
        @(posedge clk);   // Espera al siguiente ciclo para estabilizar
        
        // 4. Check result
        if (s_out == expected_result) begin
            $display("[%0t ns] Test: SUCCESS! S(%0d) = %0d", $time, n, s_out);
        end else begin
            $error("[%0t ns] Test: FAILED! S(%0d). Expected %0d, Got %0d", $time, n, expected_result, s_out);
        end
        
        #(CLK_PERIOD * 10); // Wait a bit
    endtask

    // --- Test Sequence ---
    initial begin
        $display("--- Simulation Started: tb_algorithm_moser ---");
        // 
        start <= 1'b0;
        n_in  <= 8'h00;
        clr   <= 1'b1;
        #(CLK_PERIOD * 5);
        clr   <= 1'b0;
        #(CLK_PERIOD * 10);

        // --- Run Tests ---
        
        // Test 1: Base Case n=0 (S(0) = 0)
        check_moser(8'd0, 32'd0);
        
        // Test 2: Case n=5 (S(5) = 17)
        // n=5 -> 0b101 -> 101 (base 4) = 1*16 + 0*4 + 1*1 = 17
        check_moser(8'd5, 32'd17);
        
        // Test 3: Case n=6 (S(6) = 20)
        // n=6 -> 0b110 -> 110 (base 4) = 1*16 + 1*4 + 0*1 = 20
        check_moser(8'd6, 32'd20);

        $display("--- Simulation Finished ---");
        $stop;
    end

endmodule


