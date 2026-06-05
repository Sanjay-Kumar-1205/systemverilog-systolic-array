`timescale 1ns / 1ps

module tb_systolic_consistency;

localparam DATA_WIDTH = 8;
localparam ACC_WIDTH = 32;
localparam N = 2;
localparam FRAME_CYCLES = (2*N)-1;

typedef logic signed [DATA_WIDTH-1:0] data_t;
typedef logic signed [ACC_WIDTH-1:0] acc_t;

logic clk;
logic rst;
logic en;
logic clear_acc;
logic valid_in;

data_t data0;
data_t data1;
data_t weight0;
data_t weight1;

logic input_valid;
logic input_ready;
logic output_valid;
logic output_ready;
data_t data_in [N-1:0];
data_t weight_in [N-1:0];

acc_t acc00_ref;
acc_t acc01_ref;
acc_t acc10_ref;
acc_t acc11_ref;
acc_t acc_out [N-1:0][N-1:0];

data_t a_mat [N-1:0][N-1:0];
data_t b_mat [N-1:0][N-1:0];
acc_t golden [N-1:0][N-1:0];

systolic_2x2 dut_ref (
    .clk(clk),
    .rst(rst),
    .en(en),
    .clear_acc(clear_acc),
    .valid_in(valid_in),
    .data0_in(data0),
    .data1_in(data1),
    .weight0_in(weight0),
    .weight1_in(weight1),
    .acc00(acc00_ref),
    .acc01(acc01_ref),
    .acc10(acc10_ref),
    .acc11(acc11_ref)
);

systolic_array #(
    .N(N),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .FRAME_CYCLES(FRAME_CYCLES)
) dut_generic (
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
    valid_in = 1'b0;
    input_valid = 1'b0;
    output_ready = 1'b0;
    data0 = '0;
    data1 = '0;
    weight0 = '0;
    weight1 = '0;
    data_in[0] = '0;
    data_in[1] = '0;
    weight_in[0] = '0;
    weight_in[1] = '0;

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
        a_mat[0][0] = 8'sd1;  a_mat[0][1] = 8'sd2;
        a_mat[1][0] = 8'sd3;  a_mat[1][1] = 8'sd4;

        b_mat[0][0] = 8'sd5;  b_mat[0][1] = 8'sd6;
        b_mat[1][0] = 8'sd7;  b_mat[1][1] = 8'sd8;
    end
    else begin
        a_mat[0][0] = -8'sd2; a_mat[0][1] =  8'sd5;
        a_mat[1][0] =  8'sd7; a_mat[1][1] = -8'sd3;

        b_mat[0][0] =  8'sd4; b_mat[0][1] = -8'sd1;
        b_mat[1][0] = -8'sd6; b_mat[1][1] =  8'sd2;
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

task automatic drive_cycle(input int cycle_idx, input logic drive_valid);
    int a_col0;
    int a_col1;
    int b_row0;
    int b_row1;
begin
    a_col0 = cycle_idx;
    a_col1 = cycle_idx - 1;
    b_row0 = cycle_idx;
    b_row1 = cycle_idx - 1;

    @(negedge clk);

    if (drive_valid) begin
        data0 = ((a_col0 >= 0) && (a_col0 < N)) ? a_mat[0][a_col0] : '0;
        data1 = ((a_col1 >= 0) && (a_col1 < N)) ? a_mat[1][a_col1] : '0;
        weight0 = ((b_row0 >= 0) && (b_row0 < N)) ? b_mat[b_row0][0] : '0;
        weight1 = ((b_row1 >= 0) && (b_row1 < N)) ? b_mat[b_row1][1] : '0;
    end
    else begin
        data0 = '0;
        data1 = '0;
        weight0 = '0;
        weight1 = '0;
    end

    valid_in = drive_valid;
    input_valid = drive_valid;
    data_in[0] = data0;
    data_in[1] = data1;
    weight_in[0] = weight0;
    weight_in[1] = weight1;

    if (drive_valid && !input_ready)
        $error("generic array deasserted input_ready during frame transfer");
end
endtask

task automatic check_outputs(input string test_name);
begin
    if (acc00_ref !== golden[0][0]) $error("%s ref acc00 expected %0d got %0d", test_name, golden[0][0], acc00_ref);
    if (acc01_ref !== golden[0][1]) $error("%s ref acc01 expected %0d got %0d", test_name, golden[0][1], acc01_ref);
    if (acc10_ref !== golden[1][0]) $error("%s ref acc10 expected %0d got %0d", test_name, golden[1][0], acc10_ref);
    if (acc11_ref !== golden[1][1]) $error("%s ref acc11 expected %0d got %0d", test_name, golden[1][1], acc11_ref);

    if (acc_out[0][0] !== golden[0][0]) $error("%s generic acc00 expected %0d got %0d", test_name, golden[0][0], acc_out[0][0]);
    if (acc_out[0][1] !== golden[0][1]) $error("%s generic acc01 expected %0d got %0d", test_name, golden[0][1], acc_out[0][1]);
    if (acc_out[1][0] !== golden[1][0]) $error("%s generic acc10 expected %0d got %0d", test_name, golden[1][0], acc_out[1][0]);
    if (acc_out[1][1] !== golden[1][1]) $error("%s generic acc11 expected %0d got %0d", test_name, golden[1][1], acc_out[1][1]);

    if (acc_out[0][0] !== acc00_ref) $error("%s mismatch between generic and reference acc00", test_name);
    if (acc_out[0][1] !== acc01_ref) $error("%s mismatch between generic and reference acc01", test_name);
    if (acc_out[1][0] !== acc10_ref) $error("%s mismatch between generic and reference acc10", test_name);
    if (acc_out[1][1] !== acc11_ref) $error("%s mismatch between generic and reference acc11", test_name);
end
endtask

task automatic run_case(input int case_id, input string test_name, input int hold_cycles);
begin
    load_case(case_id);
    compute_golden();
    pulse_clear();

    drive_cycle(0, 1'b1);
    drive_cycle(1, 1'b1);
    drive_cycle(2, 1'b1);
    drive_cycle(3, 1'b0);

    repeat (6) @(posedge clk);
    wait (output_valid);

    repeat (hold_cycles) begin
        @(negedge clk);
        output_ready = 1'b0;
        if (output_valid !== 1'b1) $error("%s output_valid dropped under backpressure", test_name);
    end

    check_outputs(test_name);

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

    run_case(0, "positive_case", 2);
    run_case(1, "signed_case", 3);

    $display("tb_systolic_consistency passed");
    $finish;
end

endmodule
