#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORFS_DIR="${ORFS_DIR:-$HOME/eda/OpenROAD-flow-scripts}"

SKY130_LIB="${SKY130_LIB:-$ORFS_DIR/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib}"

cd "$ROOT_DIR"

if [[ ! -s "$SKY130_LIB" ]]; then
    echo "ERROR: SKY130 Liberty file not found:"
    echo "$SKY130_LIB"
    exit 1
fi

mkdir -p reports/synthesis results/netlist

echo "============================================"
echo " SKY130HD TECHNOLOGY-MAPPED SYNTHESIS"
echo "============================================"
echo "Top module : int8_matmul"
echo "Library    : $SKY130_LIB"
echo "============================================"

YOSYS_SCRIPT="$(mktemp)"
trap 'rm -f "$YOSYS_SCRIPT"' EXIT

# Generate a plain Yosys command script.
cat > "$YOSYS_SCRIPT" <<EOF
read_verilog -sv rtl/mac_pe.sv
read_verilog -sv rtl/mac_array.sv
read_verilog -sv rtl/matmul_controller.sv
read_verilog -sv rtl/int8_matmul.sv

hierarchy -check -top int8_matmul

synth -top int8_matmul -flatten -noabc

# Remove non-hardware hierarchy metadata created by flatten.
delete t:\$scopeinfo

# Check the synthesized RTL logic before library mapping.
check

# Map sequential cells to SKY130HD cells.
dfflibmap -liberty $SKY130_LIB

# Map combinational logic to SKY130HD cells.
abc -liberty $SKY130_LIB

clean

# Report mapped cell statistics and Liberty-based area.
# Avoid a second check here: some Yosys versions can report
# false undriven-wire warnings after dfflibmap.
stat -liberty $SKY130_LIB

write_verilog -noattr results/netlist/int8_matmul_sky130hd.v
write_json results/netlist/int8_matmul_sky130hd.json
EOF

yosys -s "$YOSYS_SCRIPT" \
    2>&1 | tee reports/synthesis/day7_sky130hd_yosys.log
