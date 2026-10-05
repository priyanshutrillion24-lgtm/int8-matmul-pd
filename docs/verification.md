# Functional Verification

## 1. Verification Objective

The purpose of Day 5 verification is to establish functional confidence in the
8x8 signed INT8 matrix-multiply accelerator before beginning timing constraints
and synthesis work.

The verification environment uses a self-checking SystemVerilog testbench with
an independent software reference calculation.

For every test:

1. Matrix A is loaded.
2. Matrix B is loaded.
3. Computation is started.
4. The controller performs the 8 MAC steps for k = 0...7.
5. The 64 results are serialized in row-major order.
6. Every DUT result is compared against the independently calculated reference.

## 2. Testbench

Primary testbench:

    tb/tb_int8_matmul.sv

The testbench checks:

- reset behavior
- A/B matrix loading
- start/computation sequencing
- computation completion
- output-valid behavior
- output counter sequencing
- all 64 output values

A timeout is used while waiting for `done` so that a control-path failure
does not result in an indefinitely hanging simulation.

## 3. Directed Tests

Eight directed test cases were executed:

| Test | Description |
|---|---|
| 1 | All-zero matrices |
| 2 | All +1 matrices |
| 3 | Positive × positive |
| 4 | Negative × positive |
| 5 | Positive × negative |
| 6 | Negative × negative |
| 7 | INT8 boundary values: -128 and +127 |
| 8 | Structured mixed-sign matrices |

Result:

**8 / 8 directed tests passed.**

## 4. Randomized Tests

Twenty reproducible random matrix pairs were tested.

Random inputs cover the complete signed INT8 range:

    -128 ... +127

Random seed:

    0x5A172026

Result:

**20 / 20 random tests passed.**

## 5. Overall Result

Total tests:

    28

Total matrix-result comparisons:

    28 × 64 = 1792

Result:

**28 / 28 tests passed.**

The simulation completed without assertion failures or output mismatches.

## 6. Waveform Evidence

Waveform database:

    int8_matmul_day5.fst

Portfolio screenshot:

    images/day5_functional_verification_waveform.png

The waveform demonstrates the control sequence:

    LOAD_A
       ->
    LOAD_B
       ->
    READY
       ->
    COMPUTE
       ->
    DONE
       ->
    OUTPUT

During COMPUTE, `k_count` progresses through the eight MAC iterations.
During OUTPUT, `out_count` serializes the 64 matrix results.

## 7. Functional Verification Limitations

The current verification provides strong functional coverage of signed
matrix multiplication and normal transaction sequencing, but it does not
exhaustively prove every possible protocol misuse.

The current suite does not comprehensively test:

- reset asserted in the middle of a transaction
- all possible invalid `matrix_sel` / `data_valid` combinations
- arbitrary interruptions and stalls at every possible loading position
- formal properties or exhaustive state-space verification
- gate-level or post-synthesis behavior

These are verification limitations, not observed functional failures.

## 8. Reproduction

Run the lint check:

    verilator --lint-only --timing -Wall \
        --top-module tb_int8_matmul \
        rtl/mac_pe.sv \
        rtl/mac_array.sv \
        rtl/matmul_controller.sv \
        rtl/int8_matmul.sv \
        tb/tb_int8_matmul.sv

Build the simulation:

    verilator --binary --timing --trace-fst \
        --top-module tb_int8_matmul \
        rtl/mac_pe.sv \
        rtl/mac_array.sv \
        rtl/matmul_controller.sv \
        rtl/int8_matmul.sv \
        tb/tb_int8_matmul.sv

Run:

    ./obj_dir/Vtb_int8_matmul

## 9. Day 5 Conclusion

The RTL accelerator passes the directed and randomized functional
verification suite.

The design is ready to move from functional RTL verification into the
timing-constraint and synthesis phase.
