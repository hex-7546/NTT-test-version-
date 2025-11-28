// ============================================================================
// File: rtl/ntt_wrapper.v
// Memory-Mapped NTT Wrapper
// Provides simple interface for PicoRV32 CPU
// Memory map:
//   0x00: Control Register (start, mode)
//   0x04: Status Register (busy, done, error)
//   0x100-0x2FF: Coefficient Memory (256 x 16-bit = 512 bytes)
// ============================================================================

module ntt_wrapper #(
    parameter BASE_ADDR = 32'h10000000,
    parameter Q = 3329,
    parameter N = 256,
    parameter W = 16
)(
    input  wire         clk,
    input  wire         rst,
    
    // Simple memory interface from CPU
    input  wire         mem_valid,
    output reg          mem_ready,
    input  wire [31:0]  mem_addr,
    input  wire [31:0]  mem_wdata,
    input  wire [3:0]   mem_wstrb,
    output reg  [31:0]  mem_rdata
);

    // ========================================================================
    // Registers
    // ========================================================================
    
    reg         ctrl_start;
    reg         ctrl_mode;         // 0: NTT, 1: INTT
    wire        status_busy;
    wire        status_done;
    wire        status_error;
    
    // ========================================================================
    // Coefficient Memory (Dual-port BRAM)
    // ========================================================================
    
    reg  [W-1:0] coeff_mem [0:N-1];
    
    // CPU port
    wire        cpu_coeff_we;
    wire [7:0]  cpu_coeff_addr;
    wire [W-1:0] cpu_coeff_wdata;
    reg  [W-1:0] cpu_coeff_rdata;
    
    // NTT core port
    wire [7:0]  ntt_coeff_addr;
    wire        ntt_coeff_we;
    wire [W-1:0] ntt_coeff_wdata;
    wire [W-1:0] ntt_coeff_rdata;
    
    // ========================================================================
    // Address Decoding
    // ========================================================================
    
    wire addr_match;
    wire [11:0] local_addr;
    
    assign addr_match = (mem_addr[31:12] == BASE_ADDR[31:12]);
    assign local_addr = mem_addr[11:0];
    
    wire is_ctrl_reg = (local_addr == 12'h000);
    wire is_status_reg = (local_addr == 12'h004);
    wire is_coeff_mem = (local_addr >= 12'h100) && (local_addr < 12'h300);
    
    assign cpu_coeff_addr = local_addr[8:1];  // Word address (16-bit words)
    assign cpu_coeff_we = mem_valid && is_coeff_mem && (|mem_wstrb) && !status_busy;
    assign cpu_coeff_wdata = mem_wdata[15:0];
    
    // ========================================================================
    // CPU Interface Logic
    // ========================================================================
    
    always @(posedge clk) begin
        if (rst) begin
            mem_ready <= 0;
            mem_rdata <= 0;
            ctrl_start <= 0;
            ctrl_mode <= 0;
        end
        else begin
            // Default values
            ctrl_start <= 0;
            mem_ready <= 0;
            
            if (mem_valid && addr_match && !mem_ready) begin
                mem_ready <= 1;
                
                if (|mem_wstrb) begin  // Write operation
                    if (is_ctrl_reg && !status_busy) begin
                        ctrl_start <= mem_wdata[0];
                        ctrl_mode <= mem_wdata[1];
                    end
                    // Coefficient writes handled by BRAM
                end
                else begin  // Read operation
                    if (is_ctrl_reg) begin
                        mem_rdata <= {30'd0, ctrl_mode, 1'b0};
                    end
                    else if (is_status_reg) begin
                        mem_rdata <= {29'd0, status_error, status_done, status_busy};
                    end
                    else if (is_coeff_mem) begin
                        mem_rdata <= {16'd0, cpu_coeff_rdata};
                    end
                    else begin
                        mem_rdata <= 32'd0;
                    end
                end
            end
        end
    end
    
    // ========================================================================
    // Coefficient Memory (Dual-Port)
    // ========================================================================
    
    // CPU port (when NTT is not busy)
    always @(posedge clk) begin
        if (cpu_coeff_we && !status_busy) begin
            coeff_mem[cpu_coeff_addr] <= cpu_coeff_wdata;
        end
        cpu_coeff_rdata <= coeff_mem[cpu_coeff_addr];
    end
    
    // NTT port (when NTT is busy)
    always @(posedge clk) begin
        if (ntt_coeff_we) begin
            coeff_mem[ntt_coeff_addr] <= ntt_coeff_wdata;
        end
    end
    
    assign ntt_coeff_rdata = coeff_mem[ntt_coeff_addr];
    
    // ========================================================================
    // NTT Core Instance
    // ========================================================================
    
    ntt_core #(
        .Q(Q),
        .N(N),
        .W(W)
    ) ntt_inst (
        .clk(clk),
        .rst(rst),
        .start(ctrl_start),
        .mode(ctrl_mode),
        .done(status_done),
        .busy(status_busy),
        .coeff_addr(ntt_coeff_addr),
        .coeff_we(ntt_coeff_we),
        .coeff_wdata(ntt_coeff_wdata),
        .coeff_rdata(ntt_coeff_rdata),
        .error(status_error)
    );

endmodule