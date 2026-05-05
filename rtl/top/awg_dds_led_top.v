//------------------------------------------------------------------------------
// AWG DDS LED Demo Top - K325T Board Test (Key-controlled Frequency)
// 【AWG 项目 DDS 板级测试顶层模块 — 按键调频版】
//
// 功能说明：
//   使用板载的 100MHz 差分时钟，通过 DDS 产生正弦波。
//   支持通过板载按键动态切换 8 档预设频率（1Hz ~ 10MHz）。
//   正弦波输出到教学 DAC（ATK-HS-ADDA 模块），同时通过 LED 指示波形状态。
//
// 按键定义（低电平有效，按下为 0）：
//   - KEY0 (A26)：频率加档（1Hz -> 10Hz -> ... -> 10MHz -> 1Hz）
//   - KEY1 (A25)：频率减档（1Hz <- 10MHz <- ... <- 10Hz <- 1Hz）
//
// 硬件连接：
//   - 差分时钟输入：sys_clk_p (AE10) / sys_clk_n (AF10)
//   - 复位按键：sys_rst_n (AB25)，低电平有效
//   - 调频按键：key0 (A26) / key1 (A25)，低电平有效
//   - LED 输出：led[0] (R24) / led[1] (R23)
//   - DAC 输出：da_clk (AH22) / da_data[7:0] (AB22,AG20,AB23,AH20,AC22,AH21,AD22,AJ21)
//
// DDS 输出频率计算（板级 100MHz 时钟，48bit 相位宽度）：
//   phase_inc = f_out * 2^48 / 100_000_000
//   f_out     = phase_inc * 100_000_000 / 2^48
//------------------------------------------------------------------------------

module awg_dds_led_top (
    input  wire        sys_clk_p,   // 差分时钟正端，接板子 AE10 引脚，100MHz
    input  wire        sys_clk_n,   // 差分时钟负端，接板子 AF10 引脚
    input  wire        sys_rst_n,   // 低电平复位，接板子 AB25 引脚
    input  wire        key0,        // 频率加档按键，接板子 A26 引脚，低电平有效
    input  wire        key1,        // 频率减档按键，接板子 A25 引脚，低电平有效
    output wire [1:0]  led,         // LED 输出，R24(led[0]) / R23(led[1])
    // 教学 DAC 接口（ATK-HS-ADDA 模块）
    output wire        da_clk,      // DAC 采样时钟
    output wire [7:0]  da_data      // DAC 并行数据（8bit）
);

    //--------------------------------------------------------------------------
    // 内部信号声明
    //--------------------------------------------------------------------------
    wire clk_ibuf;           // IBUFDS 输出的单端时钟（未缓冲）
    wire clk;                // BUFG 输出的全局时钟（全局缓冲后）
    wire rst_n;              // 复位信号

    // DDS 模块接口信号
    wire [15:0] sine_out;    // DDS 输出的 16bit 正弦波
    wire        out_valid;   // DDS 输出有效标志
    reg         freq_load;   // 频率加载脉冲（按键按下时产生）
    reg  [47:0] phase_inc;   // 频率控制字（相位增量）

    // 按键消抖信号
    reg  [20:0] key0_cnt;    // KEY0 消抖计数器（100MHz 下约 20ms）
    reg         key0_d, key0_dd;
    reg         key0_stable; // KEY0 稳定状态（消抖后）
    reg         key0_stable_prev;
    reg  [20:0] key1_cnt;    // KEY1 消抖计数器
    reg         key1_d, key1_dd;
    reg         key1_stable; // KEY1 稳定状态（消抖后）
    reg         key1_stable_prev;

    // 频率档位选择
    reg  [2:0]  freq_sel;    // 0~7 对应 8 档频率

    //--------------------------------------------------------------------------
    // 【频率控制字查找表】8 档预设频率
    //
    // 公式：phase_inc = round(f_out * 2^48 / 100_000_000)
    //   2^48 = 281,474,976,710,656
    //--------------------------------------------------------------------------
    localparam [47:0] PHASE_INC_1HZ     = 48'h0000000002AF31E;  //   1 Hz
    localparam [47:0] PHASE_INC_10HZ    = 48'h000000001AD7F2A;  //  10 Hz
    localparam [47:0] PHASE_INC_100HZ   = 48'h000000010C6F7A1;  // 100 Hz
    localparam [47:0] PHASE_INC_1KHZ    = 48'h0000000A7C5AC47;  //   1 kHz
    localparam [47:0] PHASE_INC_10KHZ   = 48'h00000068DB8BAC7;  //  10 kHz
    localparam [47:0] PHASE_INC_100KHZ  = 48'h000004189374BC7;  // 100 kHz
    localparam [47:0] PHASE_INC_1MHZ    = 48'h000028F5C28F5C3;  //   1 MHz
    localparam [47:0] PHASE_INC_10MHZ   = 48'h0001999999999A;   //  10 MHz

    //--------------------------------------------------------------------------
    // 【差分时钟输入缓冲】IBUFDS + BUFG
    //--------------------------------------------------------------------------
    IBUFDS clk_ibufds (
        .I  (sys_clk_p),
        .IB (sys_clk_n),
        .O  (clk_ibuf)
    );

    BUFG clk_bufg (
        .I (clk_ibuf),
        .O (clk)
    );

    //--------------------------------------------------------------------------
    // 【复位处理】直接透传
    //--------------------------------------------------------------------------
    assign rst_n = sys_rst_n;

    //--------------------------------------------------------------------------
    // 【按键消抖逻辑】KEY0
    //
    // 原理：按键按下时会产生机械抖动（约 5~20ms），
    //       当电平稳定保持 20ms 以上才认为按键状态有效。
    //       100MHz 时钟周期 = 10ns，20ms 需要约 2,000,000 个时钟周期。
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key0_cnt    <= 0;
            key0_d      <= 1'b1;
            key0_dd     <= 1'b1;
            key0_stable <= 1'b1;
        end else begin
            // 两级同步，消除亚稳态
            key0_d  <= key0;
            key0_dd <= key0_d;

            // 如果电平变化，清零计数器
            if (key0_d != key0_dd) begin
                key0_cnt <= 0;
            end else if (key0_cnt < 21'd2_000_000) begin
                key0_cnt <= key0_cnt + 1'b1;
            end else begin
                // 稳定超过 20ms，更新稳定状态
                key0_stable <= key0_dd;
            end
        end
    end

    //--------------------------------------------------------------------------
    // 【按键消抖逻辑】KEY1
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key1_cnt    <= 0;
            key1_d      <= 1'b1;
            key1_dd     <= 1'b1;
            key1_stable <= 1'b1;
        end else begin
            key1_d  <= key1;
            key1_dd <= key1_d;

            if (key1_d != key1_dd) begin
                key1_cnt <= 0;
            end else if (key1_cnt < 21'd2_000_000) begin
                key1_cnt <= key1_cnt + 1'b1;
            end else begin
                key1_stable <= key1_dd;
            end
        end
    end

    //--------------------------------------------------------------------------
    // 【频率档位切换逻辑】
    //
    // KEY0 按下（下降沿）：freq_sel + 1（循环 0->7->0）
    // KEY1 按下（下降沿）：freq_sel - 1（循环 0->7->0）
    // 切换时产生一个 freq_load 脉冲，通知 DDS 更新频率
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_sel          <= 3'd0;
            freq_load         <= 1'b0;
            key0_stable_prev  <= 1'b1;
            key1_stable_prev  <= 1'b1;
        end else begin
            key0_stable_prev <= key0_stable;
            key1_stable_prev <= key1_stable;

            // 默认不产生加载脉冲
            freq_load <= 1'b0;

            // KEY0 下降沿检测（按键按下）
            if (key0_stable_prev && !key0_stable) begin
                if (freq_sel < 3'd7)
                    freq_sel <= freq_sel + 1'b1;
                else
                    freq_sel <= 3'd0;
                freq_load <= 1'b1;
            end
            // KEY1 下降沿检测（按键按下）
            else if (key1_stable_prev && !key1_stable) begin
                if (freq_sel > 3'd0)
                    freq_sel <= freq_sel - 1'b1;
                else
                    freq_sel <= 3'd7;
                freq_load <= 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // 【频率控制字查找表】根据 freq_sel 选择 phase_inc
    //--------------------------------------------------------------------------
    always @(*) begin
        case (freq_sel)
            3'd0: phase_inc = PHASE_INC_1HZ;
            3'd1: phase_inc = PHASE_INC_10HZ;
            3'd2: phase_inc = PHASE_INC_100HZ;
            3'd3: phase_inc = PHASE_INC_1KHZ;
            3'd4: phase_inc = PHASE_INC_10KHZ;
            3'd5: phase_inc = PHASE_INC_100KHZ;
            3'd6: phase_inc = PHASE_INC_1MHZ;
            3'd7: phase_inc = PHASE_INC_10MHZ;
            default: phase_inc = PHASE_INC_1HZ;
        endcase
    end

    //--------------------------------------------------------------------------
    // 【DDS 封装模块实例化】
    //--------------------------------------------------------------------------
    dds_compiler_wrapper dds_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .freq_load (freq_load),
        .phase_inc (phase_inc),
        .sine_out  (sine_out),
        .out_valid (out_valid)
    );

    //--------------------------------------------------------------------------
    // 【DAC 接口实例化】教学 DAC 并行数据输出
    //--------------------------------------------------------------------------
    dac_edu_parallel_if u_dac_if (
        .clk      (clk),
        .rst_n    (rst_n),
        .sine_in  (sine_out),
        .da_clk   (da_clk),
        .da_data  (da_data)
    );

    //--------------------------------------------------------------------------
    // 【LED 输出逻辑】
    //
    // led[0] - 符号位指示（正弦波正半周/负半周）
    // led[1] - 峰值指示（波峰/波谷时亮，过零点附近灭）
    //--------------------------------------------------------------------------
    assign led[0] = sine_out[15];                    // 符号位
    assign led[1] = sine_out[14] ^ sine_out[15];     // 峰值指示

endmodule
