# ==============================================================================
# File: dma.xdc
# Description: Timing and Clock Constraints for DMA Controller (50 MHz default)
# ==============================================================================

# Primary Clock Constraint (50 MHz, 20.0 ns period)
create_clock -period 20.000 -name sys_clk -waveform {0.000 10.000} [get_ports clk]

# Input / Output Delays (nominal 2.0 ns setup/hold margin)
set_input_delay -clock [get_clocks sys_clk] -max 2.000 [get_ports {rst_n reg_write reg_read reg_addr* reg_wdata* periph_rx_valid periph_rx_data* periph_tx_ready mem_rdata* mem_ready}]
set_input_delay -clock [get_clocks sys_clk] -min 0.500 [get_ports {rst_n reg_write reg_read reg_addr* reg_wdata* periph_rx_valid periph_rx_data* periph_tx_ready mem_rdata* mem_ready}]

set_output_delay -clock [get_clocks sys_clk] -max 2.000 [get_ports {reg_rdata* periph_rx_ready periph_tx_valid periph_tx_data* mem_req mem_we mem_addr* mem_wdata* mem_be* irq}]
set_output_delay -clock [get_clocks sys_clk] -min 0.500 [get_ports {reg_rdata* periph_rx_ready periph_tx_valid periph_tx_data* mem_req mem_we mem_addr* mem_wdata* mem_be* irq}]
