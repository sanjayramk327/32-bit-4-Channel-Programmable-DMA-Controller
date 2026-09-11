// =============================================================================
// File: dma_datapath.v
// Description: Datapath for DMA channel.
//              Handles:
//              - Shadow registers for source and destination address generation
//              - Programmable address step (+1 byte, +2 halfword, +4 word)
//              - Transfer countdown counter with end-of-transfer detection
//              - 32-bit internal data staging register
//              - Arbitrary bit-width masking (1 to 32 bits)
//              - Memory byte-enable (mem_be) steering for sub-word writes
//              - Sub-word byte/halfword extraction for memory reads
// =============================================================================

`timescale 1ns / 1ps

module dma_datapath (
    input  wire        clk,
    input  wire        rst_n,

    // Configuration Inputs from Registers
    input  wire [31:0] src_addr,
    input  wire [31:0] dst_addr,
    input  wire [31:0] transfer_len,
    input  wire [5:0]  data_width,     // 1 to 32 bits
    input  wire        direction,      // 0: P2M, 1: M2P
    input  wire        src_inc,
    input  wire        dst_inc,

    // Control Inputs from FSM
    input  wire        load_config,
    input  wire        update_step,
    input  wire        latch_periph_rx,
    input  wire        latch_mem_rdata,

    // Status Output to FSM
    output wire        count_zero,

    // External Peripheral Data
    input  wire [31:0] periph_rx_data,
    output wire [31:0] periph_tx_data,

    // External Memory Data & Addressing
    output wire [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output reg  [3:0]  mem_be,
    input  wire [31:0] mem_rdata
);

    // Internal Shadow Registers
    reg [31:0] curr_src_addr;
    reg [31:0] curr_dst_addr;
    reg [31:0] rem_count;
    reg [31:0] data_buf;

    // -------------------------------------------------------------------------
    // Address Step Calculation based on DATA_WIDTH
    // -------------------------------------------------------------------------
    wire [31:0] addr_step;
    assign addr_step = (data_width <= 6'd8)  ? 32'd1 :
                       (data_width <= 6'd16) ? 32'd2 : 32'd4;

    // -------------------------------------------------------------------------
    // Bitmask Generation for Data Width (1 to 32 bits)
    // -------------------------------------------------------------------------
    wire [31:0] data_mask;
    assign data_mask = (data_width >= 6'd32) ? 32'hFFFFFFFF :
                       ((32'd1 << data_width) - 32'd1);

    // -------------------------------------------------------------------------
    // End-of-Transfer Detection
    // -------------------------------------------------------------------------
    // When remaining count is 1 or less, the current active beat completes the block.
    assign count_zero = (rem_count <= 32'd1);

    // Active memory address depends on direction (P2M writes to DST, M2P reads from SRC)
    assign mem_addr = (!direction) ? curr_dst_addr : curr_src_addr;

    // Peripheral transmit data output
    assign periph_tx_data = data_buf & data_mask;

    // -------------------------------------------------------------------------
    // Sub-Word Read Data Extraction Logic (M2P)
    // -------------------------------------------------------------------------
    reg [31:0] extracted_rdata;
    always @(*) begin
        if (data_width <= 6'd8) begin
            case (curr_src_addr[1:0])
                2'b00: extracted_rdata = {24'd0, mem_rdata[7:0]};
                2'b01: extracted_rdata = {24'd0, mem_rdata[15:8]};
                2'b10: extracted_rdata = {24'd0, mem_rdata[23:16]};
                2'b11: extracted_rdata = {24'd0, mem_rdata[31:24]};
            endcase
        end else if (data_width <= 6'd16) begin
            case (curr_src_addr[1])
                1'b0: extracted_rdata = {16'd0, mem_rdata[15:0]};
                1'b1: extracted_rdata = {16'd0, mem_rdata[31:16]};
            endcase
        end else begin
            extracted_rdata = mem_rdata;
        end
    end

    // -------------------------------------------------------------------------
    // Byte Enable and Memory Write Data Steering Logic (P2M)
    // -------------------------------------------------------------------------
    wire [31:0] masked_buf;
    assign masked_buf = data_buf & data_mask;

    always @(*) begin
        mem_be    = 4'b1111;
        mem_wdata = masked_buf;

        if (data_width <= 6'd8) begin
            case (curr_dst_addr[1:0])
                2'b00: begin
                    mem_be    = 4'b0001;
                    mem_wdata = {24'd0, masked_buf[7:0]};
                end
                2'b01: begin
                    mem_be    = 4'b0010;
                    mem_wdata = {16'd0, masked_buf[7:0], 8'd0};
                end
                2'b10: begin
                    mem_be    = 4'b0100;
                    mem_wdata = {8'd0, masked_buf[7:0], 16'd0};
                end
                2'b11: begin
                    mem_be    = 4'b1000;
                    mem_wdata = {masked_buf[7:0], 24'd0};
                end
            endcase
        end else if (data_width <= 6'd16) begin
            case (curr_dst_addr[1])
                1'b0: begin
                    mem_be    = 4'b0011;
                    mem_wdata = {16'd0, masked_buf[15:0]};
                end
                1'b1: begin
                    mem_be    = 4'b1100;
                    mem_wdata = {masked_buf[15:0], 16'd0};
                end
            endcase
        end else begin
            mem_be    = 4'b1111;
            mem_wdata = masked_buf;
        end
    end

    // -------------------------------------------------------------------------
    // Sequential Datapath Registers (Addresses, Counter, Data Buffer)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_src_addr <= 32'd0;
            curr_dst_addr <= 32'd0;
            rem_count     <= 32'd0;
            data_buf      <= 32'd0;
        end else begin
            // 1. Configuration Loading on transfer start
            if (load_config) begin
                curr_src_addr <= src_addr;
                curr_dst_addr <= dst_addr;
                rem_count     <= transfer_len;
            end

            // 2. Data Buffer Latching
            if (latch_periph_rx) begin
                data_buf <= periph_rx_data;
            end else if (latch_mem_rdata) begin
                data_buf <= extracted_rdata;
            end

            // 3. Address and Counter Updates per beat
            if (update_step) begin
                // Decrement transfer counter
                if (rem_count > 32'd0) begin
                    rem_count <= rem_count - 32'd1;
                end

                // Increment source address if enabled
                if (src_inc) begin
                    curr_src_addr <= curr_src_addr + addr_step;
                end

                // Increment destination address if enabled
                if (dst_inc) begin
                    curr_dst_addr <= curr_dst_addr + addr_step;
                end
            end
        end
    end

endmodule
