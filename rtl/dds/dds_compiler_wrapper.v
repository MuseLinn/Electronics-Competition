//------------------------------------------------------------------------------
// DDS Compiler Wrapper for AWG K325T
// 【DDS 编译器封装模块】将 Xilinx DDS Compiler IP 的复杂接口简化为易用接口
//
// 功能说明：
//   本模块是对 Xilinx DDS Compiler v6.0 IP 核的封装。
//   IP 核原生使用 AXI-Stream 接口（s_axis_config/m_axis_data），
//   对外部使用者来说比较复杂。本模块将其简化为：
//     - 一个脉冲信号 freq_load 加载频率
//     - 一个 48bit 数值 phase_inc 设定频率
//     - 一个 16bit 有符号输出 sine_out
//
// DDS 基本原理：
//   DDS（Direct Digital Synthesizer，直接数字频率合成器）的核心是一个相位累加器：
//     每个时钟上升沿：phase = phase + phase_inc
//     然后取 phase 的高 N 位作为地址，查正弦 lookup table
//     输出对应的正弦幅度值
//
//   输出频率公式：f_out = phase_inc × f_clk / 2^48
//   反过来求控制字：phase_inc = f_out × 2^48 / f_clk
//
// IP 配置参数：
//   - Phase Width（相位宽度）: 48 bit  → 相位累加器精度
//   - Output Width（输出位宽）: 16 bit → 正弦波幅度精度（有符号数）
//   - Phase Increment（相位增量）: Programmable → 频率可编程
//   - 在 5GSa/s 时钟下，频率分辨率约 17.8 uHz（微赫兹）
//
// 端口说明：
//   clk        - DDS 工作时钟（最终系统可达 5GSa/s）
//   rst_n      - 低电平有效的复位信号（0=复位，1=正常工作）
//   freq_load  - 频率加载脉冲（高电平持续一个时钟周期即可加载新频率）
//   phase_inc  - 48-bit 频率控制字（相位增量，决定输出频率）
//   sine_out   - 16-bit 有符号正弦波输出（范围 -32768 ~ +32767）
//   out_valid  - 输出数据有效标志（高电平时 sine_out 有效）
//------------------------------------------------------------------------------

module dds_compiler_wrapper (
    input  wire        clk,         // 系统时钟输入
    input  wire        rst_n,       // 低电平复位（asynchronous reset, active low）
    input  wire        freq_load,   // 频率加载脉冲：上升沿时加载 phase_inc
    input  wire [47:0] phase_inc,   // 48-bit 频率控制字（相位增量）
    output wire [15:0] sine_out,    // 16-bit 有符号正弦波输出
    output wire        out_valid    // 输出有效标志
);

    //--------------------------------------------------------------------------
    // 内部信号声明
    // 这些信号用于连接 Xilinx IP 核的 AXI-Stream 接口
    //--------------------------------------------------------------------------
    reg         config_tvalid;  // AXI-Stream Config 接口的 valid 信号
    wire [47:0] config_tdata;   // AXI-Stream Config 接口的数据（相位增量）
    wire [31:0] data_tdata;     // AXI-Stream Data 接口的输出数据（IP输出32bit）
    wire        data_tvalid;    // AXI-Stream Data 接口的 valid 信号

    //--------------------------------------------------------------------------
    // 【配置通道】将外部的 freq_load 脉冲转换为 IP 需要的 AXI-Stream valid
    //
    // AXI-Stream 协议简介：
    //   - valid 信号为高时，表示数据有效
    //   - 这里我们简化为：freq_load 脉冲 → config_tvalid 脉冲
    //   - 只要 freq_load 有一个时钟周期的高电平，IP 就会在新的相位增量上工作
    //
    // 时序说明：
    //   freq_load 只需要一个时钟周期的高电平
    //   本模块在时钟上升沿采样 freq_load，生成 config_tvalid
    //--------------------------------------------------------------------------
    assign config_tdata = phase_inc;  // 直接将外部频率字接到 IP 配置数据端口

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位时：清除 valid，确保不会误加载
            config_tvalid <= 1'b0;
        end else begin
            // 正常工作时：把 freq_load 传递给 IP 的 valid
            // 注意：如果 freq_load 持续多周期高电平，config_tvalid 也会持续多周期
            // 这对 IP 来说是安全的，每次 valid 都会更新相位增量
            config_tvalid <= freq_load;
        end
    end

    //--------------------------------------------------------------------------
    // 【数据输出通道】从 IP 的 32bit 输出中提取 16bit 正弦数据
    //
    // 为什么 IP 输出 32bit 但我们只取低 16bit？
    //   Xilinx DDS Compiler IP 的 m_axis_data_tdata 位宽取决于配置。
    //   当 Output Width = 16 时，有效数据在 [15:0]，高位 [31:16] 无意义。
    //   这是 IP 的固定行为：总是输出 32bit 或更宽的总线，有效数据在低位。
    //--------------------------------------------------------------------------
    assign sine_out  = data_tdata[15:0];  // 提取低16位：有符号正弦幅度
    assign out_valid = data_tvalid;        // 直接传递 valid 信号

    //--------------------------------------------------------------------------
    // 【Xilinx DDS Compiler v6.0 IP 实例化】
    //
    // IP 核的 AXI-Stream 接口：
    //   - s_axis_config_* : 配置通道（输入频率控制字）
    //   - m_axis_data_*   : 数据通道（输出正弦波）
    //
    // 接口信号说明：
    //   aclk                 : IP 工作时钟
    //   s_axis_config_tvalid : 配置数据有效（由本模块生成）
    //   s_axis_config_tdata  : 配置数据（48bit 相位增量）
    //   m_axis_data_tvalid   : 输出数据有效
    //   m_axis_data_tdata    : 输出数据（32bit，低16位有效）
    //--------------------------------------------------------------------------
    dds_compiler_0 dds_inst (
        .aclk                      (clk),            // 时钟输入
        .s_axis_config_tvalid      (config_tvalid),  // 配置valid
        .s_axis_config_tdata       (config_tdata),   // 配置数据（相位增量）
        .m_axis_data_tvalid        (data_tvalid),    // 输出valid
        .m_axis_data_tdata         (data_tdata)      // 输出数据
    );

endmodule
