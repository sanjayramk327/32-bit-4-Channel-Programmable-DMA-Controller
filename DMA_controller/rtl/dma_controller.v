// =============================================================================
// File: dma_controller.v
// Description: DMA Controller top wrapper.
//              In Stage 1, wraps a single DMA channel.
//              Prepared for Stage 4 expansion to 4 channels with arbiter.
// =============================================================================

`timescale 1ns / 1ps

module dma_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Bus Slave Interface
    input  wire        reg_write,
    input  wire        reg_read,
    input  wire [7:0]  reg_addr,
    input  wire [31:0] reg_wdata,
    output wire [31:0] reg_rdata,

    // Peripheral Interface (Channel 0)
    input  wire        periph_rx_valid,
    output wire        periph_rx_ready,
    input  wire [31:0] periph_rx_data,
    output wire        periph_tx_valid,
    input  wire        periph_tx_ready,
    output wire [31:0] periph_tx_data,

    // Memory Master Interface
    output wire        mem_req,
    output wire        mem_we,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_be,
    input  wire [31:0] mem_rdata,
    input  wire        mem_ready,

    // Interrupt
    output wire        irq
);

    // Channel 0 Instance
    dma_channel u_channel_0 (
        .clk             (clk),
        .rst_n           (rst_n),

        .reg_write       (reg_write),
        .reg_read        (reg_read),
        .reg_addr        (reg_addr),
        .reg_wdata       (reg_wdata),
        .reg_rdata       (reg_rdata),

        .periph_rx_valid (periph_rx_valid),
        .periph_rx_ready (periph_rx_ready),
        .periph_rx_data  (periph_rx_data),
        .periph_tx_valid (periph_tx_valid),
        .periph_tx_ready (periph_tx_ready),
        .periph_tx_data  (periph_tx_data),

        .mem_req         (mem_req),
        .mem_we          (mem_we),
        .mem_addr        (mem_addr),
        .mem_wdata       (mem_wdata),
        .mem_be          (mem_be),
        .mem_rdata       (mem_rdata),
        .mem_ready       (mem_ready),

        .irq             (irq)
    );

endmodule
