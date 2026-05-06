//------------------------------------------------------------------------------
// AWG LED Status Multiplexer
//
// Shows the current UI mode for a short window after any control value changes.
// After the window expires, LEDs return to the waveform indicator.
//
// UI mode status code:
//   0 frequency : LED0 on
//   1 waveform  : LED1 on
//   2 amplitude : LED0 + LED1 on
//   3 offset    : blink both LEDs
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module awg_led_status #(
    parameter [31:0] STATUS_TICKS = 32'd100_000_000
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire [1:0]        ui_mode,
    input  wire [2:0]        wave_mode,
    input  wire [47:0]       phase_inc,
    input  wire [15:0]       amplitude,
    input  wire signed [15:0] offset,
    input  wire [1:0]        wave_led,
    output wire [1:0]        led
);

    reg [1:0]        ui_mode_d;
    reg [2:0]        wave_mode_d;
    reg [47:0]       phase_inc_d;
    reg [15:0]       amplitude_d;
    reg signed [15:0] offset_d;
    reg [31:0]       status_cnt;
    reg [24:0]       blink_cnt;

    wire control_changed;
    wire status_active;
    reg [1:0] status_led;

    assign control_changed = (ui_mode    != ui_mode_d)    ||
                             (wave_mode  != wave_mode_d)  ||
                             (phase_inc  != phase_inc_d)  ||
                             (amplitude  != amplitude_d)  ||
                             (offset     != offset_d);

    assign status_active = (status_cnt != 32'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ui_mode_d    <= 2'd0;
            wave_mode_d  <= 3'd0;
            phase_inc_d  <= 48'd0;
            amplitude_d  <= 16'd0;
            offset_d     <= 16'sd0;
            status_cnt   <= STATUS_TICKS;
            blink_cnt    <= 25'd0;
        end else begin
            ui_mode_d    <= ui_mode;
            wave_mode_d  <= wave_mode;
            phase_inc_d  <= phase_inc;
            amplitude_d  <= amplitude;
            offset_d     <= offset;
            blink_cnt    <= blink_cnt + 1'b1;

            if (control_changed) begin
                status_cnt <= STATUS_TICKS;
            end else if (status_cnt != 32'd0) begin
                status_cnt <= status_cnt - 1'b1;
            end
        end
    end

    always @(*) begin
        case (ui_mode)
            2'd0: status_led = 2'b01;
            2'd1: status_led = 2'b10;
            2'd2: status_led = 2'b11;
            2'd3: status_led = blink_cnt[24] ? 2'b11 : 2'b00;
            default: status_led = 2'b01;
        endcase
    end

    assign led = status_active ? status_led : wave_led;

endmodule
