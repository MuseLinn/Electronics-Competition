# AWG Phase Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the current AD9144 AWG bring-up phase so another engineer can clone the repo, understand the verified state, rebuild/program the design, and continue measurement work without reading the full chat history.

**Architecture:** Add a concise project entry README, a detailed phase handoff note, and update the durable agent/Obsidian handoff surfaces. Do not commit Vivado generated outputs, bitstreams, reports, or local measurement CSVs.

**Tech Stack:** Markdown documentation, existing Python tools, Vivado 2024.1 scripts, Git.

---

### Task 1: Project Entry Points

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\README.md`
- Create: `D:\FPGA\ad9144_bringup_k325t\docs\phase_handoff_2026-05-07.md`

- [x] **Step 1: Add a short README**

List the active target, known-good bitstream build script, programming command, GUI command, and docs index.

- [x] **Step 2: Add a detailed handoff**

Record the verified board behavior, environment, tracked source layout, generated artifact policy, known limitations, and recommended next tasks.

### Task 2: Existing Handoff Surfaces

**Files:**
- Modify: `D:\FPGA\AGENTS.md`
- Modify: `D:\FPGA\ad9144_bringup_k325t\docs\next_board_session_checklist.md`
- Modify: `D:\awg_fpga\obsidian\02-模块设计\AD9144 UART Control.md`

- [x] **Step 1: Update AGENTS**

Append the phase handoff location and current next actions.

- [x] **Step 2: Update the board checklist**

Make COM7 and the GUI flow explicit while still telling future users to re-detect the COM port.

- [x] **Step 3: Update Obsidian**

Mirror the same current-state summary for the local notes vault.

### Task 3: Verification And Git

- [x] **Step 1: Run Python tool checks**

Run `py_compile` for all AD9144 host tools and smoke the GUI import.

- [x] **Step 2: Run generated-report checks**

Run dry-run/template/report commands to make sure the documented tool flow still works.

- [x] **Step 3: Check diffs**

Run `git diff --check` on the staged source/docs. Confirm generated files remain untracked/ignored.

- [x] **Step 4: Commit and push**

Commit the documentation wrap-up to `main`, then push. If Obsidian is a separate checkout state, commit/rebase/push it too.
