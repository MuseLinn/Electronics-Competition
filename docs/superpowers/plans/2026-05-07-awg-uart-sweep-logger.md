# AWG UART Sweep Logger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a command-line sweep/logger that programs the verified AD9144 UART AWG registers across known test points and writes a CSV record for later oscilloscope correlation.

**Architecture:** Reuse `awg_uart_control.py` as the single UART/register protocol layer. Keep the sweep tool PC-side only, with dry-run support for CI-style checks and a live mode for `COM7` hardware validation.

**Tech Stack:** Python 3, pyserial, CSV, Vivado/FPGA docs only for handoff.

---

### Task 1: Sweep Logger Tool

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py`
- Modify: `D:\FPGA\ad9144_bringup_k325t\docs\awg_uart_panel.md`

- [x] **Step 1: Implement the sweep command**

Create a CLI with `--port`, `--out`, `--dry-run`, `--settle`, and default test points covering sine frequency sweep, amplitude sweep, and waveform-mode sweep.

- [x] **Step 2: Write CSV rows**

Each row must include timestamp, port, target frequency, target amplitude, target waveform, phase increment, readback control/status/frequency/amplitude/waveform, and a `scope_note` column for later manual annotation.

- [x] **Step 3: Restore safe output**

By default, restore 50 MHz sine, amplitude `0x6000`, register-control enabled at the end of the sweep.

### Task 2: Verification

**Files:**
- Test: `D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py`

- [x] **Step 1: Compile Python**

Run:

```powershell
python -m py_compile D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py
```

- [x] **Step 2: Dry run**

Run:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py --dry-run --out C:\tmp\awg_sweep_dry.csv
```

Expected: CSV file exists with planned rows and no serial access.

- [x] **Step 3: Live status**

Run:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 status
```

Expected: `ID=0x41574731`.

- [x] **Step 4: Short live sweep**

Run:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py --port COM7 --profile quick --out D:\FPGA\ad9144_bringup_k325t\measurements\uart_sweeps\quick_latest.csv
```

Expected: CSV file exists and final status returns to 50 MHz sine.

### Result

- Dry run wrote `C:\tmp\awg_sweep_dry.csv`.
- Live quick sweep wrote `D:\FPGA\ad9144_bringup_k325t\measurements\uart_sweeps\quick_latest.csv`.
- Readbacks matched target phase increments for 10 MHz, 50 MHz, and 100 MHz sine.
- Final board readback returned to 50 MHz sine:
  `CONTROL=0x00000003`, `PHASE_INC=0x0CCCCCCCCCCD`, `AMPLITUDE=0x6000`, `WAVE_MODE=0`.
