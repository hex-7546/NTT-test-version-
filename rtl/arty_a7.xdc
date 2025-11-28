## ============================================================================
## File: rtl/arty_a7.xdc
## Constraints for Arty A7-100T FPGA Board
## Vivado 2025.1
## ============================================================================

## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_100mhz }];

## Reset button (BTN0)
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## LEDs
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## UART
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }];
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { uart_txd }];

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Bitstream configuration
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## Timing constraints
## Set input delay for UART
set_input_delay -clock [get_clocks sys_clk_pin] -min 0 [get_ports uart_rxd]
set_input_delay -clock [get_clocks sys_clk_pin] -max 2 [get_ports uart_rxd]

## Set output delay for UART
set_output_delay -clock [get_clocks sys_clk_pin] -min 0 [get_ports uart_txd]
set_output_delay -clock [get_clocks sys_clk_pin] -max 2 [get_ports uart_txd]

## Set false paths for reset and LEDs
set_false_path -from [get_ports rst_n]
set_false_path -to [get_ports led[*]]