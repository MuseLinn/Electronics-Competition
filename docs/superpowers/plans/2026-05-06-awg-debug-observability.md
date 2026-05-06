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

- [ ] Create a small LED mux that shows `ui_mode` briefly after control changes, then returns to waveform indication.
- [ ] Add it to the board top.
- [ ] Simulate mode-change and timeout behavior.

### Task 2: Conditional ILA Debug Top

**Files:**
- Modify: `D:\awg_fpga\rtl\top\awg_dds_led_top.v`
- Create: `D:\awg_fpga\scripts\rebuild_awg_debug.tcl`

- [ ] Add an `AWG_DEBUG_ILA` guarded `ila_awg_debug` instance.
- [ ] Generate/configure the ILA IP in Tcl.
- [ ] Build and copy `awg_dds_led_top_debug.bit`.

### Task 3: Hardware Capture Script

**Files:**
- Create: `D:\awg_fpga\scripts\program_and_capture_awg_debug.tcl`

- [ ] Program `awg_dds_led_top_debug.bit`.
- [ ] Find available hw_ila cores.
- [ ] Run captures and export CSV to `D:\awg_fpga\measurements\ila`.

### Task 4: Verification

- [ ] Run LED status simulation.
- [ ] Run existing key UI simulation.
- [ ] Run existing AWG core simulation.
- [ ] Build debug bitstream with Vivado 2024.1.
