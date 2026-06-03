`timescale 1ns / 1ps

module mac #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic clear_acc,
    input logic valid_in,
    output logic valid_out,
    input logic signed [DATA_WIDTH-1:0] a,
    input logic signed [DATA_WIDTH-1:0] b,
    output logic signed [ACC_WIDTH-1:0] acc
);

logic signed [(2*DATA_WIDTH)-1:0] mult;
logic signed [ACC_WIDTH-1:0] mult_ext;

assign mult = a * b;
assign mult_ext = mult;

always_ff @(posedge clk)
begin
    if (rst || clear_acc)
    begin
        acc <= 0;
        valid_out <= 0;
    end
    else
    begin
        valid_out <= 0;

        if (en)
        begin
            valid_out <= valid_in;

            if (valid_in)
                acc <= acc + mult_ext;
        end
    end
end

endmodule
