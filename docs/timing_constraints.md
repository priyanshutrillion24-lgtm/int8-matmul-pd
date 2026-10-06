# Timing Constraint Notes

## Timing Target

The accelerator has a baseline target of:

- Clock period: 5.0 ns
- Frequency: 200 MHz

The 5.0 ns value is a design requirement, not a measured timing result.

## Clock

The primary clock is `clk`.

The constraint:

    create_clock -period 5.0

defines the primary synchronous timing reference.

## Clock Uncertainty

Baseline assumptions:

- Setup uncertainty: 0.10 ns
- Hold uncertainty: 0.05 ns

These values reserve margin for clock variation and are project assumptions
for the initial timing model.

## Input Delays

The following inputs are externally timed:

- `rst_n`
- `data_valid`
- `matrix_sel`
- `start`
- `data_in[7:0]`

Baseline assumptions:

- Maximum input delay: 1.0 ns
- Minimum input delay: 0.2 ns

These represent timing behavior of logic outside the accelerator.

## Output Delays

The following outputs are externally timed:

- `busy`
- `done`
- `out_valid`
- `data_out[17:0]`

Baseline assumptions:

- Maximum output delay: 1.0 ns
- Minimum output delay: 0.2 ns

These represent timing requirements of logic consuming the accelerator outputs.

## Design-Rule Constraints

Baseline assumptions:

- Maximum transition: 0.50 ns
- Maximum fanout: 16

These constraints help limit poor electrical conditions that can increase
delay or create difficult implementation conditions.

## Important Interpretation

The SDC describes the timing environment expected by the design.

The SDC does not prove that the RTL meets 200 MHz.

Actual timing quality will be established later using synthesis and static
timing analysis, including WNS and TNS measurements.

## Day 6 Baseline

Constraint file:

    constraints/int8_matmul.sdc
