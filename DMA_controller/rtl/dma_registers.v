// =============================================================================
// File: dma_registers.v
// Description: Configuration and status register bank for a DMA channel.
//              Supports 32-bit word registers with bitfield decoding for control,
//              status (with W1C), source/destination addresses, transfer length,
//              and configurable data bit-width.
// =============================================================================

`timescale 1ns / 1ps

module dma_registers (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Bus Slave Interface
    input  wire        reg_write,
    input  wire        reg_read,
    input  wire [7:0]  reg_addr,
    input  wire [31:0] reg_wdata,
    output reg  [31:0] reg_rdata,

    // Decoded Configuration Outputs to FSM & Datapath
    output reg  [31:0] src_addr,
    output reg  [31:0] dst_addr,
    output reg  [31:0] transfer_len,
    output reg  [5:0]  data_width,     // 1 to 32 bits
    output reg         start,          // 1-cycle pulse to start DMA
    output reg         enable,         // Channel enable
    output reg         direction,      // 0: P2M (Periph->Mem), 1: M2P (Mem->Periph)
    output reg         src_inc,        // 1: Increment source address, 0: Fixed
    output reg         dst_inc,        // 1: Increment dest address, 0: Fixed
    output reg         irq_en,         // 1: Enable completion interrupt
    output reg         abort,          // 1-cycle pulse to abort transfer

    // Status Inputs from FSM
    input  wire        fsm_busy,
    input  wire        fsm_done,
    input  wire        fsm_error
);

    // Register Address Map
    localparam ADDR_CONTROL      = 8'h00;
    localparam ADDR_STATUS       = 8'h04;
    localparam ADDR_SRC_ADDR     = 8'h08;
    localparam ADDR_DST_ADDR     = 8'h0C;
    localparam ADDR_TRANSFER_LEN = 8'h10;
    localparam ADDR_DATA_WIDTH   = 8'h14;

    // Internal Status Flags (latched until cleared)
    reg status_done_reg;
    reg status_error_reg;

    // -------------------------------------------------------------------------
    // Synchronous Register Write Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr         <= 32'd0;
            dst_addr         <= 32'd0;
            transfer_len     <= 32'd0;
            data_width       <= 6'd32; // Default to 32-bit words
            start            <= 1'b0;
            enable           <= 1'b0;
            direction        <= 1'b0;
            src_inc          <= 1'b0;
            dst_inc          <= 1'b1; // Default to incrementing destination
            irq_en           <= 1'b0;
            abort            <= 1'b0;
            status_done_reg  <= 1'b0;
            status_error_reg <= 1'b0;
        end else begin
            // Single-cycle pulses
            start <= 1'b0;
            abort <= 1'b0;

            // Latch completion from FSM
            if (fsm_done) begin
                status_done_reg <= 1'b1;
            end

            // Latch error from FSM
            if (fsm_error) begin
                status_error_reg <= 1'b1;
            end

            // CPU Register Writes
            if (reg_write) begin
                case (reg_addr)
                    ADDR_CONTROL: begin
                        // Bit 0: START (pulse)
                        if (reg_wdata[0]) begin
                            start           <= 1'b1;
                            status_done_reg <= 1'b0; // Auto-clear done on new start
                        end
                        enable    <= reg_wdata[1];
                        direction <= reg_wdata[2];
                        src_inc   <= reg_wdata[3];
                        dst_inc   <= reg_wdata[4];
                        irq_en    <= reg_wdata[5];
                        // Bit 6: ABORT (pulse)
                        if (reg_wdata[6]) begin
                            abort <= 1'b1;
                        end
                    end

                    ADDR_STATUS: begin
                        // Write-1-to-Clear (W1C)
                        if (reg_wdata[1]) status_done_reg  <= 1'b0;
                        if (reg_wdata[2]) status_error_reg <= 1'b0;
                    end

                    ADDR_SRC_ADDR: begin
                        src_addr <= reg_wdata;
                    end

                    ADDR_DST_ADDR: begin
                        dst_addr <= reg_wdata;
                    end

                    ADDR_TRANSFER_LEN: begin
                        transfer_len <= reg_wdata;
                    end

                    ADDR_DATA_WIDTH: begin
                        // Clamp between 1 and 32 bits
                        if (reg_wdata[5:0] >= 6'd1 && reg_wdata[5:0] <= 6'd32) begin
                            data_width <= reg_wdata[5:0];
                        end else if (reg_wdata[5:0] == 6'd0) begin
                            data_width <= 6'd32;
                        end
                    end

                    default: begin
                        // Unmapped addresses ignored
                    end
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // Combinational Register Read Logic
    // -------------------------------------------------------------------------
    always @(*) begin
        reg_rdata = 32'd0;
        if (reg_read) begin
            case (reg_addr)
                ADDR_CONTROL: begin
                    reg_rdata[0] = 1'b0; // START is write-only pulse
                    reg_rdata[1] = enable;
                    reg_rdata[2] = direction;
                    reg_rdata[3] = src_inc;
                    reg_rdata[4] = dst_inc;
                    reg_rdata[5] = irq_en;
                    reg_rdata[6] = 1'b0; // ABORT is write-only pulse
                    reg_rdata[31:7] = 25'd0;
                end

                ADDR_STATUS: begin
                    reg_rdata[0] = fsm_busy;
                    reg_rdata[1] = status_done_reg | fsm_done;
                    reg_rdata[2] = status_error_reg | fsm_error;
                    reg_rdata[31:3] = 29'd0;
                end

                ADDR_SRC_ADDR: begin
                    reg_rdata = src_addr;
                end

                ADDR_DST_ADDR: begin
                    reg_rdata = dst_addr;
                end

                ADDR_TRANSFER_LEN: begin
                    reg_rdata = transfer_len;
                end

                ADDR_DATA_WIDTH: begin
                    reg_rdata = {26'd0, data_width};
                end

                default: begin
                    reg_rdata = 32'd0;
                end
            endcase
        end
    end

endmodule