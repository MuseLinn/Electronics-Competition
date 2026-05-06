# UART pins for the optional AD9144 AWG PC-control variant.

set_property PACKAGE_PIN T23 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]

set_property PACKAGE_PIN T22 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

set_false_path -from [get_ports uart_rxd]
