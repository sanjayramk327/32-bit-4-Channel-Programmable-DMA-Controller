// =============================================================================
// File: dma_top.v
// Description: Top-level module for the DMA system.
// =============================================================================

`timescale 1ns / 1ps

module dma_top (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Slave Interface
    input  wire        reg_write,
    input  wire        reg_read,
    input  wire [7:0]  reg_addr,
    input  wire [31:0] reg_wdata,
    output wire [31:0] reg_rdata,

    // Peripheral Interface
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

    dma_controller u_dma_controller (
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
