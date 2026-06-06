`timescale 1ns / 1ps

module tb_systolic_2x2;

logic clk;
logic rst;
logic en;
logic clear_acc;

logic valid_in;

logic signed [7:0] data0;
logic signed [7:0] data1;

logic signed [7:0] weight0;
logic signed [7:0] weight1;

logic signed [31:0] acc00;
logic signed [31:0] acc01;
logic signed [31:0] acc10;
logic signed [31:0] acc11;

systolic_2x2 dut(
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_in),
    .data0_in(data0),
    .data1_in(data1),
    .weight0_in(weight0),
    .weight1_in(weight1),
    .acc00(acc00),
    .acc01(acc01),
    .acc10(acc10),
    .acc11(acc11)
);

always #5 clk = ~clk;

task automatic drive_inputs(
    input logic signed [7:0] data0_in,
    input logic signed [7:0] data1_in,
    input logic signed [7:0] weight0_in,
    input logic signed [7:0] weight1_in,
    input logic valid
);
begin
    @(negedge clk);
    data0 = data0_in;
    data1 = data1_in;
    weight0 = weight0_in;
    weight1 = weight1_in;
    valid_in = valid;
end
endtask

initial begin
    clk = 0;
    rst = 1;
    en  = 0;
    clear_acc = 0;
    valid_in = 0;
    data0 = 0;
    data1 = 0;
    weight0 = 0;
    weight1 = 0;
    repeat (2) @(negedge clk);
    rst = 0;
    en  = 1;
    clear_acc = 1;
    @(negedge clk);
    clear_acc = 0;
    drive_inputs(8'sd1, 8'sd0, 8'sd5, 8'sd0, 1'b1);
    drive_inputs(8'sd2, 8'sd3, 8'sd7, 8'sd6, 1'b1);
    drive_inputs(8'sd0, 8'sd4, 8'sd0, 8'sd8, 1'b1);
    drive_inputs(8'sd0, 8'sd0, 8'sd0, 8'sd0, 1'b0);
    repeat (6) @(posedge clk);
    $display("Final systolic result:");
    $display("[%0d %0d]", acc00, acc01);
    $display("[%0d %0d]", acc10, acc11);
    $display("Expected:");
    $display("[19 22]");
    $display("[43 50]");
    if (acc00 !== 32'sd19) $error("acc00 expected 19, got %0d", acc00);
    if (acc01 !== 32'sd22) $error("acc01 expected 22, got %0d", acc01);
    if (acc10 !== 32'sd43) $error("acc10 expected 43, got %0d", acc10);
    if (acc11 !== 32'sd50) $error("acc11 expected 50, got %0d", acc11);
    $finish;
end

endmodule
