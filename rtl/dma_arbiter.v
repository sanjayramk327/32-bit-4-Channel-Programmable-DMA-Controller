// =============================================================================
// File: dma_arbiter.v
// Description: 8-Channel Round-Robin Arbiter with Beat-Level Bus Ownership.
//              Guarantees fair memory bus access across all 8 channels with
//              zero channel starvation. Locks active channel during multi-cycle
//              memory handshakes and rotates the priority token on completion.
// =============================================================================

`timescale 1ns / 1ps

module dma_arbiter (
    input  wire        clk,
    input  wire        rst_n,

    // Channel Requests (1 bit per channel)
    input  wire [7:0]  request,

    // Handshake Acknowledge from Memory for currently granted channel
    input  wire        ack_step,

    // Grant Outputs
    output reg  [7:0]  grant,
    output reg         grant_valid,
    output reg  [2:0]  grant_idx
);

    reg       busy_beat;
    reg [2:0] held_idx;
    reg [2:0] token;

    // -------------------------------------------------------------------------
    // Circular Priority Search Function
    // -------------------------------------------------------------------------
    function [3:0] find_grant;
        input [2:0] start_ptr;
        input [7:0] reqs;
        reg   [3:0] result;
        integer j;
        reg   [2:0] probe_idx;
        begin
            result = 4'b0000;
            for (j = 0; j < 8; j = j + 1) begin
                probe_idx = start_ptr + j[2:0];
                if (reqs[probe_idx] && !result[3]) begin
                    result = {1'b1, probe_idx}; // [3] is valid flag, [2:0] is channel index
                end
            end
            find_grant = result;
        end
    endfunction

    wire [3:0] unheld_grant;
    assign unheld_grant = find_grant(token, request);

    // -------------------------------------------------------------------------
    // Combinational Grant Selection
    // -------------------------------------------------------------------------
    always @(*) begin
        if (busy_beat) begin
            grant_idx   = held_idx;
            grant_valid = 1'b1;
            grant       = (8'b0000_0001 << held_idx);
        end else if (unheld_grant[3]) begin
            grant_idx   = unheld_grant[2:0];
            grant_valid = 1'b1;
            grant       = (8'b0000_0001 << unheld_grant[2:0]);
        end else begin
            grant_idx   = 3'd0;
            grant_valid = 1'b0;
            grant       = 8'd0;
        end
    end

    // -------------------------------------------------------------------------
    // Sequential State: Token Rotation & Beat Lock
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            token     <= 3'd0;
            busy_beat <= 1'b0;
            held_idx  <= 3'd0;
        end else begin
            if (busy_beat) begin
                if (ack_step) begin
                    // Transfer beat acknowledged by memory
                    busy_beat <= 1'b0;
                    token     <= held_idx + 3'd1; // Rotate token to next channel
                end
            end else begin
                if (unheld_grant[3]) begin
                    // Lock active channel until its memory beat handshakes
                    busy_beat <= 1'b1;
                    held_idx  <= unheld_grant[2:0];
                end
            end
        end
    end

endmodule
