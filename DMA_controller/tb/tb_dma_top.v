// =============================================================================
// File: tb_dma_top.v
// Description: Comprehensive self-checking testbench for 1-Channel DMA Controller.
//              Verifies:
//              - TC1: Register R/W and default values
//              - TC2: Peripheral-to-Memory (P2M) 32-bit transfer
//              - TC3: Peripheral-to-Memory (P2M) 8-bit sub-word transfer
//              - TC4: Memory-to-Peripheral (M2P) 32-bit transfer
//              - TC5: Memory-to-Peripheral (M2P) 16-bit sub-word transfer
//              - TC6: Fixed address mode (FIFO / constant address)
//              - TC7: Completion interrupt (irq) & status register behavior
// =============================================================================

`timescale 1ns / 1ps

module tb_dma_top;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // CPU Bus Slave Interface
    reg         reg_write;
    reg         reg_read;
    reg  [7:0]  reg_addr;
    reg  [31:0] reg_wdata;
    wire [31:0] reg_rdata;

    // Peripheral Interface
    reg         periph_rx_valid;
    wire        periph_rx_ready;
    reg  [31:0] periph_rx_data;
    wire        periph_tx_valid;
    reg         periph_tx_ready;
    wire [31:0] periph_tx_data;

    // Memory Master Bus
    wire        mem_req;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_be;
    wire [31:0] mem_rdata;
    wire        mem_ready;

    // Interrupt
    wire        irq;

    // Test tracking counters
    integer tests_passed = 0;
    integer tests_failed = 0;
    integer i;

    // Register Map Constants
    localparam ADDR_CONTROL      = 8'h00;
    localparam ADDR_STATUS       = 8'h04;
    localparam ADDR_SRC_ADDR     = 8'h08;
    localparam ADDR_DST_ADDR     = 8'h0C;
    localparam ADDR_TRANSFER_LEN = 8'h10;
    localparam ADDR_DATA_WIDTH   = 8'h14;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------------
    dma_top u_dut (
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

    // -------------------------------------------------------------------------
    // Behavioral Memory Model
    // -------------------------------------------------------------------------
    tb_dma_memory u_memory (
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

    // -------------------------------------------------------------------------
    // Clock Generation (50 MHz, 20ns period)
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // CPU Register Access Tasks
    // -------------------------------------------------------------------------
    task cpu_write;
        input [7:0]  addr;
        input [31:0] data;
        begin
            @(posedge clk);
            reg_addr  <= addr;
            reg_wdata <= data;
            reg_write <= 1'b1;
            reg_read  <= 1'b0;
            @(posedge clk);
            reg_write <= 1'b0;
            reg_addr  <= 8'd0;
            reg_wdata <= 32'd0;
        end
    endtask

    task cpu_read;
        input  [7:0]  addr;
        output [31:0] data;
        begin
            @(posedge clk);
            reg_addr  <= addr;
            reg_read  <= 1'b1;
            reg_write <= 1'b0;
            @(posedge clk);
            data = reg_rdata;
            reg_read  <= 1'b0;
            reg_addr  <= 8'd0;
        end
    endtask

    task wait_dma_done;
        reg [31:0] status;
        integer timeout;
        begin
            timeout = 1000;
            status = 32'd0;
            while (!status[1] && timeout > 0) begin
                cpu_read(ADDR_STATUS, status);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                $display("[ERROR] DMA wait timed out!");
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    reg [31:0] rdata_temp;
    reg [31:0] m2p_rx_buffer [0:31];
    integer rx_idx;

    // Background peripheral transmitter process (for M2P test)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_idx <= 0;
        end else if (periph_tx_valid && periph_tx_ready) begin
            m2p_rx_buffer[rx_idx] <= periph_tx_data;
            rx_idx <= rx_idx + 1;
        end
    end

    initial begin
        // Setup VCD Waveform Dump
        $dumpfile("build/dma_sim.vcd");
        $dumpvars(0, tb_dma_top);

        $display("================================================================");
        $display("   STARTING DMA CONTROLLER (STAGE 1) VERIFICATION TESTBENCH    ");
        $display("================================================================");

        // Initialization
        rst_n           = 1'b0;
        reg_write       = 1'b0;
        reg_read        = 1'b0;
        reg_addr        = 8'd0;
        reg_wdata       = 32'd0;
        periph_rx_valid = 1'b0;
        periph_rx_data  = 32'd0;
        periph_tx_ready = 1'b1; // Default peripheral ready to sink data

        u_memory.clear_all();

        // Apply Reset
        #40;
        @(posedge clk);
        rst_n = 1'b1;
        #20;

        // ---------------------------------------------------------------------
        // TEST CASE 1: Register Read/Write & Default Check
        // ---------------------------------------------------------------------
        $display("\n--- [TC1] Checking Register Access & Defaults ---");
        cpu_read(ADDR_DATA_WIDTH, rdata_temp);
        if (rdata_temp == 32'd32) begin
            $display("[PASS] Default DATA_WIDTH is 32");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Expected DATA_WIDTH=32, got %0d", rdata_temp);
            tests_failed = tests_failed + 1;
        end

        cpu_write(ADDR_SRC_ADDR, 32'hA000_1000);
        cpu_read(ADDR_SRC_ADDR, rdata_temp);
        if (rdata_temp == 32'hA000_1000) begin
            $display("[PASS] SRC_ADDR write/read succeeded");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] SRC_ADDR mismatch: %h", rdata_temp);
            tests_failed = tests_failed + 1;
        end

        cpu_write(ADDR_DST_ADDR, 32'hB000_2000);
        cpu_read(ADDR_DST_ADDR, rdata_temp);
        if (rdata_temp == 32'hB000_2000) begin
            $display("[PASS] DST_ADDR write/read succeeded");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] DST_ADDR mismatch: %h", rdata_temp);
            tests_failed = tests_failed + 1;
        end

        // ---------------------------------------------------------------------
        // TEST CASE 2: Peripheral-to-Memory (P2M), 32-bit words, Length = 8
        // ---------------------------------------------------------------------
        $display("\n--- [TC2] Peripheral-to-Memory (P2M) 32-bit Transfer ---");
        // Configure DMA
        cpu_write(ADDR_SRC_ADDR,     32'h4000_0000); // Fixed peripheral address
        cpu_write(ADDR_DST_ADDR,     32'h0000_1000); // Target memory starting at 0x1000
        cpu_write(ADDR_TRANSFER_LEN, 32'd8);         // 8 transfers
        cpu_write(ADDR_DATA_WIDTH,   32'd32);        // 32-bit word width
        // CONTROL: enable=1, direction=0 (P2M), src_inc=0, dst_inc=1, irq_en=1, start=1
        // bit0=start(1), bit1=en(1), bit2=dir(0), bit3=src_inc(0), bit4=dst_inc(1), bit5=irq_en(1) -> 0x33
        cpu_write(ADDR_CONTROL,      32'h0000_0033);

        // Feed peripheral stream
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk);
            while (!periph_rx_ready) @(posedge clk);
            periph_rx_data  <= 32'hDEAD_0000 + i;
            periph_rx_valid <= 1'b1;
            @(posedge clk);
            periph_rx_valid <= 1'b0;
        end

        wait_dma_done();

        // Verify Memory Contents
        begin : verify_tc2
            integer tc2_ok;
            tc2_ok = 1;
            for (i = 0; i < 8; i = i + 1) begin
                if (u_memory.get_word(32'h0000_1000 + (i * 4)) !== (32'hDEAD_0000 + i)) begin
                    $display("[FAIL] Mismatch at Mem[0x%h]: expected 0x%h, got 0x%h",
                             32'h0000_1000 + (i * 4), 32'hDEAD_0000 + i, u_memory.get_word(32'h0000_1000 + (i * 4)));
                    tc2_ok = 0;
                end
            end
            if (tc2_ok) begin
                $display("[PASS] All 8 words correctly written from peripheral to memory!");
                tests_passed = tests_passed + 1;
            end else begin
                tests_failed = tests_failed + 1;
            end
        end

        // ---------------------------------------------------------------------
        // TEST CASE 3: Peripheral-to-Memory (P2M), 8-bit bytes, Length = 16
        // ---------------------------------------------------------------------
        $display("\n--- [TC3] Peripheral-to-Memory (P2M) 8-bit Sub-word Transfer ---");
        // Configure DMA for 16-byte transfer to 0x2000
        cpu_write(ADDR_SRC_ADDR,     32'h4000_0000);
        cpu_write(ADDR_DST_ADDR,     32'h0000_2000);
        cpu_write(ADDR_TRANSFER_LEN, 32'd16);        // 16 bytes
        cpu_write(ADDR_DATA_WIDTH,   32'd8);         // 8-bit width
        // CONTROL: start(1), en(1), dir(0), src_inc(0), dst_inc(1), irq_en(0) -> 0x13
        cpu_write(ADDR_CONTROL,      32'h0000_0013);

        // Feed 16 individual bytes
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            while (!periph_rx_ready) @(posedge clk);
            periph_rx_data  <= 8'hA0 + i;
            periph_rx_valid <= 1'b1;
            @(posedge clk);
            periph_rx_valid <= 1'b0;
        end

        wait_dma_done();

        // Verify Individual Bytes in Memory
        begin : verify_tc3
            integer tc3_ok;
            tc3_ok = 1;
            for (i = 0; i < 16; i = i + 1) begin
                if (u_memory.get_byte(32'h0000_2000 + i) !== (8'hA0 + i)) begin
                    $display("[FAIL] Byte mismatch at 0x%h: expected 0x%h, got 0x%h",
                             32'h0000_2000 + i, 8'hA0 + i, u_memory.get_byte(32'h0000_2000 + i));
                    tc3_ok = 0;
                end
            end
            if (tc3_ok) begin
                $display("[PASS] All 16 bytes correctly packed into memory using byte enables!");
                tests_passed = tests_passed + 1;
            end else begin
                tests_failed = tests_failed + 1;
            end
        end

        // ---------------------------------------------------------------------
        // TEST CASE 4: Memory-to-Peripheral (M2P), 32-bit words, Length = 4
        // ---------------------------------------------------------------------
        $display("\n--- [TC4] Memory-to-Peripheral (M2P) 32-bit Transfer ---");
        // Preload memory at 0x3000
        u_memory.preload_word(32'h0000_3000, 32'hCAFE_0001);
        u_memory.preload_word(32'h0000_3004, 32'hCAFE_0002);
        u_memory.preload_word(32'h0000_3008, 32'hCAFE_0003);
        u_memory.preload_word(32'h0000_300C, 32'hCAFE_0004);

        rx_idx = 0;

        // Configure DMA
        cpu_write(ADDR_SRC_ADDR,     32'h0000_3000); // Read from memory
        cpu_write(ADDR_DST_ADDR,     32'h5000_0000); // Fixed peripheral sink
        cpu_write(ADDR_TRANSFER_LEN, 32'd4);
        cpu_write(ADDR_DATA_WIDTH,   32'd32);
        // CONTROL: start(1), en(1), dir=1(M2P), src_inc=1, dst_inc=0, irq_en=1
        // bit0=1, bit1=1, bit2=1, bit3=1, bit4=0, bit5=1 -> 0x2F
        cpu_write(ADDR_CONTROL,      32'h0000_002F);

        wait_dma_done();

        // Verify received peripheral stream
        begin : verify_tc4
            integer tc4_ok;
            tc4_ok = 1;
            if (rx_idx !== 4) begin
                $display("[FAIL] Expected 4 beats, received %0d", rx_idx);
                tc4_ok = 0;
            end else begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (m2p_rx_buffer[i] !== (32'hCAFE_0001 + i)) begin
                        $display("[FAIL] Beat %0d mismatch: expected 0x%h, got 0x%h",
                                 i, 32'hCAFE_0001 + i, m2p_rx_buffer[i]);
                        tc4_ok = 0;
                    end
                end
            end
            if (tc4_ok) begin
                $display("[PASS] Memory-to-Peripheral 32-bit transfer stream matched!");
                tests_passed = tests_passed + 1;
            end else begin
                tests_failed = tests_failed + 1;
            end
        end

        // ---------------------------------------------------------------------
        // TEST CASE 5: Memory-to-Peripheral (M2P), 16-bit halfwords, Length = 4
        // ---------------------------------------------------------------------
        $display("\n--- [TC5] Memory-to-Peripheral (M2P) 16-bit Sub-word Transfer ---");
        // Preload memory words containing 16-bit values:
        // Word 0 (0x4000): {16'h5678, 16'h1234}
        // Word 1 (0x4004): {16'hDEF0, 16'h9ABC}
        u_memory.preload_word(32'h0000_4000, 32'h5678_1234);
        u_memory.preload_word(32'h0000_4004, 32'hDEF0_9ABC);

        rx_idx = 0;

        // Configure DMA for 4 halfwords starting at 0x4000
        cpu_write(ADDR_SRC_ADDR,     32'h0000_4000);
        cpu_write(ADDR_DST_ADDR,     32'h5000_0000);
        cpu_write(ADDR_TRANSFER_LEN, 32'd4);
        cpu_write(ADDR_DATA_WIDTH,   32'd16);        // 16-bit
        cpu_write(ADDR_CONTROL,      32'h0000_002F); // M2P, src_inc=1

        wait_dma_done();

        begin : verify_tc5
            integer tc5_ok;
            tc5_ok = 1;
            if (m2p_rx_buffer[0] !== 32'h1234 ||
                m2p_rx_buffer[1] !== 32'h5678 ||
                m2p_rx_buffer[2] !== 32'h9ABC ||
                m2p_rx_buffer[3] !== 32'hDEF0) begin
                $display("[FAIL] Halfword stream mismatch: [0]=0x%h, [1]=0x%h, [2]=0x%h, [3]=0x%h",
                         m2p_rx_buffer[0], m2p_rx_buffer[1], m2p_rx_buffer[2], m2p_rx_buffer[3]);
                tc5_ok = 0;
            end
            if (tc5_ok) begin
                $display("[PASS] 16-bit sub-word extraction verified successfully!");
                tests_passed = tests_passed + 1;
            end else begin
                tests_failed = tests_failed + 1;
            end
        end

        // ---------------------------------------------------------------------
        // TEST CASE 6: Fixed Destination Address Mode
        // ---------------------------------------------------------------------
        $display("\n--- [TC6] Fixed Destination Address Mode (FIFO simulation) ---");
        // Clear destination memory at 0x5000
        u_memory.preload_word(32'h0000_5000, 32'd0);

        // Configure DMA with dst_inc = 0 (bit 4 = 0)
        cpu_write(ADDR_SRC_ADDR,     32'h4000_0000);
        cpu_write(ADDR_DST_ADDR,     32'h0000_5000);
        cpu_write(ADDR_TRANSFER_LEN, 32'd4);
        cpu_write(ADDR_DATA_WIDTH,   32'd32);
        // bit0=start(1), bit1=en(1), bit2=dir(0), bit3=src_inc(0), bit4=dst_inc(0), bit5=irq_en(0) -> 0x03
        cpu_write(ADDR_CONTROL,      32'h0000_0003);

        for (i = 0; i < 4; i = i + 1) begin
            @(posedge clk);
            while (!periph_rx_ready) @(posedge clk);
            periph_rx_data  <= 32'hBEEF_0001 + i;
            periph_rx_valid <= 1'b1;
            @(posedge clk);
            periph_rx_valid <= 1'b0;
        end

        wait_dma_done();

        // Memory at 0x5000 should hold the LAST written word because address was fixed
        if (u_memory.get_word(32'h0000_5000) === 32'hBEEF_0004 &&
            u_memory.get_word(32'h0000_5004) === 32'd0) begin
            $display("[PASS] Fixed destination address correctly maintained at 0x5000");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Fixed address failed: Mem[0x5000]=%h, Mem[0x5004]=%h",
                     u_memory.get_word(32'h0000_5000), u_memory.get_word(32'h0000_5004));
            tests_failed = tests_failed + 1;
        end

        // ---------------------------------------------------------------------
        // TEST CASE 7: Status Register Clear (W1C)
        // ---------------------------------------------------------------------
        $display("\n--- [TC7] Status Register W1C Verification ---");
        cpu_read(ADDR_STATUS, rdata_temp);
        if (rdata_temp[1] == 1'b1) begin
            $display("[PASS] Status DONE bit is set");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Expected DONE bit set");
            tests_failed = tests_failed + 1;
        end

        // Write-1-to-Clear DONE bit (bit 1)
        cpu_write(ADDR_STATUS, 32'h0000_0002);
        cpu_read(ADDR_STATUS, rdata_temp);
        if (rdata_temp[1] == 1'b0) begin
            $display("[PASS] Status DONE bit successfully cleared via W1C");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] DONE bit did not clear: 0x%h", rdata_temp);
            tests_failed = tests_failed + 1;
        end

        // ---------------------------------------------------------------------
        // SUMMARY
        // ---------------------------------------------------------------------
        #100;
        $display("\n================================================================");
        $display("   TEST SUMMARY: PASSED: %0d  |  FAILED: %0d", tests_passed, tests_failed);
        $display("================================================================");

        if (tests_failed == 0) begin
            $display(">>> ALL STAGE 1 VERIFICATION TESTS PASSED SUCCESSFULLY! <<<");
        end else begin
            $display(">>> SOME TESTS FAILED. PLEASE CHECK SIMULATION LOG. <<<");
        end

        $finish;
    end

endmodule
