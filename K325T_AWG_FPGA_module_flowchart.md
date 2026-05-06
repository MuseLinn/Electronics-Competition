# K325T AWG FPGA Module Flowchart

本文档用于按图推进 FPGA 侧开发。第一张图看“信号在 FPGA 里怎么流”，第二张图看“开发顺序怎么一步一步做”。

当前已经实现的统一前端是 `D:\awg_fpga\rtl\dsp\awg_core.v`：它把 DDS、波形选择、幅度、偏置和限幅封装成一个模块，并由 `D:\awg_fpga\rtl\top\awg_dds_led_top.v` 直接实例化。

## 1. FPGA 内部模块流程图

```mermaid
flowchart LR
    PC["PC 上位机\nCLI / GUI / 校准脚本"]
    COMM["通信接口\nPCIe XDMA 主线\nUDP 备用\nUART 调试"]
    CSR["awg_csr_regs\n控制/状态寄存器"]
    APPLY["cmd_apply_ctrl\n参数影子寄存器\nAPPLY 同步更新"]

    CLK["clk_reset\n100MHz 输入\nMMCM/PLL\n复位同步"]
    STATUS["status_monitor\nPLL/DDR/DAC ready\n欠载/溢出/错误计数"]
    ILA["ILA/VIO 调试\n关键波形抓取"]

    SWEEP["sweep_engine\n线性扫频\n对数扫频表播放\n输出 phase_inc"]
    DDS["dds_nco\n64bit 相位累加\n相位偏置\n输出相位地址"]
    LUT["sine_lut / DDS Compiler\n正弦/余弦样本"]
    SHAPE["wave_shape_gen\n方波/三角/锯齿\n测试码型"]

    BRAM["bram_wave_player\n小容量任意波"]
    DDR["ddr3_wave_buffer\n大容量任意波缓存"]
    DMA["wave_dma_bridge\nPC 波形下发到 DDR3"]

    MUX["sample_mux\n选择输出模式\nDDS / 任意波 / 扫频 / 测试"]
    SCALE["amp_offset_scale\n幅度缩放\n偏置叠加\n饱和限幅"]
    CAL["calibration_lut\n幅频/幅度/偏置预校准"]
    FMT["dac_stream_formatter\n补码/偏移码转换\n通道交织\n并行/串行打包"]

    DAC_EDU["dac_edu_parallel_if\n正点原子低速教学 DAC"]
    DAC_FMC["dac_fmc_parallel_if\nFMC 高速 DAC 子板"]
    DAC_JESD["dac_jesd_stub\nJESD/GTX DAC 预留"]
    DAC["外部高速 DAC\n低抖动采样时钟"]
    ANA["模拟链路\n重构滤波\n可变增益/衰减\n50Ω 输出"]

    PC --> COMM --> CSR --> APPLY
    APPLY --> SWEEP
    APPLY --> DDS
    APPLY --> SHAPE
    APPLY --> BRAM
    APPLY --> SCALE
    APPLY --> CAL
    APPLY --> MUX

    CLK --> CSR
    CLK --> SWEEP
    CLK --> DDS
    CLK --> BRAM
    CLK --> DDR
    CLK --> FMT

    SWEEP --> DDS
    DDS --> LUT --> MUX
    DDS --> SHAPE --> MUX
    BRAM --> MUX
    PC --> COMM --> DMA --> DDR --> MUX

    MUX --> SCALE --> CAL --> FMT
    FMT --> DAC_EDU
    FMT --> DAC_FMC
    FMT --> DAC_JESD
    DAC_FMC --> DAC --> ANA
    DAC_JESD --> DAC
    DAC_EDU --> ANA

    STATUS --> CSR
    STATUS --> ILA
    DDS --> STATUS
    DDR --> STATUS
    FMT --> STATUS
```

### 这张图怎么读

1. PC 只负责发命令和下载波形，不直接参与高速实时输出。
2. `awg_csr_regs` 保存参数，`cmd_apply_ctrl` 负责让参数在安全边界一次性生效。
3. `sweep_engine` 不直接产生波形，它改变 DDS 的 `phase_inc`，从而实现扫频。
4. DDS、方波/三角波、任意波播放器都会进入 `sample_mux`。
5. 所有波形统一经过幅度、偏置、校准，再进入 DAC 格式化模块。
6. 最终 DAC 接口可以先用教学 DAC 验证，后续换成 FMC 高速 DAC 或 JESD/GTX DAC。

## 2. 开发顺序流程图

```mermaid
flowchart TD
    A["Step 0\n解决合法 Vivado license\n确认能综合 XC7K325T"]
    B["Step 1\n跑通 LED 自建工程\n确认 JTAG 下载流程"]
    C["Step 2\n建立 D:\\awg_fpga 英文短路径工程\n添加基础时钟/复位/LED 约束"]
    D["Step 3\n实现 clk_reset\n复位同步、PLL locked、LED 状态灯"]
    E["Step 4\n实现 dds_nco + sine_lut\n先做仿真，不急着上板"]
    F["Step 5\n实现 wave_shape_gen\n方波、三角、锯齿、测试码型"]
    G["Step 6\n实现 awg_core\n把 sample_mux + amp_offset_scale 串成统一前端"]
    H["Step 7\n接正点原子教学 DAC\n示波器看到低速正弦/方波/三角波"]
    I["Step 8\n实现 sweep_engine\n线性扫频先跑通，对数扫频用查表"]
    J["Step 9\n实现 bram_wave_player\n小容量任意波播放"]
    K["Step 10\n接 MIG DDR3\n实现 ddr3_wave_buffer 长波形缓存"]
    L["Step 11\n接 PCIe XDMA\nPC 写寄存器、下发波形到 DDR3"]
    M["Step 12\n接最终高速 DAC 子板\nFMC 并行或 JESD/GTX"]
    N["Step 13\n做幅度/频响/THD/SFDR 校准和测试\n整理答辩资料"]

    A --> B --> C --> D --> E --> F --> G --> H --> I --> J --> K --> L --> M --> N
```

## 3. 每一步的上板验收点

| 顺序 | 模块 | 先看什么现象 | 通过标准 |
|---:|---|---|---|
| 0 | Vivado license | `Run Synthesis` 不再报 `Common 17-345` | 能生成自写 bitstream |
| 1 | LED 工程 | LED 随按键或计数变化 | JTAG 下载正常 |
| 2 | `clk_reset` | LED 显示 PLL locked / reset 状态 | 复位释放稳定 |
| 3 | `dds_nco` | 仿真样本周期变化 | 改 `phase_inc` 后频率变化 |
| 4 | `wave_shape_gen` | 仿真方波/三角/锯齿 | 波形形状正确 |
| 5 | `amp_offset_scale` | 仿真幅度和偏置变化 | 不溢出，能饱和限幅 |
| 5.5 | `awg_core` | 参考链路逐拍对拍 | `sample_mux` / `amp_offset_scale` 封装后一致 |
| 6 | 教学 DAC | 示波器看到低速波形 | 频率和幅度可调 |
| 7 | `sweep_engine` | 示波器/频谱仪看到扫频 | 起止频率、驻留时间正确 |
| 8 | `bram_wave_player` | 播放固定任意波表 | 周期连续，无跳变 |
| 9 | DDR3 | `ddr_ready=1`，FIFO 不欠载 | 长波形连续播放 |
| 10 | PCIe XDMA | PC 能读写寄存器和 DDR3 | 上位机命令控制输出 |
| 11 | 高速 DAC | 输出高频正弦 | 进入指标测试 |
| 12 | 校准测试 | 记录 Vpp、THD、SFDR、平坦度 | 可支撑比赛答辩 |

## 4. 最小可运行主线

如果时间紧，优先做这条主线：

```text
license -> LED -> clk_reset -> DDS -> amp_offset_scale -> 教学 DAC -> sweep_engine -> BRAM 任意波 -> 答辩演示
```

如果时间和硬件允许，再补强：

```text
DDR3 -> PCIe XDMA -> 高速 DAC -> 校准表 -> 完整指标测试
```

## 5. 当前最关键提醒

1. license 没解决前，所有自写 RTL 都不能生成新的 K325T bitstream。
2. 教学 DAC 只能验证流程，不能代表最终 5GSa/s、14bit、1GHz 指标。
3. 最终高速 DAC 的接口选型会决定 `dac_fmc_parallel_if` 还是 `dac_jesd_stub` 是主线。
4. FPGA 内部模块一定要先仿真，再上板，否则调试成本会非常高。


## Current implementation note (2026-05-06)

- The practical first-iteration board chain is now:
  `sys_clk_p/n -> awg_key_ui_ctrl -> awg_core -> dac_edu_parallel_if -> teaching DAC`
- `KEY0` and `KEY1` are active in the current demo for mode/parameter control.
- The current demo bitstream is:
  `D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit`
- Keep the JESD/GTX high-speed DAC path as the phase-2 route, not the first bring-up path.