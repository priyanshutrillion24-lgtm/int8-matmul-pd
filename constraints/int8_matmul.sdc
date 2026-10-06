# ============================================================
# INT8 Matrix-Multiply Accelerator
# Baseline Timing Constraints
# ============================================================

# ------------------------------------------------------------
# 1. Primary clock
#
# Target frequency = 200 MHz
# Period            = 5.0 ns
# ------------------------------------------------------------
create_clock \
    -name clk \
    -period 5.0 \
    [get_ports clk]

# ------------------------------------------------------------
# 2. Clock uncertainty
#
# These values reserve margin for clock variation/jitter.
# They are project assumptions for the baseline flow.
# ------------------------------------------------------------
set_clock_uncertainty \
    -setup 0.10 \
    [get_clocks clk]

set_clock_uncertainty \
    -hold 0.05 \
    [get_clocks clk]

# ------------------------------------------------------------
# 3. Input timing
#
# External logic is assumed to require:
#   max = 1.0 ns before the active clock edge
#   min = 0.2 ns before the active clock edge
#
# Clock itself is excluded because it is constrained above.
# ------------------------------------------------------------
set_input_delay \
    -clock [get_clocks clk] \
    -max 1.0 \
    [get_ports {rst_n data_valid matrix_sel start data_in[*]}]

set_input_delay \
    -clock [get_clocks clk] \
    -min 0.2 \
    [get_ports {rst_n data_valid matrix_sel start data_in[*]}]

# ------------------------------------------------------------
# 4. Output timing
#
# External logic is assumed to consume the output within:
#   max = 1.0 ns after the active clock edge
#   min = 0.2 ns after the active clock edge
# ------------------------------------------------------------
set_output_delay \
    -clock [get_clocks clk] \
    -max 1.0 \
    [get_ports {busy done out_valid data_out[*]}]

set_output_delay \
    -clock [get_clocks clk] \
    -min 0.2 \
    [get_ports {busy done out_valid data_out[*]}]

# ------------------------------------------------------------
# 5. Basic design-rule constraints
# ------------------------------------------------------------

# Maximum allowed transition.
set_max_transition 0.50 [all_inputs]

# Maximum fanout assumption for input-driven logic.
set_max_fanout 16 [all_inputs]
