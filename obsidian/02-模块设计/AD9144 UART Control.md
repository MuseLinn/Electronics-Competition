---
type: module
updated: 2026-05-07
tags:
  - ad9144
  - uart
  - awg
  - register-control
---

# AD9144 UART Control

This note records the PC-control bring-up variant for the K325T AD9144 AWG path.

## Purpose

The user-confirmed button waveform demo remains the fallback baseline. The UART variant adds a PC-side register-control path so frequency, amplitude, phase, waveform, and output enable can be changed without recompiling FPGA logic.

## Key Files

```text
D:\FPGA\ad9144_bringup_k325t\docs\ad9144_uart_control_protocol.md
D:\FPGA\ad9144_bringup_k325t\docs\next_board_session_checklist.md
D:\FPGA\ad9144_bringup_k325t\rtl\awg\uart_rx.v
D:\FPGA\ad9144_bringup_k325t\rtl\awg\uart_tx.v
D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_uart_reg_bridge.v
D:\FPGA\ad9144_bringup_k325t\constraints\awg_uart_k325t.xdc
D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py
```

## Build And Program

Build:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl
```

Program:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_uart.tcl
```

Generated bit:

```text
D:\FPGA\ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart.bit
```

## UART Protocol

- 115200 baud, 8N1.
- Read: `R <addr_hex_2>`.
- Write: `W <addr_hex_2> <data_hex_8>`.
- Expected ID: `R 00` returns `D 41574731`.
- Enable register control: `W 08 00000003`.
- Return to button control: `W 08 00000001`.

## Host Smoke Test

After programming, wait 12-15 seconds for AD9144 startup.

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM3 status
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM3 preset --frequency 50000000 --amplitude 0x6000 --wave sine
```

If the COM port is not `COM3`, list ports:

```powershell
Get-PnpDevice -PresentOnly -Class Ports
```

## Status

- UART bit generated on 2026-05-07.
- Bitstream write succeeded.
- Build log has a non-blocking `blk_mem_gen_0` locked-IP critical warning.
- Timing is not final-clean: route log reports setup violations around `WNS=-3.330ns`, `TNS=-3948.764ns`; hold is clean.
- Use this as a controlled bring-up artifact, then clean CDC/reset/debug timing before final competition measurements.
