# RTL-to-GDSII Physical Design and PPA Optimization of an INT8 Matrix-Multiply Accelerator

## 1. Project Overview

This project is a coherent RTL-to-GDSII physical-design study built around an INT8 matrix-multiply accelerator.

The same baseline design will later be used for synthesis, timing analysis, floorplanning, placement, CTS, routing, physical verification, timing closure, congestion analysis, and PPA experiments.

The project is intended to produce a measurable and reproducible physical-design portfolio project.

---

## 2. Project Scope

### Project title

**RTL-to-GDSII Physical Design and PPA Optimization of an INT8 Matrix-Multiply Accelerator**

### Core workload

```text
C = A × B
```

where:

```text
A = 8×8 matrix
B = 8×8 matrix
```

### Input type

```text
Signed INT8 matrix elements
```

### Baseline target clock

```text
Clock period = 5 ns
Target frequency = 200 MHz
```

This is the initial project target. Actual timing will be measured later using synthesis and static timing analysis.

---

## 3. Baseline Philosophy

This first version is the preserved reference point for all later experiments.

The baseline should remain:

- simple
- synthesizable
- reproducible
- measurable
- suitable for PPA, timing, congestion, and physical-verification experiments

Future experiments should change one major variable at a time and compare the result against preserved baseline reports, logs, and configurations.

### Baseline discipline

1. Do not overwrite the baseline run or its raw reports.
2. Record actual tool versions used for reproducibility-sensitive results.
3. Treat later RTL, timing, floorplan, placement, and routing changes as controlled experiments.
4. Do not optimize one metric without preserving the previous configuration and documenting the trade-off.
5. Use measured implementation data for timing and PPA claims.

---

## 4. Baseline External Interface

The baseline interface uses one signed INT8 input element per accepted cycle.

Matrices are loaded into local accelerator storage, computation is started explicitly, and the output matrix is serialized as signed INT18 values.

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `clk` | 1 | Input | Main clock; baseline target is 5 ns |
| `rst_n` | 1 | Input | Active-low synchronous reset |
| `data_in` | 8 | Input | Signed INT8 matrix element |
| `data_valid` | 1 | Input | Indicates that `data_in` is valid on the current clock edge |
| `matrix_sel` | 1 | Input | `0 = matrix A`, `1 = matrix B` |
| `start` | 1 | Input | One-cycle command to begin matrix multiplication after A and B are loaded |
| `busy` | 1 | Output | Accelerator transaction is active |
| `done` | 1 | Output | One-cycle indication that matrix computation has completed |
| `data_out` | 18 | Output | Signed INT18 result element |
| `out_valid` | 1 | Output | Indicates that `data_out` is valid |

---

## 5. Input Transfer Convention

One INT8 element is accepted per valid input cycle.

Matrix elements are sent in row-major order.

### Matrix A

```text
A[0][0]
A[0][1]
A[0][2]
...
A[0][7]

A[1][0]
...
A[7][7]
```

A total of 64 accepted INT8 values are required for matrix A.

### Matrix B

Matrix B follows matrix A, also in row-major order:

```text
B[0][0]
B[0][1]
B[0][2]
...
B[7][7]
```

A total of 64 accepted INT8 values are required for matrix B.

Therefore:

```text
64 A values + 64 B values = 128 accepted input elements
```

---

## 6. Output Transfer Convention

The output matrix C is serialized in row-major order:

```text
C[0][0]
C[0][1]
C[0][2]
...
C[0][7]

C[1][0]
...
C[7][7]
```

Each valid result is presented on `data_out` with `out_valid` asserted.

No `out_index` port is included in the baseline. The receiver infers output position from the sequence of valid output cycles.

---

## 7. Baseline Timing Target

The project baseline is:

```text
Clock period = 5 ns
Target frequency = 200 MHz
```

This is an initial project target rather than an achieved timing result.

Actual WNS, TNS, critical paths, path delays, and clock effects will be measured later through synthesis and STA.

---

## 8. Intended Toolchain

The intended open-source toolchain is:

| Tool / Technology | Role |
|---|---|
| SystemVerilog | RTL design |
| Yosys | Logic synthesis and synthesis reporting |
| OpenROAD | Floorplanning, placement, CTS, routing, and physical-design flow |
| OpenSTA | Static timing analysis |
| KLayout / Magic | Layout inspection and physical-verification support |
| Python | Experiment automation, report parsing, data collection, and plotting |
| Tcl | Flow control and tool scripting |

Exact installed versions should be recorded in:

```text
docs/tool_versions.txt
```

---

## 9. Repository Organization

The baseline repository uses:

```text
int8-matmul-pd/
├── rtl/
├── tb/
├── constraints/
├── flow/
├── scripts/
├── floorplan/
├── placement/
├── timing_closure/
├── reports/
├── results/
├── images/
├── docs/
├── README.md
└── .gitignore
```

---

## 10. Day 1 Scope Boundary

The following architectural details are intentionally kept out of this Day 1 project specification:

- compute organization
- PE count and PE mapping
- accumulator width
- detailed PE datapath
- controller FSM
- detailed reset behavior
- cycle-by-cycle controller timing
- timing endpoints
- architecture diagram

These are defined separately in the Day 2 architecture specification.

---

## 11. Reproducibility Requirements

The project should remain reproducible from a clean checkout.

Each milestone should preserve:

- source files
- configuration
- tool versions
- raw logs
- experiment results
- relevant screenshots or reports

The baseline must not be overwritten by later experiments.

---

## 12. Day 1 Definition of Done

Day 1 is complete when:

- Project scope is frozen at an 8×8 INT8 matrix-multiply accelerator.
- Baseline target clock is frozen at 5 ns / 200 MHz.
- External interface is frozen around one INT8 input element per cycle.
- A and B input order is fixed as row-major.
- C output order is fixed as row-major.
- Intended open-source toolchain is recorded.
- Exact local tool versions are recorded after installation and verification.
- Repository skeleton exists.
- Day 1 files are committed to Git.
- Working tree is clean.

---

## 13. Baseline Status

```text
Day 1 baseline status: FROZEN
```

Detailed accelerator microarchitecture is defined in the Day 2 architecture specification.
