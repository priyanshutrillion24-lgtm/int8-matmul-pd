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

    output logic signed [ACC_WIDTH-1:0]  data_out,
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
    // These remain internal 2-D arrays.
    // Yosys is rejecting the 2-D ARRAY PORT, not these internal
    // storage declarations.
    // ------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0]
        a_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    logic signed [DATA_WIDTH-1:0]
        b_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    // ------------------------------------------------------------
    // Accumulator storage
    // ------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0]
        acc_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    // ------------------------------------------------------------
    // Flat buses used to connect to mac_array.
    //
    // This avoids unsupported/awkward unpacked array module ports
    // in the classic Yosys SystemVerilog frontend.
    // ------------------------------------------------------------
    logic signed
        [MATRIX_SIZE*MATRIX_SIZE*DATA_WIDTH-1:0] a_flat;

    logic signed
        [MATRIX_SIZE*MATRIX_SIZE*DATA_WIDTH-1:0] b_flat;

    logic signed
        [MATRIX_SIZE*MATRIX_SIZE*ACC_WIDTH-1:0] acc_flat;

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
    // Flatten 2-D A/B storage into packed buses.
    // ------------------------------------------------------------
    genvar r;
    genvar c;

    generate
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin : gen_flatten_row

            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin : gen_flatten_col

                localparam int INDEX =
                    r * MATRIX_SIZE + c;

                assign a_flat[
                    INDEX*DATA_WIDTH
                    +: DATA_WIDTH
                ] = a_matrix[r][c];

                assign b_flat[
                    INDEX*DATA_WIDTH
                    +: DATA_WIDTH
                ] = b_matrix[r][c];

                assign acc_matrix[r][c] =
                    acc_flat[
                        INDEX*ACC_WIDTH
                        +: ACC_WIDTH
                    ];

            end

        end
    endgenerate

    // ------------------------------------------------------------
    // MAC array
    // ------------------------------------------------------------
    mac_array #(
        .MATRIX_SIZE (MATRIX_SIZE),
        .DATA_WIDTH  (DATA_WIDTH),
        .ACC_WIDTH   (ACC_WIDTH)
    ) u_mac_array (
        .clk        (clk),
        .a_flat     (a_flat),
        .b_flat     (b_flat),
        .k_count    (k_count),
        .acc_clear  (acc_clear),
        .mac_enable (mac_enable),
        .acc_flat   (acc_flat)
    );

    // ------------------------------------------------------------
    // Output serialization
    //
    // Row-major:
    //
    // 0  -> C[0][0]
    // 1  -> C[0][1]
    // ...
    // 63 -> C[7][7]
    // ------------------------------------------------------------
    always_comb begin

        data_out = '0;

        if (out_valid) begin
            data_out =
                acc_matrix[
                    out_count[5:3]
                ][
                    out_count[2:0]
                ];
        end

    end

endmodule
