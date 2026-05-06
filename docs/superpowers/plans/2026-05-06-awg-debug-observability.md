# AWG Debug Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a no-oscilloscope debug path for the current K325T AWG demo.

**Architecture:** Keep the normal AWG path intact, add LED status feedback in RTL, and conditionally instantiate a Vivado ILA when `AWG_DEBUG_ILA` is defined. Provide Tcl scripts to rebuild a debug bit and capture selected signals through Hardware Manager.

**Tech Stack:** Verilog, Vivado 2024.1 Tcl, Xilinx ILA IP, K325T `xc7k325tffg900-2`.

---

### Task 1: LED Status Feedback

**Files:**
- Create: `D:\awg_fpga\rtl\control\awg_led_status.v`
- Modify: `D:\awg_fpga\rtl\top\awg_dds_led_top.v`
- Test: `D:\awg_fpga\sim\tb\tb_awg_led_status.v`

- [x] Create a small LED mux that shows `ui_mode` briefly after control changes, then returns to waveform indication.
- [x] Add it to the board top.
- [x] Simulate mode-change and timeout behavior.

### Task 2: Conditional ILA Debug Top

**Files:**
- Modify: `D:\awg_fpga\rtl\top\awg_dds_led_top.v`
- Create: `D:\awg_fpga\scripts\rebuild_awg_debug.tcl`

- [x] Add an `AWG_DEBUG_ILA` guarded `ila_awg_debug` instance.
- [x] Generate/configure the ILA IP in Tcl.
- [x] Build and copy `awg_dds_led_top_debug.bit` and `.ltx` to `D:\awg_fpga\artifacts\debug`.

### Task 3: Hardware Capture Script

**Files:**
- Create: `D:\awg_fpga\scripts\program_and_capture_awg_debug.tcl`

- [x] Program script created with target retry and clear failure messages.
- [x] Program `awg_dds_led_top_debug.bit`.
- [x] Find available hw_ila cores.
- [x] Run captures and export CSV to `D:\awg_fpga\measurements\ila`.

Result: after the board power was turned back on, Vivado detected `xc7k325t_0`, programmed the debug bit, found `hw_ila_1`, and exported `D:\awg_fpga\measurements\ila\capture_20260506_181837\hw_ila_1.csv`.

Important fix: set `BSCAN_SWITCH_USER_MASK=1` before/after programming so Hardware Manager can detect `dbg_hub` on user scan chain 1.

### Task 4: Verification

- [x] Run LED status simulation.
- [x] Run existing key UI simulation.
- [x] Run existing AWG core simulation.
- [x] Build debug bitstream with Vivado 2024.1.
- [x] Rebuild normal bitstream after debug build to restore non-debug `awg_dds_led_top.bit`.
