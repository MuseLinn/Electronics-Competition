# RTL 模块速查

> **Scope**: `rtl/` 目录下的 Verilog RTL 源码
> **Parent**: 详见根目录 `AGENTS.md` 的完整模块文档（第 4 章、第 13-23 章）

---

## 目录结构

```
rtl/
├── top/          # 顶层模块
├── dds/          # 数字频率合成
├── dsp/          # 数字信号处理（波形选择、幅度/偏置）
├── control/      # 按键 UI 与 LED 状态
├── dac/          # DAC 接口（AD9144 SPI）
├── sweep/        # 扫频引擎
├── wave/         # BRAM 波形存储
├── fmc/          # FMC 子卡（JESD204、SPI 配置、vendor demo）
└── clk/          # 时钟芯片 SPI 控制
```

---

## 模块速查

| 模块 | 路径 | 功能 | 对应 Testbench |
|------|------|------|----------------|
| `awg_dds_led_top` | `top/` | 基础 AWG 顶层（LED 指示） | — |
| `awg_fmc_adda_top` | `top/` | FMC ADDA 顶层 stub（JESD204 预留） | — |
| `awg_core` | `dsp/` | 统一前端：DDS + 波形选择 + 幅度/偏置 | `tb_awg_core` |
| `amp_offset_scale` | `dsp/` | Q15 幅度缩放 + 偏移 + 饱和 | — |
| `sample_mux` | `dsp/` | 7 模式波形选择器 | — |
| `dds_compiler_wrapper` | `dds/` | Xilinx DDS Compiler v6.0 封装 | `tb_dds_compiler` |
| `dds_nco` | `dds/` | 手写的 64bit 相位累加器 | — |
| `sine_lut` | `dds/` | 4096x16bit 正弦 ROM | — |
| `wave_shape_gen` | `dds/` | 组合逻辑方波/三角波/锯齿波 | — |
| `awg_key_ui_ctrl` | `control/` | 2 键消抖 UI 控制器 | `tb_awg_key_ui_ctrl` |
| `awg_led_status` | `control/` | LED 模式指示 | `tb_awg_led_status` |
| `sweep_engine` | `sweep/` | 线性扫频引擎 | — |
| `bram_wave_player` | `wave/` | BRAM 任意波形播放器 | — |

---

## 编码约定

- **命名**: 小写 + 下划线；模块前缀 `awg_` / `ad9144_` / `lmk04828_`；testbench 前缀 `tb_`
- **复位**: 统一 `rst_n`，低电平有效异步复位：`always @(posedge clk or negedge rst_n)`
- **时钟**: 差分时钟必须 `IBUFDS -> BUFG`，禁止直连差分信号到逻辑
- **文件头**: 每文件开头 `` `timescale 1ns / 1ps ``，随后中文功能说明块
- **端口**: 显式声明 `input wire` / `output wire` / `output reg`

## 反模式

- ❌ 跳过 `IBUFDS + BUFG`
- ❌ 使用单端时钟端口（导致 DRC NSTD-1 / UCIO-1）
- ❌ 省略 `IOSTANDARD` 约束
- ❌ 使用 Vivado 2024.2（JESD204 不支持 7 系列）
- ❌ 硬编码 `D:/awg_fpga` 路径到脚本

## 仿真入口

```powershell
# 一键运行 testbench（位于 sim/work/）
.\sim\work\run_awg_core_sim.ps1
.\sim\work\run_awg_key_ui_ctrl_sim.ps1
```

## 综合入口

```powershell
# 基础 AWG bitstream
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source .\scripts\rebuild_awg_base.tcl

# Debug ILA 版本
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source .\scripts\rebuild_awg_debug.tcl
```
