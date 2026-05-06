$ErrorActionPreference = "Stop"

$root = "D:\FPGA\ad9144_bringup_k325t"

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing file: $Path"
    }
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -notmatch $Pattern) {
        throw $Message
    }
}

$top = Join-Path $root "variants\awg_button\top.v"
$createButton = Join-Path $root "scripts\create_awg_button_project.tcl"
$createUart = Join-Path $root "scripts\create_awg_uart_project.tcl"
$synthUart = Join-Path $root "scripts\synth_awg_uart_direct.tcl"
$buildUart = Join-Path $root "scripts\build_awg_uart_direct.tcl"
$programUart = Join-Path $root "scripts\program_awg_uart.tcl"
$uartXdc = Join-Path $root "constraints\awg_uart_k325t.xdc"
$bridge = Join-Path $root "rtl\awg\ad9144_uart_reg_bridge.v"
$uartRx = Join-Path $root "rtl\awg\uart_rx.v"
$uartTx = Join-Path $root "rtl\awg\uart_tx.v"
$tool = Join-Path $root "tools\awg_uart_control.py"
$protocol = Join-Path $root "docs\ad9144_uart_control_protocol.md"
$checklist = Join-Path $root "docs\next_board_session_checklist.md"

Assert-FileContains $top 'AWG_UART_CONTROL' "top.v does not contain the UART compile gate."
Assert-FileContains $top 'input\s+uart_rxd' "top.v does not expose uart_rxd under the UART gate."
Assert-FileContains $top 'output\s+uart_txd' "top.v does not expose uart_txd under the UART gate."
Assert-FileContains $top 'ad9144_uart_reg_bridge\s*#' "top.v does not instantiate ad9144_uart_reg_bridge."
Assert-FileContains $top '\.cfg_wr_en\s*\(\s*awg_cfg_wr_en\s*\)' "Register bank write enable is not connected to the UART bridge mux."
Assert-FileContains $top 'assign\s+awg_cfg_wr_en\s*=\s*1''b0' "Button build fallback does not tie cfg_wr_en low."
Assert-FileContains $top 'assign\s+led\s*=\s*awg_reg_use_control\s*\?' "UART build does not expose register-control state on LEDs."

Assert-FileContains $bridge 'module\s+ad9144_uart_reg_bridge' "Missing UART register bridge module."
Assert-FileContains $bridge 'W aa dddddddd' "UART bridge does not document write command format."
Assert-FileContains $bridge 'R aa' "UART bridge does not document read command format."
Assert-FileContains $bridge 'cfg_wr_en\s*<=\s*1''b1' "UART bridge never emits cfg_wr_en."
Assert-FileContains $bridge 'cfg_rd_en\s*<=\s*1''b1' "UART bridge never emits cfg_rd_en."
Assert-FileContains $bridge 'SEND_DATA' "UART bridge does not implement readback responses."

Assert-FileContains $uartRx 'module\s+uart_rx' "Missing uart_rx module."
Assert-FileContains $uartRx 'CLKS_PER_BIT\s*=\s*CLK_HZ\s*/\s*BAUD' "uart_rx does not derive CLKS_PER_BIT from parameters."
Assert-FileContains $uartTx 'module\s+uart_tx' "Missing uart_tx module."
Assert-FileContains $uartTx 'tx_start' "uart_tx does not expose tx_start."

Assert-FileContains $createButton 'project_name' "Project creator is not parameterized for project_name."
Assert-FileContains $createButton 'verilog_define' "Project creator does not pass Verilog defines."
Assert-FileContains $createButton 'extra_constraints' "Project creator does not support extra constraints."
Assert-FileContains $createUart 'AWG_UART_CONTROL' "UART project script does not set AWG_UART_CONTROL."
Assert-FileContains $createUart 'vivado_awg_uart' "UART project script does not use a separate project directory."
Assert-FileContains $synthUart 'create_awg_uart_project.tcl' "UART synth script does not source the UART project."
Assert-FileContains $buildUart 'top_awg_uart.bit' "UART build script does not write top_awg_uart.bit."
Assert-FileContains $programUart 'top_awg_uart.bit' "UART program script does not program top_awg_uart.bit."

Assert-FileContains $uartXdc 'PACKAGE_PIN\s+T23\s+\[get_ports uart_rxd\]' "UART RX pin constraint is missing or wrong."
Assert-FileContains $uartXdc 'PACKAGE_PIN\s+T22\s+\[get_ports uart_txd\]' "UART TX pin constraint is missing or wrong."
Assert-FileContains $tool 'phase_inc_from_frequency' "Host tool does not implement frequency conversion."
Assert-FileContains $tool 'ADDR_CONTROL' "Host tool does not know the control register."
Assert-FileContains $protocol 'W <addr_hex_2> <data_hex_8>' "Protocol doc does not describe write format."
Assert-FileContains $checklist 'program_awg_uart.tcl' "Board checklist does not mention UART programming."

Write-Host "AD9144 AWG UART control wiring check PASS"
