//------------------------------------------------------------------------------
// Amplitude / Offset / Scale Module
// 【幅度缩放 + 偏置叠加 + 饱和限幅】
//
// 功能说明：
//   对输入样本进行幅度缩放和偏置叠加，最后做饱和限幅。
//   计算顺序：scaled = sample * amplitude >>> 15
//             biased = scaled + offset
//             output = saturate(biased)
//
// 数据格式：
//   amplitude : unsigned Q1.15
//             0x0000 = 0 (静音)
//             0x4000 = 0.5
//             0x7FFF ≈ 0.99997 (接近满幅)
//   offset    : signed 16bit，单位同样本
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module amp_offset_scale #(
    parameter DATA_W = 16
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire signed [DATA_W-1:0] sample_in,     // 输入样本
    input  wire [DATA_W-1:0] amplitude,            // 幅度系数 (unsigned Q1.15)
    input  wire signed [DATA_W-1:0] offset,        // 直流偏置
    output reg  signed [DATA_W-1:0] sample_out     // 输出样本
);

    //----------------------------------------------------------------------
    // 组合逻辑：定点数乘法 + 偏置 + 饱和
    //----------------------------------------------------------------------
    wire signed [31:0] product;
    wire signed [31:0] shifted;
    wire signed [31:0] biased;
    wire signed [DATA_W-1:0] saturated;

    // 乘法：sample * amplitude
    // amplitude 是无符号 Q1.15，最高位始终为 0（范围 0~32767）
    assign product = sample_in * $signed({1'b0, amplitude});

    // 算术右移 15 位，相当于除以 32768
    assign shifted = product >>> 15;

    // 叠加偏置
    assign biased = shifted + offset;

    // 饱和限幅：防止溢出
    assign saturated = (biased > 32'sd32767) ? 16'sd32767 :
                       (biased < -32'sd32768) ? -16'sd32768 :
                       biased[DATA_W-1:0];

    //----------------------------------------------------------------------
    // 输出寄存器（打一拍，改善时序）
    //----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sample_out <= 16'sd0;
        else
            sample_out <= saturated;
    end

endmodule
