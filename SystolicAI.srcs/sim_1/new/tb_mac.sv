`timescale 1ns / 1ps

module tb_mac;

logic clk;
logic rst;
logic en;
logic clear_acc;
logic valid_in;
logic valid_out;
logic signed [7:0] a;
logic signed [7:0] b;
logic signed [31:0] acc;

mac dut (
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_in),
    .valid_out(valid_out),
    .a(a),
    .b(b),
    .acc(acc)
);

always #5 clk = ~clk;

task automatic drive_cycle(
    input logic drive_valid,
    input logic drive_en,
    input logic signed [7:0] drive_a,
    input logic signed [7:0] drive_b
);
begin
    @(negedge clk);
    valid_in = drive_valid;
    en = drive_en;
    a = drive_a;
    b = drive_b;
end
endtask

initial begin
    clk = 0;
    rst = 1;
    en = 0;
    clear_acc = 0;
    valid_in = 0;
    a = 0;
    b = 0;

    repeat (2) @(negedge clk);
    rst = 0;

    drive_cycle(1'b1, 1'b1, 8'sd2, 8'sd3);
    @(posedge clk);
    #1;
    if (acc !== 32'sd6) $error("MAC accumulation failed after first product: %0d", acc);
    if (valid_out !== 1'b1) $error("valid_out should follow valid_in when enabled");

    drive_cycle(1'b1, 1'b1, -8'sd4, 8'sd5);
    @(posedge clk);
    #1;
    if (acc !== -32'sd14) $error("Signed accumulation failed: %0d", acc);

    drive_cycle(1'b1, 1'b0, 8'sd7, 8'sd9);
    @(posedge clk);
    #1;
    if (acc !== -32'sd14) $error("Accumulator changed while disabled: %0d", acc);
    if (valid_out !== 1'b0) $error("valid_out should be low while disabled");

    drive_cycle(1'b0, 1'b1, 8'sd12, -8'sd3);
    @(posedge clk);
    #1;
    if (acc !== -32'sd14) $error("Accumulator changed on invalid input: %0d", acc);
    if (valid_out !== 1'b0) $error("valid_out should be low when valid_in is low");

    @(negedge clk);
    clear_acc = 1'b1;
    @(posedge clk);
    #1;
    if (acc !== 32'sd0) $error("clear_acc failed to zero the accumulator");
    if (valid_out !== 1'b0) $error("valid_out should clear with clear_acc");
    @(negedge clk);
    clear_acc = 1'b0;

    drive_cycle(1'b1, 1'b1, -8'sd8, -8'sd2);
    @(posedge clk);
    #1;
    if (acc !== 32'sd16) $error("MAC did not restart cleanly after clear: %0d", acc);

    $display("tb_mac passed");
    $finish;
end

endmodule
