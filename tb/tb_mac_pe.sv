`timescale 1ns/1ps

module tb_mac_pe;

    logic clk = 1'b0;
    logic signed [7:0]  a_in;
    logic signed [7:0]  b_in;
    logic               acc_clear;
    logic               mac_enable;
    logic signed [17:0] acc_out;

    mac_pe dut (
        .clk        (clk),
        .a_in       (a_in),
        .b_in       (b_in),
        .acc_clear  (acc_clear),
        .mac_enable (mac_enable),
        .acc_out    (acc_out)
    );

    // 10 ns clock period
    always #5 clk <= ~clk;

    // Waveform dump
    initial begin
        $dumpfile("mac_pe.fst");
        $dumpvars(0, tb_mac_pe);
    end

    task automatic step(input logic signed [7:0] a,
    input logic signed [7:0] b);
        begin
            a_in       = a;
            b_in       = b;
            mac_enable = 1'b1;

            @(posedge clk);
            #1;

            $display(
                "t=%0t a=%0d b=%0d product=%0d acc=%0d",
                $time, a, b, dut.product, acc_out
            );
        end
    endtask

    initial begin
        a_in       = '0;
        b_in       = '0;
        acc_clear  = 1'b1;
        mac_enable = 1'b0;

        // Clear accumulator.
        @(posedge clk);
        #1;
        acc_clear = 1'b0;
        // Check signed MAC:
        //
        // 2*3 + (-4)*5 + (-128)*127
        // = 6 - 20 - 16256
        // = -16270

        step(2, 3);
        step(-4, 5);
        step(-128, 127);

        if (acc_out !== -18'sd16270) begin
            $fatal(
                1,
                "Unexpected accumulator result: %0d (expected -16270)",
                acc_out
            );
        end

        $display("PASS: mac_pe signed MAC test");

        $finish;
    end

endmodule
