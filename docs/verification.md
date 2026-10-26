# 8-Channel DMA Controller Verification Guide

## Simulation Environment
- **Simulator**: Icarus Verilog (`iverilog` v0.9.7 or newer) + `vvp`
- **Waveform Viewer**: GTKWave
- **Testbench Directory**: `tb/`
- **Waveform Output**: `build/dma_sim.vcd`
- **Signal Layout**: `build/dma_waves.gtkw`

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
  rtl/dma_arbiter.v `
  rtl/dma_controller.v `
  rtl/dma_top.v `
  tb/tb_dma_memory.v `
  tb/tb_dma_top.v

# 2. Run simulation
vvp build/sim_dma.vvp

# 3. View waveforms with pre-grouped 8-channel signals in GTKWave
gtkwave build/dma_sim.vcd build/dma_waves.gtkw
```

*(Or simply execute `.\run_sim.bat` or press `Ctrl + Shift + B` in VS Code).*

---

## Automated Test Cases (`tb_dma_top.v`)

| Test ID | Test Name | Description | Verification Check | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC1** | Register Context Isolation | Writes distinct configurations across all 8 channels; verifies no cross-talk. | Exact parameter readback across CH0 through CH7. | **PASS** |
| **TC2** | Sequential Transfers (CH0..CH7) | Sequentially executes P2M transfers on all 8 channels with unique addresses. | Word-for-word memory verification across all 8 target regions. | **PASS** |
| **TC3** | Concurrent Transfers (All 8 CHs) | Simulates all 8 channels simultaneously streaming data through the Round-Robin arbiter. | All 8 memory buffers verified with zero data corruption or lost beats. | **PASS** |
| **TC4** | Mixed-Mode Concurrent Transfers | Concurrently runs P2M on even channels and M2P on odd channels. | Verifies simultaneous memory writes and reads through shared arbiter. | **PASS** |
| **TC5** | Independent Programmable Lengths | Configures lengths 2, 4, 6, 8 across channels; verifies exact countdown termination. | Verifies each channel terminates independently at its programmed count. | **PASS** |
| **TC6** | Per-Channel & Global IRQ and W1C | Verifies per-channel `irq_channels[k]` assertions, global `irq`, and Status W1C clearing. | Flags and interrupts toggle accurately. | **PASS** |
