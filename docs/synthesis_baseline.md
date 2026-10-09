# Day 7 — SKY130HD Synthesis Baseline

## Objective

Synthesize the INT8 matrix-multiplication accelerator and record
technology-mapped cell statistics using the SKY130HD standard-cell library.

## Design configuration

- Top module: `int8_matmul`
- Datapath: 8x8 signed INT8 matrix multiplication
- Clock target: 5.0 ns (200 MHz)
- Synthesis tool: Yosys 0.52
- Standard-cell library: SKY130HD
- Library corner: `tt_025C_1v80`
- Liberty file: `sky130_fd_sc_hd__tt_025C_1v80.lib`

## Synthesis results

| Metric | Result |
|---|---:|
| Cells before technology mapping | 44,411 |
| Cells after technology mapping | 34,701 |
| Liberty-reported cell area | 285,696.5056 |
| Sequential cell area | 54,191.9744 |
| Sequential area as percentage of total | 18.97% |
| Undriven-wire messages | 0 |

The reported area is calculated from the standard-cell library's area
attributes. It is not the final placed or routed design area.

## Flow summary

1. Read the SystemVerilog RTL.
2. Check the design hierarchy.
3. Synthesize and flatten the design without initial ABC mapping.
4. Map sequential cells with `dfflibmap`.
5. Map combinational logic with ABC.
6. Report mapped cell statistics using the SKY130HD Liberty file.
7. Export the mapped Verilog netlist and JSON netlist.

## Warnings and observations

- Yosys reports that `acc_matrix` is replaced with a list of registers.
  This is expected when lowering the RTL register array.
- ABC reports detection of multi-output library cells, including a full-adder
  example. Do not assume those multi-output cells were used by the mapper.
- ABC also reports that its mapping network is combinational.
- No `has no driver` messages were found.
- No `$scopeinfo` cells were found in the exported Verilog netlist.

## Generated artifacts

- Synthesis script: `flow/synth_sky130hd.sh`
- Synthesis log: `reports/synthesis/day7_sky130hd_yosys.log`
- Mapped Verilog: `results/netlist/int8_matmul_sky130hd.v`
- JSON netlist: `results/netlist/int8_matmul_sky130hd.json`

## Reproduce the run

From the repository root:

```bash
./flow/synth_sky130hd.sh
```

## Limitations

This is a synthesis baseline only. The reported area is not post-placement
area, and this report does not establish that the 5.0 ns timing target is met.
Static timing analysis and physical design remain separate steps.
