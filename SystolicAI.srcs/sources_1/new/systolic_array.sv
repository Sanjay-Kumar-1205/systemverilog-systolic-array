`timescale 1ns / 1ps

module systolic_array #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter FRAME_CYCLES = (2*N)-1
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic clear_acc,
    input logic input_valid,
    output logic input_ready,
    input logic signed [DATA_WIDTH-1:0] data_in [N-1:0],
    input logic signed [DATA_WIDTH-1:0] weight_in [N-1:0],
    output logic output_valid,
    input logic output_ready,
    output logic signed [ACC_WIDTH-1:0] acc_out [N-1:0][N-1:0]
);

logic signed [DATA_WIDTH-1:0] data_forward [N-1:0][N-1:0];
logic signed [DATA_WIDTH-1:0] weight_forward [N-1:0][N-1:0];

logic valid_right [N-1:0][N-1:0];
logic valid_down [N-1:0][N-1:0];
logic transfer_valid;
logic final_result_valid;
logic [$clog2(FRAME_CYCLES+1)-1:0] accepted_count;

assign input_ready = en && !output_valid;
assign transfer_valid = input_valid && input_ready;
assign final_result_valid = valid_down[N-1][N-1] && (accepted_count == FRAME_CYCLES);

always_ff @(posedge clk)
begin
    if (rst || clear_acc)
    begin
        accepted_count <= 0;
        output_valid <= 0;
    end
    else if (en)
    begin
        if (output_valid && output_ready)
            output_valid <= 0;

        if (transfer_valid && accepted_count != FRAME_CYCLES)
            accepted_count <= accepted_count + 1'b1;

        if (final_result_valid)
            output_valid <= 1;
    end
end

genvar i,j;

generate
for(i=0;i<N;i++) begin : row_gen
    for(j=0;j<N;j++) begin : col_gen

        pe #(
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
        ) pe_inst(

            .clk(clk),
            .rst(rst),
            .en(en),
            .clear_acc(clear_acc),

            .valid_in(
    (j==0) ?
    ((i==0) ? transfer_valid : valid_down[i-1][j]) :
    valid_right[i][j-1]
),

            .data_in(
                (j==0) ?
                data_in[i] :
                data_forward[i][j-1]
            ),

            .weight_in(
                (i==0) ?
                weight_in[j] :
                weight_forward[i-1][j]
            ),

            .data_out(data_forward[i][j]),
            .weight_out(weight_forward[i][j]),

            .valid_right_out(valid_right[i][j]),
            .valid_down_out(valid_down[i][j]),

            .acc_out(acc_out[i][j])

        );

    end
end
endgenerate

endmodule
