# Create a Vivado project for the K325T AD9144 AWG UART-control variant.

set proj_root "D:/FPGA/ad9144_bringup_k325t"
set proj_dir "$proj_root/vivado_awg_uart"
set project_name "ad9144_awg_uart_k325t"
set verilog_defines [list AWG_UART_CONTROL]
set extra_constraints [list "$proj_root/constraints/awg_uart_k325t.xdc"]

source "$proj_root/scripts/create_awg_button_project.tcl"
