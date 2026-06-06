`timescale 1ns / 1ps

module systolic_2x2(
    input logic clk,
    input logic rst,
    input logic en,
    input logic clear_acc,
    input logic valid_in,
    input logic signed [7:0] data0_in,
    input logic signed [7:0] data1_in,
    input logic signed [7:0] weight0_in,
    input logic signed [7:0] weight1_in,
    output logic signed [31:0] acc00,
    output logic signed [31:0] acc01,
    output logic signed [31:0] acc10,
    output logic signed [31:0] acc11
);

logic signed [7:0] data_pe00_to_pe01;
logic signed [7:0] data_pe10_to_pe11;
logic signed [7:0] weight_pe00_to_pe10;
logic signed [7:0] weight_pe01_to_pe11;
logic valid_pe00_to_pe01;
logic valid_pe00_to_pe10;
logic valid_pe01_to_pe11;
logic valid_pe10_to_pe11;

pe pe00(
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_in),
    .data_in(data0_in),
    .weight_in(weight0_in),
    .data_out(data_pe00_to_pe01),
    .weight_out(weight_pe00_to_pe10),
    .valid_right_out(valid_pe00_to_pe01),
    .valid_down_out(valid_pe00_to_pe10),
    .acc_out(acc00)
);

pe pe01(
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_pe00_to_pe01),
    .data_in(data_pe00_to_pe01),
    .weight_in(weight1_in),
    .data_out(),
    .weight_out(weight_pe01_to_pe11),
    .valid_right_out(),
    .valid_down_out(valid_pe01_to_pe11),
    .acc_out(acc01)
);

pe pe10(
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_pe00_to_pe10),
    .data_in(data1_in),
    .weight_in(weight_pe00_to_pe10),
    .data_out(data_pe10_to_pe11),
    .weight_out(),
    .valid_right_out(valid_pe10_to_pe11),
    .valid_down_out(),
    .acc_out(acc10)
);

pe pe11(
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_pe10_to_pe11),
    .data_in(data_pe10_to_pe11),
    .weight_in(weight_pe01_to_pe11),
    .data_out(),
    .weight_out(),
    .valid_right_out(),
    .valid_down_out(),
    .acc_out(acc11)
);

endmodule
