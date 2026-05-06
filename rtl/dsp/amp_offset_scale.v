//------------------------------------------------------------------------------
// Amplitude / Offset / Scale Module
//
// Fixed-point path:
//   scaled  = sample_in * amplitude >>> 15
//   biased  = scaled + offset
//   output  = saturate(biased)
//
// amplitude is unsigned Q1.15:
//   16'h0000 = mute
//   16'h4000 = 0.5
//   16'h7fff ~= 1.0 full scale
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module amp_offset_scale #(
    parameter DATA_W = 16
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire signed [DATA_W-1:0]  sample_in,
    input  wire [DATA_W-1:0]         amplitude,
    input  wire signed [DATA_W-1:0]  offset,
    output reg  signed [DATA_W-1:0]  sample_out
);

    reg  signed [31:0] product_reg;
    reg  signed [DATA_W-1:0] offset_reg;

    wire signed [31:0] shifted;
    wire signed [31:0] biased;
    wire signed [DATA_W-1:0] saturated;

    assign shifted = product_reg >>> 15;
    assign biased  = shifted + offset_reg;

    assign saturated = (biased > 32'sd32767)  ? 16'sd32767  :
                       (biased < -32'sd32768) ? -16'sd32768 :
                       biased[DATA_W-1:0];

    // Register the DSP multiply result, then saturate next cycle. This cuts the
    // wave-select -> sample_mux -> DSP -> saturate path at the 100 MHz boundary.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_reg <= 32'sd0;
            offset_reg  <= {DATA_W{1'b0}};
            sample_out  <= {DATA_W{1'b0}};
        end else begin
            product_reg <= sample_in * $signed({1'b0, amplitude});
            offset_reg  <= offset;
            sample_out  <= saturated;
        end
    end

endmodule
