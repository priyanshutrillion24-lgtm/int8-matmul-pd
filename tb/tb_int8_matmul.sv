`timescale 1ns/1ps

module tb_int8_matmul;

    localparam int MATRIX_SIZE = 8;
    localparam int DATA_WIDTH  = 8;
    localparam int ACC_WIDTH   = 18;

    // ------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------
    logic clk;
    logic rst_n;

    // ------------------------------------------------------------
    // DUT inputs
    // ------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] data_in;
    logic                         data_valid;
    logic                         matrix_sel;
    logic                         start;

    // ------------------------------------------------------------
    // DUT outputs
    // ------------------------------------------------------------
    logic                         busy;
    logic                         done;
    logic signed [ACC_WIDTH-1:0] data_out;
    logic                         out_valid;

    // ------------------------------------------------------------
    // Test matrices
    // ------------------------------------------------------------
    logic signed [7:0] a_values [0:7][0:7];
    logic signed [7:0] b_values [0:7][0:7];

    // Software reference in row-major order
    integer expected_flat [0:63];

    integer r;
    integer c;
    integer k;
    integer idx;

    integer expected_value;
    integer actual_value;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    int8_matmul #(
        .MATRIX_SIZE (MATRIX_SIZE),
        .DATA_WIDTH  (DATA_WIDTH),
        .ACC_WIDTH   (ACC_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),

        .data_in    (data_in),
        .data_valid (data_valid),
        .matrix_sel (matrix_sel),
        .start      (start),

        .busy       (busy),
        .done       (done),

        .data_out   (data_out),
        .out_valid  (out_valid)
    );

    // ------------------------------------------------------------
    // 10 ns clock period
    // ------------------------------------------------------------
    always #5 clk <= ~clk;

    // ------------------------------------------------------------
    // Test helper
    // ------------------------------------------------------------
    task automatic check(
        input logic  condition,
        input string message
    );
        begin
            if (!condition) begin
                $display("ERROR: %s", message);
                $fatal(1);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------
    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------
        clk        = 1'b0;
        rst_n      = 1'b0;

        data_in    = '0;
        data_valid = 1'b0;
        matrix_sel = 1'b0;
        start      = 1'b0;

        // --------------------------------------------------------
        // Build deterministic signed matrices
        //
        // A[r][c] = r - c
        // B[r][c] = r + c - 3
        //
        // These contain both positive and negative INT8 values.
        // --------------------------------------------------------
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                a_values[r][c] = 8'(r - c);
                b_values[r][c] = 8'(r + c - 3);

            end
        end

        // --------------------------------------------------------
        // Generate software reference:
        //
        // C[r][c] = sum(A[r][k] * B[k][c])
        // --------------------------------------------------------
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                expected_value = 0;

                for (k = 0; k < MATRIX_SIZE; k = k + 1) begin
                    expected_value =
                        expected_value
                        + $signed(a_values[r][k])
                        * $signed(b_values[k][c]);
                end

                idx = r * MATRIX_SIZE + c;
                expected_flat[idx] = expected_value;

            end
        end

        // --------------------------------------------------------
        // Waveform tracing
        // --------------------------------------------------------
        $dumpfile("int8_matmul.fst");
        $dumpvars(0, tb_int8_matmul);

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------
        repeat (2) @(posedge clk);

        #1;

        check(busy == 1'b0,
              "busy should be 0 after reset");

        check(done == 1'b0,
              "done should be 0 after reset");

        check(out_valid == 1'b0,
              "out_valid should be 0 after reset");

        $display("PASS: reset");

        // Release reset
        @(negedge clk);
        rst_n = 1'b1;

        // --------------------------------------------------------
        // LOAD MATRIX A
        //
        // Inputs are changed on negedge.
        // DUT samples them on the following posedge.
        // --------------------------------------------------------
        @(negedge clk);

        data_valid = 1'b1;
        matrix_sel = 1'b0;

        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                data_in = a_values[r][c];

                @(posedge clk);
                #1;

                check(busy == 1'b1,
                      "busy should be high during A loading");

            end
        end

        $display("PASS: loaded matrix A");

        // --------------------------------------------------------
        // LOAD MATRIX B
        //
        // matrix_sel changes only after the final A clock edge,
        // so the final A transfer is sampled with matrix_sel = 0.
        // --------------------------------------------------------
        @(negedge clk);

        matrix_sel = 1'b1;

        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                data_in = b_values[r][c];

                @(posedge clk);
                #1;

                check(busy == 1'b1,
                      "busy should be high during B loading");

            end
        end

        $display("PASS: loaded matrix B");

        // --------------------------------------------------------
        // Finish loading and enter READY
        // --------------------------------------------------------
        @(negedge clk);

        data_valid = 1'b0;
        matrix_sel = 1'b0;
        data_in    = '0;

        @(posedge clk);
        #1;

        check(busy == 1'b1,
              "busy should be high in READY");

        check(dut.u_controller.state == 3'd3,
              "controller should be in READY");

        $display("PASS: entered READY");

        // --------------------------------------------------------
        // START COMPUTATION
        //
        // start is asserted on negedge and sampled on posedge.
        // --------------------------------------------------------
        @(negedge clk);
        start = 1'b1;

        // During READY + start, acc_clear should be asserted.
        #1;

        check(dut.u_controller.state == 3'd3,
              "controller should still be in READY before start edge");

        check(dut.u_controller.acc_clear == 1'b1,
              "acc_clear should assert when start is accepted");

        @(posedge clk);
        #1;

        check(dut.u_controller.state == 3'd4,
              "controller should enter COMPUTE");

        check(dut.u_controller.k_count == 3'd0,
              "first compute cycle should use k=0");

        check(dut.u_controller.mac_enable == 1'b1,
              "mac_enable should assert during COMPUTE");

        start = 1'b0;

        $display("PASS: computation started");

        // --------------------------------------------------------
        // VERIFY 8 COMPUTE CYCLES
        //
        // k = 0,1,2,3,4,5,6,7
        // --------------------------------------------------------
        for (k = 0; k < 8; k = k + 1) begin

            // Signals are stable after the previous rising edge.
            #1;

            $display(
                "DEBUG: state=%0d k=%0d mac_enable=%0d done=%0d",
                dut.u_controller.state,
                dut.u_controller.k_count,
                dut.u_controller.mac_enable,
                done
            );

            check(dut.u_controller.state == 3'd4,
                  "controller should be in COMPUTE");

            check(dut.u_controller.k_count == 3'(k),
                  "k_count mismatch during COMPUTE");

            check(dut.u_controller.mac_enable == 1'b1,
                  "mac_enable should be high during COMPUTE");

            check(dut.u_controller.acc_clear == 1'b0,
                  "acc_clear should be low during COMPUTE");

            check(done == 1'b0,
                  "done should remain low before final MAC");

            @(posedge clk);
            #1;

        end

        // --------------------------------------------------------
        // FINAL MAC / DONE
        // --------------------------------------------------------
        check(dut.u_controller.state == 3'd5,
              "controller should enter OUTPUT after final MAC");

        check(done == 1'b1,
              "done should pulse after final MAC");

        check(dut.u_controller.mac_enable == 1'b0,
              "mac_enable should be low after final MAC");

        check(out_valid == 1'b0,
              "out_valid should remain low during done");

        $display("PASS: 8 compute cycles");
        $display("PASS: computation complete");

        // --------------------------------------------------------
        // MOVE TO FIRST OUTPUT
        // --------------------------------------------------------
        @(posedge clk);
        #1;

        check(done == 1'b0,
              "done should be a one-cycle pulse");

        check(out_valid == 1'b1,
              "out_valid should assert after done");

        check(dut.u_controller.out_count == 6'd0,
              "first output index should be 0");

        $display("PASS: output started");

        // --------------------------------------------------------
        // CHECK ALL 64 OUTPUTS
        //
        // Output order is row-major:
        //
        // 0  -> C[0][0]
        // 1  -> C[0][1]
        // ...
        // 7  -> C[0][7]
        // 8  -> C[1][0]
        // ...
        // 63 -> C[7][7]
        // --------------------------------------------------------
        for (idx = 0; idx < 64; idx = idx + 1) begin

            #1;

            check(out_valid == 1'b1,
                  "out_valid should remain high during output");

            check(dut.u_controller.out_count == 6'(idx),
                  "out_count mismatch during output");

            actual_value = int'($signed(data_out));
            expected_value = expected_flat[idx];

            if (actual_value != expected_value) begin

                $display(
                    "ERROR: output[%0d] actual=%0d expected=%0d",
                    idx,
                    actual_value,
                    expected_value
                );

                $fatal(1);
            end

            @(posedge clk);
            #1;

        end

        // --------------------------------------------------------
        // TRANSACTION COMPLETE
        // --------------------------------------------------------
        check(out_valid == 1'b0,
              "out_valid should be low after final output");

        check(busy == 1'b0,
              "busy should be low after transaction");

        check(done == 1'b0,
              "done should be low after transaction");

        $display("PASS: all 64 matrix results");

        // --------------------------------------------------------
        // Print software reference matrix
        // --------------------------------------------------------
        $display("");
        $display("Reference matrix C:");

        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin

            $write("  ");

            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                $write(
                    "%6d ",
                    expected_flat[r * MATRIX_SIZE + c]
                );
            end

            $display("");

        end

        $display("");
        $display("========================================");
        $display(" PASS: int8_matmul integration test");
        $display("========================================");
        $display("");

        $finish;

    end

endmodule
