# Next Board Session Checklist

Use this checklist when the K325T board and FMCADDA-9250-9144 card are powered again.

## 1. Physical Setup

- K325T board powered on.
- FMCADDA-9250-9144 card fully seated in the FMC HPC connector.
- JTAG USB connected to the PC.
- UART USB/COM connection available if testing the UART-control bit.
- Oscilloscope connected to AD9144 `OUT1` first.

## 2. Known-Good Button Bit

Program the known-good button bit first if the current FPGA contents are unknown:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_button.tcl
```

Expected:

- DONE/startup completes.
- Wait 12-15 seconds after programming.
- OUT1 shows the previously confirmed DAC waveform.
- KEY0/KEY1 frequency and amplitude changes remain visible on the oscilloscope.

## 3. UART-Control Bit

Current generated UART bitstream:

```text
D:\FPGA\ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart.bit
```

It was built successfully on 2026-05-07. The routed build still has known setup timing violations, so use it for UART bring-up and oscilloscope control testing, not as the final timing-clean release.

The build log also has a non-blocking `blk_mem_gen_0` locked-IP critical warning. Do not treat that warning alone as a failed UART build when the bitstream exists.

Build, if the bitstream is missing or stale:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl
```

Program:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_uart.tcl
```

Wait 12-15 seconds before UART access.

## 4. PC Control Smoke Test

List COM ports in Device Manager or with PowerShell:

```powershell
Get-PnpDevice -PresentOnly -Class Ports
```

Read the AWG ID:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM3 status
```

Load a 50 MHz sine preset:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM3 preset --frequency 50000000 --amplitude 0x6000 --wave sine
```

Expected:

- The script reads `ID=0x41574731`.
- OUT1 shows a waveform after register control is enabled.
- `W 08 00000001` or the host `button` command returns control to physical buttons.

## 5. Common Failures

- `Vivado license not found`: first confirm the command is not running from a restricted sandbox. The working license path is `C:\Users\17844\AppData\Roaming\XilinxLicense\Xlnx_2024.lic`.
- `error deleting D:/FPGA/.Xil/.../straps.rtd`: rebuild with `-tempDir C:/tmp/...`, `-journal C:/tmp/...`, and `-log C:/tmp/...`.
- No OUT1 signal immediately after programming: wait 12-15 seconds, then recheck.
- UART no response: verify the correct COM port, 115200 baud, and that the UART-control bit, not the plain button bit, is programmed.
- UART bit works but waveform quality is imperfect: this is expected for the current bring-up branch. Log the frequency, amplitude, waveform mode, channel, termination, and screenshot instead of immediately rewriting RTL.
