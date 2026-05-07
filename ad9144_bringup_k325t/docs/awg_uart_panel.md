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
