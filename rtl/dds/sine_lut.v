//------------------------------------------------------------------------------
// Sine Lookup Table (ROM)
// 【正弦查表 ROM】
//
// 功能说明：
//   存储 4096 点 × 16bit 正弦样本，覆盖 0°~360°。
//   通过 $readmemh 从外部文件初始化，便于用脚本生成精确值。
//
// 数据格式：
//   16-bit 有符号补码，范围 [-32768, +32767]
//   初始化文件：rtl/dds/sine_table.hex（每行一个 4 位十六进制值）
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module sine_lut #(
    parameter ADDR_W = 12,
    parameter DATA_W = 16,
    parameter DEPTH  = 4096
)(
    input  wire              clk,
    input  wire [ADDR_W-1:0] addr,
    output reg  signed [DATA_W-1:0] data
);

    // 片上 ROM 存储器（Vivado 会自动综合为 Distributed RAM 或 Block RAM）
    reg signed [DATA_W-1:0] rom [0:DEPTH-1];

    // 从十六进制文件初始化 ROM
    // 文件路径相对于仿真/综合的工作目录
    initial begin
        $readmemh("sine_table.hex", rom);
    end

    // 时钟上升沿读取（一级流水线，保证时序）
    always @(posedge clk) begin
        data <= rom[addr];
    end

endmodule
