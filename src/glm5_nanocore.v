//=============================================================================
// GLM-5.2 NanoCore V3-FINAL - Synchronous Neuromorphic Matrix Tile
// SkyWater 130nm PDK Compatible
// Hardwired Weights - Zero External Memory Dependency
//
// Architecture: 8-bit input -> Registered -> 4x4 MAC Matrix (15-bit wide) ->
//               Single 8-bit Output Neuron -> Registered -> 8-bit output
// Timing: Synchronous with global clock, combinational core
//
// Corrections V3-FINAL:
//   - prod_xx:     13 bits (9-bit input * 4-bit weight)
//   - sum_xa/xb:   14 bits (13+13 addition)
//   - sum_xe/xf:   15 bits (14+14 addition)
//   - hidden[x]:   15 bits (15+13 accumulation + bias)
//   - hidden_relu: 15 bits (ReLU preserves width)
//   - o_px:        20 bits (15-bit hidden * 5-bit weight)
//   - o_s1/s2:     21 bits (20+20 addition)
//   - out_raw:     21 bits (21+16 accumulation + bias)
//   - out_sat:     8 bits (final saturation)
//
// Author: Principal ASIC Design Engineer
// Target: OpenLane + Sky130_fd_sc_hd
//=============================================================================

`timescale 1ns / 1ps

module glm5_nanocore (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] in,
    output reg  [7:0] out
);

    //=========================================================================
    // SECTION 1: REGISTERED INPUTS
    //=========================================================================

    reg [7:0] in_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_reg <= 8'b0;
        end else begin
            in_reg <= in;
        end
    end

    //=========================================================================
    // SECTION 2: HARDWIRED WEIGHT CONSTANTS
    //=========================================================================

    localparam signed [3:0] W00 = 4'sd2;
    localparam signed [3:0] W01 = 4'sd1;
    localparam signed [3:0] W02 = 4'sd3;
    localparam signed [3:0] W03 = 4'sd0;
    localparam signed [3:0] W04 = 4'sd2;
    localparam signed [3:0] W05 = 4'sd1;
    localparam signed [3:0] W06 = 4'sd2;
    localparam signed [3:0] W07 = 4'sd1;

    localparam signed [3:0] W10 = 4'sd1;
    localparam signed [3:0] W11 = 4'sd2;
    localparam signed [3:0] W12 = 4'sd1;
    localparam signed [3:0] W13 = 4'sd3;
    localparam signed [3:0] W14 = 4'sd1;
    localparam signed [3:0] W15 = 4'sd2;
    localparam signed [3:0] W16 = 4'sd1;
    localparam signed [3:0] W17 = 4'sd2;

    localparam signed [3:0] W20 = 4'sd3;
    localparam signed [3:0] W21 = 4'sd1;
    localparam signed [3:0] W22 = 4'sd2;
    localparam signed [3:0] W23 = 4'sd1;
    localparam signed [3:0] W24 = 4'sd3;
    localparam signed [3:0] W25 = 4'sd1;
    localparam signed [3:0] W26 = 4'sd2;
    localparam signed [3:0] W27 = 4'sd1;

    localparam signed [3:0] W30 = 4'sd1;
    localparam signed [3:0] W31 = 4'sd3;
    localparam signed [3:0] W32 = 4'sd1;
    localparam signed [3:0] W33 = 4'sd2;
    localparam signed [3:0] W34 = 4'sd1;
    localparam signed [3:0] W35 = 4'sd3;
    localparam signed [3:0] W36 = 4'sd1;
    localparam signed [3:0] W37 = 4'sd2;

    // V3-FINAL: Biases widened to 15 bits to match accumulator width
    localparam signed [14:0] B0 = 15'sd5;
    localparam signed [14:0] B1 = 15'sd3;
    localparam signed [14:0] B2 = 15'sd7;
    localparam signed [14:0] B3 = 15'sd4;

    localparam signed [4:0] V0 = 5'sd4;
    localparam signed [4:0] V1 = 5'sd6;
    localparam signed [4:0] V2 = 5'sd3;
    localparam signed [4:0] V3 = 5'sd5;

    // V3-FINAL: Output bias widened to 21 bits
    localparam signed [20:0] C_OUT = 21'sd10;

    //=========================================================================
    // SECTION 3: COMBINATIONAL MAC CORE (Hidden Layer)
    // V3-FINAL: Full overflow-free datapath with progressive width increase
    //=========================================================================

    // V3-FINAL: hidden wires widened to 15 bits
    wire signed [14:0] hidden [0:3];

    //---- NEURON 0 ----
    // V3-FINAL: prod 13-bit, sum 14-bit, accumulator 15-bit
    wire signed [12:0] prod_00, prod_01, prod_02, prod_03;
    wire signed [12:0] prod_04, prod_05, prod_06, prod_07;
    wire signed [13:0] sum_0a, sum_0b, sum_0c, sum_0d;  // 14-bit
    wire signed [14:0] sum_0e, sum_0f;                   // 15-bit

    assign prod_00 = $signed({1'b0, in_reg}) * W00;
    assign prod_01 = $signed({1'b0, in_reg}) * W01;
    assign prod_02 = $signed({1'b0, in_reg}) * W02;
    assign prod_03 = $signed({1'b0, in_reg}) * W03;
    assign prod_04 = $signed({1'b0, in_reg}) * W04;
    assign prod_05 = $signed({1'b0, in_reg}) * W05;
    assign prod_06 = $signed({1'b0, in_reg}) * W06;
    assign prod_07 = $signed({1'b0, in_reg}) * W07;

    // V3-FINAL: Progressive width increase through adder tree
    assign sum_0a = {{1{prod_00[12]}}, prod_00} + {{1{prod_01[12]}}, prod_01};  // 13→14 bit
    assign sum_0b = {{1{prod_02[12]}}, prod_02} + {{1{prod_03[12]}}, prod_03};
    assign sum_0c = {{1{prod_04[12]}}, prod_04} + {{1{prod_05[12]}}, prod_05};
    assign sum_0d = {{1{prod_06[12]}}, prod_06} + {{1{prod_07[12]}}, prod_07};
    assign sum_0e = {{1{sum_0a[13]}}, sum_0a} + {{1{sum_0b[13]}}, sum_0b};      // 14→15 bit
    assign sum_0f = {{1{sum_0c[13]}}, sum_0c} + {{1{sum_0d[13]}}, sum_0d};
    assign hidden[0] = sum_0e + sum_0f + B0;

    //---- NEURON 1 ----
    wire signed [12:0] prod_10, prod_11, prod_12, prod_13;
    wire signed [12:0] prod_14, prod_15, prod_16, prod_17;
    wire signed [13:0] sum_1a, sum_1b, sum_1c, sum_1d;
    wire signed [14:0] sum_1e, sum_1f;

    assign prod_10 = $signed({1'b0, in_reg}) * W10;
    assign prod_11 = $signed({1'b0, in_reg}) * W11;
    assign prod_12 = $signed({1'b0, in_reg}) * W12;
    assign prod_13 = $signed({1'b0, in_reg}) * W13;
    assign prod_14 = $signed({1'b0, in_reg}) * W14;
    assign prod_15 = $signed({1'b0, in_reg}) * W15;
    assign prod_16 = $signed({1'b0, in_reg}) * W16;
    assign prod_17 = $signed({1'b0, in_reg}) * W17;

    assign sum_1a = {{1{prod_10[12]}}, prod_10} + {{1{prod_11[12]}}, prod_11};
    assign sum_1b = {{1{prod_12[12]}}, prod_12} + {{1{prod_13[12]}}, prod_13};
    assign sum_1c = {{1{prod_14[12]}}, prod_14} + {{1{prod_15[12]}}, prod_15};
    assign sum_1d = {{1{prod_16[12]}}, prod_16} + {{1{prod_17[12]}}, prod_17};
    assign sum_1e = {{1{sum_1a[13]}}, sum_1a} + {{1{sum_1b[13]}}, sum_1b};
    assign sum_1f = {{1{sum_1c[13]}}, sum_1c} + {{1{sum_1d[13]}}, sum_1d};
    assign hidden[1] = sum_1e + sum_1f + B1;

    //---- NEURON 2 ----
    wire signed [12:0] prod_20, prod_21, prod_22, prod_23;
    wire signed [12:0] prod_24, prod_25, prod_26, prod_27;
    wire signed [13:0] sum_2a, sum_2b, sum_2c, sum_2d;
    wire signed [14:0] sum_2e, sum_2f;

    assign prod_20 = $signed({1'b0, in_reg}) * W20;
    assign prod_21 = $signed({1'b0, in_reg}) * W21;
    assign prod_22 = $signed({1'b0, in_reg}) * W22;
    assign prod_23 = $signed({1'b0, in_reg}) * W23;
    assign prod_24 = $signed({1'b0, in_reg}) * W24;
    assign prod_25 = $signed({1'b0, in_reg}) * W25;
    assign prod_26 = $signed({1'b0, in_reg}) * W26;
    assign prod_27 = $signed({1'b0, in_reg}) * W27;

    assign sum_2a = {{1{prod_20[12]}}, prod_20} + {{1{prod_21[12]}}, prod_21};
    assign sum_2b = {{1{prod_22[12]}}, prod_22} + {{1{prod_23[12]}}, prod_23};
    assign sum_2c = {{1{prod_24[12]}}, prod_24} + {{1{prod_25[12]}}, prod_25};
    assign sum_2d = {{1{prod_26[12]}}, prod_26} + {{1{prod_27[12]}}, prod_27};
    assign sum_2e = {{1{sum_2a[13]}}, sum_2a} + {{1{sum_2b[13]}}, sum_2b};
    assign sum_2f = {{1{sum_2c[13]}}, sum_2c} + {{1{sum_2d[13]}}, sum_2d};
    assign hidden[2] = sum_2e + sum_2f + B2;

    //---- NEURON 3 ----
    wire signed [12:0] prod_30, prod_31, prod_32, prod_33;
    wire signed [12:0] prod_34, prod_35, prod_36, prod_37;
    wire signed [13:0] sum_3a, sum_3b, sum_3c, sum_3d;
    wire signed [14:0] sum_3e, sum_3f;

    assign prod_30 = $signed({1'b0, in_reg}) * W30;
    assign prod_31 = $signed({1'b0, in_reg}) * W31;
    assign prod_32 = $signed({1'b0, in_reg}) * W32;
    assign prod_33 = $signed({1'b0, in_reg}) * W33;
    assign prod_34 = $signed({1'b0, in_reg}) * W34;
    assign prod_35 = $signed({1'b0, in_reg}) * W35;
    assign prod_36 = $signed({1'b0, in_reg}) * W36;
    assign prod_37 = $signed({1'b0, in_reg}) * W37;

    assign sum_3a = {{1{prod_30[12]}}, prod_30} + {{1{prod_31[12]}}, prod_31};
    assign sum_3b = {{1{prod_32[12]}}, prod_32} + {{1{prod_33[12]}}, prod_33};
    assign sum_3c = {{1{prod_34[12]}}, prod_34} + {{1{prod_35[12]}}, prod_35};
    assign sum_3d = {{1{prod_36[12]}}, prod_36} + {{1{prod_37[12]}}, prod_37};
    assign sum_3e = {{1{sum_3a[13]}}, sum_3a} + {{1{sum_3b[13]}}, sum_3b};
    assign sum_3f = {{1{sum_3c[13]}}, sum_3c} + {{1{sum_3d[13]}}, sum_3d};
    assign hidden[3] = sum_3e + sum_3f + B3;

    //=========================================================================
    // SECTION 4: NON-LINEARITE (ReLU)
    // V3-FINAL: 15-bit ReLU
    //=========================================================================

    wire signed [14:0] hidden_relu [0:3];

    assign hidden_relu[0] = (hidden[0][14] == 1'b1) ? 15'sd0 : hidden[0];
    assign hidden_relu[1] = (hidden[1][14] == 1'b1) ? 15'sd0 : hidden[1];
    assign hidden_relu[2] = (hidden[2][14] == 1'b1) ? 15'sd0 : hidden[2];
    assign hidden_relu[3] = (hidden[3][14] == 1'b1) ? 15'sd0 : hidden[3];

    //=========================================================================
    // SECTION 5: OUTPUT LAYER (Single 8-bit Neuron, Overflow-Free)
    // V3-FINAL: 20-bit products, 21-bit accumulation
    //=========================================================================

    // V3-FINAL: 15-bit ReLU * 5-bit weight = 20 bits
    wire signed [19:0] o_p0, o_p1, o_p2, o_p3;
    wire signed [20:0] o_s1, o_s2;
    wire signed [20:0] out_raw_wide;

    assign o_p0 = hidden_relu[0] * V0;
    assign o_p1 = hidden_relu[1] * V1;
    assign o_p2 = hidden_relu[2] * V2;
    assign o_p3 = hidden_relu[3] * V3;

    // V3-FINAL: 20→21 bit progressive accumulation
    assign o_s1 = {{1{o_p0[19]}}, o_p0} + {{1{o_p1[19]}}, o_p1};
    assign o_s2 = {{1{o_p2[19]}}, o_p2} + {{1{o_p3[19]}}, o_p3};
    assign out_raw_wide = o_s1 + o_s2 + C_OUT;

    //=========================================================================
    // SECTION 6: SATURATION LOGIC (8-bit unsigned)
    //=========================================================================

    wire [7:0] out_sat;

    assign out_sat = (out_raw_wide[20] == 1'b1) ? 8'd0 :
                     (|out_raw_wide[19:8]) ? 8'd255 :
                     out_raw_wide[7:0];

    //=========================================================================
    // SECTION 7: REGISTERED OUTPUTS
    //=========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out <= 8'b0;
        end else begin
            out <= out_sat;
        end
    end

endmodule
