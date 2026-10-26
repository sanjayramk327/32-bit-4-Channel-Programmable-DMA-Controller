// =============================================================================
// File: tb_dma_controller.v
// Description: Unit testbench for 8-channel dma_controller module.
// =============================================================================

`timescale 1ns / 1ps

module tb_dma_controller;

    reg          clk;
    reg          rst_n;

    reg          reg_write;
    reg          reg_read;
    reg  [7:0]   reg_addr;
    reg  [31:0]  reg_wdata;
    wire [31:0]  reg_rdata;

    reg  [7:0]   periph_rx_valid;
    wire [7:0]   periph_rx_ready;
    reg  [255:0] periph_rx_data;
    wire [7:0]   periph_tx_valid;
    reg  [7:0]   periph_tx_ready;
    wire [255:0] periph_tx_data;

    wire         mem_req;
    wire         mem_we;
    wire [31:0]  mem_addr;
    wire [31:0]  mem_wdata;
    wire [3:0]   mem_be;
    wire [31:0]  mem_rdata;
    wire         mem_ready;

    wire [7:0]   irq_channels;
    wire         irq;

    dma_controller u_ctrl (
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

        .irq_channels    (irq_channels),
        .irq             (irq)
    );

    tb_dma_memory u_mem (
        .clk             (clk),
        .rst_n           (rst_n),
        .mem_req         (mem_req),
        .mem_we          (mem_we),
        .mem_addr        (mem_addr),
        .mem_wdata       (mem_wdata),
        .mem_be          (mem_be),
        .mem_rdata       (mem_rdata),
        .mem_ready       (mem_ready)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    initial begin
        rst_n           = 1'b0;
        reg_write       = 1'b0;
        reg_read        = 1'b0;
        reg_addr        = 8'd0;
        reg_wdata       = 32'd0;
        periph_rx_valid = 8'd0;
        periph_rx_data  = 256'd0;
        periph_tx_ready = 8'hFF;

        #40;
        @(posedge clk);
        rst_n = 1'b1;
        #20;

        $display("[tb_dma_controller] 8-channel reset released. Controller smoke test on Channel 7.");

        // Write Channel 7 registers (Base: 8'hE0)
        @(posedge clk);
        reg_addr  <= 8'hE8; reg_wdata <= 32'h0; reg_write <= 1'b1; // CH7 SRC
        @(posedge clk);
        reg_addr  <= 8'hEC; reg_wdata <= 32'h700; reg_write <= 1'b1; // CH7 DST
        @(posedge clk);
        reg_addr  <= 8'hF0; reg_wdata <= 32'd1; reg_write <= 1'b1; // CH7 LEN = 1
        @(posedge clk);
        reg_addr  <= 8'hF4; reg_wdata <= 32'd32; reg_write <= 1'b1; // CH7 WIDTH = 32
        @(posedge clk);
        reg_addr  <= 8'hE0; reg_wdata <= 32'h0000_0033; reg_write <= 1'b1; // CH7 START P2M
        @(posedge clk);
        reg_write <= 1'b0;

        @(posedge clk);
        while (!periph_rx_ready[7]) @(posedge clk);
        periph_rx_data[7*32 +: 32] <= 32'h7777_8888;
        periph_rx_valid[7]         <= 1'b1;
        @(posedge clk);
        periph_rx_valid[7]         <= 1'b0;

        #100;
        if (u_mem.get_word(32'h700) === 32'h7777_8888 && irq_channels[7] === 1'b0) begin
            $display("[tb_dma_controller] PASS: Channel 7 transfer succeeded through arbiter!");
        end else begin
            $display("[tb_dma_controller] FAIL: Data mismatch or IRQ error!");
        end

        #20;
        $finish;
    end

endmodule
