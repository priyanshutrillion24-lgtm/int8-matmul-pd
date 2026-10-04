`timescale 1ns/1ps

module matmul_controller (
    input  logic       clk,
    input  logic       rst_n,

    // External control / input handshake
    input  logic       data_valid,
    input  logic       matrix_sel,   // 0 = A, 1 = B
    input  logic       start,

    // Matrix loading controls
    output logic       a_write_en,
    output logic       b_write_en,
    output logic [5:0] load_count,

    // Compute controls
    output logic [2:0] k_count,
    output logic       acc_clear,
    output logic       mac_enable,

    // Output controls
    output logic [5:0] out_count,
    output logic       out_valid,

    // Status
    output logic       busy,
    output logic       done
);

    // ------------------------------------------------------------
    // State definition
    // ------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE,
        LOAD_A,
        LOAD_B,
        READY,
        COMPUTE,
        OUTPUT
    } state_t;

    state_t state;
    state_t next_state;

    // ------------------------------------------------------------
    // Next-state logic
    // ------------------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)

            IDLE: begin
                // First accepted input must be an A element.
                if (data_valid && !matrix_sel) begin
                    next_state = LOAD_A;
                end
            end

            LOAD_A: begin
                // Accept A elements until A[7][7].
                if (data_valid && !matrix_sel &&
                    (load_count == 6'd63)) begin
                    next_state = LOAD_B;
                end
            end

            LOAD_B: begin
                // Accept B elements until B[7][7].
                if (data_valid && matrix_sel &&
                    (load_count == 6'd63)) begin
                    next_state = READY;
                end
            end

            READY: begin
                // Wait for the computation request.
                if (start) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                // k = 0 through 7
                if (k_count == 3'd7) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                // Hold one cycle after done, then serialize 64 values.
                if (!done && (out_count == 6'd63)) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    // ------------------------------------------------------------
    // State, counters, and done register
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state      <= IDLE;

            load_count <= 6'd0;
            k_count    <= 3'd0;
            out_count  <= 6'd0;

            done       <= 1'b0;
        end
        else begin
            state <= next_state;

            // done is a one-cycle pulse
            done <= 1'b0;

            case (state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------
                IDLE: begin
                    if (data_valid && !matrix_sel) begin
                        // First A element is written at A[0][0].
                        // The next accepted element uses index 1.
                        load_count <= 6'd1;
                    end
                end

                // ------------------------------------------------
                // LOAD_A
                // ------------------------------------------------
                LOAD_A: begin
                    if (data_valid && !matrix_sel) begin
                        if (load_count == 6'd63) begin
                            // Final A element was accepted.
                            // Reset index for B loading.
                            load_count <= 6'd0;
                        end
                        else begin
                            load_count <= load_count + 6'd1;
                        end
                    end
                end

                // ------------------------------------------------
                // LOAD_B
                // ------------------------------------------------
                LOAD_B: begin
                    if (data_valid && matrix_sel) begin
                        if (load_count == 6'd63) begin
                            // Final B element was accepted.
                            load_count <= 6'd0;
                        end
                        else begin
                            load_count <= load_count + 6'd1;
                        end
                    end
                end

                // ------------------------------------------------
                // READY
                // ------------------------------------------------
                READY: begin
                    if (start) begin
                        // COMPUTE begins with k = 0.
                        k_count <= 3'd0;
                    end
                end

                // ------------------------------------------------
                // COMPUTE
                // ------------------------------------------------
                COMPUTE: begin
                    if (k_count == 3'd7) begin
                        // Final MAC cycle has completed.
                        k_count   <= 3'd0;
                        out_count <= 6'd0;
                        done      <= 1'b1;
                    end
                    else begin
                        k_count <= k_count + 3'd1;
                    end
                end

                // ------------------------------------------------
                // OUTPUT
                // ------------------------------------------------
                OUTPUT: begin
                    // The first OUTPUT cycle is reserved for the
                    // one-cycle done pulse.
                    if (done) begin
                        out_count <= 6'd0;
                    end
                    else if (out_count == 6'd63) begin
                        // Last output has been presented.
                        out_count <= 6'd0;
                    end
                    else begin
                        out_count <= out_count + 6'd1;
                    end
                end

                default: begin
                    state      <= IDLE;
                    load_count <= 6'd0;
                    k_count    <= 3'd0;
                    out_count  <= 6'd0;
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // Control-output decode
    // ------------------------------------------------------------
    always_comb begin
        // Defaults
        a_write_en = 1'b0;
        b_write_en = 1'b0;

        acc_clear  = 1'b0;
        mac_enable = 1'b0;

        out_valid  = 1'b0;

        busy       = 1'b0;

        // Busy during every non-IDLE state.
        if (state != IDLE) begin
            busy = 1'b1;
        end

        // --------------------------------------------
        // Matrix loading
        // --------------------------------------------
        if ((state == IDLE || state == LOAD_A) &&
            data_valid && !matrix_sel) begin
            a_write_en = 1'b1;
        end

        if ((state == LOAD_B) &&
            data_valid && matrix_sel) begin
            b_write_en = 1'b1;
        end

        // --------------------------------------------
        // Accumulator clear
        // --------------------------------------------
        // Pulses once when start is accepted in READY.
        if ((state == READY) && start) begin
            acc_clear = 1'b1;
        end

        // --------------------------------------------
        // MAC enable
        // --------------------------------------------
        if (state == COMPUTE) begin
            mac_enable = 1'b1;
        end

        // --------------------------------------------
        // Output valid
        // --------------------------------------------
        // OUTPUT begins after the one-cycle done pulse.
        if ((state == OUTPUT) && !done) begin
            out_valid = 1'b1;
        end
    end

endmodule
