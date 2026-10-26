// =============================================================================
// File: tb_dma_memory.v
// Description: Behavioral SRAM memory model for DMA verification.
//              Supports:
//              - 64KB storage (16384 x 32-bit words)
//              - Byte enables (mem_be[3:0]) for byte, halfword, and word writes
//              - Synchronous read and write with mem_ready handshake
//              - Helper tasks for testbench inspection and preloading
// =============================================================================

`timescale 1ns / 1ps

module tb_dma_memory (
    input  wire        clk,
    input  wire        rst_n,

    // Memory Master Bus Interface
    input  wire        mem_req,
    input  wire        mem_we,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_be,
    output reg  [31:0] mem_rdata,
    output reg         mem_ready
);

    // 16K x 32-bit memory (64 KB)
    localparam MEM_DEPTH = 16384;
    reg [31:0] mem_array [0:MEM_DEPTH-1];

    wire [13:0] word_idx;
    assign word_idx = mem_addr[15:2];

    integer i;

    // -------------------------------------------------------------------------
    // Synchronous Memory Access Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_rdata <= 32'd0;
            mem_ready <= 1'b0;
        end else begin
            // Ready response: responds on request
            mem_ready <= mem_req;

            if (mem_req) begin
                if (mem_we) begin
                    // Byte-enabled write
                    if (mem_be[0]) mem_array[word_idx][7:0]   <= mem_wdata[7:0];
                    if (mem_be[1]) mem_array[word_idx][15:8]  <= mem_wdata[15:8];
                    if (mem_be[2]) mem_array[word_idx][23:16] <= mem_wdata[23:16];
                    if (mem_be[3]) mem_array[word_idx][31:24] <= mem_wdata[31:24];
                end else begin
                    // Read operation
                    mem_rdata <= mem_array[word_idx];
                end
            end else begin
                mem_rdata <= 32'd0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Helper Tasks for Testbench
    // -------------------------------------------------------------------------
    task clear_all;
        integer j;
        begin
            for (j = 0; j < MEM_DEPTH; j = j + 1) begin
                mem_array[j] = 32'd0;
            end
        end
    endtask

    task preload_word;
        input [31:0] byte_addr;
        input [31:0] data;
        begin
            mem_array[byte_addr[15:2]] = data;
        end
    endtask

    task preload_byte;
        input [31:0] byte_addr;
        input [7:0]  bdata;
        reg [13:0] w_idx;
        begin
            w_idx = byte_addr[15:2];
            case (byte_addr[1:0])
                2'b00: mem_array[w_idx][7:0]   = bdata;
                2'b01: mem_array[w_idx][15:8]  = bdata;
                2'b10: mem_array[w_idx][23:16] = bdata;
                2'b11: mem_array[w_idx][31:24] = bdata;
            endcase
        end
    endtask

    function [31:0] get_word;
        input [31:0] byte_addr;
        begin
            get_word = mem_array[byte_addr[15:2]];
        end
    endfunction

    function [7:0] get_byte;
        input [31:0] byte_addr;
        reg [31:0] w;
        begin
            w = mem_array[byte_addr[15:2]];
            case (byte_addr[1:0])
                2'b00: get_byte = w[7:0];
                2'b01: get_byte = w[15:8];
                2'b10: get_byte = w[23:16];
                2'b11: get_byte = w[31:24];
            endcase
        end
    endfunction

endmodule
