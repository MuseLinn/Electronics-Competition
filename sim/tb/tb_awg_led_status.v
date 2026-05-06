//------------------------------------------------------------------------------
// AWG LED Status Testbench
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_awg_led_status;

    localparam CLK_PERIOD = 10;

    reg clk;
    reg rst_n;
    reg [1:0] ui_mode;
    reg [2:0] wave_mode;
    reg [47:0] phase_inc;
    reg [15:0] amplitude;
    reg signed [15:0] offset;
    reg [1:0] wave_led;
    wire [1:0] led;

    integer error_cnt;

    awg_led_status #(
        .STATUS_TICKS (32'd5)
    ) u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .ui_mode   (ui_mode),
        .wave_mode (wave_mode),
        .phase_inc (phase_inc),
        .amplitude (amplitude),
        .offset    (offset),
        .wave_led  (wave_led),
        .led       (led)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
            #1;
        end
    endtask

    task check_led;
        input [1:0] expected;
        input [127:0] name;
        begin
            if (led !== expected) begin
                $display("  [FAIL] %0s expected %b got %b", name, expected, led);
                error_cnt = error_cnt + 1;
            end else begin
                $display("  [PASS] %0s", name);
            end
        end
    endtask

    initial begin
        clk       = 1'b0;
        rst_n     = 1'b0;
        ui_mode   = 2'd0;
        wave_mode = 3'd0;
        phase_inc = 48'h1;
        amplitude = 16'h4000;
        offset    = 16'sd0;
        wave_led  = 2'b10;
        error_cnt = 0;

        $display("============================================================");
        $display("AWG LED Status TB Start");
        $display("============================================================");

        wait_cycles(3);
        rst_n = 1'b1;
        wait_cycles(1);

        $display("");
        $display("[TEST 1] Reset shows frequency status");
        check_led(2'b01, "freq status");

        wait_cycles(8);
        $display("");
        $display("[TEST 2] Timeout returns to waveform LEDs");
        check_led(2'b10, "waveform led");

        $display("");
        $display("[TEST 3] UI mode change shows waveform-mode status");
        ui_mode = 2'd1;
        wait_cycles(2);
        check_led(2'b10, "wave mode status");

        wait_cycles(8);
        check_led(2'b10, "waveform led after wave mode timeout");

        $display("");
        $display("[TEST 4] Amplitude change shows amplitude-mode status");
        ui_mode = 2'd2;
        amplitude = 16'h6000;
        wait_cycles(2);
        check_led(2'b11, "amplitude mode status");

        wait_cycles(8);
        check_led(2'b10, "waveform led after amplitude timeout");

        if (error_cnt == 0) begin
            $display("");
            $display("============================================================");
            $display("[PASS] All AWG LED status tests passed!");
            $display("============================================================");
        end else begin
            $display("");
            $display("============================================================");
            $display("[FAIL] AWG LED status tests failed: %0d errors", error_cnt);
            $display("============================================================");
        end

        $finish;
    end

endmodule
