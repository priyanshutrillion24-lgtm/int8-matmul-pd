`timescale 1ns/1ps

module tb_int8_matmul;

    localparam int MATRIX_SIZE = 8;
    localparam int DATA_WIDTH  = 8;
    localparam int ACC_WIDTH   = 18;

    localparam int NUM_RANDOM_TESTS = 20;

    // Fixed seed for reproducibility.
    localparam int unsigned RANDOM_SEED_INIT = 32'h5A17_2026;

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
    logic signed [ACC_WIDTH-1:0]  data_out;
    logic                         out_valid;

    // ------------------------------------------------------------
    // Test matrices
    // ------------------------------------------------------------
    logic signed [7:0] a_values [0:7][0:7];
    logic signed [7:0] b_values [0:7][0:7];

    // ------------------------------------------------------------
    // Software reference
    // ------------------------------------------------------------
    integer expected_flat [0:63];

    // ------------------------------------------------------------
    // Loop / calculation variables
    // ------------------------------------------------------------
    integer r;
    integer c;
    integer k;
    integer idx;
    integer cycle;

    integer expected_value;
    integer actual_value;

    integer random_test_num;

    integer signed random_value_a;
    integer signed random_value_b;

    // Fixed reproducible random seed.
    integer unsigned random_seed;

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
    // Clock: 10 ns period
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
    // Calculate independent software reference
    //
    // C[r][c] = sum(A[r][k] * B[k][c])
    // ------------------------------------------------------------
    task automatic calculate_reference;
        begin
            for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
                for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                    expected_value = 0;

                    for (k = 0; k < MATRIX_SIZE; k = k + 1) begin
                        expected_value =
                            expected_value
                            + $signed(a_values[r][k])
                            * $signed(b_values[k][c]);
                    end

                    expected_flat[r * MATRIX_SIZE + c]
                        = expected_value;
                end
            end
        end
    endtask

    // ------------------------------------------------------------
    // Reset DUT
    // ------------------------------------------------------------
    task automatic reset_dut;
        begin
            @(negedge clk);

            rst_n      = 1'b0;
            data_valid = 1'b0;
            matrix_sel = 1'b0;
            start      = 1'b0;
            data_in    = '0;

            repeat (2) @(posedge clk);

            #1;

            check(busy == 1'b0,
                  "busy should be 0 after reset");

            check(done == 1'b0,
                  "done should be 0 after reset");

            check(out_valid == 1'b0,
                  "out_valid should be 0 after reset");

            @(negedge clk);

            rst_n = 1'b1;
        end
    endtask

    // ------------------------------------------------------------
    // Load matrix A
    // ------------------------------------------------------------
    task automatic load_matrix_a;
        begin
            @(negedge clk);

            data_valid = 1'b1;
            matrix_sel = 1'b0;

            for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
                for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                    data_in = a_values[r][c];

                    @(posedge clk);
                    #1;

                    check(busy == 1'b1,
                          "busy should be high while loading A");
                end
            end

            $display("PASS: loaded matrix A");
        end
    endtask

    // ------------------------------------------------------------
    // Load matrix B
    // ------------------------------------------------------------
    task automatic load_matrix_b;
        begin
            @(negedge clk);

            matrix_sel = 1'b1;

            for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
                for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                    data_in = b_values[r][c];

                    @(posedge clk);
                    #1;

                    check(busy == 1'b1,
                          "busy should be high while loading B");
                end
            end

            $display("PASS: loaded matrix B");
        end
    endtask

    // ------------------------------------------------------------
    // Start computation
    // ------------------------------------------------------------
    task automatic start_compute;
        begin
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

            @(negedge clk);

            start = 1'b1;

            @(posedge clk);
            #1;

            check(busy == 1'b1,
                  "busy should remain high after start");

            check(dut.u_controller.state == 3'd4,
                  "controller should enter COMPUTE");

            check(dut.u_controller.k_count == 3'd0,
                  "compute should begin with k=0");

            start = 1'b0;

            $display("PASS: computation started");
        end
    endtask

    // ------------------------------------------------------------
    // Wait for done with timeout
    // ------------------------------------------------------------
    task automatic wait_for_done;
        bit saw_done;

        begin
            saw_done = 1'b0;

            for (cycle = 0; cycle < 20; cycle = cycle + 1) begin

                @(posedge clk);
                #1;

                if (done) begin
                    saw_done = 1'b1;
                    break;
                end
            end

            check(saw_done,
                  "timed out waiting for done");

            check(out_valid == 1'b0,
                  "out_valid should be low during done");

            $display("PASS: computation complete");
        end
    endtask

    // ------------------------------------------------------------
    // Check all 64 outputs
    // ------------------------------------------------------------
    task automatic check_outputs;
        begin
            // Move from done cycle to first output cycle.
            @(posedge clk);
            #1;

            check(done == 1'b0,
                  "done should return low");

            check(out_valid == 1'b1,
                  "out_valid should assert after done");

            check(dut.u_controller.out_count == 6'd0,
                  "first output count should be 0");

            for (idx = 0; idx < 64; idx = idx + 1) begin

                check(out_valid == 1'b1,
                      "out_valid should remain high");

                check(
                    dut.u_controller.out_count == 6'(idx),
                    "output counter mismatch"
                );

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

            check(out_valid == 1'b0,
                  "out_valid should be low after final output");

            check(busy == 1'b0,
                  "busy should be low after final output");

            $display("PASS: all 64 outputs");
        end
    endtask

    // ------------------------------------------------------------
    // Run one complete matrix test
    // ------------------------------------------------------------
    task automatic run_matrix_test(
        input string test_name
    );
        begin
            $display("");
            $display("========================================");
            $display("TEST: %s", test_name);
            $display("========================================");

            calculate_reference;
            reset_dut;
            load_matrix_a;
            load_matrix_b;
            start_compute;
            wait_for_done;
            check_outputs;

            $display("PASS: %s", test_name);
        end
    endtask

    // ------------------------------------------------------------
    // Generate one random matrix pair
    //
    // Random values cover the complete signed INT8 range:
    //     -128 ... +127
    //
    // $urandom(seed) updates seed, so the entire sequence is
    // reproducible from RANDOM_SEED_INIT.
    // ------------------------------------------------------------
    task automatic generate_random_matrices;
        begin

            for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
                for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                    // Generate unsigned 8-bit quantity 0...255.
                    random_value_a =
                        $urandom(random_seed) & 32'h0000_00FF;

                    random_value_b =
                        $urandom(random_seed) & 32'h0000_00FF;

                    // Shift into signed INT8 range:
                    // 0...255 -> -128...127
                    random_value_a = random_value_a - 128;
                    random_value_b = random_value_b - 128;

                    a_values[r][c] = 8'(random_value_a);
                    b_values[r][c] = 8'(random_value_b);

                end
            end
        end
    endtask

    // ------------------------------------------------------------
    // Print random test matrices
    // Useful if a random test ever fails.
    // ------------------------------------------------------------
    task automatic print_test_matrices;
        begin

            $display("");
            $display("Matrix A:");

            for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
                $write("  ");

                for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                    $write("%5d ", a_values[r][c]);
                end

                $display("");
            end

            $display("");
            $display("Matrix B:");

            for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
                $write("  ");

                for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                    $write("%5d ", b_values[r][c]);
                end

                $display("");
            end
        end
    endtask

    // ------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------
    initial begin

        clk        = 1'b0;
        rst_n      = 1'b0;

        data_in    = '0;
        data_valid = 1'b0;
        matrix_sel = 1'b0;
        start      = 1'b0;

        // Initialize reproducible random sequence.
        random_seed = RANDOM_SEED_INIT;

        $display("");
        $display("========================================");
        $display(" DAY-5 FUNCTIONAL VERIFICATION");
        $display(" Random seed = 0x%08h", random_seed);
        $display("========================================");

        // --------------------------------------------------------
        // Waveform
        // --------------------------------------------------------
        $dumpfile("int8_matmul_day5.fst");
        $dumpvars(0, tb_int8_matmul);

        // ========================================================
        // DIRECTED TEST 1: All zeros
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = 8'sd0;
                b_values[r][c] = 8'sd0;
            end
        end

        run_matrix_test("all zeros");

        // ========================================================
        // DIRECTED TEST 2: All +1
        //
        // Expected result: every C element = 8
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = 8'sd1;
                b_values[r][c] = 8'sd1;
            end
        end

        run_matrix_test("all +1");

        // ========================================================
        // DIRECTED TEST 3: Positive × positive
        //
        // 3 × 2 × 8 = 48
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = 8'sd3;
                b_values[r][c] = 8'sd2;
            end
        end

        run_matrix_test("positive x positive");

        // ========================================================
        // DIRECTED TEST 4: Negative × positive
        //
        // (-3) × 2 × 8 = -48
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = -8'sd3;
                b_values[r][c] = 8'sd2;
            end
        end

        run_matrix_test("negative x positive");

        // ========================================================
        // DIRECTED TEST 5: Positive × negative
        //
        // 3 × (-2) × 8 = -48
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = 8'sd3;
                b_values[r][c] = -8'sd2;
            end
        end

        run_matrix_test("positive x negative");

        // ========================================================
        // DIRECTED TEST 6: Negative × negative
        //
        // (-3) × (-2) × 8 = 48
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = -8'sd3;
                b_values[r][c] = -8'sd2;
            end
        end

        run_matrix_test("negative x negative");

        // ========================================================
        // DIRECTED TEST 7: INT8 boundary values
        //
        // -128 × 127 × 8 = -130048
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = 8'sh80;   // -128
                b_values[r][c] = 8'sd127;  // +127
            end
        end

        run_matrix_test("INT8 boundary values");

        // ========================================================
        // DIRECTED TEST 8: Structured mixed-sign matrices
        // ========================================================
        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                a_values[r][c] = 8'(r - c);
                b_values[r][c] = 8'(r + c - 3);
            end
        end

        run_matrix_test("structured mixed-sign");

        // ========================================================
        // RANDOM TESTS
        // ========================================================
        $display("");
        $display("========================================");
        $display(" STARTING %0d RANDOM TESTS", NUM_RANDOM_TESTS);
        $display("========================================");

        for (
            random_test_num = 1;
            random_test_num <= NUM_RANDOM_TESTS;
            random_test_num = random_test_num + 1
        ) begin

            generate_random_matrices;

            $display("");
            $display(
                "RANDOM TEST %02d / %02d",
                random_test_num,
                NUM_RANDOM_TESTS
            );

            /*
             * In the event of a failure, uncomment this line
             * to print the matrices that caused the failure:
             *
             * print_test_matrices;
             */

            run_matrix_test(
                $sformatf(
                    "random %02d",
                    random_test_num
                )
            );

        end

        // --------------------------------------------------------
        // Final result
        // --------------------------------------------------------
        $display("");
        $display("========================================");
        $display(" ALL DAY-5 TESTS PASSED");
        $display("========================================");
        $display(" Directed tests : 8");
        $display(" Random tests   : %0d", NUM_RANDOM_TESTS);
        $display(" Total tests    : %0d", 8 + NUM_RANDOM_TESTS);
        $display(" Random seed    : 0x%08h", RANDOM_SEED_INIT);
        $display("========================================");
        $display("");

        $finish;
    end

endmodule
