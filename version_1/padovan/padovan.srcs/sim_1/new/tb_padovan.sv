`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.11.2025 15:29:04
// Design Name: 
// Module Name: tb_padovan
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
 * Testbench for padovan
 *
 * 
 */
module tb_algorithm_padovan;

    // --- Clock simulation ---
    localparam CLK_PERIOD = 10; // 100MHz
    logic clk;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --- DUT Signals ---
    logic       clr;
    logic       start;
    logic [7:0] n_in;
    logic [31:0] p_out;
    logic       ready;

    // --- Instantiate DUT ---
    padovan i_dut (
        .clk(clk),
        .clr(clr),
        .start(start),
        .n_in(n_in),
        .p_out(p_out),
        .ready(ready)
    );

    // --- Test Sequence (SIN TAREAS) ---
    initial begin
        $display("--- Simulation Started: tb_algorithm_padovan ---");
        
        // 1. Initialize and Reset
        start <= 1'b0;
        n_in  <= 8'h00;
        clr   <= 1'b1;
        #(CLK_PERIOD * 5);
        clr   <= 1'b0;
        #(CLK_PERIOD * 10);

        // --- Test 1: Base Case n=2 (P(2) = 1) ---
        $display("[%0t ns] Test: Starting Padovan(2)...", $time);
        n_in <= 8'd2;
        start <= 1'b1;      // <-- Pulso 1
        @(posedge clk);
        start <= 1'b0;
        

        while (ready == 1'b0) begin
            @(posedge clk);
        end
        
        // Comprueba el resultado
        if (p_out == 32'd1) begin
            $display("[%0t ns] Test: SUCCESS! P(2) = %0d", $time, p_out);
        end else begin
            $error("[%0t ns] Test: FAILED! P(2). Expected 1, Got %0d", $time, p_out);
        end
        
        #(CLK_PERIOD * 10); // Pausa

        // --- Test 2: Recursive Case n=5 (P(5) = 3) ---
        $display("[%0t ns] Test: Starting Padovan(5)...", $time);
        @(posedge clk);
        n_in <= 8'd5;
        start <= 1'b1;      // <-- Pulso 2
        @(posedge clk);
        start <= 1'b0;
        

        while (ready == 1'b0) begin
            @(posedge clk);
        end
        
        // Comprueba el resultado
        if (p_out == 32'd3) begin
            $display("[%0t ns] Test: SUCCESS! P(5) = %0d", $time, p_out);
        end else begin
            $error("[%0t ns] Test: FAILED! P(5). Expected 3, Got %0d", $time, p_out);
        end

        #(CLK_PERIOD * 10); // Pausa
        
        // --- Test 3: Recursive Case n=10 (P(10) = 12) ---
        $display("[%0t ns] Test: Starting Padovan(10)...", $time);
        @(posedge clk);
        n_in <= 8'd10;
        start <= 1'b1;      // <-- Pulso 3
        @(posedge clk);
        start <= 1'b0;
        

        while (ready == 1'b0) begin
            @(posedge clk);
        end
        
        // Comprueba el resultado
        if (p_out == 32'd12) begin
            $display("[%0t ns] Test: SUCCESS! P(10) = %0d", $time, p_out);
        end else begin
            $error("[%0t ns] Test: FAILED! P(10). Expected 12, Got %0d", $time, p_out);
        end
        
        #(CLK_PERIOD * 10); // Pausa

        $display("--- Simulation Finished ---");
        $stop;
    end

endmodule



