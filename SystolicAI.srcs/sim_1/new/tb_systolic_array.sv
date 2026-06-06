`timescale 1ns / 1ps

module tb_systolic_array;

parameter N = 3;
parameter DATA_WIDTH = 8;
parameter ACC_WIDTH = 32;
localparam FRAME_CYCLES = (2*N)-1;

typedef logic signed [DATA_WIDTH-1:0] data_t;
typedef logic signed [ACC_WIDTH-1:0] acc_t;

logic clk;
logic rst;
logic en;
logic clear_acc;
logic input_valid;
logic input_ready;
logic output_valid;
logic output_ready;

data_t data_in [N-1:0];
data_t weight_in [N-1:0];
acc_t acc_out [N-1:0][N-1:0];

data_t a_mat [N-1:0][N-1:0];
data_t b_mat [N-1:0][N-1:0];
acc_t golden [N-1:0][N-1:0];

systolic_array #(
    .N(N),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .FRAME_CYCLES(FRAME_CYCLES)
) dut (
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

task automatic apply_reset;
begin
    rst = 1'b1;
    en = 1'b0;
    clear_acc = 1'b0;
    input_valid = 1'b0;
    output_ready = 1'b0;

    for (int idx = 0; idx < N; idx++) begin
        data_in[idx] = '0;
        weight_in[idx] = '0;
    end

    repeat (2) @(negedge clk);
    rst = 1'b0;
    en = 1'b1;
end
endtask

task automatic pulse_clear;
begin
    @(negedge clk);
    clear_acc = 1'b1;
    @(negedge clk);
    clear_acc = 1'b0;
end
endtask

task automatic load_case(input int case_id);
begin
    if (case_id == 0) begin
        a_mat[0][0] = 8'sd1;  a_mat[0][1] = 8'sd2;  a_mat[0][2] = 8'sd3;
        a_mat[1][0] = 8'sd4;  a_mat[1][1] = 8'sd5;  a_mat[1][2] = 8'sd6;
        a_mat[2][0] = 8'sd7;  a_mat[2][1] = 8'sd8;  a_mat[2][2] = 8'sd9;

        b_mat[0][0] = 8'sd9;  b_mat[0][1] = 8'sd8;  b_mat[0][2] = 8'sd7;
        b_mat[1][0] = 8'sd6;  b_mat[1][1] = 8'sd5;  b_mat[1][2] = 8'sd4;
        b_mat[2][0] = 8'sd3;  b_mat[2][1] = 8'sd2;  b_mat[2][2] = 8'sd1;
    end
    else begin
        a_mat[0][0] = -8'sd3; a_mat[0][1] =  8'sd1; a_mat[0][2] = -8'sd2;
        a_mat[1][0] =  8'sd4; a_mat[1][1] = -8'sd5; a_mat[1][2] =  8'sd6;
        a_mat[2][0] = -8'sd7; a_mat[2][1] =  8'sd8; a_mat[2][2] =  8'sd2;

        b_mat[0][0] =  8'sd2; b_mat[0][1] = -8'sd1; b_mat[0][2] =  8'sd0;
        b_mat[1][0] = -8'sd4; b_mat[1][1] =  8'sd3; b_mat[1][2] =  8'sd5;
        b_mat[2][0] =  8'sd6; b_mat[2][1] =  8'sd7; b_mat[2][2] = -8'sd2;
    end
end
endtask

task automatic compute_golden;
begin
    for (int row = 0; row < N; row++) begin
        for (int col = 0; col < N; col++) begin
            golden[row][col] = '0;
            for (int k = 0; k < N; k++)
                golden[row][col] += $signed(a_mat[row][k]) * $signed(b_mat[k][col]);
        end
    end
end
endtask

task automatic load_stream_cycle(input int cycle_idx);
begin
    for (int row = 0; row < N; row++) begin
        int a_col;
        a_col = cycle_idx - row;
        if ((a_col >= 0) && (a_col < N))
            data_in[row] = a_mat[row][a_col];
        else
            data_in[row] = '0;
    end

    for (int col = 0; col < N; col++) begin
        int b_row;
        b_row = cycle_idx - col;
        if ((b_row >= 0) && (b_row < N))
            weight_in[col] = b_mat[b_row][col];
        else
            weight_in[col] = '0;
    end
end
endtask

task automatic send_frame;
begin
    for (int cycle_idx = 0; cycle_idx < FRAME_CYCLES; cycle_idx++) begin
        @(negedge clk);
        if (!input_ready) $error("input_ready dropped before frame completion at cycle %0d", cycle_idx);
        load_stream_cycle(cycle_idx);
        input_valid = 1'b1;
    end

    @(negedge clk);
    input_valid = 1'b0;
    for (int idx = 0; idx < N; idx++) begin
        data_in[idx] = '0;
        weight_in[idx] = '0;
    end
end
endtask

task automatic check_result(input string test_name);
begin
    for (int row = 0; row < N; row++) begin
        for (int col = 0; col < N; col++) begin
            if (acc_out[row][col] !== golden[row][col]) begin
                $error("%s mismatch at [%0d][%0d]: expected %0d got %0d",
                       test_name, row, col, golden[row][col], acc_out[row][col]);
            end
        end
    end
end
endtask

task automatic run_case(input int case_id, input string test_name, input int hold_cycles);
begin
    load_case(case_id);
    compute_golden();
    pulse_clear();
    send_frame();

    wait (output_valid);
    if (input_ready !== 1'b0) $error("%s: input_ready must deassert while output_valid is high", test_name);

    repeat (hold_cycles) begin
        @(negedge clk);
        output_ready = 1'b0;
        if (output_valid !== 1'b1) $error("%s: output_valid dropped during backpressure", test_name);
    end

    check_result(test_name);

    @(negedge clk);
    output_ready = 1'b1;
    @(posedge clk);
    @(negedge clk);
    output_ready = 1'b0;
end
endtask

initial begin
    clk = 0;
    apply_reset();

    run_case(0, "dense_positive_3x3", 2);
    run_case(1, "signed_mixed_3x3", 4);

    $display("tb_systolic_array passed for %0d x %0d frames", N, N);
    $finish;
end

endmodule
