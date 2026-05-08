# AWG DDS LED Demo - K325T Pin Constraints
# Target: xc7k325tffg900-2

# Differential 100MHz clock
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_p]
set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_n]

# Active-low reset (KEY0 on board)
set_property PACKAGE_PIN AB25 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

# Keys (frequency control)
set_property PACKAGE_PIN A26 [get_ports key0]
set_property IOSTANDARD LVCMOS33 [get_ports key0]
set_property PACKAGE_PIN A25 [get_ports key1]
set_property IOSTANDARD LVCMOS33 [get_ports key1]

# LEDs (only 2 available on K325T core board)
set_property PACKAGE_PIN R24 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN R23 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]


# Create clock constraint
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

# False path for LED outputs (not timing critical)
set_false_path -to [get_ports {led[*]}]
