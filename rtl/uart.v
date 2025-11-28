// ============================================================================
// File: rtl/uart.v
// Simple UART Module for debugging
// ============================================================================

module simple_uart #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        mem_valid,
    output reg         mem_ready,
    input  wire [1:0]  mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg  [31:0] mem_rdata,
    input  wire        uart_rxd,
    output wire        uart_txd
);

    // Simple polled UART
    // Register 0: TX data (write), RX data (read)
    // Register 1: Status (bit 0: TX ready, bit 1: RX ready)
    
    localparam DIVISOR = CLK_FREQ / BAUD_RATE;
    
    reg [7:0]  tx_data;
    reg        tx_start;
    wire       tx_busy;
    
    wire [7:0] rx_data;
    wire       rx_valid;
    
    uart_tx #(.DIVISOR(DIVISOR)) tx_inst (
        .clk(clk),
        .rst(rst),
        .data(tx_data),
        .start(tx_start),
        .busy(tx_busy),
        .tx(uart_txd)
    );
    
    uart_rx #(.DIVISOR(DIVISOR)) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(uart_rxd),
        .data(rx_data),
        .valid(rx_valid)
    );
    
    reg [7:0] rx_buffer;
    reg       rx_ready;
    
    always @(posedge clk) begin
        if (rst) begin
            mem_ready <= 0;
            tx_start <= 0;
            rx_ready <= 0;
        end
        else begin
            tx_start <= 0;
            mem_ready <= mem_valid && !mem_ready;
            
            if (rx_valid) begin
                rx_buffer <= rx_data;
                rx_ready <= 1;
            end
            
            if (mem_valid) begin
                case (mem_addr)
                    2'h0: begin
                        if (|mem_wstrb) begin
                            tx_data <= mem_wdata[7:0];
                            tx_start <= 1;
                        end
                        mem_rdata <= {24'h0, rx_buffer};
                        if (!mem_wstrb)
                            rx_ready <= 0;
                    end
                    2'h1: begin
                        mem_rdata <= {30'h0, rx_ready, !tx_busy};
                    end
                    default: mem_rdata <= 32'h0;
                endcase
            end
        end
    end

endmodule

// ============================================================================
// UART TX
// ============================================================================

module uart_tx #(
    parameter DIVISOR = 434
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire       start,
    output reg        busy,
    output reg        tx
);

    reg [3:0]  bit_count;
    reg [15:0] divisor_count;
    reg [7:0]  shift_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            busy <= 0;
            tx <= 1;
            bit_count <= 0;
            divisor_count <= 0;
        end
        else begin
            if (!busy && start) begin
                shift_reg <= data;
                busy <= 1;
                bit_count <= 0;
                divisor_count <= 0;
                tx <= 0; // Start bit
            end
            else if (busy) begin
                if (divisor_count == DIVISOR - 1) begin
                    divisor_count <= 0;
                    
                    if (bit_count < 8) begin
                        tx <= shift_reg[bit_count];
                        bit_count <= bit_count + 1;
                    end
                    else if (bit_count == 8) begin
                        tx <= 1; // Stop bit
                        bit_count <= bit_count + 1;
                    end
                    else begin
                        busy <= 0;
                    end
                end
                else begin
                    divisor_count <= divisor_count + 1;
                end
            end
        end
    end

endmodule

// ============================================================================
// UART RX
// ============================================================================

module uart_rx #(
    parameter DIVISOR = 434
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);

    reg [3:0]  bit_count;
    reg [15:0] divisor_count;
    reg [7:0]  shift_reg;
    reg        busy;
    reg [1:0]  rx_sync;
    
    always @(posedge clk) begin
        if (rst) begin
            busy <= 0;
            valid <= 0;
            bit_count <= 0;
            divisor_count <= 0;
            rx_sync <= 2'b11;
        end
        else begin
            rx_sync <= {rx_sync[0], rx};
            valid <= 0;
            
            if (!busy) begin
                if (rx_sync[1] == 0) begin // Start bit detected
                    busy <= 1;
                    bit_count <= 0;
                    divisor_count <= DIVISOR / 2; // Sample in middle
                end
            end
            else begin
                if (divisor_count == DIVISOR - 1) begin
                    divisor_count <= 0;
                    
                    if (bit_count < 8) begin
                        shift_reg[bit_count] <= rx_sync[1];
                        bit_count <= bit_count + 1;
                    end
                    else begin
                        data <= shift_reg;
                        valid <= 1;
                        busy <= 0;
                    end
                end
                else begin
                    divisor_count <= divisor_count + 1;
                end
            end
        end
    end

endmodule