@echo off
echo [%date% %time%] Starting Vivado rebuild...
D:\vivado\Vivado\2024.2\bin\vivado.bat -mode batch -source D:\awg_fpga\scripts\rebuild_awg_base.tcl > D:\awg_fpga\vivado\rebuild_run.log 2>&1
echo [%date% %time%] Vivado finished with exit code %ERRORLEVEL%
