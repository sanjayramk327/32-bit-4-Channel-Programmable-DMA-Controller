// =============================================================================
// File: dma_fsm.v
// Description: Finite State Machine for a single DMA channel.
//              Manages transaction flow for both Peripheral-to-Memory (P2M)
//              and Memory-to-Peripheral (M2P) transfers using standard
//              ready/valid handshakes for peripheral and memory interfaces.
// =============================================================================

`timescale 1ns / 1ps

module dma_fsm (
    input  wire        clk,
    input  wire        rst_n,

    // Control Inputs from Registers
    input  wire        start,
    input  wire        enable,
    input  wire        direction,      // 0: P2M, 1: M2P
    input  wire        irq_en,
    input  wire        abort,

    // Status from Datapath
    input  wire        count_zero,     // Asserted when last item is reached

    // Peripheral Handshake
    input  wire        periph_rx_valid,
    output reg         periph_rx_ready,
    output reg         periph_tx_valid,
    input  wire        periph_tx_ready,

    // Memory Master Handshake
    output reg         mem_req,
    output reg         mem_we,
    input  wire        mem_ready,

    // Datapath Control Outputs
    output reg         load_config,
    output reg         update_step,
    output reg         latch_periph_rx,
    output reg         latch_mem_rdata,

    // Status Outputs to Registers
    output reg         fsm_busy,
    output reg         fsm_done,
    output reg         fsm_error,
    output reg         irq
);

    // State Encoding
    localparam S_IDLE        = 4'd0;
    localparam S_LOAD        = 4'd1;
    localparam S_P2M_WAIT_RX = 4'd2;
    localparam S_P2M_MEM_WR  = 4'd3;
    localparam S_P2M_UPDATE  = 4'd4;
    localparam S_M2P_MEM_RD  = 4'd5;
    localparam S_M2P_WAIT_TX = 4'd6;
    localparam S_M2P_UPDATE  = 4'd7;
    localparam S_DONE        = 4'd8;

    reg [3:0] current_state;
    reg [3:0] next_state;

    // -------------------------------------------------------------------------
    // Sequential State Register
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else if (abort && (current_state != S_IDLE)) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // -------------------------------------------------------------------------
    // Next State Logic
    // -------------------------------------------------------------------------
    always @(*) begin
        next_state = current_state;

        case (current_state)
            S_IDLE: begin
                if (start && enable) begin
                    next_state = S_LOAD;
                end
            end

            S_LOAD: begin
                if (!direction) begin
                    next_state = S_P2M_WAIT_RX;
                end else begin
                    next_state = S_M2P_MEM_RD;
                end
            end

            // --- Peripheral to Memory (P2M) Flow ---
            S_P2M_WAIT_RX: begin
                if (periph_rx_valid) begin
                    next_state = S_P2M_MEM_WR;
                end
            end

            S_P2M_MEM_WR: begin
                if (mem_ready) begin
                    next_state = S_P2M_UPDATE;
                end
            end

            S_P2M_UPDATE: begin
                if (count_zero) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_P2M_WAIT_RX;
                end
            end

            // --- Memory to Peripheral (M2P) Flow ---
            S_M2P_MEM_RD: begin
                if (mem_ready) begin
                    next_state = S_M2P_WAIT_TX;
                end
            end

            S_M2P_WAIT_TX: begin
                if (periph_tx_ready) begin
                    next_state = S_M2P_UPDATE;
                end
            end

            S_M2P_UPDATE: begin
                if (count_zero) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_M2P_MEM_RD;
                end
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Output Logic (Registered & Mealy/Moore Control Signals)
    // -------------------------------------------------------------------------
    always @(*) begin
        // Defaults
        periph_rx_ready = 1'b0;
        periph_tx_valid = 1'b0;
        mem_req         = 1'b0;
        mem_we          = 1'b0;
        load_config     = 1'b0;
        update_step     = 1'b0;
        latch_periph_rx = 1'b0;
        latch_mem_rdata = 1'b0;
        fsm_busy        = 1'b1;
        fsm_done        = 1'b0;
        fsm_error       = 1'b0;
        irq             = 1'b0;

        case (current_state)
            S_IDLE: begin
                fsm_busy = 1'b0;
            end

            S_LOAD: begin
                load_config = 1'b1;
            end

            S_P2M_WAIT_RX: begin
                periph_rx_ready = 1'b1;
                if (periph_rx_valid) begin
                    latch_periph_rx = 1'b1;
                end
            end

            S_P2M_MEM_WR: begin
                mem_req = 1'b1;
                mem_we  = 1'b1;
            end

            S_P2M_UPDATE: begin
                update_step = 1'b1;
            end

            S_M2P_MEM_RD: begin
                mem_req = 1'b1;
                mem_we  = 1'b0;
                if (mem_ready) begin
                    latch_mem_rdata = 1'b1;
                end
            end

            S_M2P_WAIT_TX: begin
                periph_tx_valid = 1'b1;
            end

            S_M2P_UPDATE: begin
                update_step = 1'b1;
            end

            S_DONE: begin
                fsm_busy = 1'b0;
                fsm_done = 1'b1;
                if (irq_en) begin
                    irq = 1'b1;
                end
            end

            default: begin
                fsm_busy = 1'b0;
            end
        endcase

        // Abort status
        if (abort && (current_state != S_IDLE)) begin
            fsm_error = 1'b1;
        end
    end

endmodule
