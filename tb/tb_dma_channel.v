// =============================================================================
// File: tb_dma_channel.v
// Description: Unit testbench for dma_channel module.
// =============================================================================

`timescale 1ns / 1ps

module tb_dma_channel;

    reg         clk;
    reg         rst_n;

    reg         reg_write;
    reg         reg_read;
    reg  [7:0]  reg_addr;
    reg  [31:0] reg_wdata;
    wire [31:0] reg_rdata;

    reg         periph_rx_valid;
    wire        periph_rx_ready;
    reg  [31:0] periph_rx_data;
    wire        periph_tx_valid;
    reg         periph_tx_ready;
    wire [31:0] periph_tx_data;

    wire        mem_req;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_be;
    wire [31:0] mem_rdata;
    wire        mem_ready;

    wire        irq;

    // Unit Under Test
    dma_channel u_channel (
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

    // Memory Model
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
        periph_rx_valid = 1'b0;
        periph_rx_data  = 32'd0;
        periph_tx_ready = 1'b1;

        #40;
        @(posedge clk);
        rst_n = 1'b1;
        #20;

        $display("[tb_dma_channel] Channel reset de-asserted. Basic channel test starting.");

        // Write Config: Src 0x10, Dst 0x200, Len 2, Width 32
        @(posedge clk);
        reg_addr  <= 8'h08; reg_wdata <= 32'h10; reg_write <= 1'b1;
        @(posedge clk);
        reg_addr  <= 8'h0C; reg_wdata <= 32'h200; reg_write <= 1'b1;
        @(posedge clk);
        reg_addr  <= 8'h10; reg_wdata <= 32'd2; reg_write <= 1'b1;
        @(posedge clk);
        reg_addr  <= 8'h14; reg_wdata <= 32'd32; reg_write <= 1'b1;
        @(posedge clk);
        // Start P2M: en=1, dir=0, dst_inc=1, start=1 -> 0x13
        reg_addr  <= 8'h00; reg_wdata <= 32'h0000_0013; reg_write <= 1'b1;
        @(posedge clk);
        reg_write <= 1'b0;

        // Feed 2 items
        @(posedge clk);
        while (!periph_rx_ready) @(posedge clk);
        periph_rx_data <= 32'h1111_2222;
        periph_rx_valid <= 1'b1;
        @(posedge clk);
        periph_rx_valid <= 1'b0;

        @(posedge clk);
        while (!periph_rx_ready) @(posedge clk);
        periph_rx_data <= 32'h3333_4444;
        periph_rx_valid <= 1'b1;
        @(posedge clk);
        periph_rx_valid <= 1'b0;

        #100;
        if (u_mem.get_word(32'h200) === 32'h1111_2222 && u_mem.get_word(32'h204) === 32'h3333_4444) begin
            $display("[tb_dma_channel] PASS: Channel direct test successfully wrote memory!");
        end else begin
            $display("[tb_dma_channel] FAIL: Data mismatch!");
        end

        #20;
        $finish;
    end

endmodule
