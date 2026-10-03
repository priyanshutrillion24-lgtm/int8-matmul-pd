# RTL-to-GDSII Physical Design and PPA Optimization of an INT8 Matrix-Multiply Accelerator

## Day 2 — Finalized Architecture Specification

**Status:** DAY 2 FROZEN  
**RTL implementation begins on Day 3**

---

## 1. Architectural Objective

The accelerator computes:

```text
C = A × B
```

for fixed 8×8 matrices.

```text
A = 8×8 signed INT8 matrix
B = 8×8 signed INT8 matrix
C = 8×8 result matrix
```

Each output element is:

\[
C_{ij} = \sum_{k=0}^{7} A_{ik} B_{kj}
\]

The baseline architecture is intentionally regular and simple so that the same implementation can support later synthesis, floorplanning, placement, CTS, routing, STA, congestion, and PPA experiments.

---

## 2. Frozen Compute Organization

### 2.1 8×8 MAC Array

The baseline uses an 8×8 output-stationary MAC array containing:

```text
8 × 8 = 64 processing elements
```

Each PE is permanently associated with one output:

```text
PE[0][0] → C[0][0]
PE[0][1] → C[0][1]
...
PE[7][7] → C[7][7]
```

### 2.2 Output-Stationary Behavior

Each PE keeps its partial sum locally while the reduction dimension `k` advances.

For `PE[i][j]`:

```text
acc_next[i][j] =
    acc[i][j] + A[i][k] × B[k][j]
```

for:

```text
k = 0, 1, 2, 3, 4, 5, 6, 7
```

After the eighth MAC:

```text
acc[i][j] = C[i][j]
```

No partial sum is transferred between PEs.

---

## 3. Frozen PE Datapath

Each PE contains:

- one signed INT8 × INT8 multiplier
- an INT16 product
- sign-extension from INT16 to INT18
- an INT18 adder/accumulator path
- an INT18 accumulator register

Conceptually:

```text
A[i][k] ─────┐
             ├──> INT8 × INT8
B[k][j] ─────┘
                    │
                    ▼
               INT16 product
                    │
                    ▼
               sign-extend
                    │
                    ▼
                INT18 ADD
                    │
                    ▼
             ACC[17:0] register
                    ▲
                    │
                    └── feedback
```

### Datapath widths

| Signal / data item | Width | Role |
|---|---:|---|
| `A` operand | signed INT8 | Current `A[i][k]` value |
| `B` operand | signed INT8 | Current `B[k][j]` value |
| Product | signed INT16 | Multiplier result |
| Accumulator | signed INT18 | Partial/final sum for `C[i][j]` |

---

## 4. Accumulator Width Decision

The baseline accumulator width is:

```text
signed INT18
```

This is the chosen width for an 8-term signed INT8 dot product.

A 32-bit accumulator is intentionally **not** part of the baseline.

A wider accumulator may be introduced later only as a controlled RTL/PPA experiment.

---

## 5. Pipeline Strategy

The baseline MAC is **unpipined**.

There is no register between the multiplier and the accumulator adder.

The baseline datapath is:

```text
A/B storage register
        ↓
k-dependent operand selection
        ↓
8×8 multiplier
        ↓
18-bit addition
        ↓
18-bit accumulator register
```

A pipelined product stage is deliberately deferred to later timing-closure experiments.

---

## 6. A/B Storage Organization

A and B are stored locally as register arrays.

Conceptually:

```systemverilog
logic signed [7:0] A [0:7][0:7];
logic signed [7:0] B [0:7][0:7];
```

Storage:

```text
A = 64 × signed INT8
B = 64 × signed INT8
```

All A entries are overwritten during the A-load phase.

All B entries are overwritten during the B-load phase.

A/B registers are not globally reset.

No SRAM or memory macro is part of the baseline.

---

## 7. Accumulator Storage

Conceptually:

```systemverilog
logic signed [17:0] acc [0:7][0:7];
```

There are:

```text
64 × 18-bit accumulator registers
```

They are not globally reset.

A one-cycle `acc_clear` action initializes all accumulators to zero immediately before the first MAC.

---

## 8. PE Operand Mapping

For the current global `k_count`, every PE performs:

```text
PE[i][j]:
    acc[i][j] ← acc[i][j] + A[i][k] × B[k][j]
```

Examples:

```text
PE[0][0] uses A[0][k] × B[k][0]
PE[0][7] uses A[0][k] × B[k][7]
PE[7][0] uses A[7][k] × B[k][0]
PE[7][7] uses A[7][k] × B[k][7]
```

All 64 PEs use the same global `k_count`.

There is no PE-to-PE data movement.

---

## 9. Controller Architecture

The controller is a single global FSM coordinating:

- input loading
- accumulator initialization
- computation
- output serialization

FSM:

```text
IDLE
  ↓
LOAD_A
  ↓
LOAD_B
  ↓
READY
  ↓
COMPUTE
  ↓
OUTPUT
  ↓
IDLE
```

### State responsibilities

| State | Purpose | Main counter/control |
|---|---|---|
| `IDLE` | Wait for first valid A element | No active transaction |
| `LOAD_A` | Accept A in row-major order | `load_count[5:0]` |
| `LOAD_B` | Accept B in row-major order | `load_count[5:0]` |
| `READY` | Wait for start command | Hold A/B; no MAC |
| `COMPUTE` | Perform one MAC per PE per cycle | `k_count[2:0]` |
| `OUTPUT` | Serialize C in row-major order | `out_count[5:0]` |

---

## 10. Controller Counters and Indexing

### `load_count`

```text
Width: 6 bits
Range: 0...63
Purpose: A/B load position
```

Row/column mapping:

```text
row    = load_count[5:3]
column = load_count[2:0]
```

Therefore:

```text
0  → [0][0]
1  → [0][1]
...
7  → [0][7]
8  → [1][0]
...
63 → [7][7]
```

### `k_count`

```text
Width: 3 bits
Range: 0...7
Purpose: Reduction dimension
```

### `out_count`

```text
Width: 6 bits
Range: 0...63
Purpose: Serialized output position
```

---

## 11. Detailed State Behavior

### 11.1 IDLE

Wait for the first valid A element.

When:

```text
data_valid = 1
matrix_sel = 0
```

accept `data_in` as:

```text
A[0][0]
```

and enter `LOAD_A`.

### 11.2 LOAD_A

Accept one INT8 whenever:

```text
data_valid = 1
```

Write:

```text
A[load_count]
```

and increment `load_count`.

If:

```text
data_valid = 0
```

stall without changing the counter.

After the 64th A element:

```text
LOAD_A → LOAD_B
```

and reset `load_count`.

### 11.3 LOAD_B

Accept one INT8 whenever:

```text
data_valid = 1
```

Write:

```text
B[load_count]
```

and increment `load_count`.

If:

```text
data_valid = 0
```

stall without changing the counter.

After the 64th B element:

```text
LOAD_B → READY
```

and reset `load_count`.

### 11.4 READY

Wait for:

```text
start = 1
```

When `start` is accepted:

```text
acc_clear = 1 for one cycle
k_count   = 0
state     = COMPUTE
```

No MAC occurs while waiting in `READY`.

### 11.5 COMPUTE

For the current `k_count`, all 64 PEs perform one MAC.

```text
k_count = 0...7
```

After the final `k=7` MAC is captured:

```text
done = 1 for one cycle
out_count = 0
state = OUTPUT
```

### 11.6 OUTPUT

Present:

```text
C[out_count]
```

in row-major order with:

```text
out_valid = 1
```

After `C[7][7]`, return to:

```text
IDLE
```

and deassert:

```text
busy
out_valid
```

---

## 12. Reset Behavior

Reset is:

```text
active-low
synchronous
```

### Reset actions

| Item | Reset action |
|---|---|
| FSM state | `IDLE` |
| `load_count` | `0` |
| `k_count` | `0` |
| `out_count` | `0` |
| `busy` | `0` |
| `done` | `0` |
| `out_valid` | `0` |
| `data_out` | `0` |
| A storage | Not globally reset |
| B storage | Not globally reset |
| Accumulators | Not globally reset; cleared with `acc_clear` before compute |

If reset occurs during:

```text
LOAD_A
LOAD_B
READY
COMPUTE
OUTPUT
```

the current transaction is aborted.

The controller returns to `IDLE` on the next rising edge.

A new transaction must reload A and B completely.

---

## 13. Exact Cycle-Level Compute Sequence

Convention:

- inputs and control commands are sampled on the rising edge
- the MAC datapath operates during the following clock period
- the accumulator captures the result at the next rising edge

### Start / clear

```text
E129:
    start accepted
    clear all 64 accumulators
    k_count ← 0
    enter COMPUTE
```

### MAC iterations

```text
E129 → E130:
    k = 0
    acc ← acc + A[:,0] × B[0,:]

E130:
    capture k=0 result
    k_count ← 1
```

```text
E130 → E131:
    k = 1
    acc ← acc + A[:,1] × B[1,:]

E131:
    capture k=1 result
    k_count ← 2
```

```text
E131 → E132:
    k = 2
    acc ← acc + A[:,2] × B[2,:]

E132:
    capture k=2 result
    k_count ← 3
```

```text
E132 → E133:
    k = 3
    acc ← acc + A[:,3] × B[3,:]

E133:
    capture k=3 result
    k_count ← 4
```

```text
E133 → E134:
    k = 4
    acc ← acc + A[:,4] × B[4,:]

E134:
    capture k=4 result
    k_count ← 5
```

```text
E134 → E135:
    k = 5
    acc ← acc + A[:,5] × B[5,:]

E135:
    capture k=5 result
    k_count ← 6
```

```text
E135 → E136:
    k = 6
    acc ← acc + A[:,6] × B[6,:]

E136:
    capture k=6 result
    k_count ← 7
```

```text
E136 → E137:
    k = 7
    acc ← acc + A[:,7] × B[7,:]

E137:
    final MAC captured
    done = 1 for one cycle
    enter OUTPUT
```

---

## 14. Output Serialization

The 64 C results are serialized after computation.

No `out_index` port is included.

The receiver infers position from the sequence of valid output cycles.

```text
out_count = 0  → C[0][0]
out_count = 1  → C[0][1]
...
out_count = 63 → C[7][7]
```

---

## 15. Register Organization

| Register group | Size | Role |
|---|---:|---|
| A storage | 64 × 8 bits | Matrix A local storage |
| B storage | 64 × 8 bits | Matrix B local storage |
| Accumulator storage | 64 × 18 bits | Partial/final C values |
| `load_count` | 6 bits | A/B load position |
| `k_count` | 3 bits | Compute iteration |
| `out_count` | 6 bits | Output position |
| FSM state | 6-state encoded register | Global sequencing |
| `data_out` register | 18 bits | Serialized output value |

---

## 16. Timing Endpoints and Candidate Critical Paths

The primary sequential endpoints of interest are the 64 accumulator registers.

Candidate paths are identified at architecture level; actual criticality will be determined by synthesis and STA.

### Operand path

```text
A/B storage register
        ↓
operand selection
        ↓
multiplier
        ↓
adder
        ↓
accumulator register
```

### Accumulator feedback

```text
accumulator register
        ↓
adder
        ↓
accumulator register
```

### Output path

```text
accumulator register
        ↓
output selection
        ↓
data_out register
```

### Control paths

```text
FSM/counter registers
        ↓
control/decode logic
        ↓
next-state/counter registers
```

---

## 17. Final Architecture Diagram

```text
                         ┌──────────────────────┐
                         │      CONTROLLER      │
                         │                      │
                         │ FSM                  │
                         │ load_count[5:0]      │
                         │ k_count[2:0]         │
                         │ out_count[5:0]       │
                         └──────────┬───────────┘
                                    │
                           control / k_count
                                    │
              ┌─────────────────────┴────────────────────┐
              │                                          │
              ▼                                          ▼
      ┌────────────────┐                        ┌────────────────┐
      │   A STORAGE    │                        │   B STORAGE    │
      │ 64 × INT8 regs │                        │ 64 × INT8 regs │
      └───────┬────────┘                        └───────┬────────┘
              │                                          │
              │ A[i][k]                                  │ B[k][j]
              │                                          │
              └─────────────────┬────────────────────────┘
                                │
                                ▼
                    ┌────────────────────────┐
                    │       8 × 8 MAC        │
                    │         ARRAY          │
                    │                        │
                    │  PE00 ... PE07         │
                    │  PE10 ... PE17         │
                    │  ...                   │
                    │  PE70 ... PE77         │
                    │                        │
                    │ 64 × INT8 multipliers  │
                    │ 64 × INT18 adders      │
                    │ 64 × INT18 accumulators│
                    └────────────┬───────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   OUTPUT SELECT/MUX    │
                    │   out_count[5:0]       │
                    └────────────┬───────────┘
                                 │
                                 ▼
                         data_out[17:0]
                         out_valid
```

---

## 18. Frozen Design Assumptions

| Assumption | Frozen baseline |
|---|---|
| Matrix size | 8×8 |
| Input datatype | signed INT8 |
| Product datatype | signed INT16 |
| Accumulator datatype | signed INT18 |
| PE organization | 8×8 = 64 PEs |
| PE mapping | `PE[i][j] → C[i][j]` |
| Storage | Register arrays for A, B, and accumulators |
| Compute | One MAC per PE per clock |
| Reduction dimension | `k = 0...7` |
| Baseline pipeline | Unpipelined multiplier + adder |
| Inter-PE communication | None |
| Input order | A row-major, then B row-major |
| Output order | C row-major |
| Clock target | 5 ns / 200 MHz |
| Reset | Active-low synchronous |
| Accumulator initialization | Explicit `acc_clear` before first MAC |
| Reset during transaction | Abort transaction and return to `IDLE` |

---

## 19. Day 2 Sign-Off

The following are frozen:

- Compute organization
- 64-PE arrangement
- Accumulator width = 18 bits
- PE datapath and operand mapping
- A/B register organization
- Unpipelined baseline
- Controller FSM and counters
- Reset and accumulator-clear behavior
- Cycle-level compute sequence
- Output serialization
- Timing endpoints and candidate paths
- Architecture diagram
- Design assumptions

Any later architectural change must be recorded as a new experiment rather than silently replacing the baseline.

```text
Day 2 status: COMPLETE / BASELINE ARCHITECTURE FROZEN
```
