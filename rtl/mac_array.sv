`timescale 1ns/1ps

module mac_array #(
    parameter int MATRIX_SIZE = 8,
    parameter int DATA_WIDTH  = 8,
    parameter int ACC_WIDTH   = 18
) (
    input  logic clk,

    input logic signed [DATA_WIDTH-1:0]
        a_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],

    input logic signed [DATA_WIDTH-1:0]
        b_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],

    input logic [2:0] k_count,

    input logic acc_clear,
    input logic mac_enable,

    output logic signed [ACC_WIDTH-1:0]
        acc_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1]
);

    genvar i, j;

    generate
        for (i = 0; i < MATRIX_SIZE; i++) begin : gen_row
            for (j = 0; j < MATRIX_SIZE; j++) begin : gen_col

                mac_pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_mac_pe (
                    .clk       (clk),

                    .a_in      (a_matrix[i][k_count]),
                    .b_in      (b_matrix[k_count][j]),

                    .acc_clear (acc_clear),
                    .mac_enable(mac_enable),

                    .acc_out   (acc_matrix[i][j])
                );

            end
        end
    endgenerate

endmodule
