`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.11.2025 16:38:36
// Design Name: 
// Module Name: top_controller
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
 * Controlador Principal FSMD (Versión 1 - Solo UART)
 *
 * Esta FSM gestiona la comunicacion y los algoritmos.
 * Protocolo de Comando: [P/M] [n] [Enter]
 * - 'P' (0x50) o 'M' (0x4D)
 * - 'n' (ASCII '0'-'9', 'A'-'F')
 * - 'Enter' (0x0D)
 *
 * Salida: "0x[Resultado_Hex]\r\n"
 */
module top_controller (
    input  logic clk,
    input  logic clr,
    
    // Interfaz UART
    input  logic RxD,
    output logic TxD
);
    // 100MHz / 9600 baud = 10417
    localparam int BIT_TIME = 10417; 
    
    // --- Instancias de Modulos ---
    
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
    
    padovan i_pado ( // El nombre "padovan" debe coincidir con tu archivo
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

    moser i_moser ( // El nombre "moser" debe coincidir con tu archivo
        .clk(clk),
        .clr(clr), 
        .start(moser_start),
        .n_in(moser_n), 
        .s_out(moser_out), 
        .ready(moser_ready)
    );

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
        S_SEND_NEWLINE_R_WAIT, // \r
        S_SEND_NEWLINE_N, 
        S_SEND_NEWLINE_N_WAIT, // \n
        S_SEND_ERROR,
        S_SEND_ERROR_WAIT
    } state_t;
    
    state_t state_reg, state_next;
    
    // --- Registros del Datapath (Controlador) ---
    logic [7:0]  cmd_char;     // 'P' o 'M'
    logic [7:0]  n_char;       // '0' a 'F'
    logic [7:0]  n_value;      // Valor binario de n
    logic [31:0] result_value; // Resultado de 32 bits
    logic [31:0] result_buffer; // Buffer para enviar resultado
    logic [3:0]  send_count;   // Contador para enviar 8 digitos hex
    
    // ROM para el mensaje de bienvenida
    localparam string WELCOME_MSG = "Comando: [P/M] [n, 0-F] [Enter]\r\n";
    logic [6:0] msg_index; // Indice para el mensaje

    // --- Lógica Secuencial (Registros y Acciones de Estado) ---
    always_ff @(posedge clk) begin
        if (clr) begin
            // Resetea todos los registros y FSMs
            state_reg   <= S_IDLE;
            rx_rdrf_clr <= 1'b0;
            tx_ready    <= 1'b0;
            pado_start  <= 1'b0;
            moser_start <= 1'b0;
            msg_index   <= '0;
            send_count  <= '0;
        end else begin
            // Valores por defecto
            state_reg   <= state_next;
            rx_rdrf_clr <= 1'b0;
            tx_ready    <= 1'b0;
            pado_start  <= 1'b0;
            moser_start <= 1'b0;

            case (state_reg)
                S_IDLE: begin
                    msg_index <= 0; // Prepara el mensaje de bienvenida
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
                            31: tx_data <= 8'h0D;
                            32: tx_data <= "\n";
                            default: tx_data <= " "; // Caracter por defecto
                        endcase
                        //tx_data <= WELCOME_MSG[msg_index];
                        tx_ready <= 1'b1;
                        msg_index <= msg_index + 1;
                    end
                end

                S_WAIT_CMD: begin
                    if (rx_rdrf) begin
                        cmd_char <= rx_data;
                        rx_rdrf_clr <= 1'b1;
                    end
                end

                S_ECHO_CMD: begin
                    if (tx_tdre) begin
                        tx_data <= cmd_char; // Echo
                        tx_ready <= 1'b1;
                    end
                end

                S_WAIT_N: begin
                    if (rx_rdrf) begin
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
                    if (rx_rdrf) 
                    rx_rdrf_clr <= 1'b1;
                end
                
                S_ECHO_ENTER: begin
                    if (tx_tdre) begin
                        tx_data <= 8'h0D; // Echo \r
                        tx_ready <= 1'b1;
                    end
                end

                S_PARSE: begin
                     // Convertir n (ASCII Hex) a binario
                     // '0' (0x30) -> 0
                     // 'A' (0x41) -> 10. 'A' - 0x30 = 17. 17 - 7 = 10.
                    n_value <= (n_char >= 8'h41) ? (n_char - 8'h37) : (n_char - 8'h30);
                end
                
                S_RUN_PADOVAN: begin
                    pado_start <= 1'b1;
                    pado_n <= n_value; 
                end
                S_RUN_MOSER: begin
                    moser_start <= 1'b1;
                    moser_n <= n_value; 
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
                    tx_data <= "0"; // Envia '0'
                    tx_ready <= 1'b1;
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
            if (rx_rdrf)
             state_next = S_ECHO_CMD;
             
            S_ECHO_CMD:     
            if (tx_tdre) 
            state_next = S_WAIT_N;
            S_WAIT_N:       
            if (rx_rdrf) 
            state_next = S_ECHO_N;
            S_ECHO_N:       
            if (tx_tdre) 
            state_next = S_WAIT_ENTER;
            S_WAIT_ENTER:   
            if (rx_rdrf) 
            state_next = S_ECHO_ENTER;
            
            S_ECHO_ENTER:   
            if (tx_tdre)
            state_next = S_PARSE;
            
            S_PARSE: begin
                // Parsear
                if (cmd_char == 8'h50) begin // 'P'
                    // pado_n <= n_value; // <-- MOVIDO
                    state_next = S_RUN_PADOVAN;
                end else if (cmd_char == 8'h4D) begin // 'M'
                    // moser_n <= n_value; // <-- MOVIDO
                    state_next = S_RUN_MOSER;
                end else begin
                    state_next = S_SEND_ERROR;
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

            S_FORMAT_RESULT:  
            state_next = S_FORMAT_RESULT_WAIT; // Espera '0'
            
            S_FORMAT_RESULT_WAIT:
            if(tx_tdre)
            state_next = S_SEND_X_WAIT;
            
            S_SEND_X_WAIT:   
            if (tx_tdre) 
            state_next = S_SEND_X;
            
            S_SEND_X_WAIT:        
            if (tx_ready) 
            state_next = S_SEND_X;
            
            S_SEND_X:
            state_next = S_SEND_WAIT;
            
            S_SEND_RESULT: 
            state_next = S_SEND_WAIT;
            
            S_SEND_WAIT:
            if (tx_tdre) begin // Cuando el transmisor esté libre...
        //if (send_count == 8)
        if (send_count[3])
            state_next = S_SEND_NEWLINE_R; // Si ya enviamos 8, terminamos.
        else 
            state_next = S_SEND_RESULT; // Si no, enviamos el siguiente dígito.
        end     

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
             state_next = S_IDLE; // Ciclo completo

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
