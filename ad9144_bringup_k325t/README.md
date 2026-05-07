# K325T AD9144 AWG Bring-Up

This folder contains the current K325T + FMCADDA-9250-9144 AD9144 AWG bring-up work.

## Current Phase

The current working path is the UART-controlled AD9144 AWG demo:

```text
PC GUI/CLI -> CH340 UART -> K325T register bank -> DDS4 sample generator -> JESD204 TX -> AD9144 OUT1
```

Verified on 2026-05-07:

- OUT1 responds to UART-controlled frequency changes.
- OUT1 responds to UART-controlled amplitude changes.
- OUT1 responds to sine/square/triangle/saw waveform mode changes.
- Coarse sine sweep looked broadly normal through 300 MHz.
- A 400 MHz counter/frequency jump was traced to oscilloscope measurement behavior; FPGA readback stayed stable.

## One-Minute Start

1. Power the K325T board and FMCADDA-9250-9144 card.
2. Connect JTAG and the CH340 UART adapter.
3. Program the UART bit:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_uart.tcl
```

4. Wait 12-15 seconds for AD9144/clock setup.
5. Detect the COM port:

```powershell
Get-PnpDevice -PresentOnly -Class Ports
```

6. Start the GUI:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_panel.py
```

7. In the GUI, choose the COM port, click `Read Status`, then load a known baseline:

```text
Frequency Hz: 50000000
Sample Rate: 1000000000
Amplitude: 0x6000
Offset: 0
Phase deg: 0
Wave: sine
```

## Important Commands

Build the UART-control bitstream if the generated bit is missing or stale:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl
```

CLI status check:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 status
```

CLI preset:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 preset --frequency 50000000 --amplitude 0x6000 --wave sine
```

Run a repeatable UART sweep:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py --port COM7 --profile quick --settle 0.05 --out D:\FPGA\ad9144_bringup_k325t\measurements\uart_sweeps\quick_latest.csv
```

Run digital waveform self-check:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_wave_quality.py --profile quick --out D:\FPGA\ad9144_bringup_k325t\reports\wave_quality\quick_latest.csv
```

Create a fillable oscilloscope measurement sheet:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_scope_measurement.py template --profile freq_response
```

## Documentation Map

- Phase handoff: `D:\FPGA\ad9144_bringup_k325t\docs\phase_handoff_2026-05-07.md`
- Next board checklist: `D:\FPGA\ad9144_bringup_k325t\docs\next_board_session_checklist.md`
- UART protocol: `D:\FPGA\ad9144_bringup_k325t\docs\ad9144_uart_control_protocol.md`
- Register map: `D:\FPGA\ad9144_bringup_k325t\docs\awg_register_map.md`
- GUI notes: `D:\FPGA\ad9144_bringup_k325t\docs\awg_uart_panel.md`
- Digital waveform quality: `D:\FPGA\ad9144_bringup_k325t\docs\awg_wave_quality.md`
- Scope measurement workflow: `D:\FPGA\ad9144_bringup_k325t\docs\awg_scope_measurement.md`

## Generated Files Policy

Vivado output directories, bitstreams, reports, measurement CSVs, and local logs are intentionally not tracked by Git. Rebuild them from the checked-in scripts when needed.
