//------------------------------------------------------------------------------
// DDS NCO - 64bit Phase Accumulator
// 【直接数字频率合成器 - 手写数控振荡器】
//
// 功能说明：
//   纯 Verilog 实现的相位累加器，可替代 Xilinx DDS Compiler IP。
//   支持 64bit 相位宽度，满足 5GSa/s 下 1mHz 分辨率指标。
//
// 接口设计：
//   与 dds_compiler_wrapper.v 保持兼容，方便直接替换。
//
// 参数：
//   PHASE_W : 相位累加器位宽，默认 64bit
//   ADDR_W  : 查表地址位宽，默认 12bit (LUT depth = 4096)
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module dds_nco #(
    parameter PHASE_W = 64,
    parameter ADDR_W  = 12
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  freq_load,    // 频率加载脉冲
    input  wire [PHASE_W-1:0]    phase_inc,    // 频率控制字（相位增量）
    input  wire [PHASE_W-1:0]    phase_offset, // 相位偏置（可选）
    output wire [ADDR_W-1:0]     phase_addr,   // 查表地址
    output wire                  addr_valid    // 地址有效标志
);

    // 相位累加器寄存器
    reg [PHASE_W-1:0] phase_acc;

    //----------------------------------------------------------------------
    // 相位累加器核心
    // 每时钟周期：phase_acc = phase_acc + phase_inc
    // 溢出自动绕回（模 2^PHASE_W），这是 DDS 频率合成的核心
    //----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n)
            phase_acc <= {PHASE_W{1'b0}};
        else
            phase_acc <= phase_acc + phase_inc;
    end

    //----------------------------------------------------------------------
    // 取相位高位作为查表地址
    // 64bit 累加器中，取最高 ADDR_W 位作为 LUT 地址
    // 例如：取 phase_acc[63:52] 作为 12bit 地址
    //----------------------------------------------------------------------
    wire [ADDR_W-1:0] base_addr = phase_acc[PHASE_W-1 -: ADDR_W];
    
    // 叠加相位偏置（如果提供）
    // 偏置也取对应高位，保证和地址同宽
    wire [ADDR_W-1:0] offset_addr = phase_offset[PHASE_W-1 -: ADDR_W];
    
    assign phase_addr = base_addr + offset_addr;
    assign addr_valid = 1'b1;   // 手写版本无初始化延迟，始终有效

endmodule
