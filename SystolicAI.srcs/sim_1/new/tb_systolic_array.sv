`timescale 1ns / 1ps

module tb_systolic_array;

parameter N = 2;
parameter DATA_WIDTH = 8;
parameter ACC_WIDTH = 32;

logic clk;
logic rst;
logic en;
logic clear_acc;
logic input_valid;
logic input_ready;
logic output_valid;
logic output_ready;

logic signed [DATA_WIDTH-1:0] data_in [N-1:0];
logic signed [DATA_WIDTH-1:0] weight_in [N-1:0];

logic signed [ACC_WIDTH-1:0] acc_out [N-1:0][N-1:0];

systolic_array #(
    .N(N),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH)
) dut(
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .input_valid(input_valid),
    .input_ready(input_ready),
    .data_in(data_in),
    .weight_in(weight_in),
    .output_valid(output_valid),
    .output_ready(output_ready),
    .acc_out(acc_out)
);

always #5 clk = ~clk;

task automatic drive_inputs(
    input logic signed [7:0] data0,
    input logic signed [7:0] data1,
    input logic signed [7:0] weight0,
    input logic signed [7:0] weight1,
    input logic valid
);
begin
    @(negedge clk);
    data_in[0] = data0;
    data_in[1] = data1;
    weight_in[0] = weight0;
    weight_in[1] = weight1;
    input_valid = valid;
    if (valid)
        wait (input_ready);
end
endtask

initial begin

    clk = 0;
    rst = 1;
    en = 0;
    clear_acc = 0;
    input_valid = 0;
    output_ready = 0;
    data_in[0] = 0;
    data_in[1] = 0;
    weight_in[0] = 0;
    weight_in[1] = 0;

    repeat (2) @(negedge clk);

    rst = 0;
    en = 1;

    clear_acc = 1;
    @(negedge clk);
    clear_acc = 0;

    drive_inputs(8'sd1, 8'sd0, 8'sd5, 8'sd0, 1'b1);
    drive_inputs(8'sd2, 8'sd3, 8'sd7, 8'sd6, 1'b1);
    drive_inputs(8'sd0, 8'sd4, 8'sd0, 8'sd8, 1'b1);
    drive_inputs(8'sd0, 8'sd0, 8'sd0, 8'sd0, 1'b0);

    wait (output_valid);

    $display("Final systolic result:");
    $display("[%0d %0d]", acc_out[0][0], acc_out[0][1]);
    $display("[%0d %0d]", acc_out[1][0], acc_out[1][1]);
    $display("Expected:");
    $display("[19 22]");
    $display("[43 50]");

    if (acc_out[0][0] !== 32'sd19) $error("acc_out[0][0] expected 19, got %0d", acc_out[0][0]);
    if (acc_out[0][1] !== 32'sd22) $error("acc_out[0][1] expected 22, got %0d", acc_out[0][1]);
    if (acc_out[1][0] !== 32'sd43) $error("acc_out[1][0] expected 43, got %0d", acc_out[1][0]);
    if (acc_out[1][1] !== 32'sd50) $error("acc_out[1][1] expected 50, got %0d", acc_out[1][1]);

    @(negedge clk);
    output_ready = 1;
    @(negedge clk);

    $finish;

end

endmodule
