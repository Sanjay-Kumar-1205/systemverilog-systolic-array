`timescale 1ns / 1ps

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic clear_acc,
    input logic valid_in,
    input logic signed [DATA_WIDTH-1:0] data_in,
    input logic signed [DATA_WIDTH-1:0] weight_in,
    output logic signed [DATA_WIDTH-1:0] data_out,
    output logic signed [DATA_WIDTH-1:0] weight_out,
    output logic valid_right_out,
    output logic valid_down_out,
    output logic signed [ACC_WIDTH-1:0] acc_out
);

logic mac_valid;

mac #(
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH)
) inst_mac(
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_in),
    .valid_out(mac_valid),
    .a(data_in),
    .b(weight_in),
    .acc(acc_out)
);

always_ff @(posedge clk)
begin
    if (rst || clear_acc) begin
        data_out <= 0;
        weight_out <= 0;
        valid_right_out <= 0;
        valid_down_out <= 0;
    end else if (en) begin
        data_out <= data_in;
        weight_out <= weight_in;
        valid_right_out <= valid_in;
        valid_down_out <= valid_in;
    end
end

endmodule
