`timescale 1ns/1ps

module tb_matmul_controller;

    // ------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------
    logic clk;
    logic rst_n;

    // ------------------------------------------------------------
    // DUT inputs
    // ------------------------------------------------------------
    logic       data_valid;
    logic       matrix_sel;
    logic       start;

    // ------------------------------------------------------------
    // DUT outputs
    // ------------------------------------------------------------
    logic       a_write_en;
    logic       b_write_en;
    logic [5:0] load_count;

    logic [2:0] k_count;
    logic       acc_clear;
    logic       mac_enable;

    logic [5:0] out_count;
    logic       out_valid;

    logic       busy;
    logic       done;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    matmul_controller dut (
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
    // Clock: 10 ns period
    // ------------------------------------------------------------
    always #5 clk <= ~clk;

    // ------------------------------------------------------------
    // Test helper
    // ------------------------------------------------------------
    task automatic check(
        input logic   condition,
        input string  message
    );
        begin
            if (!condition) begin
                $display("ERROR: %s", message);
                $fatal(1);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    integer i;

    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------
        clk        = 1'b0;
        rst_n      = 1'b0;

        data_valid = 1'b0;
        matrix_sel = 1'b0;
        start      = 1'b0;

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------
        repeat (2) @(posedge clk);

        #1;

        check(busy == 1'b0,
              "busy should be 0 after reset");

        check(done == 1'b0,
              "done should be 0 after reset");

        check(load_count == 6'd0,
              "load_count should be 0 after reset");

        check(k_count == 3'd0,
              "k_count should be 0 after reset");

        check(out_count == 6'd0,
              "out_count should be 0 after reset");

        check(a_write_en == 1'b0,
              "a_write_en should be 0 after reset");

        check(b_write_en == 1'b0,
              "b_write_en should be 0 after reset");

        check(acc_clear == 1'b0,
              "acc_clear should be 0 after reset");

        check(mac_enable == 1'b0,
              "mac_enable should be 0 after reset");

        check(out_valid == 1'b0,
              "out_valid should be 0 after reset");

        $display("PASS: reset");

        // --------------------------------------------------------
        // Release reset
        // --------------------------------------------------------
        rst_n = 1'b1;

        // --------------------------------------------------------
        // IDLE: no input
        // --------------------------------------------------------
        @(posedge clk);
        #1;

        check(busy == 1'b0,
              "busy should remain 0 while idle");

        check(load_count == 6'd0,
              "load_count should remain 0 while idle");

        check(a_write_en == 1'b0,
              "a_write_en should be 0 while idle");

        check(b_write_en == 1'b0,
              "b_write_en should be 0 while idle");

        $display("PASS: idle");

        // --------------------------------------------------------
        // Accept first A element
        // --------------------------------------------------------
        data_valid = 1'b1;
        matrix_sel = 1'b0;

        @(posedge clk);
        #1;

        check(busy == 1'b1,
              "busy should become 1 after starting A load");

        check(a_write_en == 1'b1,
              "a_write_en should pulse for first A element");

        check(b_write_en == 1'b0,
              "b_write_en should be low during A loading");

        check(load_count == 6'd1,
              "load_count should become 1 after first A element");

        $display("PASS: first A element");

        // --------------------------------------------------------
        // Stall test
        // data_valid = 0 must not advance the counter
        // --------------------------------------------------------
        data_valid = 1'b0;

        @(posedge clk);
        #1;

        check(load_count == 6'd1,
              "load_count should not advance during stall");

        check(a_write_en == 1'b0,
              "a_write_en should be low when data_valid is 0");

        check(b_write_en == 1'b0,
              "b_write_en should remain low during A stall");

        $display("PASS: A-load stall");

        // --------------------------------------------------------
        // Continue A loading
        // --------------------------------------------------------
        data_valid = 1'b1;

        for (i = 1; i < 64; i = i + 1) begin

            // During LOAD_A, A writes are enabled.
            #1;

            check(a_write_en == 1'b1,
                  "a_write_en should be high during A loading");

            check(b_write_en == 1'b0,
                  "b_write_en should be low during A loading");

            @(posedge clk);
            #1;

            if (i < 63) begin
                check(load_count == 6'(i + 1),
                      "A load counter increment mismatch");
            end
            else begin
                check(load_count == 6'd0,
                      "load_count should reset after final A element");
            end

        end

        $display("PASS: all 64 A elements accepted");

        // --------------------------------------------------------
        // B loading
        // --------------------------------------------------------
        matrix_sel = 1'b1;

        // First B element
        @(posedge clk);
        #1;

        check(b_write_en == 1'b1,
              "b_write_en should pulse for first B element");

        check(a_write_en == 1'b0,
              "a_write_en should be low during B loading");

        check(load_count == 6'd1,
              "load_count should become 1 after first B element");

        // Remaining B elements
        for (i = 1; i < 64; i = i + 1) begin

            #1;

            check(b_write_en == 1'b1,
                  "b_write_en should be high during B loading");

            check(a_write_en == 1'b0,
                  "a_write_en should be low during B loading");

            @(posedge clk);
            #1;

            if (i < 63) begin
                check(load_count == 6'(i + 1),
                      "B load counter increment mismatch");
            end
            else begin
                check(load_count == 6'd0,
                      "load_count should reset after final B element");
            end

        end

        $display("PASS: all 64 B elements accepted");

        // --------------------------------------------------------
        // Stop input
        // --------------------------------------------------------
        data_valid = 1'b0;
        matrix_sel = 1'b0;

        // --------------------------------------------------------
        // READY
        // --------------------------------------------------------
        @(posedge clk);
        #1;

        check(busy == 1'b1,
              "busy should remain high in READY");

        check(k_count == 3'd0,
              "k_count should be 0 before compute");

        check(a_write_en == 1'b0,
              "a_write_en should be low in READY");

        check(b_write_en == 1'b0,
              "b_write_en should be low in READY");

        check(mac_enable == 1'b0,
              "mac_enable should be low in READY");

        $display("PASS: ready state");

        // --------------------------------------------------------
        // Start computation
        // --------------------------------------------------------
        start = 1'b1;

        // In READY, start causes acc_clear to assert.
        #1;

        check(acc_clear == 1'b1,
              "acc_clear should be high when start is accepted");

        check(mac_enable == 1'b0,
              "mac_enable should still be low during acc_clear");

        @(posedge clk);
        #1;

        check(k_count == 3'd0,
              "k_count should start at 0");

        start = 1'b0;

        $display("PASS: start accepted");

        // --------------------------------------------------------
        // Verify 8 MAC cycles
        // --------------------------------------------------------
        for (i = 0; i < 8; i = i + 1) begin

            #1;

            check(mac_enable == 1'b1,
                  "mac_enable should be high during COMPUTE");

            check(k_count == 3'(i),
                  "k_count mismatch during COMPUTE");

            check(acc_clear == 1'b0,
                  "acc_clear should be low during COMPUTE");

            @(posedge clk);
            #1;

        end

        check(done == 1'b1,
              "done should pulse after final MAC");

        check(mac_enable == 1'b0,
              "mac_enable should be low after final MAC");

        $display("PASS: 8 compute cycles");

        // --------------------------------------------------------
        // Done cycle
        // --------------------------------------------------------
        check(out_valid == 1'b0,
              "out_valid should be low during done cycle");

        check(done == 1'b1,
              "done should remain high for one cycle");

        @(posedge clk);
        #1;

        check(done == 1'b0,
              "done should return low after one cycle");

        check(out_valid == 1'b1,
              "out_valid should assert after done");

        check(out_count == 6'd0,
              "first output count should be 0");

        $display("PASS: done pulse and output start");

        // --------------------------------------------------------
        // Verify all 64 output positions
        // --------------------------------------------------------
        for (i = 0; i < 64; i = i + 1) begin

            check(out_valid == 1'b1,
                  "out_valid should remain high during output");

            check(out_count == 6'(i),
                  "out_count mismatch during output");

            @(posedge clk);
            #1;

        end

        check(out_valid == 1'b0,
              "out_valid should deassert after final output");

        check(busy == 1'b0,
              "busy should return low after output");

        check(out_count == 6'd0,
              "out_count should return to 0 after output");

        $display("PASS: all 64 output positions");

        // --------------------------------------------------------
        // Final result
        // --------------------------------------------------------
        $display("");
        $display("========================================");
        $display(" PASS: matmul_controller testbench");
        $display("========================================");
        $display("");

        $finish;
    end

endmodule
