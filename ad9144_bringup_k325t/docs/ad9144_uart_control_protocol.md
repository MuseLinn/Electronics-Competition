# AD9144 AWG UART Control Protocol

This protocol is for the UART-control variant of the K325T AD9144 AWG bring-up design.

## Electrical And Runtime Assumptions

- UART pins: `uart_rxd -> T23`, `uart_txd -> T22`, `LVCMOS33`.
- Line format: 115200 baud, 8 data bits, no parity, 1 stop bit.
- The UART bridge runs in the AD9144 TX core clock domain. Send commands after the board has been programmed and the AD9144 startup sequence has had 12-15 seconds to settle.
- The current button demo remains the default behavior until register control is enabled with `CONTROL[1]=1`.

## Command Format

Commands are ASCII lines ending in `\n` or `\r\n`.

```text
W <addr_hex_2> <data_hex_8>
R <addr_hex_2>
```

Examples:

```text
R 00
W 08 00000003
W 10 CCCCCCCD
W 14 00000CCC
W 2C 00000001
```

Responses:

```text
OK
D 41574731
ERR
```

## Register Map

| Address | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `ID` | R | `0x41574731` (`AWG1`) |
| `0x04` | `VERSION` | R | Register block version |
| `0x08` | `CONTROL` | R/W | bit0 `output_enable`, bit1 `use_reg_control` |
| `0x0C` | `STATUS` | R | link/status bits |
| `0x10` | `PHASE_INC_LO` | R/W | DDS phase increment `[31:0]` |
| `0x14` | `PHASE_INC_HI` | R/W | DDS phase increment `[47:32]` |
| `0x18` | `PHASE_OFFSET_LO` | R/W | phase offset `[31:0]` |
| `0x1C` | `PHASE_OFFSET_HI` | R/W | phase offset `[47:32]` |
| `0x20` | `AMPLITUDE` | R/W | unsigned Q15 amplitude |
| `0x24` | `OFFSET` | R/W | signed 16-bit offset |
| `0x28` | `WAVE_MODE` | R/W | `0=sine`, `1=square`, `2=triangle`, `3=saw` |
| `0x2C` | `APPLY` | W | toggles update marker |
| `0x30` | `BUTTON_STATE` | R | current button UI state |
| `0x38` | `OUTPUT_EN` | R/W | compatibility alias of `CONTROL[0] output_enable` |
| `0x3C` | `CAL_ENABLE` | R/W | bit0 enables digital calibration |
| `0x40`-`0x7C` | `CAL_TABLE[0:15]` | R/W | `{signed offset[15:0], unsigned Q1.15 gain[15:0]}` |

## Frequency Formula

The AD9144 DDS4 path emits four DAC samples per TX core clock. The host utility therefore uses a default effective sample rate of `1_000_000_000` samples/s.

```text
phase_inc = round(f_out * 2^48 / sample_rate)
f_out     = phase_inc * sample_rate / 2^48
```

Known example:

```text
50 MHz -> phase_inc = 0x0CCCCCCCCCCD
```

## Safe Bring-Up Sequence

1. Program the known-good button bit first if the board state is uncertain.
2. Program the UART variant only after the button path has been shown to work recently.
3. Wait 12-15 seconds after programming before sending UART commands.
4. Read `ID` with `R 00`; expect `D 41574731`.
5. Write frequency/amplitude/waveform registers.
6. Write `CONTROL=0x00000003` to enable output and switch from button control to register control.
7. Write `APPLY=1`.
8. Check OUT1 on the oscilloscope.

To fall back to physical buttons without reprogramming:

```text
W 08 00000001
```

## Current Build Artifact

```text
D:\FPGA\ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart.bit
```

Build log:

```text
C:\tmp\vivado_awg_uart.log
```

Vivado generated the bitstream successfully on 2026-05-07. The routed timing report still has setup violations (`WNS=-3.330ns`, `TNS=-3948.764ns`, hold clean), so this artifact is for bring-up and UART-control validation only.

The log also contains a non-blocking `blk_mem_gen_0` locked-IP critical warning. Treat it as a cleanup item unless bit generation fails.
