


`timescale 1ns/1ps
module mac_pe #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 18
) (
    input  logic                         clk,
    input  logic signed [DATA_WIDTH-1:0] a_in,
    input  logic signed [DATA_WIDTH-1:0] b_in,
    input  logic                         acc_clear,
    input  logic                         mac_enable,
    output logic signed [ACC_WIDTH-1:0]  acc_out
);

    localparam int PROD_WIDTH = 2 * DATA_WIDTH;

    // Multiplier result: signed INT16 for the baseline DATA_WIDTH=8 case.
    logic signed [PROD_WIDTH-1:0] product;

    // Product extended to accumulator width before addition.
    logic signed [ACC_WIDTH-1:0] product_ext;

    // Explicitly size/sign the multiplier result and then sign-extend it.
    assign product = $signed(a_in) * $signed(b_in);
    assign product_ext = {{(ACC_WIDTH-PROD_WIDTH){product[PROD_WIDTH-1]}}, product};

    // Baseline sequential behavior.
    // acc_clear has priority over mac_enable.
    always_ff @(posedge clk) begin
        if (acc_clear) begin
            acc_out <= '0;
        end
        else if (mac_enable) begin
            acc_out <= acc_out + product_ext;
        end
    end

endmodule
