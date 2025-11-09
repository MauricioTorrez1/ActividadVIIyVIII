`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 20:35:34
// Design Name: 
// Module Name: top_controller_v2
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
 * Controlador Principal FSMD (Versión 2 - UART + Hardware)
 *
 * MODO UART (SW15 = 0):
 * - Protocolo: [P/M] [n] [Enter]
 * - Salida: "0x[Resultado_Hex]\r\n"
 *
 * MODO MANUAL (SW15 = 1):
 * - SW14: Comando (0=P, 1=M)
 * - SW[3:0]: Valor 'n'
 * - BTNR: Ejecutar "Enter"
 *
 * DISPLAY 7-SEGMENTOS:
 * - Muestra estado/resultado.
 */
module top_controller_v2 (
    input  logic clk,
    input  logic clr,
    
    // Interfaz UART 
    input  logic RxD,
    output logic TxD,
    
    
    input  logic [15:0] sw,   // 16 switches
    input  logic btnr, // Botón derecho (para "Enter")
    
    
    output logic [3:0]  anodes,   // Ánodos del display
    output logic [7:0]  cathodes  // Cátodos del display
);
    // 100MHz / 9600 baud = 10417
    localparam int BIT_TIME = 10417; 
    
    
    
    // UART RX
    logic [7:0] rx_data;
    logic rx_rdrf;
    logic rx_rdrf_clr;
    
    uart_rx #(.CLKS_PER_BIT(BIT_TIME)) i_uart_rx (
        .clk(clk), 
        .clr(clr), 
        .RxD(RxD),
        .rdrf_clr(rx_rdrf_clr), 
        .rx_data(rx_data),
        .rdrf(rx_rdrf), 
        .FE()
    );

    // UART TX
    logic [7:0] tx_data;
    logic tx_ready;
    logic tx_tdre;
    
    uart_tx #(.BIT_TIME(BIT_TIME)) i_uart_tx (
        .clk(clk), 
        .clr(clr), 
        .tx_data(tx_data),
        .ready(tx_ready), 
        .TxD(TxD),
        .tdre(tx_tdre)
    );
    
    // Algoritmo PADOVAN
    logic pado_start;
    logic [7:0]  pado_n;
    logic [31:0] pado_out;
    logic pado_ready;
    
    padovan i_pado (
        .clk(clk), 
        .clr(clr), 
        .start(pado_start),
        .n_in(pado_n), 
        .p_out(pado_out),
        .ready(pado_ready)
    );

    // Algoritmo MOSER
    logic moser_start;
    logic [7:0]  moser_n;
    logic [31:0] moser_out;
    logic moser_ready;

    moser i_moser (
        .clk(clk),
        .clr(clr), 
        .start(moser_start),
        .n_in(moser_n), 
        .s_out(moser_out), 
        .ready(moser_ready)
    );

    
   
    logic [15:0] display_data; // El dato que queremos mostrar
    
     x7segmux_v2 i_display (
        .clk(clk),
        .clr(clr),
        .hex_data(display_data),
        .anodes(anodes),
        .cathodes(cathodes)
    );
    
    // Debouncer para el botón "Enter"
    logic btnr_pulse; 
    
    debouncer_v2 i_btnr_debounce (
        .clk(clk),
        .clr(clr),
        .btn_in(btnr),
        .btn_pulse(btnr_pulse)
    );
    
    // Selector de Modo
    logic input_is_uart;
    assign input_is_uart = (sw[15] == 0); // SW15 selecciona el modo


    // --- FSM Principal ---
    typedef enum {
        S_IDLE, 
        S_WELCOME_MSG, 
        S_WELCOME_WAIT,
        S_WAIT_CMD, 
        S_ECHO_CMD, 
        S_WAIT_N, 
        S_ECHO_N,
        S_WAIT_ENTER,
        S_ECHO_ENTER,
        S_PARSE,
        S_RUN_PADOVAN, 
        S_WAIT_PADOVAN,
        S_RUN_MOSER,
        S_WAIT_MOSER,
        S_FORMAT_RESULT, 
        S_FORMAT_RESULT_WAIT, 
        S_SEND_X, 
        S_SEND_X_WAIT, 
        S_SEND_RESULT, 
        S_SEND_WAIT,
        S_SEND_NEWLINE_R,
        S_SEND_NEWLINE_R_WAIT,
        S_SEND_NEWLINE_N, 
        S_SEND_NEWLINE_N_WAIT,
        S_SEND_ERROR,
        S_SEND_ERROR_WAIT
    } state_t;
    
    state_t state_reg, state_next;
    
    // --- Registros del Datapath ---
    logic [7:0]  cmd_char;     // 'P' o 'M'
    logic [7:0]  n_char;       // '0' a 'F' (ASCII)
    logic [7:0]  n_value;      // Valor binario de n
    logic [31:0] result_value; // Resultado de 32 bits
    logic [31:0] result_buffer;// Buffer para enviar resultado
    logic [3:0]  send_count;   // Contador para enviar 8 digitos hex
    
    // ROM para el mensaje de bienvenida
    localparam string WELCOME_MSG = "Comando: [P/M] [n, 0-F] [Enter]\r\n";
    logic [6:0] msg_index; // Indice para el mensaje

    // --- Lógica Secuencial (Registros y Acciones de Estado) ---
    always_ff @(posedge clk) begin
        if (clr) begin
            // Resetea 
            state_reg     <= S_IDLE;
            rx_rdrf_clr   <= 1'b0;
            tx_ready      <= 1'b0;
            pado_start    <= 1'b0;
            moser_start   <= 1'b0;
            msg_index     <= '0;
            send_count    <= '0;
            display_data  <= 16'hAAAA; // "----"
        end else begin
            // Valores por defecto
            state_reg     <= state_next;
            rx_rdrf_clr   <= 1'b0;
            tx_ready      <= 1'b0;
            pado_start    <= 1'b0;
            moser_start   <= 1'b0;
            display_data  <= display_data; // Mantener valor

            case (state_reg)
                S_IDLE: begin
                    msg_index <= 0;
                    display_data <= 16'hAAAA; // "----"
                end

                S_WELCOME_MSG: begin
                    if (tx_tdre) begin
                        case (msg_index)
                            0:  tx_data <= "C";
                            1:  tx_data <= "o";
                            2:  tx_data <= "m";
                            3:  tx_data <= "a";
                            4:  tx_data <= "n";
                            5:  tx_data <= "d";
                            6:  tx_data <= "o";
                            7:  tx_data <= ":";
                            8:  tx_data <= " ";
                            9:  tx_data <= "[";
                            10: tx_data <= "P";
                            11: tx_data <= "/";
                            12: tx_data <= "M";
                            13: tx_data <= "]";
                            14: tx_data <= " ";
                            15: tx_data <= "[";
                            16: tx_data <= "n";
                            17: tx_data <= ",";
                            18: tx_data <= " ";
                            19: tx_data <= "0";
                            20: tx_data <= "-";
                            21: tx_data <= "F";
                            22: tx_data <= "]";
                            23: tx_data <= " ";
                            24: tx_data <= "[";
                            25: tx_data <= "E";
                            26: tx_data <= "n";
                            27: tx_data <= "t";
                            28: tx_data <= "e";
                            29: tx_data <= "r";
                            30: tx_data <= "]";
                            31: tx_data <= 8'h0D; // \r
                            32: tx_data <= 8'h0A; // \n
                            default: tx_data <= " ";
                        endcase
                        tx_ready <= 1'b1;
                        msg_index <= msg_index + 1;
                    end
                end

                S_WAIT_CMD: begin
                    if (input_is_uart) begin
                        if (rx_rdrf) begin 
                            cmd_char <= rx_data;
                            rx_rdrf_clr <= 1'b1;
                        end
                        display_data <= 16'hBCCC; // "UArt"
                    end else begin
                        display_data <= sw; // Muestra el valor de los switches
                    end
                end

                S_ECHO_CMD: begin
                    if (tx_tdre) begin
                        tx_data <= cmd_char; // Echo
                        tx_ready <= 1'b1;
                    end
                end

                S_WAIT_N: begin
                    if (input_is_uart & rx_rdrf) begin 
                        n_char <= rx_data;
                        rx_rdrf_clr <= 1'b1;
                    end
                end
                
                S_ECHO_N: begin
                    if (tx_tdre) begin
                        tx_data <= n_char; // Echo
                        tx_ready <= 1'b1;
                    end
                end

                S_WAIT_ENTER: begin
                    if (input_is_uart & rx_rdrf) begin 
                        rx_rdrf_clr <= 1'b1;
                    end
                end
                
                S_ECHO_ENTER: begin
                    if (tx_tdre) begin
                        tx_data <= 8'h0D; // Echo \r
                        tx_ready <= 1'b1;
                    end
                end

                S_PARSE: begin
                    if (input_is_uart) begin
                        // Convertir ASCII Hex a binario
                        n_value <= (n_char >= 8'h41) ? (n_char - 8'h37) : (n_char - 8'h30);
                    end else begin
                        //  Cargar desde switches
                        cmd_char <= (sw[14]) ? 8'h4D : 8'h50; // 'M' if SW14=1, 'P' if 0
                        n_value  <= sw[3:0]; // Valor binario directo
                    end
                end
                
                S_RUN_PADOVAN: begin
                    pado_start <= 1'b1;
                    pado_n <= (input_is_uart) ? n_value : sw[3:0]; 
                    display_data <= 16'hFBBB; // "runn"
                end
                S_RUN_MOSER: begin
                    moser_start <= 1'b1;
                    moser_n <= (input_is_uart) ? n_value : sw[3:0]; 
                    display_data <= 16'hFBBB; // "runn"
                end

                S_WAIT_PADOVAN: begin
                    if (pado_ready) 
                        result_value <= pado_out;
                end
                
                S_WAIT_MOSER: begin
                    if (moser_ready) 
                        result_value <= moser_out;
                end

                S_FORMAT_RESULT: begin
                    result_buffer <= result_value;
                    send_count <= 0;
                    tx_data <= "0"; // Envia '0' de "0x"
                    tx_ready <= 1'b1;
                    display_data <= result_value[15:0]; // Muestra 4 LSBs
                end
                
                S_SEND_X: begin
                    tx_data <= "x";
                    tx_ready <= 1'b1;
                end

                S_SEND_RESULT: begin
                    automatic logic [3:0] nibble = result_buffer[31:28];
                    tx_data <= (nibble < 10) ? (nibble + 8'h30) : (nibble + 8'h37);
                    tx_ready <= 1'b1;
                    result_buffer <= result_buffer << 4; // Desplaza para el prox nibble
                    send_count <= send_count + 1;
                end
                
                S_SEND_NEWLINE_R: begin
                    if (tx_tdre) begin
                        tx_data <= 8'h0D; // '\r'
                        tx_ready <= 1'b1;
                    end
                end
                
                S_SEND_NEWLINE_N: begin
                    if (tx_tdre) begin
                        tx_data <= 8'h0A; // '\n'
                        tx_ready <= 1'b1;
                    end
                end

                S_SEND_ERROR: begin
                    if (tx_tdre) begin
                        tx_data <= "E"; // Error
                        tx_ready <= 1'b1;
                    end
                end
                
                default: ; 
            endcase
        end
    end

    // --- Lógica Combinacional (Siguiente Estado) ---
    always_comb begin
        state_next = state_reg; // Valor por defecto

        case (state_reg)
            S_IDLE: 
                state_next = S_WELCOME_MSG;
            
            S_WELCOME_MSG: 
                state_next = S_WELCOME_WAIT; 
            
            S_WELCOME_WAIT: 
                if (tx_tdre) begin
                    if (msg_index == WELCOME_MSG.len()) 
                        state_next = S_WAIT_CMD;
                    else 
                        state_next = S_WELCOME_MSG;
                end

            S_WAIT_CMD: 
                if (input_is_uart) begin
                    if (rx_rdrf)
                        state_next = S_ECHO_CMD;
                end else begin
                    if (btnr_pulse) //  Botón presionado
                        state_next = S_PARSE; // Saltar a PARSE
                end
                
            S_ECHO_CMD: 
                if (input_is_uart & tx_tdre) 
                    state_next = S_WAIT_N;
                else if (~input_is_uart) 
                    state_next = S_WAIT_N;

            S_WAIT_N: 
                if (input_is_uart & rx_rdrf) 
                    state_next = S_ECHO_N;
                else if (~input_is_uart) 
                    state_next = S_ECHO_N;

            S_ECHO_N: 
                if (input_is_uart & tx_tdre) 
                    state_next = S_WAIT_ENTER;
                else if (~input_is_uart) 
                    state_next = S_WAIT_ENTER;

            S_WAIT_ENTER: 
                if (input_is_uart & rx_rdrf) 
                    state_next = S_ECHO_ENTER;
                else if (~input_is_uart) 
                    state_next = S_ECHO_ENTER;
            
            S_ECHO_ENTER: 
                if (input_is_uart & tx_tdre) 
                    state_next = S_PARSE;
                else if (~input_is_uart) 
                    state_next = S_PARSE;
                
            S_PARSE: begin
            if (input_is_uart) begin
                    if (cmd_char == 8'h50) // 'P'
                        state_next = S_RUN_PADOVAN;
                    else if (cmd_char == 8'h4D) // 'M'
                        state_next = S_RUN_MOSER;
                    else
                        state_next = S_SEND_ERROR;
                end else begin
                    // Leemos los switches 
                    if (sw[14] == 0) // 'P'
                        state_next = S_RUN_PADOVAN;
                    else // 'M'
                        state_next = S_RUN_MOSER;
                end
            end

            S_RUN_PADOVAN: 
                state_next = S_WAIT_PADOVAN;
            S_RUN_MOSER: 
                state_next = S_WAIT_MOSER;
            
            S_WAIT_PADOVAN: 
                if (pado_ready) 
                    state_next = S_FORMAT_RESULT;
            S_WAIT_MOSER: 
                if (moser_ready) 
                    state_next = S_FORMAT_RESULT;

            // --- Lógica de Envío de Resultado 
            S_FORMAT_RESULT:
                state_next = S_FORMAT_RESULT_WAIT;
            
            S_FORMAT_RESULT_WAIT:
                if (tx_tdre) // Esperar a que el '0' termine
                    state_next = S_SEND_X_WAIT;

            S_SEND_X_WAIT: 
                if (tx_tdre) 
                    state_next = S_SEND_X;
            
            S_SEND_X: 
                state_next = S_SEND_WAIT;
            
            S_SEND_RESULT:
                state_next = S_SEND_WAIT;
            
            S_SEND_WAIT: 
                if (tx_tdre) begin
                    if (send_count[3]) // 
                        state_next = S_SEND_NEWLINE_R; // Termino
                    else 
                        state_next = S_SEND_RESULT;
                end
            
            // --- Envío de \r\n ---
            S_SEND_NEWLINE_R: 
                if (tx_ready) 
                    state_next = S_SEND_NEWLINE_R_WAIT;
            S_SEND_NEWLINE_R_WAIT: 
                if(tx_tdre) 
                    state_next = S_SEND_NEWLINE_N;
            S_SEND_NEWLINE_N: 
                if (tx_ready) 
                    state_next = S_SEND_NEWLINE_N_WAIT;
            S_SEND_NEWLINE_N_WAIT:
                if(tx_tdre) 
                    state_next = S_IDLE; 

            // --- Envío de Error ---
            S_SEND_ERROR: 
                if (tx_ready) 
                    state_next = S_SEND_ERROR_WAIT;
            S_SEND_ERROR_WAIT: 
                if (tx_tdre)
                    state_next = S_IDLE;

            default: state_next = S_IDLE;
        endcase
    end

endmodule
