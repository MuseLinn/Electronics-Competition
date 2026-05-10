set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set sim_dir [file join $root_dir .tmp_tb_awg_cal_sim]

create_project -force tb_awg_cal_sim $sim_dir -part xc7k325tffg900-2
set rtl_dir [file join $root_dir rtl awg]
add_files -fileset sim_1 [file join $rtl_dir ad9144_awg_cal.v]
add_files -fileset sim_1 [file join $rtl_dir tb_awg_cal.v]
set_property top tb_awg_cal [get_filesets sim_1]
launch_simulation -mode behavioral
run 1 us
close_sim
close_project
exit
