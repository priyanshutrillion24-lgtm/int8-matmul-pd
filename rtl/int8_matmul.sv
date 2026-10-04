`timescale 1ns/1ps

module int8_matmul #(
    parameter int MATRIX_SIZE = 8,
    parameter int DATA_WIDTH  = 8,
    parameter int ACC_WIDTH   = 18
) (
    // ------------------------------------------------------------
    // External interface
    // ------------------------------------------------------------
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic signed [DATA_WIDTH-1:0] data_in,
    input  logic                         data_valid,
    input  logic                         matrix_sel,
    input  logic                         start,

    output logic                         busy,
    output logic                         done,

    output logic signed [ACC_WIDTH-1:0] data_out,
    output logic                         out_valid
);

    // ------------------------------------------------------------
    // Controller signals
    // ------------------------------------------------------------
    logic       a_write_en;
    logic       b_write_en;
    logic [5:0] load_count;

    logic [2:0] k_count;
    logic       acc_clear;
    logic       mac_enable;

    logic [5:0] out_count;

    // ------------------------------------------------------------
    // Matrix storage
    //
    // A[row][column]
    // B[row][column]
    //
    // Each element is signed INT8.
    // ------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0]
        a_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    logic signed [DATA_WIDTH-1:0]
        b_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    // ------------------------------------------------------------
    // Accumulator array
    //
    // acc_matrix[i][j] = C[i][j]
    // ------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0]
        acc_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    // ------------------------------------------------------------
    // Controller
    // ------------------------------------------------------------
    matmul_controller u_controller (
        .clk        (clk),
        .rst_n      (rst_n),

        .data_valid (data_valid),
        .matrix_sel (matrix_sel),
        .start      (start),

        .a_write_en (a_write_en),
        .b_write_en (b_write_en),
        .load_count (load_count),

        .k_count    (k_count),
        .acc_clear  (acc_clear),
        .mac_enable (mac_enable),

        .out_count  (out_count),
        .out_valid  (out_valid),

        .busy       (busy),
        .done       (done)
    );

    // ------------------------------------------------------------
    // A and B storage
    //
    // load_count[5:3] = row
    // load_count[2:0] = column
    //
    // A and B are loaded one element per accepted cycle.
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (a_write_en) begin
            a_matrix[load_count[5:3]][load_count[2:0]]
                <= $signed(data_in);
        end

        if (b_write_en) begin
            b_matrix[load_count[5:3]][load_count[2:0]]
                <= $signed(data_in);
        end
    end

    // ------------------------------------------------------------
    // MAC array
    //
    // Each PE computes:
    //
    //     acc[i][j] += A[i][k] * B[k][j]
    //
    // for k = 0...7.
    // ------------------------------------------------------------
    mac_array #(
        .MATRIX_SIZE (MATRIX_SIZE),
        .DATA_WIDTH  (DATA_WIDTH),
        .ACC_WIDTH   (ACC_WIDTH)
    ) u_mac_array (
        .clk        (clk),
        .a_matrix   (a_matrix),
        .b_matrix   (b_matrix),
        .k_count    (k_count),
        .acc_clear  (acc_clear),
        .mac_enable (mac_enable),
        .acc_matrix (acc_matrix)
    );

    // ------------------------------------------------------------
    // Output serialization
    //
    // out_count is row-major:
    //
    // 0  -> C[0][0]
    // 1  -> C[0][1]
    // ...
    // 7  -> C[0][7]
    // 8  -> C[1][0]
    // ...
    // 63 -> C[7][7]
    //
    // data_out is meaningful when out_valid = 1.
    // ------------------------------------------------------------
    always_comb begin
        data_out = '0;

        if (out_valid) begin
            data_out =
                acc_matrix[out_count[5:3]][out_count[2:0]];
        end
    end

endmodule
