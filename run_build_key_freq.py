import subprocess
import sys
import time

cmd = [
    r"D:\vivado\Vivado\2024.2\bin\vivado.bat",
    "-mode", "batch",
    "-source", r"D:\awg_fpga\build_key_freq.tcl"
]

print("Starting Vivado build...")
print(f"Command: {' '.join(cmd)}")

with open(r"D:\awg_fpga\build_key_freq.log", "w", encoding="utf-8") as log:
    proc = subprocess.Popen(
        cmd,
        stdout=log,
        stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NEW_CONSOLE
    )
    print(f"Vivado PID: {proc.pid}")
    print("Log file: D:\\awg_fpga\\build_key_freq.log")
    print("Run 'type D:\\awg_fpga\\build_key_freq.log' to check progress.")
