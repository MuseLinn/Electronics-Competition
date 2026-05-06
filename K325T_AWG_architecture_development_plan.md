# K325T AWG Architecture Development Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于正点原子 K7-325T 开发板完成研电赛优利德赛题二“任意波形信号发生器”的 FPGA 数字基带、控制、缓存、扫频和 DAC 接口开发，并为外部高速 DAC 与模拟输出链路预留可落地接口。

**Architecture:** K325T 不直接承担 5GSa/s、14bit、1GHz 带宽的模拟输出，而是承担 DDS/NCO、任意波形播放、扫频、幅度/偏置校准、DDR3 波形缓存、PCIe/以太网控制和高速 DAC 数字接口。最终系统由 PC 控制端、K325T 数字基带、外部高速 DAC、低抖动时钟、重构滤波、宽带放大/衰减和 50Ω 输出链路共同完成指标。

**Tech Stack:** Vivado 2024.2 或 Vivado 2023.1、Verilog、Xilinx/AMD DDS Compiler 可选、Clocking Wizard、MIG DDR3、AXI/AXI-Lite、PCIe XDMA、ILA/VIO、正点原子 K7-325T 例程、外部高速 DAC 子板。

当前实现进度：`D:\awg_fpga\rtl\dsp\awg_core.v` 已把 DDS / 波形选择 / 幅度 / 偏置串成统一前端，并已接入 `D:\awg_fpga\rtl\top\awg_dds_led_top.v`；`D:\awg_fpga\sim\tb\tb_awg_core.v` 对拍通过。下一步是把这些固定常量替换成寄存器或按键控制，再上板确认 DAC 输出。

---

## 1. 项目结论

K325T 适合做赛题二的数字核心，不适合单板直接输出赛题要求的模拟信号。比赛指标中的 `5GSa/s`、`14bit`、`1GHz` 模拟带宽、`50Ω`、`10mVpp 到 3Vpp`、谐波和杂散指标，必须依赖外部高速 DAC、低抖动采样时钟、宽带模拟链路和 PCB 设计。K325T 的价值在于把数字波形做对、参数控制做稳、缓存和接口做通，并给高速 DAC 提供连续、可校准、可验证的数据流。

当前必须先解决 Vivado license。你们已经遇到：

```text
A valid license was not found for feature 'Synthesis' and/or device 'xc7k325t'
```

这说明当前 Vivado 环境不能综合 `XC7K325T`。在合法 license 未解决前，只能下载已有 bit 文件，不能生成新 bitstream。正式开发要使用学校/实验室/企业购买的 Vivado 授权，或 AMD 官方评估授权。不要使用来源不明的第三方 license。

## 2. 赛题指标拆解

| 指标 | FPGA 内部任务 | 外部硬件任务 | 验收方法 |
|---|---|---|---|
| 采样率不低于 5GSa/s | 输出并行样本流或高速串行数据流，保证数据连续 | 选择 5GSa/s 以上 DAC，提供低抖动采样时钟 | 示波器/频谱仪确认 DAC 采样率和输出频谱 |
| 带宽不低于 1GHz | 产生 1GHz 正弦对应的数字样本序列 | DAC、重构滤波、放大器、PCB 走线满足 1GHz | 频响扫描，记录 1MHz 到 1GHz 幅度平坦度 |
| 垂直分辨率不低于 14bit | 内部通路按 16bit 或 18bit 保留余量 | DAC 有效位数、噪声、线性度满足要求 | 用频谱仪和示波器测量噪声与失真 |
| 正弦最小频率不大于 1mHz | 使用 48bit 或 64bit 相位累加器 | 低频输出时模拟链路不能漂移过大 | 长时间测量周期或读取相位累加状态 |
| 最高频率不低于 1GHz | 支持高相位增量和高速 DAC 数据输出 | DAC、时钟、模拟链路满足射频带宽 | 频谱仪测 1GHz 基波 |
| 频率分辨率不大于 1mHz | `phase_inc = round(f_out * 2^N / f_sample)`，N 推荐 48 或 64 | 高精度参考时钟 | 计算验证和实测频点验证 |
| 谐波失真优于 -40dBc | 控制截断、量化、幅度缩放失真 | DAC SFDR、时钟相噪、模拟线性度 | 频谱仪测 THD |
| 非谐波杂散优于 -60dBc | 相位抖动、截断杂散、波形表质量控制 | 时钟相噪、电源、PCB 串扰控制 | 频谱仪测 SFDR |
| 50Ω 输出，10mVpp 到 3Vpp | 寄存器控制幅度/偏置/开关/校准表 | 可变增益、衰减、输出驱动、保护 | 示波器 50Ω 端接测量 |
| 线性/对数扫频 | FPGA 扫频状态机实时更新 `phase_inc` | 模拟链路保持扫频平坦 | 示波器/频谱仪扫频模式验证 |

## 3. 本地资料使用边界

| 资源 | 路径 | 用法 |
|---|---|---|
| 赛题 PDF | `D:\FPGA\第二十一届研电赛优利德命题 (1).pdf` | 作为指标和交付要求来源 |
| K7 FPGA 开发指南 | `D:\FPGA\【正点原子】Kintex7资料\【正点原子】Kintex7开发板资料盘（A盘）\2_文档教程\【正点原子】Kintex7之FPGA开发指南V1.3.pdf` | 板卡资源、上电、下载、DDR3、外设说明 |
| PCIe 开发指南 | `D:\FPGA\【正点原子】Kintex7资料\【正点原子】Kintex7开发板资料盘（A盘）\2_文档教程\【正点原子】Kintex7之PCIe开发指南(Windows系统版)_V1.3.pdf` | XDMA、驱动和上位机通信参考 |
| 管脚约束 | `D:\FPGA\【正点原子】Kintex7资料\【正点原子】Kintex7开发板资料盘（A盘）\3_开发板原理图\K7_IO.xdc` | 只按模块摘取需要的管脚，不整文件加入工程 |
| IO 表 | `D:\FPGA\【正点原子】Kintex7资料\【正点原子】Kintex7开发板资料盘（A盘）\3_开发板原理图\K7开发板IO引脚分配表.xlsx` | 核对 FMC、时钟、LED、按键、串口等管脚 |
| Verilog 例程 | `D:\FPGA\【正点原子】Kintex7资料\【正点原子】Kintex7开发板资料盘（A盘）\4_Source_Code\1_Verilog\XC7K325T.zip` | 学习时钟、ROM、FIFO、AD/DA、DDR3、SFP、UDP |
| PCIe 例程 | `D:\FPGA\【正点原子】Kintex7资料\【正点原子】Kintex7开发板资料盘（A盘）\4_Source_Code\2_PCIe\325.zip` | 复用 XDMA、PCIe to DDR、GPIO 控制思路 |

正点原子的 AD/DA 教学例程适合做低速验证，不满足最终模拟指标。`26_hs_ad_da` 使用的典型 DAC 是 8bit、125MSPS 级别，只能验证 DDS、ROM、FIFO、时序和软件控制流程。最终必须增加高速 DAC 子系统。

## 4. 顶层系统架构

```text
PC GUI / Python CLI / LabVIEW
        |
        | PCIe XDMA first, UDP fallback, UART debug only
        v
+-----------------------+
| K325T FPGA             |
|                       |
|  awg_csr_regs         |  参数寄存器、状态寄存器、中断
|  cmd_decoder          |  命令解析、参数装载、软触发
|  clk_reset            |  多时钟、复位、锁定检测
|  dds_nco              |  正弦/余弦、方波、三角、相位控制
|  sweep_engine         |  线性/对数扫频、驻留、循环
|  wave_player          |  BRAM/DDR3 任意波播放
|  ddr3_wave_buffer     |  大容量波形缓存
|  amp_offset_scale     |  幅度、偏置、限幅、输出静音
|  calibration_lut      |  幅频、幅度、偏置预校准
|  sample_mux           |  DDS/任意波/测试码型选择
|  dac_stream_formatter |  样本并行化、补码/偏移码转换
|  dac_if               |  教学 DAC / FMC DAC / JESD DAC 适配
|  status_monitor       |  错误状态、计数器、ILA 探针
+-----------------------+
        |
        | high-speed sample stream
        v
+-----------------------+
| External DAC Board     |
| DAC + clock + analog   |
| filter + VGA/attenuator|
| 50 ohm output          |
+-----------------------+
```

核心原则：

1. 数字波形链路和 DAC 物理接口分层。更换 DAC 子板时，`dds_nco`、`wave_player`、`sweep_engine`、`awg_csr_regs` 不重写。
2. 所有控制参数先进入影子寄存器，收到 `APPLY` 后在安全边界同步更新，避免输出毛刺。
3. 所有跨时钟域信号必须使用 CDC 模块，不能直接跨域采样。
4. 先用低速教学 DAC 跑通闭环，再上高速 DAC。这样调试风险最低。

## 5. 推荐工程目录

正式工程放在英文短路径：

```text
D:\awg_fpga
D:\awg_fpga\vivado
D:\awg_fpga\rtl
D:\awg_fpga\rtl\top
D:\awg_fpga\rtl\common
D:\awg_fpga\rtl\control
D:\awg_fpga\rtl\dds
D:\awg_fpga\rtl\sweep
D:\awg_fpga\rtl\wave
D:\awg_fpga\rtl\dsp
D:\awg_fpga\rtl\dac
D:\awg_fpga\rtl\debug
D:\awg_fpga\ip
D:\awg_fpga\constraints
D:\awg_fpga\sim
D:\awg_fpga\sim\tb
D:\awg_fpga\sim\models
D:\awg_fpga\scripts
D:\awg_fpga\host
D:\awg_fpga\docs
D:\awg_fpga\measurements
```

不要在中文路径、资料盘深层路径、压缩包内部路径中直接开发 Vivado 工程。

## 6. FPGA 文件划分

| 文件 | 职责 |
|---|---|
| `D:\awg_fpga\rtl\top\awg_top.v` | 顶层端口、模块连接、约束对应信号 |
| `D:\awg_fpga\rtl\dsp\awg_core.v` | 数字波形主链路封装，不包含板级管脚 |
| `D:\awg_fpga\rtl\top\awg_dds_led_top.v` | 当前板级演示顶层，接按键/LED/教学 DAC |
| `D:\awg_fpga\rtl\common\rst_sync.v` | 异步复位同步释放 |
| `D:\awg_fpga\rtl\common\pulse_sync.v` | 单周期脉冲跨时钟域 |
| `D:\awg_fpga\rtl\common\cdc_bus_latch.v` | 配置总线跨域装载 |
| `D:\awg_fpga\rtl\control\awg_csr_regs.v` | AXI-Lite/简单总线寄存器组 |
| `D:\awg_fpga\rtl\control\cmd_apply_ctrl.v` | 参数影子寄存器、应用边界、软触发 |
| `D:\awg_fpga\rtl\dds\dds_nco.v` | 48/64bit 相位累加、相位偏置、频率字更新 |
| `D:\awg_fpga\rtl\dds\sine_lut.v` | 正弦查表或 DDS Compiler 包装 |
| `D:\awg_fpga\rtl\dds\wave_shape_gen.v` | 方波、三角、锯齿、测试码型 |
| `D:\awg_fpga\rtl\sweep\sweep_engine.v` | 线性扫频、对数扫频、驻留时间和循环 |
| `D:\awg_fpga\rtl\wave\bram_wave_player.v` | 小容量任意波 BRAM 播放 |
| `D:\awg_fpga\rtl\wave\ddr3_wave_buffer.v` | DDR3 波形缓存读写仲裁 |
| `D:\awg_fpga\rtl\wave\wave_dma_bridge.v` | PCIe/AXI 到波形缓存的数据搬运 |
| `D:\awg_fpga\rtl\dsp\amp_offset_scale.v` | 幅度缩放、偏置叠加、饱和限幅 |
| `D:\awg_fpga\rtl\dsp\calibration_lut.v` | 幅频校准、幅度校准、偏置校准 |
| `D:\awg_fpga\rtl\dsp\sample_mux.v` | DDS、任意波、扫频、测试模式选择 |
| `D:\awg_fpga\rtl\dac\dac_edu_parallel_if.v` | 正点原子教学 DAC 低速验证接口 |
| `D:\awg_fpga\rtl\dac\dac_fmc_parallel_if.v` | FMC 并行 DAC 子板接口 |
| `D:\awg_fpga\rtl\dac\dac_jesd_stub.v` | JESD204 类 DAC 接口预留封装 |
| `D:\awg_fpga\rtl\dac\dac_stream_formatter.v` | 补码/偏移码、通道交织、样本打包 |
| `D:\awg_fpga\rtl\debug\status_monitor.v` | 错误计数、FIFO 水位、频率字回读 |
| `D:\awg_fpga\rtl\debug\ila_probe_bus.v` | ILA 探针集中封装 |
| `D:\awg_fpga\constraints\k325t_base.xdc` | 系统时钟、复位、LED、UART 基础约束 |
| `D:\awg_fpga\constraints\awg_dac_edu.xdc` | 教学 DAC 验证约束 |
| `D:\awg_fpga\constraints\awg_fmc_dac.xdc` | 最终 DAC 子板约束 |
| `D:\awg_fpga\docs\register_map.md` | 寄存器定义 |
| `D:\awg_fpga\docs\verification_plan.md` | 仿真、上板、仪器验证 |
| `D:\awg_fpga\docs\measurement_log.md` | 频率、幅度、THD、SFDR、平坦度记录 |

## 7. 数据格式和参数约定

| 项目 | 推荐约定 | 说明 |
|---|---|---|
| 内部样本格式 | signed 16bit 或 signed 18bit | 最终 14bit DAC 前保留余量 |
| DAC 输出格式 | 由 `dac_stream_formatter` 转换 | 支持二进制补码、offset binary、双通道交织 |
| 相位累加器 | 64bit 推荐，48bit 可作为资源优化版本 | 5GSa/s 下 48bit 分辨率约 17.8uHz，64bit 余量更大 |
| 频率字 | `phase_inc = round(f_out * 2^PHASE_W / f_sample)` | 上位机计算，FPGA 也保留回读 |
| 幅度 | unsigned Q1.15 或 Q2.14 | `0x0000` 静音，`0x7FFF` 接近满幅 |
| 偏置 | signed 16bit | 在限幅前叠加 |
| 相位偏置 | 64bit | 用于相位可控和多通道扩展 |
| 任意波地址 | 32bit sample index | 支持 BRAM 小波形和 DDR3 长波形 |
| 扫频时间 | 32bit tick count | tick 建议来自 1MHz 或 100kHz 控制定时 |

频率分辨率示例：

```text
f_sample = 5,000,000,000 Hz
PHASE_W = 48
frequency_resolution = f_sample / 2^48 = 17.763568 uHz
PHASE_W = 64
frequency_resolution = f_sample / 2^64 = 0.271051 pHz
```

## 8. 寄存器地图

寄存器基地址先按 32bit 对齐设计，后续接 AXI-Lite 或 XDMA BAR 都能使用。

| Offset | 名称 | R/W | 含义 |
|---:|---|---|---|
| `0x0000` | `CTRL` | R/W | bit0 enable，bit1 apply，bit2 soft_trigger，bit3 mute，bit4 reset_error |
| `0x0004` | `STATUS` | R | bit0 pll_locked，bit1 ddr_ready，bit2 dac_ready，bit3 underflow，bit4 overflow |
| `0x0008` | `MODE` | R/W | 0 sine，1 square，2 triangle，3 saw，4 arbitrary，5 linear sweep，6 log sweep，7 test pattern |
| `0x000C` | `SAMPLE_RATE_LO` | R/W | 采样率低 32bit，用于回读和频率字计算校验 |
| `0x0010` | `SAMPLE_RATE_HI` | R/W | 采样率高 32bit |
| `0x0014` | `PHASE_INC_0` | R/W | 频率字 bit31:0 |
| `0x0018` | `PHASE_INC_1` | R/W | 频率字 bit63:32 |
| `0x001C` | `PHASE_OFFSET_0` | R/W | 相位偏置 bit31:0 |
| `0x0020` | `PHASE_OFFSET_1` | R/W | 相位偏置 bit63:32 |
| `0x0024` | `AMPLITUDE` | R/W | 幅度缩放系数 |
| `0x0028` | `OFFSET` | R/W | 直流偏置 |
| `0x002C` | `WAVE_BASE_ADDR` | R/W | DDR3 任意波起始样本地址 |
| `0x0030` | `WAVE_LENGTH` | R/W | 任意波长度，单位 sample |
| `0x0034` | `WAVE_STEP` | R/W | 任意波播放步进，支持重采样 |
| `0x0038` | `SWEEP_START_INC_0` | R/W | 扫频起始频率字低 32bit |
| `0x003C` | `SWEEP_START_INC_1` | R/W | 扫频起始频率字高 32bit |
| `0x0040` | `SWEEP_STOP_INC_0` | R/W | 扫频终止频率字低 32bit |
| `0x0044` | `SWEEP_STOP_INC_1` | R/W | 扫频终止频率字高 32bit |
| `0x0048` | `SWEEP_STEP_INC_0` | R/W | 线性扫频步进低 32bit |
| `0x004C` | `SWEEP_STEP_INC_1` | R/W | 线性扫频步进高 32bit |
| `0x0050` | `SWEEP_DWELL_TICKS` | R/W | 每个频点驻留 tick |
| `0x0054` | `SWEEP_POINTS` | R/W | 扫频点数 |
| `0x0058` | `CAL_GAIN_INDEX` | R/W | 校准表索引 |
| `0x005C` | `CAL_GAIN_VALUE` | R/W | 校准表写入/读出值 |
| `0x0060` | `DEBUG_SELECT` | R/W | ILA/VIO/状态复用选择 |
| `0x0064` | `ERROR_COUNT` | R | 欠载、溢出、非法配置累计 |

## 9. 时钟和复位架构

| 时钟域 | 来源 | 频率建议 | 用途 |
|---|---|---:|---|
| `sys_clk` | 板载 100MHz 差分晶振，经 MMCM | 100MHz | 寄存器、状态机、低速控制 |
| `dsp_clk` | MMCM/PLL | 200MHz 或 250MHz | DDS、扫频、幅度计算、样本准备 |
| `axi_clk` | PCIe XDMA 或系统时钟 | 100MHz 到 250MHz | AXI-Lite、AXI-Stream |
| `ddr_ui_clk` | MIG 输出 | 按 MIG 配置 | DDR3 读写 |
| `dac_clk` | 外部 DAC/时钟芯片反馈或 FPGA 输出 | 按 DAC 方案 | DAC 接口 |

复位策略：

1. 外部 `sys_rst_n` 只作为异步输入。
2. 每个时钟域使用 `rst_sync.v` 同步释放。
3. `pll_locked`、`mig_init_calib_complete`、`dac_pll_locked` 进入 `status_monitor`。
4. 输出链路在所有 ready 信号有效前保持 mute。

## 10. 复用正点原子例程的路线

| 阶段 | 参考例程 | 复用内容 | 不直接复用的原因 |
|---|---|---|---|
| 板卡最小闭环 | `1_led` | Vivado 下载、管脚、JTAG、bitstream 流程 | 只是入门 |
| 时钟/IP | `13_ip_clk_wiz` | Clocking Wizard 使用方法 | 正式工程要按 AWG 时钟重新配置 |
| ROM/FIFO | `14_ip_1port_ram`、`16_ip_fifo` | 波形 ROM、跨模块缓冲 | 正式工程需要统一数据宽度和流接口 |
| 低速 AD/DA | `26_hs_ad_da` | DDS/ROM 到 DAC 的上板验证流程 | DAC 速率和位宽不满足比赛指标 |
| 双 DAC 验证 | `28_hs_dual_da` | 多通道样本同步思路 | 仍不是最终高速 DAC |
| DDR3 | `30_top_ddr3_rw` | MIG、DDR3 初始化和读写 | 要改成波形缓存和 DMA 流 |
| UDP 控制 | `56_ad_udp_pc` | 千兆网通信和上位机调试 | 正式高速下发建议 PCIe |
| 综合演示 | `57_top_ad_da_fft_lcd` | AD/DA、显示、FFT 调试经验 | 不作为最终主线 |
| SFP/GTX | `63_sfp_10g_speed`、`64_sfp_10g_eth_loop` | GTX 调试、10G 链路经验 | 最终 DAC 接口取决于 DAC 子板 |
| PCIe | `1_pcie_xdma`、`6_pcie_xdma_ddr` | XDMA、PC 到 DDR 数据通道 | 需要接入 AWG 寄存器和波形缓存 |

## 11. 开发阶段

### Task 1: 环境和 license 闭环

**Files:**
- Reference: `D:\k7\325\1_led\prj\led.xpr`
- Create: `D:\awg_fpga\docs\environment_check.md`

- [ ] **Step 1: 确认 Vivado 能综合 K325T**

打开 `D:\k7\325\1_led\prj\led.xpr`，执行：

```text
Run Synthesis
Run Implementation
Generate Bitstream
```

Expected:

```text
Synthesis completed successfully
Implementation completed successfully
write_bitstream completed successfully
```

如果仍然出现 `Common 17-345`，停止 FPGA 新代码开发，先解决合法授权。

- [ ] **Step 2: 建立英文短路径工程目录**

创建：

```text
D:\awg_fpga
D:\awg_fpga\vivado
D:\awg_fpga\rtl
D:\awg_fpga\constraints
D:\awg_fpga\sim
D:\awg_fpga\docs
```

Expected:

```text
工程路径不包含中文、空格和特殊字符
```

- [ ] **Step 3: 记录环境**

在 `D:\awg_fpga\docs\environment_check.md` 写入：

```markdown
# Environment Check

- FPGA board: 正点原子 K7-325T
- FPGA part: XC7K325TFFG900-2I
- Vivado version:
- License status:
- JTAG cable detected:
- LED example synthesis:
- LED example bitstream:
- Notes:
```

### Task 2: 新建 AWG 空工程和基础约束

**Files:**
- Create: `D:\awg_fpga\vivado\awg_k325t.xpr`
- Create: `D:\awg_fpga\constraints\k325t_base.xdc`
- Create: `D:\awg_fpga\rtl\top\awg_top.v`

- [ ] **Step 1: 新建 Vivado RTL Project**

配置：

```text
Project name: awg_k325t
Project location: D:\awg_fpga\vivado
Part: xc7k325tffg900-2
Target language: Verilog
```

Expected:

```text
Vivado Project Summary 显示 Part 为 xc7k325tffg900-2
```

- [ ] **Step 2: 写基础约束**

`D:\awg_fpga\constraints\k325t_base.xdc` 内容：

```tcl
create_clock -period 10.000 -name sys_clk_p [get_ports sys_clk_p]

set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_n]
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]

set_property -dict {PACKAGE_PIN AB25 IOSTANDARD LVCMOS33} [get_ports sys_rst_n]
set_property -dict {PACKAGE_PIN A26  IOSTANDARD LVCMOS33} [get_ports {key[0]}]
set_property -dict {PACKAGE_PIN A25  IOSTANDARD LVCMOS33} [get_ports {key[1]}]
set_property -dict {PACKAGE_PIN R24  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN R23  IOSTANDARD LVCMOS33} [get_ports {led[1]}]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
```

- [ ] **Step 3: 写最小顶层**

`D:\awg_fpga\rtl\top\awg_top.v` 内容：

```verilog
module awg_top (
    input  wire        sys_clk_p,
    input  wire        sys_clk_n,
    input  wire        sys_rst_n,
    input  wire [1:0]  key,
    output wire [1:0]  led
);

assign led[0] = sys_rst_n;
assign led[1] = ~key[0];

endmodule
```

- [ ] **Step 4: 综合、实现、下载**

Expected:

```text
板上 LED0 跟随复位状态，LED1 跟随 KEY0 变化
```

### Task 3: DDS/NCO 数字内核

**Files:**
- Create: `D:\awg_fpga\rtl\dds\dds_nco.v`
- Create: `D:\awg_fpga\rtl\dds\sine_lut.v`
- Create: `D:\awg_fpga\sim\tb\tb_dds_nco.v`

- [ ] **Step 1: 明确 DDS 位宽**

固定第一版参数：

```text
PHASE_W = 64
ADDR_W  = 12
DATA_W  = 16
LUT depth = 4096
```

Expected:

```text
满足 1mHz 频率分辨率，资源可控，后续可替换为 DDS Compiler
```

- [ ] **Step 2: 实现手写 DDS**

功能：

```text
phase_acc <= phase_acc + phase_inc
lut_addr  <= phase_acc[PHASE_W-1 -: ADDR_W]
sine_lut 输出 signed DATA_W 样本
```

验收：

```text
仿真中 phase_inc 非 0 时样本连续变化，phase_inc 为 0 时输出固定相位点
```

- [ ] **Step 3: DDS Compiler 评估**

在 Vivado IP Catalog 中检查 `DDS Compiler`。如果 license 和 IP 生成正常，创建一版 `dds_compiler_wrapper.v`，接口保持和 `dds_nco.v` 一致：

```verilog
module dds_compiler_wrapper (
    input  wire         clk,
    input  wire         rst,
    input  wire [63:0]  phase_inc,
    input  wire [63:0]  phase_offset,
    output wire signed [15:0] sample,
    output wire         sample_valid
);
```

验收：

```text
手写 DDS 和 DDS Compiler 在相同 phase_inc 下输出频率一致
```

### Task 4: 波形模式和幅度链路

**Files:**
- Create: `D:\awg_fpga\rtl\dds\wave_shape_gen.v`
- Create: `D:\awg_fpga\rtl\dsp\sample_mux.v`
- Create: `D:\awg_fpga\rtl\dsp\amp_offset_scale.v`
- Create: `D:\awg_fpga\sim\tb\tb_amp_offset_scale.v`

- [ ] **Step 1: 实现基础波形**

模式：

```text
0 sine
1 square
2 triangle
3 saw
7 test pattern
```

验收：

```text
仿真输出的方波只有正负满幅，三角波单调上升/下降，锯齿波周期复位
```

- [ ] **Step 2: 实现幅度和偏置**

计算顺序：

```text
scaled = sample * amplitude
shifted = scaled >>> 15
biased = shifted + offset
output = saturate(biased)
```

验收：

```text
amplitude = 0 时输出 offset
amplitude = 0x7FFF 且 offset = 0 时接近原始样本
超过范围时饱和到最大/最小值
```

### Task 5: 扫频引擎

**Files:**
- Create: `D:\awg_fpga\rtl\sweep\sweep_engine.v`
- Create: `D:\awg_fpga\sim\tb\tb_sweep_engine.v`

- [ ] **Step 1: 线性扫频**

输入参数：

```text
start_inc
stop_inc
step_inc
dwell_ticks
sweep_points
repeat_enable
```

验收：

```text
每 dwell_ticks 更新一次 phase_inc
到 stop_inc 后停止或循环
非法参数触发 error_flag
```

- [ ] **Step 2: 对数扫频**

第一版对数扫频采用上位机预计算频率字表，FPGA 从 BRAM/DDR3 依次读取。这样避免在 FPGA 内实现复杂乘除和指数计算。

验收：

```text
上位机写入 N 个 phase_inc，FPGA 按 dwell_ticks 顺序播放
```

### Task 6: 控制寄存器和参数安全更新

**Files:**
- Create: `D:\awg_fpga\rtl\control\awg_csr_regs.v`
- Create: `D:\awg_fpga\rtl\control\cmd_apply_ctrl.v`
- Create: `D:\awg_fpga\docs\register_map.md`
- Create: `D:\awg_fpga\sim\tb\tb_awg_regs.v`

- [ ] **Step 1: 实现寄存器读写**

至少实现第 8 节寄存器表中的：

```text
CTRL
STATUS
MODE
PHASE_INC_0/1
PHASE_OFFSET_0/1
AMPLITUDE
OFFSET
SWEEP_START/STOP/STEP
SWEEP_DWELL_TICKS
SWEEP_POINTS
ERROR_COUNT
```

验收：

```text
仿真写入寄存器后能读回
只读寄存器不能被软件写坏
```

- [ ] **Step 2: 实现 APPLY 机制**

规则：

```text
软件先写 shadow registers
软件写 CTRL.apply = 1
cmd_apply_ctrl 在样本边界产生 apply_pulse
工作寄存器一次性更新
```

验收：

```text
频率、幅度、模式不会在一个样本周期内分多次变化
```

### Task 7: 教学 DAC 低速闭环

**Files:**
- Reference: `XC7K325T.zip -> 26_hs_ad_da`
- Create: `D:\awg_fpga\rtl\dac\dac_edu_parallel_if.v`
- Create: `D:\awg_fpga\constraints\awg_dac_edu.xdc`

- [ ] **Step 1: 提取教学 DAC 管脚和时序**

从 `26_hs_ad_da` 例程提取 DAC 数据、DAC 时钟、使能相关约束，只复制实际使用的管脚到 `awg_dac_edu.xdc`。

验收：

```text
约束文件不包含未使用端口
没有同名管脚冲突
```

- [ ] **Step 2: 输出 DDS 到教学 DAC**

把 signed 16bit 样本截位或舍入成教学 DAC 需要的 8bit 数据。

验收：

```text
示波器能看到正弦波、方波、三角波
改变 phase_inc 后输出频率随之变化
```

### Task 8: BRAM 和 DDR3 任意波播放

**Files:**
- Reference: `XC7K325T.zip -> 30_top_ddr3_rw`
- Create: `D:\awg_fpga\rtl\wave\bram_wave_player.v`
- Create: `D:\awg_fpga\rtl\wave\ddr3_wave_buffer.v`
- Create: `D:\awg_fpga\rtl\wave\wave_dma_bridge.v`
- Create: `D:\awg_fpga\sim\tb\tb_wave_player.v`

- [ ] **Step 1: BRAM 任意波**

支持：

```text
base_addr
wave_length
wave_step
loop_enable
```

验收：

```text
播放 1024 点正弦表时周期连续
wave_length 改变后周期按预期改变
```

- [ ] **Step 2: DDR3 任意波**

从 `30_top_ddr3_rw` 学习 MIG 初始化和读写接口，把 DDR3 读通道改成连续样本 FIFO。

验收：

```text
DDR3 初始化完成后 ddr_ready = 1
连续读取不 underflow
FIFO 水位可回读
```

### Task 9: PCIe XDMA 控制和波形下发

**Files:**
- Reference: `325.zip -> 1_pcie_xdma`
- Reference: `325.zip -> 6_pcie_xdma_ddr`
- Create: `D:\awg_fpga\host\awg_cli.py`
- Create: `D:\awg_fpga\docs\pcie_control.md`

- [ ] **Step 1: 复用 XDMA 基础工程**

先跑通正点原子 PCIe XDMA 例程，确认 Windows 设备管理器能看到 PCIe 设备，XDMA 驱动正常。

验收：

```text
PC 能读写 FPGA BAR 空间
PC 能向 DDR3 写入数据并读回一致
```

- [ ] **Step 2: 写最小命令行上位机**

`awg_cli.py` 提供命令：

```text
awg_cli.py status
awg_cli.py sine --freq 1000000 --amp 0.5
awg_cli.py square --freq 100000 --amp 0.5
awg_cli.py sweep-linear --start 1000 --stop 1000000 --points 1000 --dwell-us 100
awg_cli.py upload-wave wave.csv
awg_cli.py play-wave --length 4096 --rate 100000000
```

验收：

```text
每条命令能写入对应寄存器并读回确认
```

### Task 10: 最终高速 DAC 子系统

**Files:**
- Create: `D:\awg_fpga\rtl\dac\dac_stream_formatter.v`
- Create: `D:\awg_fpga\rtl\dac\dac_fmc_parallel_if.v`
- Create: `D:\awg_fpga\rtl\dac\dac_jesd_stub.v`
- Create: `D:\awg_fpga\constraints\awg_fmc_dac.xdc`
- Create: `D:\awg_fpga\docs\dac_board_interface.md`

- [ ] **Step 1: 确定 DAC 子板接口**

从候选 DAC 板的数据手册中锁定：

```text
DAC sampling rate
DAC resolution
input interface: LVDS parallel / DDR / JESD204B / JESD204C
lane rate
clock input requirement
FPGA I/O voltage
connector: FMC HPC / custom board
```

验收：

```text
dac_board_interface.md 中写清每根信号、方向、电平、时钟关系和约束来源
```

- [ ] **Step 2: 实现 DAC 适配层**

无论最终 DAC 是并行还是 JESD，AWG 核心只输出统一流接口：

```verilog
sample_valid
sample_data[DATA_W-1:0]
sample_ready
```

DAC 适配层负责打包、交织、编码和物理发送。

验收：

```text
更换 dac_edu_parallel_if、dac_fmc_parallel_if 或 dac_jesd_stub 时，AWG 核心模块不需要修改
```

### Task 11: 校准和指标测试

**Files:**
- Create: `D:\awg_fpga\docs\verification_plan.md`
- Create: `D:\awg_fpga\docs\measurement_log.md`
- Create: `D:\awg_fpga\host\calibrate_gain.py`

- [ ] **Step 1: 建立测量表**

`measurement_log.md` 至少记录：

```markdown
| Date | Mode | Frequency | Target Vpp | Measured Vpp | THD dBc | SFDR dBc | Flatness dB | Instrument | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
```

- [ ] **Step 2: 幅度校准**

流程：

```text
输出 1MHz 正弦
依次设置 10mVpp、100mVpp、1Vpp、3Vpp
示波器 50Ω 端接测量
生成 gain correction table
写入 calibration_lut
```

验收：

```text
校准后典型频点幅度误差向 1mVpp 目标收敛
```

- [ ] **Step 3: 频响和杂散测试**

测试点：

```text
1MHz
10MHz
100MHz
500MHz
1GHz
```

验收：

```text
记录每个点的 Vpp、THD、SFDR
形成可放进答辩 PPT 的表格和截图
```

### Task 12: 比赛交付物

**Files:**
- Create: `D:\awg_fpga\docs\system_design.md`
- Create: `D:\awg_fpga\docs\demo_script.md`
- Create: `D:\awg_fpga\docs\source_code_annotation.md`
- Create: `D:\awg_fpga\docs\ppt_outline.md`

- [ ] **Step 1: 系统设计文档**

内容结构：

```markdown
# 任意波形信号发生器系统设计

## 指标拆解
## 总体架构
## FPGA 数字基带
## DDS 和扫频
## 任意波缓存
## 高速 DAC 和模拟链路
## 校准方法
## 测试结果
## 问题和改进
```

- [ ] **Step 2: 演示视频脚本**

演示顺序：

```text
1. 板卡和外部 DAC 上电
2. 上位机连接
3. 输出 1MHz 正弦
4. 改变频率
5. 改变幅度
6. 输出方波/三角波/任意波
7. 线性扫频
8. 展示频谱仪 THD/SFDR
9. 展示 PCB Logo 和日期
```

- [ ] **Step 3: PPT 大纲**

章节：

```text
赛题目标
系统方案
关键指标分解
FPGA 架构
DDS 与扫频实现
高速 DAC 与模拟链路
校准和测试
实物演示
总结和创新点
```

## 12. 关键决策点

| 决策 | 推荐选择 | 原因 |
|---|---|---|
| 上位机通道 | PCIe XDMA 主线，UDP 备用，UART 调试 | 波形下发和 DDR3 搬运需要带宽 |
| DDS 实现 | 手写 DDS 先验证，DDS Compiler 可替换 | 手写版本透明、可仿真，IP 版本性能更稳 |
| 相位位宽 | 64bit | 满足 1mHz 分辨率且留足余量 |
| 内部样本位宽 | 16bit 起步，18bit 可选 | 高于 14bit DAC，便于缩放和校准 |
| 任意波缓存 | BRAM 起步，DDR3 正式版 | 先快闭环，再支持长波形 |
| DAC 验证 | 教学 DAC 低速闭环，再接高速 DAC | 降低调试复杂度 |
| 最终 DAC 接口 | 根据实际子板选择 FMC 并行或 GTX/JESD | K325T 有 FMC 和 GTX，但接口必须匹配 DAC |
| Vivado 版本 | 例程按 2023.1 参考，现机可用 2024.2 | 统一工程后确认 IP 升级和 license |

## 13. 里程碑

| 里程碑 | 完成标准 |
|---|---|
| M0: license 和 LED 闭环 | 能综合、实现、生成 bitstream，并下载自写 LED 工程 |
| M1: DDS 仿真闭环 | 正弦、方波、三角、频率字、幅度偏置仿真通过 |
| M2: 教学 DAC 输出 | 示波器看到可调频率、可调幅度的低速波形 |
| M3: 扫频闭环 | 线性扫频和上位机预计算对数扫频均可运行 |
| M4: DDR3 任意波 | PC 下发波形到 DDR3，FPGA 连续播放不欠载 |
| M5: PCIe 控制 | 上位机可读写寄存器、上传波形、触发播放 |
| M6: 高速 DAC 联调 | 高速 DAC 输出正弦，频率和幅度可控 |
| M7: 指标测试 | 形成频率、幅度、THD、SFDR、平坦度测试记录 |
| M8: 参赛资料 | 完成设计文档、源码注释、PPT、演示视频 |

## 14. 团队分工

| 方向 | 工作内容 | 输出物 |
|---|---|---|
| FPGA 核心 | DDS、扫频、幅度、任意波、寄存器 | RTL、仿真、ILA 抓图 |
| FPGA 接口 | DDR3、PCIe、DAC 接口、约束 | Vivado 工程、时序报告、接口文档 |
| 上位机 | CLI/GUI、波形上传、参数计算、校准脚本 | `host` 工具、使用说明 |
| 硬件模拟 | DAC 子板、时钟、滤波、放大/衰减、50Ω 输出 | 原理图、PCB、BOM、测试报告 |
| 测试文档 | 仪器测试、数据记录、PPT、视频 | 测量表、截图、答辩材料 |

## 15. 风险清单

| 风险 | 影响 | 应对 |
|---|---|---|
| Vivado 无 K325T license | 无法生成 bitstream | 先解决合法授权，否则只做文档和仿真 |
| 高速 DAC 子板来不及 | 无法达到最终模拟指标 | 先完成教学 DAC 演示，同时并行采购/设计 DAC 子板 |
| JESD204 接口复杂 | 联调周期长 | 优先选资料完整、参考设计可用的 DAC 模块 |
| DDR3/PCIe 联调慢 | 任意波下发受阻 | BRAM 任意波先演示，DDR3 作为增强 |
| 1GHz 模拟链路平坦度不足 | 幅度指标不达标 | 设计可校准增益表，模拟链路预留衰减/放大裕量 |
| 杂散和谐波不达标 | 核心指标受影响 | 优先使用低相噪时钟，降低截断误差，优化电源和 PCB |

## 16. 立即执行顺序

1. 解决合法 Vivado license，确认 `1_led` 自写代码能重新生成 bitstream。
2. 建立 `D:\awg_fpga` 英文短路径工程。
3. 做 `awg_top.v + k325t_base.xdc` 最小工程，确认自建工程可下载。
4. 做 `dds_nco + sine_lut + amp_offset_scale` 仿真。
5. 接 `26_hs_ad_da` 教学 DAC，示波器看到可调正弦。
6. 加 `sweep_engine`，完成线性扫频演示。
7. 加 BRAM 任意波播放，完成任意波演示。
8. 接 DDR3 和 PCIe XDMA，完成 PC 下发波形。
9. 根据实际采购/设计的 DAC 子板实现最终 `dac_if`。
10. 做幅度、频响、THD、SFDR 测试，整理答辩资料。

## 17. 本计划的验收标准

这份架构计划本身的验收标准：

1. 能解释 K325T 在系统中的真实定位。
2. 能指导从 LED 到 DDS、扫频、任意波、PCIe、DDR3、DAC 接口逐步推进。
3. 能把正点原子资料中的可复用例程对应到具体开发阶段。
4. 能明确 license、高速 DAC、模拟链路这三个最大风险。
5. 能形成后续代码、文档、测试和答辩材料的目录结构。


## Current status addendum (2026-05-06)

- The current working board demo is no longer blocked by license.
- The validated chain is:
  `sys_clk_p/n -> awg_key_ui_ctrl -> awg_core -> dac_edu_parallel_if -> teaching DAC`
- Fresh build evidence:
  - `tb_awg_key_ui_ctrl` PASS
  - `tb_awg_core` PASS
  - `D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit` generated successfully
- The teaching DAC pins were merged into `D:\awg_fpga\constraints\awg_dds_led_top.xdc`; do not rely on `awg_dac_edu.xdc` being loaded separately.
- The old "license blocks everything" paragraph near the top is historical context only; the current environment can generate bitstreams.