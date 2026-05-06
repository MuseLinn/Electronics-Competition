# K325T 任意波形发生器 FPGA 完整开发计划

日期：2026-04-30  
目标赛题：第二十一届研电赛优利德赛题二，任意波形信号发生器  
FPGA 平台：正点原子 K7-325T，`XC7K325TFFG900-2I`  
资料根目录：`D:\FPGA`  
建议工程根目录：`D:\awg_fpga`

## 0. 总体判断

K325T 在本项目中的定位不是直接输出 5GSa/s、14bit、1GHz 模拟波形，而是承担数字部分：

1. DDS/NCO 波形合成。
2. 任意波形缓存和播放。
3. 线性/对数扫频控制。
4. 幅度、偏置、相位、输出开关等参数控制。
5. DDR3 波形缓存。
6. PCIe/以太网/串口上位机通信。
7. 高速 DAC 接口适配。
8. 调试、状态监控和校准数据管理。

赛题硬指标中的 5GSa/s、14bit、1GHz 带宽、50Ω、3Vpp、-40dBc 谐波、-60dBc 杂散，必须由外部高速 DAC、低抖动采样时钟、重构滤波器、宽带输出驱动和 PCB 共同完成。FPGA 负责提供干净、连续、可控、可校准的数字样本流。

## 1. 当前必须先解决的阻塞项

### 1.1 Vivado License

你们当前 Vivado 2024.2 报错：

```text
A valid license was not found for feature 'Synthesis' and/or device 'xc7k325t'
```

这说明当前环境不能综合 Kintex-7 `XC7K325T` 工程。没有这个授权，后续所有自写 Verilog 都不能生成 bitstream。

处理要求：

1. 找学校、实验室或老师确认是否有 Xilinx/AMD Vivado Design Edition 或支持 Kintex-7 的 license。
2. 打开 `Vivado License Manager` 导入 license。
3. 在 Vivado 中重新打开 `D:\k7\325\1_led\prj\led.xpr`，运行 `Run Synthesis`。
4. 只有 LED 例程能成功综合、实现、生成 bitstream，才进入正式开发。

### 1.2 工程路径

不要在中文路径、空格路径、资料盘深路径中开发。建议：

```text
D:\awg_fpga
D:\awg_fpga\vivado
D:\awg_fpga\rtl
D:\awg_fpga\tb
D:\awg_fpga\constraints
D:\awg_fpga\docs
D:\awg_fpga\tools
```

## 2. FPGA 系统架构

推荐 FPGA 内部架构如下：

```text
                 +----------------------+
PC GUI/控制端 -> | PCIe XDMA / Ethernet | -> AXI-Lite 寄存器
                 +----------------------+
                              |
                              v
                    +-------------------+
                    | awg_csr_regs      |
                    | 参数/状态/中断    |
                    +-------------------+
                              |
        +---------------------+----------------------+
        |                                            |
        v                                            v
+----------------+                         +----------------+
| dds_nco        |                         | wave_player    |
| 正弦/方/三角   |                         | DDR3/BRAM 任意波 |
+----------------+                         +----------------+
        |                                            |
        +---------------------+----------------------+
                              v
                    +-------------------+
                    | sweep_ctrl        |
                    | 线性/对数扫频     |
                    +-------------------+
                              |
                              v
                    +-------------------+
                    | amp_offset_scale  |
                    | 幅度/偏置/校准    |
                    +-------------------+
                              |
                              v
                    +-------------------+
                    | dac_if            |
                    | 高速 DAC 接口适配 |
                    +-------------------+
                              |
                              v
                       外部高速 DAC
```

## 3. 建议文件划分

正式工程建议从零建一个干净 Vivado 工程，不直接在正点原子例程里堆代码。正点原子例程只作为参考。

```text
D:\awg_fpga\rtl\awg_top.v
D:\awg_fpga\rtl\clk_reset.v
D:\awg_fpga\rtl\awg_csr_regs.v
D:\awg_fpga\rtl\dds_nco.v
D:\awg_fpga\rtl\sine_lut.v
D:\awg_fpga\rtl\wave_player.v
D:\awg_fpga\rtl\sweep_ctrl.v
D:\awg_fpga\rtl\amp_offset_scale.v
D:\awg_fpga\rtl\dac_parallel_if.v
D:\awg_fpga\rtl\dac_jesd_stub.v
D:\awg_fpga\rtl\axis_fifo_bridge.v
D:\awg_fpga\rtl\status_monitor.v
D:\awg_fpga\tb\tb_dds_nco.v
D:\awg_fpga\tb\tb_sweep_ctrl.v
D:\awg_fpga\tb\tb_amp_offset_scale.v
D:\awg_fpga\tb\tb_awg_chain.v
D:\awg_fpga\constraints\k325t_base.xdc
D:\awg_fpga\constraints\awg_pins.xdc
D:\awg_fpga\docs\register_map.md
D:\awg_fpga\docs\verification_plan.md
```

外设参考例程：

```text
D:\k7\325\1_led\prj\led.xpr
D:\FPGA\...\4_Source_Code\1_Verilog\XC7K325T.zip -> 26_hs_ad_da
D:\FPGA\...\4_Source_Code\1_Verilog\XC7K325T.zip -> 30_top_ddr3_rw
D:\FPGA\...\4_Source_Code\2_PCIe\325.zip -> 1_pcie_xdma
D:\FPGA\...\4_Source_Code\2_PCIe\325.zip -> 6_pcie_xdma_ddr
```

## 4. 阶段计划

### 阶段 1：环境和板卡最小闭环

目标：确认你们能生成自己的 bitstream，而不只是下载官方现成 bit。

任务：

1. 解决 Kintex-7 license。
2. 打开 `D:\k7\325\1_led\prj\led.xpr`。
3. 修复 `led.v` 中被注释掉的输出逻辑，例如：

```verilog
assign led = ~key;
```

4. 运行 `Run Synthesis`、`Run Implementation`、`Generate Bitstream`。
5. 用 Hardware Manager 下载新生成的 `led.bit`。
6. 按键控制 LED 成功后，记录 Vivado 版本、license 状态、JTAG 下载步骤。

验收标准：

1. 你们自己改过的 LED 逻辑能上板运行。
2. Vivado 不再报 `Common 17-345 license`。
3. 团队每个人都知道 `.bit` 下载到 FPGA 后断电会丢失。

### 阶段 2：低速 DDS 原型

目标：先在正点原子教学 AD/DA 模块或 LED/ILA 上验证 DDS 数字链路。

任务：

1. 参考 `26_hs_ad_da`，理解 `da_wave_send.v`、ROM、PLL、DAC 时钟。
2. 不沿用 `FREQ_ADJ` 作为最终方案，重新实现 `dds_nco.v`。
3. 使用 64 bit 相位累加器：

```text
phase_acc <= phase_acc + ftw
lut_addr  <= phase_acc[63:56]
```

4. `sine_lut.v` 先用 256 点、16 bit 正弦表。
5. `dds_nco.v` 输出至少 16 bit signed sample。
6. 写 `tb_dds_nco.v`，验证频率控制字变化时 LUT 地址步进正确。
7. 用 ILA 或低速 DAC 输出观察正弦波、方波、三角波、锯齿波。

验收标准：

1. DDS 能产生至少 4 种基本波形。
2. 支持频率控制字、相位偏移、波形选择。
3. 仿真能证明相位累加器连续，不跳变。

### 阶段 3：扫频控制

目标：实现赛题要求的线性扫频和对数扫频。

任务：

1. 实现 `sweep_ctrl.v`。
2. 输入寄存器包括：

```text
sweep_en
sweep_mode        // 0 linear, 1 log/table
ftw_start
ftw_stop
ftw_step
dwell_cycles
repeat_en
```

3. 线性扫频：每到 `dwell_cycles` 更新一次 `ftw_current += ftw_step`。
4. 对数扫频：第一版由上位机预计算频率表，FPGA 从 BRAM/DDR3 读取 FTW 表。
5. 增加扫频完成标志 `sweep_done`。

验收标准：

1. 仿真中 `ftw_current` 能从 start 到 stop。
2. 支持单次扫频和循环扫频。
3. 扫频过程中波形相位连续，避免重启相位导致输出毛刺。

### 阶段 4：幅度、偏置和校准

目标：为赛题的幅度精度、平坦度和输出范围打基础。

任务：

1. 实现 `amp_offset_scale.v`：

```text
sample_scaled = sample_in * amp_gain + dc_offset + cal_corr
```

2. 内部数据位宽建议：

```text
sample_in       signed 16 bit
amp_gain        unsigned 16 bit, Q1.15
dc_offset       signed 16 bit
cal_corr        signed 16 bit
sample_out      signed 16 bit or DAC_WIDTH
```

3. 增加饱和逻辑，避免溢出回绕。
4. 校准表第一版只做频点幅度补偿，后续再加入相位/预失真。

验收标准：

1. 仿真覆盖最大幅度、最小幅度、正偏置、负偏置。
2. 溢出时饱和，不出现符号翻转。
3. 保留未来接幅频校准表的接口。

### 阶段 5：寄存器和控制面

目标：上位机可以配置频率、幅度、波形、扫频和输出开关。

任务：

1. 实现 `awg_csr_regs.v`。
2. 第一版寄存器表：

| 地址 | 名称 | 说明 |
|---|---|---|
| `0x00` | `CTRL` | bit0 output_en，bit1 sweep_en，bit2 phase_reset |
| `0x04` | `STATUS` | bit0 locked，bit1 fifo_ready，bit2 sweep_done |
| `0x08` | `WAVE_MODE` | 0 sine，1 square，2 triangle，3 saw，4 arbitrary |
| `0x10` | `FTW_LOW` | 64 bit FTW 低 32 位 |
| `0x14` | `FTW_HIGH` | 64 bit FTW 高 32 位 |
| `0x18` | `PHASE_OFFSET` | 相位偏移 |
| `0x20` | `AMP_GAIN` | 幅度系数 |
| `0x24` | `DC_OFFSET` | 直流偏置 |
| `0x30` | `SWEEP_START_LOW` | 起始 FTW 低 32 位 |
| `0x34` | `SWEEP_START_HIGH` | 起始 FTW 高 32 位 |
| `0x38` | `SWEEP_STOP_LOW` | 终止 FTW 低 32 位 |
| `0x3C` | `SWEEP_STOP_HIGH` | 终止 FTW 高 32 位 |
| `0x40` | `SWEEP_STEP_LOW` | 步进 FTW 低 32 位 |
| `0x44` | `SWEEP_STEP_HIGH` | 步进 FTW 高 32 位 |
| `0x48` | `DWELL_CYCLES` | 每个频点停留时钟数 |

3. 前期可用 UART 或 VIO 调寄存器；正式推荐 PCIe AXI-Lite。

验收标准：

1. 仿真可写寄存器并观察 DDS 参数变化。
2. 参数更新不导致输出链路死锁。
3. 输出开关 `output_en=0` 时 DAC 数据回到中点码或 0。

### 阶段 6：DDR3 任意波形缓存

目标：支持自定义任意波形，不只输出固定数学波形。

任务：

1. 参考 `30_top_ddr3_rw`，跑通 MIG DDR3。
2. 参考 `6_pcie_xdma_ddr`，确认 PC 能通过 PCIe 写 DDR3。
3. 任意波形数据格式第一版设为 16 bit signed little-endian。
4. 实现 `wave_player.v`：

```text
base_addr
length
read_step
loop_en
sample_valid
sample_data
```

5. 使用 FIFO 隔离 DDR3 读时钟域和 DAC 输出时钟域。

验收标准：

1. PC 写入一段波形，FPGA 能循环播放。
2. FIFO 不 underflow。
3. 任意波形模式和 DDS 模式可切换。

### 阶段 7：高速 DAC 接口适配

目标：把 FPGA 数字样本送到最终高速 DAC。

任务取决于最终 DAC 硬件，分两种路线：

路线 A：并行或 DDR/LVDS DAC

1. 实现 `dac_parallel_if.v`。
2. 做数据格式转换、双沿输出、时钟相位调整。
3. 写 output delay 和 generated clock 约束。

路线 B：JESD204B/C 或多 lane GTX DAC

1. 实现 `dac_jesd_stub.v` 作为抽象边界。
2. 确定 DAC 所需 lane 数、lane rate、Subclass、SYSREF、参考时钟。
3. 使用 Xilinx JESD/GT Wizard 或 DAC 厂商参考设计。
4. 先跑 PRBS/短帧同步，再接真实样本。

验收标准：

1. DAC 接口链路稳定。
2. DAC 输出测试码、正弦码、满幅码均正常。
3. 无 FIFO underflow/overflow。

### 阶段 8：PCIe/上位机集成

目标：完成可展示的用户体验。

任务：

1. 复用 `1_pcie_xdma` 做基础通信。
2. 复用 `6_pcie_xdma_ddr` 做波形下载。
3. 上位机功能最小集：

```text
选择波形
设置频率
设置幅度
设置偏置
设置扫频起止频率
设置线性/对数扫频
下载任意波形
启动/停止输出
读取状态
```

4. FPGA 侧寄存器通过 AXI-Lite 控制。
5. 大波形通过 DMA 写 DDR3。

验收标准：

1. GUI 改频率，输出频率跟着变。
2. GUI 开扫频，FPGA 独立完成扫频。
3. GUI 下载波形，FPGA 切到 arbitrary 模式播放。

## 5. 验证计划

### 5.1 仿真验证

必须有的 testbench：

| Testbench | 验证内容 |
|---|---|
| `tb_dds_nco.v` | FTW、相位、LUT 地址、波形模式 |
| `tb_sweep_ctrl.v` | 线性扫频、循环扫频、扫频完成 |
| `tb_amp_offset_scale.v` | 增益、偏置、饱和 |
| `tb_wave_player.v` | 任意波形地址递增、循环、FIFO valid |
| `tb_awg_chain.v` | DDS 到 DAC 接口全链路 |

### 5.2 上板验证

顺序：

1. LED/按键验证 JTAG 和 bitstream。
2. ILA 观察 DDS 输出样本。
3. 教学 AD/DA 模块低速输出波形。
4. DDR3 写入和读出校验。
5. PCIe 写寄存器，读状态。
6. PCIe 下载任意波形到 DDR3。
7. DAC 测试码输出。
8. DAC 正弦输出。
9. 扫频输出。

### 5.3 指标验证

需要频谱仪或高带宽示波器：

| 指标 | 测试方法 |
|---|---|
| 最高输出频率 | 输出 1GHz 正弦，观察频谱和幅度 |
| 频率分辨率 | 低频和高频分别设置相邻 FTW，读取实际频率 |
| 谐波失真 | 频谱仪测 2/3/4 次谐波 |
| 非谐波杂散 | 频谱仪扫宽带 |
| 幅度精度 | 50Ω 负载下多频点测 Vpp |
| 平坦度 | 1MHz 到 1GHz 多点测幅度并生成校准表 |
| 扫频 | 线性/对数扫频，观察频率随时间变化 |

## 6. 赛题指标到 FPGA 任务映射

| 赛题要求 | FPGA 工作 | 非 FPGA 工作 |
|---|---|---|
| 5GSa/s | 输出数据组织、DAC 接口、时钟域管理 | 高速 DAC、采样时钟 |
| 14bit | 内部至少 16bit 数据通路、舍入/饱和 | DAC ENOB、模拟噪声 |
| 1GHz 正弦 | DDS 支持高频 FTW、预校正 | DAC 带宽、输出滤波、放大器 |
| 1mHz 分辨率 | 64bit 相位累加器 | 参考时钟稳定度 |
| -40dBc 谐波 | 波形精度、截断控制、预失真接口 | DAC 线性、模拟链路 |
| -60dBc 杂散 | 相位截断优化、时钟域干净、FIFO 稳定 | 时钟相噪、PCB 串扰、电源 |
| 10mVpp 到 3Vpp | 数字幅度控制、校准表 | VGA/衰减器/输出驱动 |
| 线性/对数扫频 | `sweep_ctrl.v` | GUI 展示和参数输入 |

## 7. 里程碑

| 周期 | 里程碑 | 交付物 |
|---|---|---|
| 第 1 周 | 环境闭环 | 自己生成并下载 LED bitstream |
| 第 2 周 | DDS 原型 | 4 种波形仿真和低速输出 |
| 第 3 周 | 扫频和幅度控制 | 线性/对数扫频、增益偏置 |
| 第 4 周 | DDR3/PCIe | PC 下载波形到 DDR3 并播放 |
| 第 5-6 周 | 高速 DAC 接口 | DAC 测试码、正弦输出 |
| 第 7 周 | 校准和指标测试 | 幅频表、杂散/谐波测试记录 |
| 第 8 周 | 展示材料 | 文档、PPT、演示视频、源码注释 |

## 8. 优先级排序

当前最优先：

1. 解决 Vivado license。
2. 跑通自改 LED 工程。
3. 跑通 `26_hs_ad_da` 或至少读懂其 DAC 时序。
4. 实现并仿真 `dds_nco.v`。
5. 确定最终高速 DAC 硬件和接口。

不要优先做：

1. 不要先写复杂 GUI。
2. 不要先纠结美观显示。
3. 不要把教学 AD9708 模块当作最终硬件。
4. 不要尝试从 PC 实时流式传 5GSa/s 原始样本。
5. 不要在没有 DAC 选型的情况下写死最终接口。

## 9. 项目风险

| 风险 | 严重性 | 应对 |
|---|---|---|
| Vivado 无 Kintex-7 license | 极高 | 立即解决，否则不能开发 |
| 高速 DAC 迟迟不定 | 极高 | 本周完成器件/板卡选型 |
| JESD/GTX IP 不熟 | 高 | 先跑 IBERT/GT Wizard，再接 DAC |
| 模拟链路不达标 | 高 | 尽早做硬件样机和频谱测试 |
| DDR3 读数断流 | 中 | FIFO 水位、突发读、时钟域约束 |
| 扫频有毛刺 | 中 | 保持相位连续，参数双缓冲 |
| 幅度精度不够 | 中 | 增加校准表和测量闭环 |



## Current status update (2026-05-06)

- The environment blocker is cleared; Vivado 2024.1 can now generate a K325T bitstream for the current AWG demo.
- Current validated chain:
  `awg_key_ui_ctrl -> awg_core -> dac_edu_parallel_if -> teaching DAC`
- Verified by fresh runs:
  - `tb_awg_key_ui_ctrl` PASS
  - `tb_awg_core` PASS
  - `D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit` generated successfully
- The next practical step is board-side observation after reconnecting the board, not more license debugging.