#!/usr/bin/env python3
"""Minimal PC-side controller for the AD9144 AWG UART variant."""

from __future__ import annotations

import argparse
import sys
import time


ADDR_ID = 0x00
ADDR_VERSION = 0x04
ADDR_CONTROL = 0x08
ADDR_STATUS = 0x0C
ADDR_PHASE_INC_LO = 0x10
ADDR_PHASE_INC_HI = 0x14
ADDR_PHASE_OFFSET_LO = 0x18
ADDR_PHASE_OFFSET_HI = 0x1C
ADDR_AMPLITUDE = 0x20
ADDR_OFFSET = 0x24
ADDR_WAVE_MODE = 0x28
ADDR_APPLY = 0x2C
ADDR_BUTTON_STATE = 0x30

WAVE_NAMES = {
    "sine": 0,
    "square": 1,
    "triangle": 2,
    "saw": 3,
    "sawtooth": 3,
}


def parse_int(text: str) -> int:
    return int(text, 0)


def import_serial():
    try:
        import serial  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "pyserial is required. Install it with: python -m pip install pyserial"
        ) from exc
    return serial


class AwgUart:
    def __init__(self, port: str, baud: int, timeout: float) -> None:
        serial = import_serial()
        self.ser = serial.Serial(port=port, baudrate=baud, timeout=timeout)
        self.ser.reset_input_buffer()

    def close(self) -> None:
        self.ser.close()

    def _line(self, text: str) -> str:
        self.ser.write((text + "\n").encode("ascii"))
        self.ser.flush()
        response = self.ser.readline().decode("ascii", errors="replace").strip()
        if not response:
            raise RuntimeError(f"timeout waiting for response to {text!r}")
        if response == "ERR":
            raise RuntimeError(f"FPGA returned ERR for {text!r}")
        return response

    def write_reg(self, addr: int, data: int) -> None:
        response = self._line(f"W {addr & 0xFF:02X} {data & 0xFFFFFFFF:08X}")
        if response != "OK":
            raise RuntimeError(f"unexpected write response: {response!r}")

    def read_reg(self, addr: int) -> int:
        response = self._line(f"R {addr & 0xFF:02X}")
        if not response.startswith("D "):
            raise RuntimeError(f"unexpected read response: {response!r}")
        return int(response[2:].strip(), 16)

    def set_phase_inc(self, value: int) -> None:
        value &= (1 << 48) - 1
        self.write_reg(ADDR_PHASE_INC_LO, value & 0xFFFFFFFF)
        self.write_reg(ADDR_PHASE_INC_HI, (value >> 32) & 0xFFFF)

    def set_phase_offset(self, value: int) -> None:
        value &= (1 << 48) - 1
        self.write_reg(ADDR_PHASE_OFFSET_LO, value & 0xFFFFFFFF)
        self.write_reg(ADDR_PHASE_OFFSET_HI, (value >> 32) & 0xFFFF)


def phase_inc_from_frequency(freq_hz: float, sample_rate: float) -> int:
    if freq_hz < 0:
        raise ValueError("frequency must be non-negative")
    return int(round(freq_hz * (1 << 48) / sample_rate)) & ((1 << 48) - 1)


def phase_offset_from_degrees(degrees: float) -> int:
    return int(round((degrees % 360.0) * (1 << 48) / 360.0)) & ((1 << 48) - 1)


def print_status(dev: AwgUart) -> None:
    reg_id = dev.read_reg(ADDR_ID)
    version = dev.read_reg(ADDR_VERSION)
    control = dev.read_reg(ADDR_CONTROL)
    status = dev.read_reg(ADDR_STATUS)
    button = dev.read_reg(ADDR_BUTTON_STATE)
    phase_lo = dev.read_reg(ADDR_PHASE_INC_LO)
    phase_hi = dev.read_reg(ADDR_PHASE_INC_HI)
    amplitude = dev.read_reg(ADDR_AMPLITUDE)
    wave = dev.read_reg(ADDR_WAVE_MODE)
    phase_inc = ((phase_hi & 0xFFFF) << 32) | phase_lo

    print(f"ID=0x{reg_id:08X}")
    print(f"VERSION=0x{version:08X}")
    print(f"CONTROL=0x{control:08X}")
    print(f"STATUS=0x{status:08X}")
    print(f"BUTTON_STATE=0x{button:08X}")
    print(f"PHASE_INC=0x{phase_inc:012X}")
    print(f"AMPLITUDE=0x{amplitude & 0xFFFF:04X}")
    print(f"WAVE_MODE={wave & 0x3}")


def cmd_read(args: argparse.Namespace) -> None:
    dev = AwgUart(args.port, args.baud, args.timeout)
    try:
        print(f"0x{dev.read_reg(args.addr):08X}")
    finally:
        dev.close()


def cmd_write(args: argparse.Namespace) -> None:
    dev = AwgUart(args.port, args.baud, args.timeout)
    try:
        dev.write_reg(args.addr, args.data)
        print("OK")
    finally:
        dev.close()


def cmd_status(args: argparse.Namespace) -> None:
    dev = AwgUart(args.port, args.baud, args.timeout)
    try:
        print_status(dev)
    finally:
        dev.close()


def cmd_button(args: argparse.Namespace) -> None:
    dev = AwgUart(args.port, args.baud, args.timeout)
    try:
        dev.write_reg(ADDR_CONTROL, 0x00000001)
        dev.write_reg(ADDR_APPLY, 0x00000001)
        print("button control enabled")
    finally:
        dev.close()


def cmd_preset(args: argparse.Namespace) -> None:
    wave = WAVE_NAMES[args.wave]
    phase_inc = phase_inc_from_frequency(args.frequency, args.sample_rate)
    phase_offset = phase_offset_from_degrees(args.phase_deg)
    amplitude = parse_int(args.amplitude) & 0xFFFF
    offset = parse_int(args.offset) & 0xFFFF

    dev = AwgUart(args.port, args.baud, args.timeout)
    try:
        dev.set_phase_inc(phase_inc)
        dev.set_phase_offset(phase_offset)
        dev.write_reg(ADDR_AMPLITUDE, amplitude)
        dev.write_reg(ADDR_OFFSET, offset)
        dev.write_reg(ADDR_WAVE_MODE, wave)
        dev.write_reg(ADDR_CONTROL, 0x00000003)
        dev.write_reg(ADDR_APPLY, 0x00000001)
        time.sleep(0.05)
        print(f"phase_inc=0x{phase_inc:012X}")
        print(f"phase_offset=0x{phase_offset:012X}")
        print("register control enabled")
        print_status(dev)
    finally:
        dev.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Control the AD9144 AWG UART variant.")
    parser.add_argument("--port", required=True, help="Windows COM port, for example COM3")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=1.0)

    sub = parser.add_subparsers(dest="command", required=True)

    read = sub.add_parser("read", help="Read one register")
    read.add_argument("addr", type=parse_int)
    read.set_defaults(func=cmd_read)

    write = sub.add_parser("write", help="Write one register")
    write.add_argument("addr", type=parse_int)
    write.add_argument("data", type=parse_int)
    write.set_defaults(func=cmd_write)

    status = sub.add_parser("status", help="Read key status registers")
    status.set_defaults(func=cmd_status)

    button = sub.add_parser("button", help="Return to physical button control")
    button.set_defaults(func=cmd_button)

    preset = sub.add_parser("preset", help="Program a waveform preset and enable register control")
    preset.add_argument("--frequency", type=float, default=50_000_000.0)
    preset.add_argument("--sample-rate", type=float, default=1_000_000_000.0)
    preset.add_argument("--amplitude", default="0x6000")
    preset.add_argument("--offset", default="0")
    preset.add_argument("--phase-deg", type=float, default=0.0)
    preset.add_argument("--wave", choices=sorted(WAVE_NAMES), default="sine")
    preset.set_defaults(func=cmd_preset)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
