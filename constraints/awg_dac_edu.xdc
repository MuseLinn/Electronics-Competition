#------------------------------------------------------------------------------
# AWG Education DAC Constraints (ATK-HS-ADDA Module)
# Target: 3PD9708E 8bit DAC on Zhengdianyuanzi K325T board
#------------------------------------------------------------------------------

# DAC sampling clock
set_property PACKAGE_PIN AH22 [get_ports da_clk]
set_property IOSTANDARD LVCMOS33 [get_ports da_clk]

# DAC parallel data (8bit)
set_property PACKAGE_PIN AB22 [get_ports {da_data[7]}]
set_property PACKAGE_PIN AG20 [get_ports {da_data[6]}]
set_property PACKAGE_PIN AB23 [get_ports {da_data[5]}]
set_property PACKAGE_PIN AH20 [get_ports {da_data[4]}]
set_property PACKAGE_PIN AC22 [get_ports {da_data[3]}]
set_property PACKAGE_PIN AH21 [get_ports {da_data[2]}]
set_property PACKAGE_PIN AD22 [get_ports {da_data[1]}]
set_property PACKAGE_PIN AJ21 [get_ports {da_data[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {da_data[*]}]

# Output delay constraint for DAC data interface
# 3PD9708E setup/hold requirement is relaxed (~5ns typical).
# 100MHz clock period = 10ns. No strict output delay needed for this demo.
set_false_path -to [get_ports {da_data[*]}]
set_false_path -to [get_ports da_clk]
