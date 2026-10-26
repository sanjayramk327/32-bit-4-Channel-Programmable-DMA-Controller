@echo off
REM ============================================================================
REM Batch script to compile, simulate, and optionally view waveforms
REM ============================================================================
echo [1/3] Compiling DMA Controller RTL and Testbench with Icarus Verilog...
iverilog -Wall -g2005 -o build/sim_dma.vvp rtl/dma_registers.v rtl/dma_fsm.v rtl/dma_datapath.v rtl/dma_channel.v rtl/dma_arbiter.v rtl/dma_controller.v rtl/dma_top.v tb/tb_dma_memory.v tb/tb_dma_top.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Executing Simulation via VVP...
vvp build/sim_dma.vvp
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation encountered runtime errors!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Simulation finished successfully!
echo Waveform dumped to: build/dma_sim.vcd
echo.
set /p VIEW_WAVE="Do you want to open waveforms in GTKWave now? (y/n): "
if /i "%VIEW_WAVE%"=="y" (
    echo Launching GTKWave...
    start gtkwave build/dma_sim.vcd build/dma_waves.gtkw
)

echo Done.
