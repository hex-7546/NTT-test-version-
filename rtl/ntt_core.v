// ============================================================================
// File: rtl/ntt_core.v
// NTT Core for Kyber512
// Implements Number Theoretic Transform with n=256, q=3329
// Uses 2 parallel butterfly units for balanced performance
// ============================================================================

module ntt_core #(
    parameter Q = 3329,           // Modulus
    parameter N = 256,            // Polynomial degree
    parameter W = 16              // Coefficient width
)(
    input  wire             clk,
    input  wire             rst,
    
    // Control signals
    input  wire             start,
    input  wire             mode,      // 0: NTT, 1: INTT
    output reg              done,
    output reg              busy,
    
    // Memory interface for coefficients
    output reg  [7:0]       coeff_addr,
    output reg              coeff_we,
    output reg  [W-1:0]     coeff_wdata,
    input  wire [W-1:0]     coeff_rdata,
    
    // Status
    output reg              error
);

    // ========================================================================
    // Parameters and Constants
    // ========================================================================
    
    localparam STAGES = 7;        // log2(128) for Kyber's truncated NTT
    
    // FSM States
    localparam IDLE         = 3'd0;
    localparam LOAD         = 3'd1;
    localparam COMPUTE      = 3'd2;
    localparam WRITEBACK    = 3'd3;
    localparam DONE_STATE   = 3'd4;
    
    reg [2:0] state, next_state;
    
    // ========================================================================
    // Internal Registers
    // ========================================================================
    
    reg [W-1:0] poly_buf [0:N-1];   // Coefficient buffer
    
    reg [8:0] stage_counter;
    reg [8:0] index_counter;
    reg [8:0] load_counter;
    reg [8:0] wb_counter;
    reg [3:0] current_stage;
    
    // Butterfly unit signals
    reg [W-1:0] bf_in_a_0, bf_in_b_0;
    reg [W-1:0] bf_in_a_1, bf_in_b_1;
    reg [W-1:0] bf_twiddle_0, bf_twiddle_1;
    reg         bf_start;
    reg         bf_mode;
    
    wire [W-1:0] bf_out_a_0, bf_out_b_0;
    wire [W-1:0] bf_out_a_1, bf_out_b_1;
    wire         bf_done_0, bf_done_1;
    
    // Twiddle factor ROM address
    reg [6:0] twiddle_addr_0, twiddle_addr_1;
    wire [W-1:0] twiddle_0, twiddle_1;
    
    // ========================================================================
    // Twiddle Factor ROM
    // ========================================================================
    
    twiddle_rom twiddle_rom_inst (
        .clk(clk),
        .mode(mode),
        .addr_0(twiddle_addr_0),
        .addr_1(twiddle_addr_1),
        .twiddle_0(twiddle_0),
        .twiddle_1(twiddle_1)
    );
    
    // ========================================================================
    // Butterfly Units (2 parallel units)
    // ========================================================================
    
    butterfly_unit bf_unit_0 (
        .clk(clk),
        .rst(rst),
        .start(bf_start),
        .mode(bf_mode),
        .in_a(bf_in_a_0),
        .in_b(bf_in_b_0),
        .twiddle(bf_twiddle_0),
        .out_a(bf_out_a_0),
        .out_b(bf_out_b_0),
        .done(bf_done_0)
    );
    
    butterfly_unit bf_unit_1 (
        .clk(clk),
        .rst(rst),
        .start(bf_start),
        .mode(bf_mode),
        .in_a(bf_in_a_1),
        .in_b(bf_in_b_1),
        .twiddle(bf_twiddle_1),
        .out_a(bf_out_a_1),
        .out_b(bf_out_b_1),
        .done(bf_done_1)
    );
    
    // ========================================================================
    // FSM - State Register
    // ========================================================================
    
    always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // ========================================================================
    // FSM - Next State Logic
    // ========================================================================
    
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end
            
            LOAD: begin
                if (load_counter == N)
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (current_stage == STAGES)
                    next_state = WRITEBACK;
            end
            
            WRITEBACK: begin
                if (wb_counter == N)
                    next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ========================================================================
    // FSM - Output Logic and Datapath
    // ========================================================================
    
    integer i;
    reg [8:0] stride;
    reg [8:0] idx_a, idx_b;
    reg [8:0] group_size;
    reg [8:0] group_idx;
    reg [8:0] pair_idx;
    
    always @(posedge clk) begin
        if (rst) begin
            busy <= 0;
            done <= 0;
            error <= 0;
            coeff_addr <= 0;
            coeff_we <= 0;
            load_counter <= 0;
            wb_counter <= 0;
            stage_counter <= 0;
            index_counter <= 0;
            bf_start <= 0;
            current_stage <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    busy <= 0;
                    done <= 0;
                    error <= 0;
                    load_counter <= 0;
                    wb_counter <= 0;
                    stage_counter <= 0;
                    index_counter <= 0;
                    current_stage <= 0;
                    bf_start <= 0;
                    
                    if (start) begin
                        busy <= 1;
                        bf_mode <= mode;
                    end
                end
                
                LOAD: begin
                    // Load coefficients from memory
                    if (load_counter < N) begin
                        coeff_addr <= load_counter[7:0];
                        coeff_we <= 0;
                        
                        if (load_counter > 0)
                            poly_buf[load_counter-1] <= coeff_rdata;
                        
                        load_counter <= load_counter + 1;
                    end
                    else begin
                        poly_buf[N-1] <= coeff_rdata;
                    end
                end
                
                COMPUTE: begin
                    // Perform NTT computation using 2 butterfly units
                    if (!bf_start && !bf_done_0 && current_stage < STAGES) begin
                        // Calculate parameters for current stage
                        stride = 1 << current_stage;
                        group_size = N >> (current_stage + 1);
                        
                        // Process 2 butterfly operations in parallel
                        if (index_counter < (N >> 1)) begin
                            group_idx = index_counter / stride;
                            pair_idx = index_counter % stride;
                            
                            idx_a = group_idx * (stride << 1) + pair_idx;
                            idx_b = idx_a + stride;
                            
                            // Setup butterfly unit 0
                            bf_in_a_0 <= poly_buf[idx_a];
                            bf_in_b_0 <= poly_buf[idx_b];
                            twiddle_addr_0 <= group_idx[6:0];
                            bf_twiddle_0 <= twiddle_0;
                            
                            // Setup butterfly unit 1 (if valid)
                            if (index_counter + 1 < (N >> 1)) begin
                                group_idx = (index_counter + 1) / stride;
                                pair_idx = (index_counter + 1) % stride;
                                
                                idx_a = group_idx * (stride << 1) + pair_idx;
                                idx_b = idx_a + stride;
                                
                                bf_in_a_1 <= poly_buf[idx_a];
                                bf_in_b_1 <= poly_buf[idx_b];
                                twiddle_addr_1 <= group_idx[6:0];
                                bf_twiddle_1 <= twiddle_1;
                            end
                            
                            bf_start <= 1;
                        end
                    end
                    else if (bf_done_0 && bf_done_1) begin
                        // Store butterfly results
                        stride = 1 << current_stage;
                        
                        group_idx = index_counter / stride;
                        pair_idx = index_counter % stride;
                        idx_a = group_idx * (stride << 1) + pair_idx;
                        idx_b = idx_a + stride;
                        
                        poly_buf[idx_a] <= bf_out_a_0;
                        poly_buf[idx_b] <= bf_out_b_0;
                        
                        if (index_counter + 1 < (N >> 1)) begin
                            group_idx = (index_counter + 1) / stride;
                            pair_idx = (index_counter + 1) % stride;
                            idx_a = group_idx * (stride << 1) + pair_idx;
                            idx_b = idx_a + stride;
                            
                            poly_buf[idx_a] <= bf_out_a_1;
                            poly_buf[idx_b] <= bf_out_b_1;
                        end
                        
                        bf_start <= 0;
                        index_counter <= index_counter + 2;
                        
                        // Move to next stage if current is complete
                        if (index_counter + 2 >= (N >> 1)) begin
                            index_counter <= 0;
                            current_stage <= current_stage + 1;
                        end
                    end
                    else if (bf_done_0 && !bf_done_1) begin
                        // Only first butterfly completed (last odd iteration)
                        stride = 1 << current_stage;
                        group_idx = index_counter / stride;
                        pair_idx = index_counter % stride;
                        idx_a = group_idx * (stride << 1) + pair_idx;
                        idx_b = idx_a + stride;
                        
                        poly_buf[idx_a] <= bf_out_a_0;
                        poly_buf[idx_b] <= bf_out_b_0;
                        
                        bf_start <= 0;
                        index_counter <= 0;
                        current_stage <= current_stage + 1;
                    end
                end
                
                WRITEBACK: begin
                    // Write results back to memory
                    if (wb_counter < N) begin
                        coeff_we <= 1;
                        coeff_addr <= wb_counter[7:0];
                        coeff_wdata <= poly_buf[wb_counter];
                        wb_counter <= wb_counter + 1;
                    end
                end
                
                DONE_STATE: begin
                    busy <= 0;
                    done <= 1;
                    coeff_we <= 0;
                end
            endcase
        end
    end

endmodule

// ============================================================================
// Butterfly Unit - Cooley-Tukey (CT) for NTT / Gentleman-Sande (GS) for INTT
// ============================================================================

module butterfly_unit #(
    parameter Q = 3329,
    parameter W = 16
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             start,
    input  wire             mode,        // 0: CT (NTT), 1: GS (INTT)
    input  wire [W-1:0]     in_a,
    input  wire [W-1:0]     in_b,
    input  wire [W-1:0]     twiddle,
    output reg  [W-1:0]     out_a,
    output reg  [W-1:0]     out_b,
    output reg              done
);

    reg [1:0] state;
    reg [W-1:0] temp_a, temp_b;
    wire [W-1:0] mult_result;
    wire [W-1:0] add_result;
    wire [W-1:0] sub_result;
    
    // Modular multiplier
    modular_mult #(.Q(Q), .W(W)) mult_inst (
        .a(mode ? (temp_a - temp_b + Q) : temp_b),
        .b(twiddle),
        .result(mult_result)
    );
    
    // Modular adder
    modular_add #(.Q(Q), .W(W)) add_inst (
        .a(temp_a),
        .b(mode ? temp_b : mult_result),
        .result(add_result)
    );
    
    // Modular subtractor
    modular_sub #(.Q(Q), .W(W)) sub_inst (
        .a(temp_a),
        .b(mode ? temp_b : mult_result),
        .result(sub_result)
    );
    
    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            done <= 0;
            out_a <= 0;
            out_b <= 0;
        end
        else begin
            case (state)
                2'd0: begin // IDLE
                    done <= 0;
                    if (start) begin
                        temp_a <= in_a;
                        temp_b <= in_b;
                        state <= 2'd1;
                    end
                end
                
                2'd1: begin // COMPUTE
                    if (mode) begin 
                        // GS butterfly (INTT)
                        out_a <= add_result;
                        out_b <= mult_result;
                    end
                    else begin 
                        // CT butterfly (NTT)
                        out_a <= add_result;
                        out_b <= sub_result;
                    end
                    state <= 2'd2;
                end
                
                2'd2: begin // DONE
                    done <= 1;
                    if (!start)
                        state <= 2'd0;
                end
                
                default: state <= 2'd0;
            endcase
        end
    end

endmodule

// ============================================================================
// Modular Arithmetic Units
// ============================================================================

module modular_mult #(
    parameter Q = 3329,
    parameter W = 16
)(
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire [W-1:0] result
);
    wire [2*W-1:0] prod;
    wire [2*W-1:0] reduced;
    
    assign prod = a * b;
    
    // Barrett reduction for q = 3329
    // k = 25, r = 2^k / q ≈ 10079
    wire [2*W-1:0] temp;
    assign temp = (prod * 10079) >> 25;
    assign reduced = prod - (temp * Q);
    
    assign result = (reduced >= Q) ? (reduced - Q) : reduced[W-1:0];
endmodule

module modular_add #(
    parameter Q = 3329,
    parameter W = 16
)(
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire [W-1:0] result
);
    wire [W:0] sum;
    assign sum = a + b;
    assign result = (sum >= Q) ? (sum - Q) : sum[W-1:0];
endmodule

module modular_sub #(
    parameter Q = 3329,
    parameter W = 16
)(
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire [W-1:0] result
);
    wire signed [W:0] diff;
    assign diff = a - b;
    assign result = (diff < 0) ? (diff + Q) : diff[W-1:0];
endmodule