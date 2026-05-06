# 开发日志与踩坑记录

> 按时间倒序记录。每次遇到 bug、修复、重要决策都写进来，避免重复踩坑。

---

## 2026-05-05：手写 DDS 核心模块框架 + 仿真踩坑

### 完成的工作

1. 修复 `awg_dds_led_top.v`：删除悬空信号 `dac_data`
2. 优化 `dac_edu_parallel_if.v`：有符号补码→偏移码转换用位操作 `{~sine_in[15], sine_in[14:8]}` 替代加法，避免溢出歧义
3. 新建手写 DDS 模块：
   - `rtl/dds/dds_nco.v` — 64bit 相位累加器
   - `rtl/dds/sine_lut.v` — 4096×16bit 正弦 ROM（`$readmemh` 初始化）
   - `rtl/dds/wave_shape_gen.v` — 方波/三角波/锯齿波
   - `rtl/dsp/sample_mux.v` — 波形选择器
   - `rtl/dsp/amp_offset_scale.v` — 幅度缩放(Q1.15) + 偏置 + 饱和限幅
4. 生成 `sine_table.hex`（Python 脚本，4096 点）
5. 编写统一 testbench `tb_awg_core.v`，覆盖 7 项测试

### 踩坑记录

#### 坑 1：`timescale` 缺失导致 xelab 报错

**现象**：
```text
ERROR: [XSIM 43-4099] "dac_edu_parallel_if.v" Line 20.
Module dac_edu_parallel_if doesn't have a timescale
but at least one module in design has a timescale.
```

**根因**：testbench 有 `` `timescale 1ns / 1ps ``，但 `dac_edu_parallel_if.v` 没有。Xilinx 仿真器要求所有模块统一 timescale。

**修复**：给所有 RTL 文件顶部都加上 `` `timescale 1ns / 1ps ``。

---

#### 坑 2：Windows 路径反斜杠在 xsim 中被当成转义符

**现象**：
```text
couldn't read file "D:wg_fpgasimwork/xsim_run.tcl": no such file or directory
```

**根因**：PowerShell 传给 `xsim -tclbatch` 的路径含反斜杠，xsim 内部 TCL 解析时 `\` 被转义。

**修复**：
- 方案 A：xsim 的 `-tclbatch` 参数只传文件名（相对路径），不传完整绝对路径
- 方案 B：用正斜杠 `/` 替代反斜杠传路径

**推荐做法**：在 xsim 调用时只写 `xsim_run.tcl`，因为 `Set-Location` 已经切到工作目录。

---

#### 坑 3：Verilog `$display` 中 `%` 被当成格式说明符

**现象**：
```text
WARNING: [VRFC 10-1581] illegal format specifier   for display
```

**根因**：字符串 `"Amplitude scaling (50%)"` 中的 `%` 被解析为格式说明符开头，`%)` 是非法格式。

**修复**：Verilog 字符串中若要显示 `%`，必须写成 `%%`。或者干脆用 `pct`、`percent`、`0.5` 等替代 `%` 字符。

**规则**：所有 `$display` / `$monitor` 字符串中，出现 `%` 一律检查是否是格式转义。

---

#### 坑 4：方波测试观察窗口太短，错过负半周

**现象**：方波测试 `peak_max = 32766, peak_min = 32766`，误判为失败。

**根因**：`phase_inc = 2^56` 时，addr[11]（决定正负半周）每 128 拍翻转一次。TEST 2 只观察了 64 拍，恰好全落在正半周。

**修复**：方波测试观察时间延长到 300 拍（>256 拍，确保覆盖一个完整周期）。

---

#### 坑 5：Q1.15 定点幅度系数的固有衰减（±1 误差）

**现象**：方波正峰值预期 32767，实测 32766；负峰值预期 -32768，实测 -32767。

**根因**：`amplitude = 16'h7FFF = 32767`，对应缩放因子 `32767/32768 ≈ 0.99997`。`32767 × 0.99997` 算术右移截断后变成 `32766`。这是 Q1.15 定点数无法精确表示 1.0 的固有误差，**不是 bug**。

**修复**：testbench 预期值放宽为 `≥32760 / ≤-32760`，不追求精确到 1。

**经验**：在答辩或文档中需要解释这个 ±1 误差来源（定点数量化），避免评委误以为是设计缺陷。

---

#### 坑 6：`$readmemh` 文件路径问题

**现象**：`sine_lut.v` 用 `$readmemh("sine_table.hex", rom)`，standalone 仿真时找不到文件。

**根因**：`$readmemh` 的路径是相对于仿真工作目录的，不是相对于 RTL 文件目录。

**修复**：在仿真脚本（PowerShell/TCL）里，把 `sine_table.hex` **复制到工作目录**后再运行仿真。

```powershell
Copy-Item "$rtl_dds\sine_table.hex" "$work_dir\sine_table.hex" -Force
```

---

### 当前状态

| 模块 | 状态 | 备注 |
|:---|:---:|:---|
| `dds_nco.v` | ✅ 框架完成，仿真待验证 | 64bit 累加器，接口兼容 wrapper |
| `sine_lut.v` | ✅ 框架完成，待仿真 | ROM + hex 初始化文件 |
| `wave_shape_gen.v` | ✅ 框架完成，待仿真 | 方/三角/锯齿 |
| `sample_mux.v` | ✅ 框架完成，待仿真 | 纯组合选择 |
| `amp_offset_scale.v` | ✅ 框架完成，待仿真 | Q1.15 定点 |
| `tb_awg_core.v` | 🔄 调试中 | 已修复所有格式/路径问题，待重跑 |
| Vivado 工程 `.xpr` | ✅ 未受影响 | 新模块未注册，不影响现有 bitstream |

### 下一步（冻结，等用户指令）

1. 重跑 `tb_awg_core.v` 仿真，确认 7 项测试全部 PASS
2. 将新模块注册到 Vivado 工程 `.xpr`
3. 修改 `awg_dds_led_top.v`，把 `dds_compiler_wrapper` 实例化替换为 `dds_nco + sine_lut + ...` 链路
4. 综合实现，生成新的 bitstream（用教学 DAC 上板验证手写 DDS）


## 2026-05-06 AWG key UI + DAC constraint fix

- Added `rtl/control/awg_key_ui_ctrl.v` for KEY0/KEY1-based mode control.
- Merged teaching DAC pins into `constraints/awg_dds_led_top.xdc` so `da_clk` and `da_data[7:0]` are constrained in the actual build.
- Fresh verification passed:
  - `run_awg_key_ui_ctrl_sim.ps1`
  - `run_awg_core_sim.ps1`
  - `scripts/rebuild_awg_base.tcl`
- Current bitstream output:
  `D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit`