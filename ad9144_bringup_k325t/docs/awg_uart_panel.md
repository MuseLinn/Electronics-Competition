# AD9144 AWG UART Panel

This is the first PC-side control panel for the K325T AD9144 AWG UART-control bit.

## Launch

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_panel.py
```

Current validated port on 2026-05-07:

```text
USB-SERIAL CH340 (COM7)
```

## Controls

- `Read Status`: reads ID, version, control, status, phase increment, amplitude, and waveform mode.
- `Apply Preset`: writes frequency, amplitude, offset, phase, waveform, then enables register control with `CONTROL=0x00000003`.
- `Button Control`: writes `CONTROL=0x00000001`, returning control to the FPGA board buttons.
- `Output Off`: clears `CONTROL[0]` while preserving the other control bits.
- `Run Sweep`: runs the selected UART sweep profile, writes a CSV, restores 50 MHz sine at amplitude `0x6000`, then refreshes status.

## Current Hardware Baseline

After the UART bridge fix and rebuild, the host tool verified:

```text
ID=0x41574731
VERSION=0x20260507
CONTROL=0x00000003
PHASE_INC=0x0CCCCCCCCCCD
AMPLITUDE=0x6000
WAVE_MODE=0
```

The user confirmed the oscilloscope shows a normal 50 MHz sine wave on AD9144 OUT1.

## Sweep Logger

Use the sweep logger to prepare repeatable oscilloscope test points and CSV records:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py --port COM7 --profile quick --out D:\FPGA\ad9144_bringup_k325t\measurements\uart_sweeps\quick_latest.csv
```

Profiles:

- `quick`: 10 MHz, 50 MHz, 100 MHz sine.
- `amplitude`: 50 MHz sine at several amplitudes.
- `wave`: 50 MHz sine/square/triangle/saw.
- `full`: combined frequency, amplitude, and waveform points.

The script restores 50 MHz sine at amplitude `0x6000` by default after a live sweep.

The GUI uses the same sweep implementation. Select `quick`, `amplitude`, `wave`, or `full`, set the CSV path if needed, then click `Run Sweep`. The default GUI CSV target is:

```text
D:\FPGA\ad9144_bringup_k325t\measurements\uart_sweeps\gui_latest.csv
```

Use the GUI sweep when the oscilloscope is available and the CLI sweep when a repeatable scripted run is easier to archive.
