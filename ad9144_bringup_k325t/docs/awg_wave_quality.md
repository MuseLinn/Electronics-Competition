# AD9144 AWG Digital Wave Quality Check

`awg_wave_quality.py` is a PC-side digital self-check for the current AD9144 AWG sample generator. It does not replace oscilloscope or spectrum-analyzer measurements, but it catches obvious NCO, waveform mode, amplitude scaling, saturation, and lookup-table problems before board time.

## Command

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_wave_quality.py --profile quick --out D:\FPGA\ad9144_bringup_k325t\reports\wave_quality\quick_latest.csv
```

Profiles match the UART sweep tool:

- `quick`: 10 MHz, 50 MHz, 100 MHz sine.
- `amplitude`: 50 MHz sine at several amplitudes.
- `wave`: 50 MHz sine/square/triangle/saw.
- `full`: combined frequency, amplitude, and waveform points.

## What It Models

- Four samples per FPGA beat, matching `ad9144_awg_dds4.v`.
- `phase_inc` and `phase_offset` with the same 48-bit accumulator math.
- `ad9144_sine_4096.hex` for sine mode.
- Square, triangle, and saw formulas from the RTL.
- Q15 amplitude multiplication, offset addition, and signed 16-bit saturation.

## CSV Fields

The report includes target frequency, waveform mode, peak/min/mean/RMS codes, fundamental bin/frequency, THD over harmonics 2-5, and the largest non-harmonic spur.

## Caveats

- This is a digital-code check only. It does not include AD9144 analog behavior, JESD deterministic latency, DAC output network effects, clock jitter, transformer response, or oscilloscope loading.
- Square, triangle, and saw modes intentionally contain harmonics, so their THD is not expected to look like sine mode.
- The default `--samples 20000` is coherent for the current 1 GSa/s 10/50/100 MHz checks. Use coherent sample counts when adding other exact frequency points.

## Current Quick Baseline

Validated on 2026-05-07 with the default 20,000-sample quick profile:

```text
10 MHz sine  -> THD -69.32 dBc, largest non-harmonic spur -77.89 dBc
50 MHz sine  -> THD -68.70 dBc, largest non-harmonic spur -75.48 dBc
100 MHz sine -> THD -66.84 dBc, largest non-harmonic spur -325.22 dBc
```

The very low 100 MHz non-harmonic spur is a coherent-model result, not a promise of analog output performance.
