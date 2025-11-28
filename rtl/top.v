// ============================================================================
// File: rtl/top.v
// Top Module: PicoRV32 + NTT Accelerator System
// For Arty A7-100T FPGA
// ============================================================================

module top (
    input  wire clk_100mhz,    // 100 MHz board clock
    input  wire rst_n,          // Active-low reset button
    
    // UART for debugging
    input  wire uart_rxd,
    output wire uart_txd,
    
    // LEDs for status
    output wire [3:0] led
);

    // ========================================================================
    // Clock and Reset
    // ========================================================================
    
    wire clk;
    wire rst;
    wire locked;
    
    // Use 50 MHz for the system (easier timing closure)
    clk_wiz_0 clk_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(clk),
        .reset(!rst_n),
        .locked(locked)
    );
    
    // Synchronize reset
    reg [3:0] reset_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reset_sync <= 4'b1111;
        else
            reset_sync <= {reset_sync[2:0], 1'b0};
    end
    assign rst = reset_sync[3] | !locked;
    
    // ========================================================================
    // Memory Map
    // ========================================================================
    // 0x00000000 - 0x00003FFF: Program ROM (16KB)
    // 0x00010000 - 0x00013FFF: Data RAM (16KB)
    // 0x10000000 - 0x100003FF: NTT Accelerator
    // 0x20000000 - 0x2000000F: UART
    
    // ========================================================================
    // PicoRV32 CPU
    // ========================================================================
    
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    
    picorv32 #(
        .ENABLE_COUNTERS(1),
        .ENABLE_COUNTERS64(1),
        .ENABLE_REGS_16_31(1),
        .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA(0),
        .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(1),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .COMPRESSED_ISA(0),
        .CATCH_MISALIGN(1),
        .CATCH_ILLINSN(1),
        .ENABLE_PCPI(0),
        .ENABLE_MUL(1),
        .ENABLE_FAST_MUL(1),
        .ENABLE_DIV(1),
        .ENABLE_IRQ(0),
        .ENABLE_IRQ_QREGS(0),
        .ENABLE_IRQ_TIMER(0),
        .ENABLE_TRACE(0),
        .REGS_INIT_ZERO(0),
        .MASKED_IRQ(32'h0000_0000),
        .LATCHED_IRQ(32'hffff_ffff),
        .PROGADDR_RESET(32'h0000_0000),
        .PROGADDR_IRQ(32'h0000_0010),
        .STACKADDR(32'h0001_3FFC)
    ) cpu (
        .clk(clk),
        .resetn(!rst),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .mem_la_read(),
        .mem_la_write(),
        .mem_la_addr(),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        .pcpi_valid(),
        .pcpi_insn(),
        .pcpi_rs1(),
        .pcpi_rs2(),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'b0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'b0),
        .eoi(),
        .trace_valid(),
        .trace_data()
    );
    
    // ========================================================================
    // Memory Subsystem
    // ========================================================================
    
    // ROM signals
    wire        rom_ready;
    wire [31:0] rom_rdata;
    wire        rom_select;
    
    // RAM signals
    wire        ram_ready;
    wire [31:0] ram_rdata;
    wire        ram_select;
    
    // NTT signals
    wire        ntt_ready;
    wire [31:0] ntt_rdata;
    wire        ntt_select;
    
    // UART signals
    wire        uart_ready;
    wire [31:0] uart_rdata;
    wire        uart_select;
    
    // Address decode
    assign rom_select  = mem_valid && (mem_addr[31:14] == 18'h0000);  // 0x00000000-0x00003FFF
    assign ram_select  = mem_valid && (mem_addr[31:14] == 18'h0004);  // 0x00010000-0x00013FFF
    assign ntt_select  = mem_valid && (mem_addr[31:12] == 20'h10000); // 0x10000000-0x10000FFF
    assign uart_select = mem_valid && (mem_addr[31:4] == 28'h2000000); // 0x20000000-0x2000000F
    
    // Merge responses
    assign mem_ready = rom_ready | ram_ready | ntt_ready | uart_ready;
    assign mem_rdata = ({32{rom_select}}  & rom_rdata)  |
                       ({32{ram_select}}  & ram_rdata)  |
                       ({32{ntt_select}}  & ntt_rdata)  |
                       ({32{uart_select}} & uart_rdata);
    
    // ========================================================================
    // Program ROM (16KB)
    // ========================================================================
    
    program_rom #(
        .ADDR_WIDTH(12),  // 4K words = 16KB
        .MEM_INIT_FILE("firmware.hex")
    ) rom (
        .clk(clk),
        .rst(rst),
        .mem_valid(rom_select),
        .mem_ready(rom_ready),
        .mem_addr(mem_addr[13:2]),  // Word address
        .mem_rdata(rom_rdata)
    );
    
    // ========================================================================
    // Data RAM (16KB)
    // ========================================================================
    
    data_ram #(
        .ADDR_WIDTH(12)  // 4K words = 16KB
    ) ram (
        .clk(clk),
        .rst(rst),
        .mem_valid(ram_select),
        .mem_ready(ram_ready),
        .mem_addr(mem_addr[13:2]),  // Word address
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(ram_rdata)
    );
    
    // ========================================================================
    // NTT Accelerator
    // ========================================================================
    
    ntt_wrapper #(
        .BASE_ADDR(32'h10000000),
        .Q(3329),
        .N(256),
        .W(16)
    ) ntt (
        .clk(clk),
        .rst(rst),
        .mem_valid(ntt_select),
        .mem_ready(ntt_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(ntt_rdata)
    );
    
    // ========================================================================
    // UART (Simple, for debugging)
    // ========================================================================
    
    simple_uart #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(115200)
    ) uart (
        .clk(clk),
        .rst(rst),
        .mem_valid(uart_select),
        .mem_ready(uart_ready),
        .mem_addr(mem_addr[3:2]),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(uart_rdata),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd)
    );
    
    // ========================================================================
    // LED Status Indicators
    // ========================================================================
    
    reg [25:0] led_counter;
    always @(posedge clk) begin
        if (rst)
            led_counter <= 0;
        else
            led_counter <= led_counter + 1;
    end
    
    assign led[0] = led_counter[25];       // Heartbeat
    assign led[1] = !rst;                   // System ready
    assign led[2] = ntt_select;             // NTT access
    assign led[3] = mem_valid && mem_ready; // Memory activity

endmodule