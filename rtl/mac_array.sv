`timescale 1ns/1ps

module mac_array #(
    parameter int MATRIX_SIZE = 8,
    parameter int DATA_WIDTH  = 8,
    parameter int ACC_WIDTH   = 18
) (
    input  logic clk,

    // Flattened A and B matrices.
    //
    // Element index:
    //     index = row * MATRIX_SIZE + column
    //
    // Each element occupies DATA_WIDTH bits.
    input logic signed
        [MATRIX_SIZE*MATRIX_SIZE*DATA_WIDTH-1:0] a_flat,

    input logic signed
        [MATRIX_SIZE*MATRIX_SIZE*DATA_WIDTH-1:0] b_flat,

    input logic [2:0] k_count,

    input logic acc_clear,
    input logic mac_enable,

    // Flattened accumulator array.
    //
    // Each element occupies ACC_WIDTH bits.
    output logic signed
        [MATRIX_SIZE*MATRIX_SIZE*ACC_WIDTH-1:0] acc_flat
);

    genvar i;
    genvar j;

    generate
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin : gen_row

            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin : gen_col

                localparam int A_INDEX =
                    i * MATRIX_SIZE;

                localparam int B_INDEX =
                    j;

                localparam int ACC_INDEX =
                    i * MATRIX_SIZE + j;

                logic signed [DATA_WIDTH-1:0] a_operand;
                logic signed [DATA_WIDTH-1:0] b_operand;

                logic signed [ACC_WIDTH-1:0] acc_value;

                // ------------------------------------------------
                // A[i][k]
                //
                // Flat index:
                //     i * MATRIX_SIZE + k_count
                // ------------------------------------------------
                assign a_operand =
    a_flat[
        ((A_INDEX + int'(k_count)) * DATA_WIDTH)
        +: DATA_WIDTH
    ];

                // ------------------------------------------------
                // B[k][j]
                //
                // Flat index:
                //     k_count * MATRIX_SIZE + j
                // ------------------------------------------------
                assign b_operand =
    b_flat[
        (((int'(k_count) * MATRIX_SIZE) + B_INDEX)
         * DATA_WIDTH)
        +: DATA_WIDTH
    ];

                // ------------------------------------------------
                // One MAC PE
                // ------------------------------------------------
                mac_pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_mac_pe (
                    .clk       (clk),
                    .a_in      (a_operand),
                    .b_in      (b_operand),
                    .acc_clear (acc_clear),
                    .mac_enable(mac_enable),
                    .acc_out   (acc_value)
                );

                // ------------------------------------------------
                // Place PE accumulator into flat output bus
                // ------------------------------------------------
                assign acc_flat[
                    ACC_INDEX*ACC_WIDTH
                    +: ACC_WIDTH
                ] = acc_value;

            end

        end
    endgenerate

endmodule
