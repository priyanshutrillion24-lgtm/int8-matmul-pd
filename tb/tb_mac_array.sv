`timescale 1ns/1ps

module tb_mac_array;

    localparam int MATRIX_SIZE = 8;
    localparam int DATA_WIDTH  = 8;
    localparam int ACC_WIDTH   = 18;

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------

    logic clk = 1'b0;

    // 10 ns clock period
    always #5 clk <= ~clk;


    // ----------------------------------------------------------------
    // DUT inputs
    // ----------------------------------------------------------------

    logic signed [DATA_WIDTH-1:0]
        a_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    logic signed [DATA_WIDTH-1:0]
        b_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    logic [2:0] k_count;

    logic acc_clear;
    logic mac_enable;


    // ----------------------------------------------------------------
    // DUT outputs
    // ----------------------------------------------------------------

    logic signed [ACC_WIDTH-1:0]
        acc_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];


    // ----------------------------------------------------------------
    // Reference model
    //
    // Use 32-bit signed values for the reference calculation so that
    // the testbench itself does not accidentally overflow during
    // multiplication.
    // ----------------------------------------------------------------

    logic signed [31:0]
        expected_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];


    // ----------------------------------------------------------------
    // Test variables
    // ----------------------------------------------------------------

    int r;
    int c;
    int k;

    integer signed actual_value;


    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------

    mac_array #(
        .MATRIX_SIZE(MATRIX_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) dut (
        .clk        (clk),
        .a_matrix   (a_matrix),
        .b_matrix   (b_matrix),
        .k_count    (k_count),
        .acc_clear  (acc_clear),
        .mac_enable (mac_enable),
        .acc_matrix (acc_matrix)
    );


    // ----------------------------------------------------------------
    // Waveform dump
    // ----------------------------------------------------------------

    initial begin
        $dumpfile("mac_array.fst");
        $dumpvars(0, tb_mac_array);
    end


    // ----------------------------------------------------------------
    // Task: execute exactly one MAC cycle
    //
    // k_value selects the reduction dimension:
    //
    //   k=0 -> A[:,0] × B[0,:]
    //   k=1 -> A[:,1] × B[1,:]
    //   ...
    //   k=7 -> A[:,7] × B[7,:]
    // ----------------------------------------------------------------

    task automatic run_mac(input logic [2:0] k_value);
        begin
            k_count    = k_value;
            mac_enable = 1'b1;

            // MAC result is captured at the rising edge.
            @(posedge clk);
            #1;

            // Disable MAC for the next cycle.
            mac_enable = 1'b0;
        end
    endtask


    // ----------------------------------------------------------------
    // Task: check all 64 accumulators
    // ----------------------------------------------------------------

task automatic check_array(input int iteration);
    begin

        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                actual_value = int'($signed(acc_matrix[r][c]));

                if (actual_value != expected_matrix[r][c]) begin

                    $display("ERROR: k=%0d C[%0d][%0d] actual=%0d expected=%0d",
                             iteration,
                             r,
                             c,
                             actual_value,
                             expected_matrix[r][c]);

                    $fatal(1);
                end

            end
        end

        $display("PASS: all 64 accumulators correct after k=%0d",
                 iteration);

    end
endtask    
                


    // ----------------------------------------------------------------
    // Main test
    // ----------------------------------------------------------------

    initial begin

        // ------------------------------------------------------------
        // Initialize control signals
        // ------------------------------------------------------------

        k_count    = 3'd0;
        acc_clear  = 1'b1;
        mac_enable = 1'b0;


        // ------------------------------------------------------------
        // Initialize A and B matrices
        //
        // A[r][c] = r - c
        //
        // B[r][c] = r + c - 3
        //
        // Both expressions are explicitly sized to signed INT8.
        // ------------------------------------------------------------

        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                a_matrix[r][c] = $signed(8'(r - c));
                b_matrix[r][c] = $signed(8'(r + c - 3));

            end
        end


        // ------------------------------------------------------------
        // Initialize reference matrix
        // ------------------------------------------------------------

        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                expected_matrix[r][c] = 32'sd0;

            end
        end


        // ------------------------------------------------------------
        // Clear all 64 accumulators
        // ------------------------------------------------------------

        @(posedge clk);
        #1;

        acc_clear = 1'b0;


        // ------------------------------------------------------------
        // Perform the 8 MAC iterations
        // ------------------------------------------------------------

        for (k = 0; k < MATRIX_SIZE; k = k + 1) begin

            // --------------------------------------------------------
            // Update software reference for this k
            //
            // Explicitly convert each INT8 operand to signed 32-bit
            // before multiplication.
            // --------------------------------------------------------

            for (r = 0; r < MATRIX_SIZE; r = r + 1) begin
                for (c = 0; c < MATRIX_SIZE; c = c + 1) begin

                    expected_matrix[r][c] =
                        expected_matrix[r][c]
                        +
                        (
                            int'($signed(a_matrix[r][k]))
                            *
                            int'($signed(b_matrix[k][c]))
                        );

                end
            end


            // --------------------------------------------------------
            // Execute hardware MAC for this k
            // --------------------------------------------------------

            run_mac(k[2:0]);


            // --------------------------------------------------------
            // Check all 64 PEs after this MAC cycle
            // --------------------------------------------------------

            check_array(k);

        end


        // ------------------------------------------------------------
        // Print final matrix
        // ------------------------------------------------------------

        $display("");
        $display("========================================");
        $display("Final C matrix:");
        $display("========================================");

        for (r = 0; r < MATRIX_SIZE; r = r + 1) begin

            $write("[ ");

            for (c = 0; c < MATRIX_SIZE; c = c + 1) begin
                $write("%0d ", expected_matrix[r][c]);
            end

            $write("]\n");

        end


        // ------------------------------------------------------------
        // Final PASS
        // ------------------------------------------------------------

        $display("");
        $display("========================================");
        $display("PASS: mac_array 64-PE verification");
        $display("All 8 MAC iterations passed.");
        $display("All 64 PE accumulators passed.");
        $display("========================================");

        $finish;

    end

endmodule
