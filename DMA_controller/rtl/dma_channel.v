// =============================================================================
// File: dma_channel.v
// Description: Top-level module for a single DMA channel.
//              Integrates:
//              - dma_registers: Register file for CPU programming
//              - dma_fsm: Main control state machine
//              - dma_datapath: Address generation, countdown, and data buffering
// =============================================================================

`timescale 1ns / 1ps

module dma_channel (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Bus Slave Interface
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

    // -------------------------------------------------------------------------
    // Internal Interconnect Wires
    // -------------------------------------------------------------------------
    // Configuration from registers
    wire [31:0] src_addr;
    wire [31:0] dst_addr;
    wire [31:0] transfer_len;
    wire [5:0]  data_width;
    wire        start;
    wire        enable;
    wire        direction;
    wire        src_inc;
    wire        dst_inc;
    wire        irq_en;
    wire        abort;

    // FSM status to registers
    wire        fsm_busy;
    wire        fsm_done;
    wire        fsm_error;

    // FSM control to datapath
    wire        load_config;
    wire        update_step;
    wire        latch_periph_rx;
    wire        latch_mem_rdata;

    // Datapath status to FSM
    wire        count_zero;

    // -------------------------------------------------------------------------
    // Submodule Instantiations
    // -------------------------------------------------------------------------

    // 1. Register File
    dma_registers u_dma_registers (
        .clk             (clk),
        .rst_n           (rst_n),

        .reg_write       (reg_write),
        .reg_read        (reg_read),
        .reg_addr        (reg_addr),
        .reg_wdata       (reg_wdata),
        .reg_rdata       (reg_rdata),

        .src_addr        (src_addr),
        .dst_addr        (dst_addr),
        .transfer_len    (transfer_len),
        .data_width      (data_width),
        .start           (start),
        .enable          (enable),
        .direction       (direction),
        .src_inc         (src_inc),
        .dst_inc         (dst_inc),
        .irq_en          (irq_en),
        .abort           (abort),

        .fsm_busy        (fsm_busy),
        .fsm_done        (fsm_done),
        .fsm_error       (fsm_error)
    );

    // 2. Control FSM
    dma_fsm u_dma_fsm (
        .clk             (clk),
        .rst_n           (rst_n),

        .start           (start),
        .enable          (enable),
        .direction       (direction),
        .irq_en          (irq_en),
        .abort           (abort),

        .count_zero      (count_zero),

        .periph_rx_valid (periph_rx_valid),
        .periph_rx_ready (periph_rx_ready),
        .periph_tx_valid (periph_tx_valid),
        .periph_tx_ready (periph_tx_ready),

        .mem_req         (mem_req),
        .mem_we          (mem_we),
        .mem_ready       (mem_ready),

        .load_config     (load_config),
        .update_step     (update_step),
        .latch_periph_rx (latch_periph_rx),
        .latch_mem_rdata (latch_mem_rdata),

        .fsm_busy        (fsm_busy),
        .fsm_done        (fsm_done),
        .fsm_error       (fsm_error),
        .irq             (irq)
    );

    // 3. Datapath
    dma_datapath u_dma_datapath (
        .clk             (clk),
        .rst_n           (rst_n),

        .src_addr        (src_addr),
        .dst_addr        (dst_addr),
        .transfer_len    (transfer_len),
        .data_width      (data_width),
        .direction       (direction),
        .src_inc         (src_inc),
        .dst_inc         (dst_inc),

        .load_config     (load_config),
        .update_step     (update_step),
        .latch_periph_rx (latch_periph_rx),
        .latch_mem_rdata (latch_mem_rdata),

        .count_zero      (count_zero),

        .periph_rx_data  (periph_rx_data),
        .periph_tx_data  (periph_tx_data),

        .mem_addr        (mem_addr),
        .mem_wdata       (mem_wdata),
        .mem_be          (mem_be),
        .mem_rdata       (mem_rdata)
    );

endmodule
