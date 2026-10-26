// =============================================================================
// File: dma_controller.v
// Description: 8-Channel Programmable DMA Controller.
//              - Instantiates 8 independent, fully-featured DMA channels
//              - Decodes CPU address [7:5] to select target channel (0x20 stride)
//              - Instantiates dma_arbiter for fair Round-Robin bus scheduling
//              - Multiplexes memory master interface across the 8 channels
//              - Gates memory ready signals strictly to the requesting channel
//              - Provides per-channel and global completion interrupt lines
// =============================================================================

`timescale 1ns / 1ps

module dma_controller (
    input  wire         clk,
    input  wire         rst_n,

    // CPU Bus Slave Interface
    input  wire         reg_write,
    input  wire         reg_read,
    input  wire [7:0]   reg_addr,
    input  wire [31:0]  reg_wdata,
    output wire [31:0]  reg_rdata,

    // Peripheral Interface (8 Channels)
    input  wire [7:0]   periph_rx_valid,
    output wire [7:0]   periph_rx_ready,
    input  wire [255:0] periph_rx_data,
    output wire [7:0]   periph_tx_valid,
    input  wire [7:0]   periph_tx_ready,
    output wire [255:0] periph_tx_data,

    // Shared Memory Master Interface
    output wire         mem_req,
    output wire         mem_we,
    output wire [31:0]  mem_addr,
    output wire [31:0]  mem_wdata,
    output wire [3:0]   mem_be,
    input  wire [31:0]  mem_rdata,
    input  wire         mem_ready,

    // Interrupt Outputs
    output wire [7:0]   irq_channels,
    output wire         irq
);

    // -------------------------------------------------------------------------
    // Channel Register Address Decoding
    // -------------------------------------------------------------------------
    wire [2:0] ch_sel;
    wire [4:0] ch_reg_offset;
    assign ch_sel        = reg_addr[7:5];
    assign ch_reg_offset = reg_addr[4:0];

    wire [7:0]   ch_reg_write;
    wire [7:0]   ch_reg_read;
    wire [255:0] ch_reg_rdata_bus;

    genvar c;
    generate
        for (c = 0; c < 8; c = c + 1) begin : gen_reg_gates
            assign ch_reg_write[c] = reg_write && (ch_sel == c[2:0]);
            assign ch_reg_read[c]  = reg_read  && (ch_sel == c[2:0]);
        end
    endgenerate

    // CPU Read Data Bus Slicing (Warning-Free)
    assign reg_rdata = ch_reg_rdata_bus[ch_sel*32 +: 32];

    // -------------------------------------------------------------------------
    // Channel Memory Master Interconnect Signals (Flattened Buses)
    // -------------------------------------------------------------------------
    wire [7:0]   ch_mem_req;
    wire [7:0]   ch_mem_we;
    wire [255:0] ch_mem_addr_bus;
    wire [255:0] ch_mem_wdata_bus;
    wire [31:0]  ch_mem_be_bus;
    wire [7:0]   ch_mem_ready;

    // -------------------------------------------------------------------------
    // Instantiate 8 Independent DMA Channels
    // -------------------------------------------------------------------------
    generate
        for (c = 0; c < 8; c = c + 1) begin : gen_channels
            dma_channel u_channel (
                .clk             (clk),
                .rst_n           (rst_n),

                // Register Slave
                .reg_write       (ch_reg_write[c]),
                .reg_read        (ch_reg_read[c]),
                .reg_addr        ({3'b000, ch_reg_offset}),
                .reg_wdata       (reg_wdata),
                .reg_rdata       (ch_reg_rdata_bus[c*32 +: 32]),

                // Peripheral
                .periph_rx_valid (periph_rx_valid[c]),
                .periph_rx_ready (periph_rx_ready[c]),
                .periph_rx_data  (periph_rx_data[c*32 +: 32]),
                .periph_tx_valid (periph_tx_valid[c]),
                .periph_tx_ready (periph_tx_ready[c]),
                .periph_tx_data  (periph_tx_data[c*32 +: 32]),

                // Memory Master (to Arbiter & Mux)
                .mem_req         (ch_mem_req[c]),
                .mem_we          (ch_mem_we[c]),
                .mem_addr        (ch_mem_addr_bus[c*32 +: 32]),
                .mem_wdata       (ch_mem_wdata_bus[c*32 +: 32]),
                .mem_be          (ch_mem_be_bus[c*4 +: 4]),
                .mem_rdata       (mem_rdata),
                .mem_ready       (ch_mem_ready[c]),

                // Interrupt
                .irq             (irq_channels[c])
            );
        end
    endgenerate

    // Global Interrupt: active when any channel fires IRQ
    assign irq = |irq_channels;

    // -------------------------------------------------------------------------
    // Round-Robin Memory Bus Arbiter
    // -------------------------------------------------------------------------
    wire [7:0] ch_grant;
    wire       grant_valid;
    wire [2:0] grant_idx;
    wire       ack_step;

    // Memory request tracking pipeline to route mem_ready strictly to the requester
    reg [2:0] mem_req_channel;
    reg       mem_req_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_req_channel <= 3'd0;
            mem_req_active  <= 1'b0;
        end else begin
            mem_req_channel <= grant_idx;
            mem_req_active  <= mem_req;
        end
    end

    // The beat acknowledges when memory responds to the specific channel's active request
    assign ack_step = mem_ready && mem_req_active && (mem_req_channel == grant_idx);

    dma_arbiter u_arbiter (
        .clk         (clk),
        .rst_n       (rst_n),
        .request     (ch_mem_req),
        .ack_step    (ack_step),
        .grant       (ch_grant),
        .grant_valid (grant_valid),
        .grant_idx   (grant_idx)
    );

    // -------------------------------------------------------------------------
    // Memory Master Multiplexing (Vector Indexed Slicing, Zero Warnings)
    // -------------------------------------------------------------------------
    assign mem_req   = grant_valid;
    assign mem_addr  = ch_mem_addr_bus[grant_idx*32 +: 32];
    assign mem_wdata = ch_mem_wdata_bus[grant_idx*32 +: 32];
    assign mem_we    = ch_mem_we[grant_idx];
    assign mem_be    = ch_mem_be_bus[grant_idx*4 +: 4];

    // Gated Memory Ready to Active Channel
    // mem_ready is only passed to the channel that actually initiated the active request
    generate
        for (c = 0; c < 8; c = c + 1) begin : gen_ready_gates
            assign ch_mem_ready[c] = mem_ready && mem_req_active && (mem_req_channel == c[2:0]);
        end
    endgenerate

endmodule
