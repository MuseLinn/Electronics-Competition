# AD9144 AWG Phase Handoff - 2026-05-07

This is the handoff note for the current K325T + FMCADDA-9250-9144 AWG bring-up phase.

## Verified State

Current working chain:

```text
PC GUI/CLI -> CH340 UART -> K325T UART bridge -> AWG register bank
  -> ad9144_awg_dds4 -> JESD204 TX -> AD9144 -> OUT1
```

Observed on board:

- UART communication works through `USB-SERIAL CH340 (COM7)` on the current laptop.
- `Read Status` returns `ID=0x41574731` and `VERSION=0x20260507`.
- Register-control mode works with `CONTROL=0x00000003`.
- OUT1 responds to frequency, amplitude, and waveform changes.
- The user observed the expected frequency, amplitude, and sine/square/triangle/saw waveform changes on the oscilloscope.
- Coarse sine sweep looked broadly normal through 300 MHz.
- At 400 MHz the oscilloscope counter appeared to jump, but FPGA readback stayed stable at:

```text
PHASE_INC=0x666666666666
AMPLITUDE=0x6000
WAVE_MODE=0
CONTROL=0x00000003
```

Current classification: the 400 MHz jump is oscilloscope counter/trigger/measurement behavior, not FPGA register instability.

## Environment

| Item | Value |
|---|---|
| Vivado | `D:\vivado\Vivado\2024.1` |
| Vivado launcher | `D:\vivado\Vivado\2024.1\bin\vivado.bat` |
| Target part | `xc7k325tffg900-2` |
| Board | 正点原子 K7-325T |
| FMC card | FMCADDA-9250-9144 |
| UART seen on current laptop | `COM7` |
| UART baud | 115200 8N1 |
| Known baseline output | 50 MHz sine, amplitude `0x6000`, `WAVE_MODE=0` |

Always re-detect the COM port on a different PC:

```powershell
Get-PnpDevice -PresentOnly -Class Ports
```

## Source Layout

Tracked source and docs:

```text
ad9144_bringup_k325t/
  README.md
  constraints/
  docs/
  ip_data/sine.coe
  rtl/awg/
  scripts/
  tools/
  variants/awg_button/top.v
```

Key RTL:

- `rtl/awg/ad9144_awg_dds4.v`: 4-sample-per-beat DDS/waveform generator.
- `rtl/awg/ad9144_awg_reg_bank.v`: register bank for frequency, phase, amplitude, offset, and waveform mode.
- `rtl/awg/ad9144_uart_reg_bridge.v`: ASCII UART register protocol bridge.
- `rtl/awg/uart_rx.v`, `rtl/awg/uart_tx.v`: UART primitives.

Key host tools:

- `tools/awg_uart_panel.py`: Tkinter GUI.
- `tools/awg_uart_control.py`: CLI register control.
- `tools/awg_uart_sweep.py`: repeatable UART sweep CSV generation.
- `tools/awg_wave_quality.py`: digital waveform FFT self-check.
- `tools/awg_scope_measurement.py`: oscilloscope measurement template/report utility.

## Build And Program

Build UART-control bitstream:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl
```

Program UART-control bitstream:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_uart.tcl
```

After programming, wait 12-15 seconds before using UART tools.

The generated local bit path is:

```text
D:\FPGA\ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart.bit
```

That bit file is intentionally ignored by Git.

## GUI Operation

Start:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_panel.py
```

Recommended first action:

1. Select the detected COM port.
2. Click `Read Status`.
3. Confirm `ID=0x41574731`.
4. Enter:

```text
Frequency Hz: 50000000
Sample Rate: 1000000000
Amplitude: 0x6000
Offset: 0
Phase deg: 0
Wave: sine
```

5. Click `Apply Preset`.

## Measurement Tools

Digital quick check:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_wave_quality.py --profile quick --out D:\FPGA\ad9144_bringup_k325t\reports\wave_quality\quick_latest.csv
```

Known digital quick baseline at 1 GSa/s, 20,000 samples:

```text
10 MHz sine  -> THD -69.32 dBc, largest non-harmonic spur -77.89 dBc
50 MHz sine  -> THD -68.70 dBc, largest non-harmonic spur -75.48 dBc
100 MHz sine -> THD -66.84 dBc, largest non-harmonic spur -325.22 dBc
```

Scope measurement template:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_scope_measurement.py template --profile freq_response
```

Repeatable sweep:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py --port COM7 --profile quick --settle 0.05 --out D:\FPGA\ad9144_bringup_k325t\measurements\uart_sweeps\quick_latest.csv
```

## Known Limitations

- The UART bit is a bring-up/demo artifact, not a final timing-clean competition release.
- Earlier routed UART builds had known setup timing violations; check current build logs before treating it as final.
- Bitstreams, Vivado outputs, measurements, and reports are ignored by Git. Rebuild or regenerate them locally.
- `COM7` is only the current laptop's port assignment; other machines may differ.
- The 400 MHz observation is currently instrument-side, but high-frequency analog output still needs real Vpp/THD/spur measurement with suitable scope/spectrum setup.
- The current design assumes a 1 GSa/s sample-rate model for host-side frequency words.

## Recommended Next Work

1. Make the UART-control build timing-clean, or isolate/waive only justified debug paths.
2. Fill the scope measurement templates with real Vpp/frequency observations.
3. Add spectrum-analyzer measurements for THD and non-harmonic spur.
4. Start an amplitude calibration table based on measured Vpp versus `AMPLITUDE`.
5. Extend host control toward competition workflow: waveform files, presets, sweep plans, and saved calibration profiles.
6. Decide whether final architecture stays in this standalone AD9144 project or merges back into `D:\awg_fpga` after the high-speed path is stable.
