# Implementation Plan: 8-Channel Programmable DMA Controller

Upgrade the DMA controller architecture from a single-channel implementation into a full **8-Channel Programmable DMA Controller** with fair Round-Robin arbitration, keeping all advanced features (programmable transfer length, programmable data width 1–32 bits, sub-word byte enables, P2M/M2P directions, and status/interrupt reporting).

---

## User Review Required

> [!IMPORTANT]
> **Register Address Decoding Scheme**:
> Each channel requires 6 registers (`CONTROL`, `STATUS`, `SRC_ADDR`, `DST_ADDR`, `TRANSFER_LEN`, `DATA_WIDTH`), occupying 32 bytes (`0x20`).
> With an 8-bit CPU register address (`reg_addr[7:0]`):
> - `reg_addr[7:5]` (top 3 bits) uniquely selects Channel $0 \dots 7$ ($2^3 = 8$ channels).
> - `reg_addr[4:0]` (bottom 5 bits) selects the register within the channel.
> This provides clean, uniform address mapping from `0x00` to `0xFF`.

> [!NOTE]
> **Arbiter Policy**:
> We will implement **Round-Robin Token-Passing Arbitration** at the transfer beat level.
> When multiple channels request the memory bus simultaneously, the arbiter services one beat from each active channel in rotating order ($0 \to 1 \to 2 \dots \to 7 \to 0$). This guarantees fair bandwidth allocation and prevents any single fast channel from starving the others.

---

## Proposed System Architecture

```
                                  CPU Register Bus (reg_write, reg_read, reg_addr[7:0], reg_wdata, reg_rdata)
                                                        │
                      ┌─────────────────────────────────┴─────────────────────────────────┐
                      ▼                                                                   ▼
       ┌───────────────────────────────┐                                   ┌───────────────────────────────┐
       │         dma_channel 0         │  ...                             │         dma_channel 7         │
       │  (Base: 0x00, Length, Width)  │                                   │  (Base: 0xE0, Length, Width)  │
       └──────────────┬────────────────┘                                   └──────────────┬────────────────┘
                      │ ch0_req                                                           │ ch7_req
                      │                                                                   │
                      ▼                                                                   ▼
       ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
       │                                     dma_arbiter.v                                                 │
       │                           (Round-Robin Token Pointer Arbiter)                                     │
       │                                  ch_grant[7:0] one-hot                                            │
       └───────────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                           │
                                                           ▼
       ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
       │                                Memory Bus Multiplexer & Gating                                    │
       │                    Routes granted channel's mem_addr, mem_wdata, mem_we, mem_be                   │
       │                    Gates external mem_ready back to granted channel                               │
       └───────────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                           │
                                                           ▼
                                               Shared Memory Master Bus
                                  (mem_req, mem_we, mem_addr, mem_wdata, mem_be, mem_rdata, mem_ready)
```

---

## 1. Register Address Map (8 Channels)

Each channel $k \in \{0 \dots 7\}$ has base offset `k * 0x20`:

| Channel | Address Range | Base Offset | Description |
| :---: | :---: | :---: | :--- |
| **CH 0** | `0x00` – `0x1F` | `8'h00` | Channel 0 Registers (`CONTROL`, `STATUS`, `SRC`, `DST`, `LEN`, `WIDTH`) |
| **CH 1** | `0x20` – `0x3F` | `8'h20` | Channel 1 Registers |
| **CH 2** | `0x40` – `0x5F` | `8'h40` | Channel 2 Registers |
| **CH 3** | `0x60` – `0x7F` | `8'h60` | Channel 3 Registers |
| **CH 4** | `0x80` – `0x9F` | `8'h80` | Channel 4 Registers |
| **CH 5** | `0xA0` – `0xBF` | `8'hA0` | Channel 5 Registers |
| **CH 6** | `0xC0` – `0xDF` | `8'hC0` | Channel 6 Registers |
| **CH 7** | `0xE0` – `0xFF` | `8'hE0` | Channel 7 Registers |

### Register Offsets within Each Channel:
- `+ 0x00`: `CONTROL` (Bit 0: START, Bit 1: ENABLE, Bit 2: DIR, Bit 3: SRC_INC, Bit 4: DST_INC, Bit 5: IRQ_EN, Bit 6: ABORT)
- `+ 0x04`: `STATUS` (Bit 0: BUSY, Bit 1: DONE [W1C], Bit 2: ERROR [W1C])
- `+ 0x08`: `SRC_ADDR` (32-bit source address)
- `+ 0x0C`: `DST_ADDR` (32-bit destination address)
- `+ 0x10`: `TRANSFER_LEN` (32-bit programmable countdown length)
- `+ 0x14`: `DATA_WIDTH` (6-bit width: 1 to 32 bits)

---

## 2. Round-Robin Arbiter Design (`rtl/dma_arbiter.v`)

### Arbiter Interface:
- **Inputs**:
  - `clk`, `rst_n`
  - `request[7:0]`: Memory request lines from the 8 DMA channels.
  - `ack_step`: Pulse indicating the current granted beat completed (`mem_req && mem_ready`).
- **Outputs**:
  - `grant[7:0]`: One-hot grant vector indicating which channel controls the memory bus.
  - `grant_valid`: High if any channel is currently granted.
  - `grant_idx[2:0]`: 3-bit binary index ($0 \dots 7$) of granted channel for fast multiplexing.

### Arbitration Logic:
1. Maintains a rotating priority token `token[2:0]`.
2. Evaluates requests circularly starting from `token`:
   $\text{token}, \text{token}+1, \dots, \text{token}+7 \pmod 8$.
3. When the current transaction finishes (`ack_step == 1'b1`), updates `token <= (grant_idx + 1) % 8`.
4. If a channel is granted and actively transferring, it retains bus ownership until the beat handshakes with memory.

---

## 3. Top-Level Integration (`dma_controller.v` & `dma_top.v`)

### Multi-Channel Peripheral Interface:
For standard FPGA and ASIC integration, 8 peripheral channels are grouped as buses:
- `periph_rx_valid[7:0]`, `periph_rx_ready[7:0]`, `periph_rx_data[255:0]` ($8 \times 32$ bits)
- `periph_tx_valid[7:0]`, `periph_tx_ready[7:0]`, `periph_tx_data[255:0]` ($8 \times 32$ bits)

### Interrupts:
- `irq_channels[7:0]`: Individual interrupt line for each channel.
- `irq`: Global combined interrupt (`|irq_channels`), signaling the CPU whenever any channel finishes.

---

## Proposed RTL Changes

### [NEW] [rtl/dma_arbiter.v](file:///D:/PROJECTS/DMA_controller/rtl/dma_arbiter.v)
- Implements 8-channel round-robin arbiter with fair token rotation and zero-starvation guarantee.

### [MODIFY] [rtl/dma_controller.v](file:///D:/PROJECTS/DMA_controller/rtl/dma_controller.v)
- Instantiates 8 $\times$ `dma_channel` instances.
- Connects register address decoding (`reg_addr[7:5]` selects channel, `reg_addr[4:0]` routed internally).
- Instantiates `dma_arbiter.v`.
- Multiplexes memory master bus signals (`mem_addr`, `mem_wdata`, `mem_we`, `mem_be`) according to `grant_idx`.
- Gates `mem_ready` to the active channel.

### [MODIFY] [rtl/dma_top.v](file:///D:/PROJECTS/DMA_controller/rtl/dma_top.v)
- Exposes the expanded 8-channel peripheral interfaces and individual/combined interrupt lines.

---

## Verification Plan

### Updated Testbench: [tb/tb_dma_top.v](file:///D:/PROJECTS/DMA_controller/tb/tb_dma_top.v)

We will implement an automated, self-checking test suite covering:
1. **TC1: All 8 Channels Register R/W Check**:
   - Loops through channels 0 to 7. Writes distinct addresses, transfer lengths, and data widths to each channel's register space; verifies correct readback.
2. **TC2: Sequential Transfer Across All 8 Channels (CH0 to CH7)**:
   - Tests each channel independently with different lengths, buffer addresses, and directions.
3. **TC3: Concurrent Multi-Channel Stress Test (The Grand Test)**:
   - Simultaneously triggers transfers on multiple channels (e.g., CH0, CH1, CH2, CH3, CH4, CH5, CH6, CH7).
   - Verifies the **Round-Robin arbiter** interleaves memory beats fairly.
   - Verifies all 8 memory destination buffers receive 100% correct data without dropped bytes or crosstalk.
4. **TC4: Mixed-Mode Concurrent Transfers**:
   - Concurrently executes P2M transfers (e.g. on CH0, CH2, CH4, CH6) and M2P transfers (on CH1, CH3, CH5, CH7).
5. **TC5: Programmable Length Verification**:
   - Configures distinct transfer lengths across channels:
     - CH0: Length = 4
     - CH1: Length = 8
     - CH2: Length = 16
     - CH3: Length = 32
     - CH4..CH7: Variable lengths
   - Verifies each channel stops precisely when its own countdown reaches 0 and fires its respective IRQ.
6. **TC6: Individual and Combined IRQ Verification**:
   - Verifies `irq_channels[k]` pulses only for channel $k$, and `irq` pulses globally.

---

## Execution Command

```powershell
# Compile and simulate the 8-channel DMA
iverilog -Wall -g2005 -o build/sim_dma.vvp `
  rtl/dma_registers.v `
  rtl/dma_fsm.v `
  rtl/dma_datapath.v `
  rtl/dma_channel.v `
  rtl/dma_arbiter.v `
  rtl/dma_controller.v `
  rtl/dma_top.v `
  tb/tb_dma_memory.v `
  tb/tb_dma_top.v

vvp build/sim_dma.vvp
```
