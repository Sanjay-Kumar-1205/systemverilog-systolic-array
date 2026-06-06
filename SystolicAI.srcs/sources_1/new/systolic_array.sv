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
localparam int COUNT_W = (FRAME_CYCLES > 0) ? $clog2(FRAME_CYCLES+1) : 1;
logic [COUNT_W-1:0] accepted_count;
logic frame_full;

assign frame_full = (accepted_count == FRAME_CYCLES);
assign input_ready = en && !output_valid && !frame_full;
assign transfer_valid = input_valid && input_ready;
assign final_result_valid = valid_down[N-1][N-1] && frame_full;

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

`ifndef SYNTHESIS
property p_counter_bounded;
    @(posedge clk) disable iff (rst || clear_acc || $isunknown(accepted_count))
        accepted_count <= FRAME_CYCLES;
endproperty

property p_frame_full_blocks_input;
    @(posedge clk) disable iff (rst || clear_acc || $isunknown(frame_full))
        frame_full |-> !input_ready;
endproperty

property p_output_valid_sticky;
    @(posedge clk) disable iff (rst || clear_acc || $isunknown(output_valid) || $isunknown(output_ready))
        output_valid && !output_ready |=> output_valid;
endproperty

property p_result_flag_sets_output_valid;
    @(posedge clk) disable iff (rst || clear_acc || $isunknown(final_result_valid))
        final_result_valid |=> output_valid;
endproperty

assert property (p_counter_bounded)
    else $error("accepted_count exceeded FRAME_CYCLES");

assert property (p_frame_full_blocks_input)
    else $error("input_ready must deassert once the frame is full");

assert property (p_output_valid_sticky)
    else $error("output_valid dropped before output_ready");

assert property (p_result_flag_sets_output_valid)
    else $error("final_result_valid did not raise output_valid");
`endif

genvar i,j;

generate
for(i=0;i<N;i++) begin : row_gen
    for(j=0;j<N;j++) begin : col_gen

        if ((i == 0) && (j == 0)) begin : pe_origin
            pe #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) pe_inst(

                .clk(clk),
                .rst(rst),
                .en(en),
                .clear_acc(clear_acc),
                .valid_in(transfer_valid),
                .data_in(data_in[i]),
                .weight_in(weight_in[j]),
                .data_out(data_forward[i][j]),
                .weight_out(weight_forward[i][j]),
                .valid_right_out(valid_right[i][j]),
                .valid_down_out(valid_down[i][j]),
                .acc_out(acc_out[i][j])

            );
        end
        else if (i == 0) begin : pe_top_row
            pe #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) pe_inst(

                .clk(clk),
                .rst(rst),
                .en(en),
                .clear_acc(clear_acc),
                .valid_in(valid_right[i][j-1]),
                .data_in(data_forward[i][j-1]),
                .weight_in(weight_in[j]),
                .data_out(data_forward[i][j]),
                .weight_out(weight_forward[i][j]),
                .valid_right_out(valid_right[i][j]),
                .valid_down_out(valid_down[i][j]),
                .acc_out(acc_out[i][j])

            );
        end
        else if (j == 0) begin : pe_left_col
            pe #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) pe_inst(

                .clk(clk),
                .rst(rst),
                .en(en),
                .clear_acc(clear_acc),
                .valid_in(valid_down[i-1][j]),
                .data_in(data_in[i]),
                .weight_in(weight_forward[i-1][j]),
                .data_out(data_forward[i][j]),
                .weight_out(weight_forward[i][j]),
                .valid_right_out(valid_right[i][j]),
                .valid_down_out(valid_down[i][j]),
                .acc_out(acc_out[i][j])

            );
        end
        else begin : pe_inner
        pe #(
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
        ) pe_inst(

            .clk(clk),
            .rst(rst),
            .en(en),
            .clear_acc(clear_acc),
            .valid_in(valid_right[i][j-1]),
            .data_in(data_forward[i][j-1]),
            .weight_in(weight_forward[i-1][j]),
            .data_out(data_forward[i][j]),
            .weight_out(weight_forward[i][j]),
            .valid_right_out(valid_right[i][j]),
            .valid_down_out(valid_down[i][j]),
            .acc_out(acc_out[i][j])

        );
        end

    end
end
endgenerate

endmodule
