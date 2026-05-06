# Build a bitstream for the AD9144 AWG UART-control variant.

source D:/FPGA/ad9144_bringup_k325t/scripts/synth_awg_uart_direct.tcl

opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file D:/FPGA/ad9144_bringup_k325t/vivado_awg_uart/top_awg_uart_timing_routed.rpt
report_utilization -file D:/FPGA/ad9144_bringup_k325t/vivado_awg_uart/top_awg_uart_util_routed.rpt

set bit_file "D:/FPGA/ad9144_bringup_k325t/vivado_awg_uart/top_awg_uart.bit"
write_bitstream -force $bit_file

puts "UART_BITSTREAM=$bit_file"
