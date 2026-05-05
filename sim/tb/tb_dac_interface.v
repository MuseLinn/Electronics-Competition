//------------------------------------------------------------------------------
// Testbench for DAC Education Board Interface
// 【教学 DAC 接口测试平台】
//
// 验证目标：
//   1. 16bit 有符号补码 -> 8bit 偏移码转换是否正确
//   2. da_clk 是否为 clk 的反相
//   3. 正弦波序列通过后的输出包络是否正确的
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_dac_interface;

    //--------------------------------------------------------------------------
    // 信号声明
    //--------------------------------------------------------------------------
    reg         clk;         // 100MHz 时钟
    reg         rst_n;       // 低电平复位
    reg  [15:0] sine_in;     // DDS 输出的 16bit 有符号样本
    wire        da_clk;      // DAC 时钟（应为 clk 反相）
    wire [7:0]  da_data;     // DAC 8bit 数据输出

    integer     error_cnt;   // 错误计数器

    //--------------------------------------------------------------------------
    // 被测模块实例化 (DUT)
    //--------------------------------------------------------------------------
    dac_edu_parallel_if dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .sine_in (sine_in),
        .da_clk  (da_clk),
        .da_data (da_data)
    );

    //--------------------------------------------------------------------------
    // 时钟产生：100MHz（周期 10ns）
    //--------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    //--------------------------------------------------------------------------
    // 主测试流程
    //--------------------------------------------------------------------------
    initial begin
        error_cnt = 0;
        
        $display("============================================");
        $display("DAC Interface Testbench Start");
        $display("============================================");
        
        //----------------------------------------------------------------------
        // 测试 1: 边界值测试（静态输入）
        //----------------------------------------------------------------------
        $display("\n[TEST 1] Static boundary value test");
        
        // 1.1 零点
        sine_in = 16'h0000; // 0
        #1;
        $display("  sine_in=0x%04h (%6d) -> da_data=0x%02h (%3d)  expect=128",
                 sine_in, $signed(sine_in), da_data, da_data);
        if (da_data !== 8'd128) error_cnt = error_cnt + 1;
        
        // 1.2 最大正数
        sine_in = 16'h7FFF; // +32767
        #1;
        $display("  sine_in=0x%04h (%6d) -> da_data=0x%02h (%3d)  expect=255",
                 sine_in, $signed(sine_in), da_data, da_data);
        if (da_data !== 8'd255) error_cnt = error_cnt + 1;
        
        // 1.3 最大负数
        sine_in = 16'h8000; // -32768
        #1;
        $display("  sine_in=0x%04h (%6d) -> da_data=0x%02h (%3d)  expect=0",
                 sine_in, $signed(sine_in), da_data, da_data);
        if (da_data !== 8'd0) error_cnt = error_cnt + 1;
        
        // 1.4 中间正值 (+16384)
        sine_in = 16'h4000;
        #1;
        $display("  sine_in=0x%04h (%6d) -> da_data=0x%02h (%3d)  expect=192",
                 sine_in, $signed(sine_in), da_data, da_data);
        if (da_data !== 8'd192) error_cnt = error_cnt + 1;
        
        // 1.5 中间负值 (-16384)
        sine_in = 16'hC000;
        #1;
        $display("  sine_in=0x%04h (%6d) -> da_data=0x%02h (%3d)  expect=64",
                 sine_in, $signed(sine_in), da_data, da_data);
        if (da_data !== 8'd64) error_cnt = error_cnt + 1;
        
        // 1.6 小正值 (+255, 接近零)
        sine_in = 16'h00FF;
        #1;
        $display("  sine_in=0x%04h (%6d) -> da_data=0x%02h (%3d)  expect=128",
                 sine_in, $signed(sine_in), da_data, da_data);
        if (da_data !== 8'd128) error_cnt = error_cnt + 1;
        
        // 1.7 小负值 (-256, 接近零)
        // sine_in=0xFF00 -> [15]=1, [14:8]=0x7F=127 -> {~1, 0x7F} = 0x7F = 127
        sine_in = 16'hFF00;
        #1;
        $display("  sine_in=0x%04h (%6d) -> da_data=0x%02h (%3d)  expect=127",
                 sine_in, $signed(sine_in), da_data, da_data);
        if (da_data !== 8'd127) error_cnt = error_cnt + 1;

        //----------------------------------------------------------------------
        // 测试 2: da_clk 极性检查
        //----------------------------------------------------------------------
        $display("\n[TEST 2] da_clk polarity check");
        @(posedge clk); #1;
        $display("  clk=1 -> da_clk=%b (expect 0)", da_clk);
        if (da_clk !== 1'b0) error_cnt = error_cnt + 1;
        
        @(negedge clk); #1;
        $display("  clk=0 -> da_clk=%b (expect 1)", da_clk);
        if (da_clk !== 1'b1) error_cnt = error_cnt + 1;

        //----------------------------------------------------------------------
        // 测试 3: 正弦波序列动态测试
        //----------------------------------------------------------------------
        $display("\n[TEST 3] Sine wave sequence test (first 16 samples)");
        
        // 模拟一个简化的 16 点正弦表（1/4 周期内）
        // 角度: 0, 22.5, 45, 67.5, 90, 112.5, 135, 157.5, 180...
        sine_in = 16'h0000; @(posedge clk); #1; $display("  sample 00: da_data=%3d", da_data);
        sine_in = 16'h31F1; @(posedge clk); #1; $display("  sample 01: da_data=%3d", da_data);
        sine_in = 16'h5A82; @(posedge clk); #1; $display("  sample 02: da_data=%3d", da_data);
        sine_in = 16'h7641; @(posedge clk); #1; $display("  sample 03: da_data=%3d", da_data);
        sine_in = 16'h7FFF; @(posedge clk); #1; $display("  sample 04: da_data=%3d (expect ~255)", da_data);
        sine_in = 16'h7641; @(posedge clk); #1; $display("  sample 05: da_data=%3d", da_data);
        sine_in = 16'h5A82; @(posedge clk); #1; $display("  sample 06: da_data=%3d", da_data);
        sine_in = 16'h31F1; @(posedge clk); #1; $display("  sample 07: da_data=%3d", da_data);
        sine_in = 16'h0000; @(posedge clk); #1; $display("  sample 08: da_data=%3d (expect ~128)", da_data);
        sine_in = 16'hCE0F; @(posedge clk); #1; $display("  sample 09: da_data=%3d", da_data);
        sine_in = 16'hA57E; @(posedge clk); #1; $display("  sample 10: da_data=%3d", da_data);
        sine_in = 16'h89BF; @(posedge clk); #1; $display("  sample 11: da_data=%3d", da_data);
        sine_in = 16'h8001; @(posedge clk); #1; $display("  sample 12: da_data=%3d (expect ~0)", da_data);
        sine_in = 16'h89BF; @(posedge clk); #1; $display("  sample 13: da_data=%3d", da_data);
        sine_in = 16'hA57E; @(posedge clk); #1; $display("  sample 14: da_data=%3d", da_data);
        sine_in = 16'hCE0F; @(posedge clk); #1; $display("  sample 15: da_data=%3d", da_data);

        //----------------------------------------------------------------------
        // 结果汇总
        //----------------------------------------------------------------------
        $display("\n============================================");
        if (error_cnt == 0) begin
            $display("[PASS] All tests passed! (0 errors)");
        end else begin
            $display("[FAIL] %0d error(s) detected!", error_cnt);
        end
        $display("============================================");
        
        $finish;
    end

    //--------------------------------------------------------------------------
    // 超时看门狗
    //--------------------------------------------------------------------------
    initial begin
        #5000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

    //--------------------------------------------------------------------------
    // VCD 波形输出
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("dac_interface_tb.vcd");
        $dumpvars(0, tb_dac_interface);
    end

endmodule
