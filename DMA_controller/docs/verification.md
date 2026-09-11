# DMA Controller Verification Guide

## Simulation Environment
- **Simulator**: Icarus Verilog (`iverilog` v0.9.7 or newer) + `vvp`
- **Waveform Viewer**: GTKWave
- **Testbench Directory**: `tb/`
- **Waveform Output**: `build/dma_sim.vcd`

---

## Running the Simulation

Execute the following commands from the project root (`D:\PROJECTS\DMA_controller`):

```powershell
# 1. Compile all RTL and Testbench sources
iverilog -Wall -g2005 -o build/sim_dma.vvp `
  rtl/dma_registers.v `
  rtl/dma_fsm.v `
  rtl/dma_datapath.v `
  rtl/dma_channel.v `
  rtl/dma_controller.v `
  rtl/dma_top.v `
  tb/tb_dma_memory.v `
  tb/tb_dma_top.v

# 2. Run simulation
vvp build/sim_dma.vvp

# 3. (Optional) Inspect waveforms in GTKWave
gtkwave build/dma_sim.vcd
```

---

## Automated Test Cases (`tb_dma_top.v`)

| Test ID | Test Name | Description | Verification Check | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC1** | Register Access & Defaults | Reads reset values of registers, writes test patterns, verifies readback. | `DATA_WIDTH == 32`, `SRC_ADDR`, `DST_ADDR` exact match. | **PASS** |
| **TC2** | P2M 32-bit Transfer | Transfers 8 words from peripheral stream to memory `0x1000..0x101C`. | Word-for-word memory inspection at all 8 target addresses. | **PASS** |
| **TC3** | P2M 8-bit Sub-word Transfer | Transfers 16 bytes from peripheral stream to memory `0x2000..0x200F`. | Validates `mem_be[3:0]` byte-lane packing and byte increment (+1). | **PASS** |
| **TC4** | M2P 32-bit Transfer | Preloads memory words, transfers 4 words to peripheral sink. | Compares received peripheral stream against expected preloaded words. | **PASS** |
| **TC5** | M2P 16-bit Sub-word Transfer | Preloads memory, reads 4 halfwords, verifies 16-bit extraction. | Checks that 16-bit halves are correctly unpacked from 32-bit words. | **PASS** |
| **TC6** | Fixed Address Mode | Sets `dst_inc = 0` (FIFO simulation) and writes 4 items. | Ensures target memory at `0x5000` is overwritten with final word and `0x5004` untouched. | **PASS** |
| **TC7** | Status & W1C | Checks `DONE` flag assertion upon completion, then writes `1` to bit 1. | Verifies `STATUS[1]` toggles from `1` to `0` via Write-1-to-Clear. | **PASS** |

---

## Standalone Unit Tests

1. **Channel Unit Test**:
   ```powershell
   iverilog -Wall -g2005 -o build/sim_channel.vvp rtl/dma_registers.v rtl/dma_fsm.v rtl/dma_datapath.v rtl/dma_channel.v tb/tb_dma_memory.v tb/tb_dma_channel.v
   vvp build/sim_channel.vvp
   ```

2. **Controller Wrapper Test**:
   ```powershell
   iverilog -Wall -g2005 -o build/sim_controller.vvp rtl/dma_registers.v rtl/dma_fsm.v rtl/dma_datapath.v rtl/dma_channel.v rtl/dma_controller.v tb/tb_dma_memory.v tb/tb_dma_controller.v
   vvp build/sim_controller.vvp
   ```
