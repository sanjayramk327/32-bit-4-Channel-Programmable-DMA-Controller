# DMA Controller Architecture Specification

## 1. System Overview
The Programmable 4-Channel DMA Controller provides autonomous data transfer between peripherals and memory subsystems without continuous CPU intervention. 

Stage 1 implements a complete, self-contained single-channel DMA context, serving as the verified core module to be duplicated across 4 channels with round-robin bus arbitration in Stage 2.

```
                      +-------------------------------------------------------+
                      |                      dma_top                          |
                      |                                                       |
  Host CPU Bus -----> |   +-----------------------------------------------+   |
  (reg_read/write,    |   |                dma_registers                  |   |
   reg_addr, wdata)   |   |  - ADDR_CONTROL (start, enable, dir, inc, irq)|   |
                      |   |  - ADDR_STATUS  (busy, done, error - W1C)     |   |
                      |   |  - ADDR_SRC, ADDR_DST, ADDR_LEN, ADDR_WIDTH   |   |
                      |   +-----------------------------------------------+   |
                      |          | src, dst, len, width ^                     |
                      |          v                      | busy, done, err     |
                      |   +---------------+     +-------------------------+   |
                      |   |    dma_fsm    |     |      dma_datapath       |   |
                      |   |               |     |                         |   |
                      |   | States:       |---->| - curr_src_addr         |   |
                      |   | - IDLE        |     | - curr_dst_addr         |   |
                      |   | - LOAD        |     | - transfer countdown    |   |
                      |   | - P2M_WAIT_RX |     | - 32-bit data buffer    |   |
                      |   | - P2M_MEM_WR  |     | - byte enable steering  |   |
                      |   | - M2P_MEM_RD  |     | - sub-word extraction   |   |
                      |   | - M2P_WAIT_TX |     +-------------------------+   |
                      |   | - UPDATE/DONE |                  |                |
                      |   +---------------+                  |                |
                      +-----------|--------------------------|----------------+
                                  v                          v
                        Memory Master Interface (SRAM / AXI-Lite compatible)
                        (mem_req, mem_we, mem_addr, mem_wdata, mem_be, mem_rdata, mem_ready)
```

---

## 2. Core Functional Blocks

### 2.1 Register Bank (`dma_registers.v`)
- Interfaces to CPU slave bus (`reg_write`, `reg_read`, `reg_addr`, `reg_wdata`, `reg_rdata`).
- Maintains channel configuration:
  - Base Source Address (`SRC_ADDR`)
  - Base Destination Address (`DST_ADDR`)
  - Total Transfer Count (`TRANSFER_LEN`)
  - Transfer Bit-Width (`DATA_WIDTH`: 1–32 bits)
  - Mode & Direction Controls (`CONTROL`)
- Latches completion and error flags in `STATUS` with Write-1-to-Clear (W1C) capability and auto-clear on new transfer start.

### 2.2 Control FSM (`dma_fsm.v`)
- Manages transaction handshaking for both **Peripheral-to-Memory (P2M)** and **Memory-to-Peripheral (M2P)** directions.
- Transitions through `IDLE -> LOAD -> (WAIT_RX <-> MEM_WR) -> UPDATE -> DONE` (P2M) or `IDLE -> LOAD -> (MEM_RD <-> WAIT_TX) -> UPDATE -> DONE` (M2P).
- Controls single-cycle start and abort requests gracefully.

### 2.3 Datapath & Address Generator (`dma_datapath.v`)
- **Shadow Registers**: Latches `curr_src_addr`, `curr_dst_addr`, and `rem_count` at `LOAD`, leaving configuration registers intact.
- **Dynamic Address Step**:
  - `DATA_WIDTH <= 8` $\implies$ byte stride (`+1`).
  - `8 < DATA_WIDTH <= 16` $\implies$ halfword stride (`+2`).
  - `16 < DATA_WIDTH <= 32` $\implies$ word stride (`+4`).
- **Memory Byte Enable Steering**: For 8-bit or 16-bit writes, generates exact `mem_be[3:0]` and shifts write data to appropriate byte lanes according to `addr[1:0]`.
- **Sub-word Read Extraction**: Extracts target 8-bit or 16-bit slice from 32-bit memory words on M2P transfers.
- **Bitmasking**: Filters data buffer output with `(1 << DATA_WIDTH) - 1` to ensure non-word bits are strictly zeroed.

---

## 3. Bus & Handshake Protocols

### 3.1 Peripheral Handshake
- **Streaming Valid/Ready Protocol**:
  - Transfer occurs on clock edge where `valid && ready == 1'b1`.
  - P2M: DMA asserts `periph_rx_ready = 1` when waiting for data; samples when `periph_rx_valid` is asserted.
  - M2P: DMA asserts `periph_tx_valid = 1` and presents data; advances when `periph_tx_ready` is asserted.

### 3.2 Memory Master Interface
- `mem_req`: Asserted when DMA initiates read or write.
- `mem_we`: `1` for write (P2M), `0` for read (M2P).
- `mem_ready`: Memory slave response acknowledging completion of current read/write cycle.
- `mem_be[3:0]`: 4-bit byte strobe for byte/halfword masking.
