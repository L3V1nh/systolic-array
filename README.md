# Systolic Array Matrix Multiplier

A high-performance, parameterizable $5 \times 5$ Systolic Array Matrix Multiplier implemented in structural Verilog. This architecture optimizes data reuse and maximizes throughput by utilizing a two-dimensional pipelined processing grid, making it highly suitable for hardware acceleration tasks such as deep learning inference.

---

## Architectural Overview

The core processing engine relies on a network of tightly coupled Processing Elements (PEs) that operate concurrently. Data flows through the network in a rhythmically timed wavefront, minimizing global memory access by passing matrix operands directly between adjacent PEs.

### Key Components

* **Top-Level Wrapper (`systolic`):** Manages the input skewing registers, external interface handling, and tail-end data protection logic.
* **Grid Network (`systolic_grid`):** Generates the internal structural mesh network interconnecting the rows and columns of the array.
* **Processing Element (`processing_element`):** Contains the multiply-accumulate (MAC) logic, support signed multiplying with Booth's Algorithm, local registers for data forwarding, and hardware execution gates.

---

## Technical Features

### Spatial Input Skewing Pipeline

To ensure the correct algebraic collisions occur within a 2D network, inputs must be staggered in time. The wrapper implements custom spatial delay pipelines (bucket brigades) for both rows and columns.

* **Row $n$** and **Column $n$** are systematically delayed by $n$ clock cycles relative to index 0, aligning the data stream into a diagonal computational wavefront.

### Tail-End Data Protection

A common structural flaw in systolic architectures is the infiltration of ghost values or floating bus data after the input matrix sequence concludes. This implementation incorporates a hardware-managed data-valid validation pipeline (`v` registers) driven by an external write-enable (`wrt_en`) signal.

* When `wrt_en` drops, internal multiplexers clamp trailing inputs to a true zero (`8'sd0`), preventing downstream registers from repeating stagnant numbers and corrupting active edge computations.

### Deterministic Output Flagging

The global validation signal (`valid_out`) is tied directly to the final stage of the validation wavefront pipeline. It automatically asserts when the final computational stream clears the maximum pipeline delay, alerting external memory blocks or testbenches that the calculation is complete.

---

## Interface Specifications

### Module Ports (`systolic`)

| Port Name | Direction | Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Global System Clock |
| `rst` | Input | 1 bit | Synchronous Active-High Reset |
| `wrt_en` | Input | 1 bit | Write Enable (Asserted while data streams in) |
| `raw_row_0` to `_4` | Input | 8 bits | Signed 8-bit Input Matrix A Rows (0 to 4) |
| `raw_col_0` to `_4` | Input | 8 bits | Signed 8-bit Input Matrix B Columns (0 to 4) |
| `matrix_out` | Output | 400 bits | Flattened 2D array of 25 parallel 16-bit signed products |
| `valid_out` | Output | 1 bit | Execution Complete Indicator Flag |

### Internal Data Representation

The output matrix bus (`matrix_out`) packs the 2D grid elements into a single contiguous vector using indexed part-select format:

```text
matrix_out[((row * 5 + col) * 16) +: 16]

```

Each cell accommodates a 16-bit signed accumulator to prevent bit-overflow during deep dot-product iterations.

---

## Verification and Simulation

A self-contained testbench environment (`systolic_tb.vcd`) validates the design correctness.

### Simulation Clocking Discipline

To avoid hold-time violations and race conditions within the simulation queue, the verification environment isolates driving and sampling boundaries:

* **Stimulus Generation:** Input data values are updated on the negative edge of the clock (`negedge clk`) while `wrt_en` is asserted.
* **Design Capture:** The physical hardware internal registers sample inputs on the rising edge of the clock (`posedge clk`), guaranteeing optimal setup window margins.
* **Tail Flush:** After five input pulses, `wrt_en` is deasserted and the wrapper internally suppresses trailing data while the pipeline drains.

### Test Matrix Profile

The current testbench streams five packed input cycles into the wrapper. Each cycle updates the five 8-bit row lanes and five 8-bit column lanes on `negedge clk`, with `wrt_en` held high during the active stream and then deasserted for the drain phase.

The specific stimulus used by `systolic_tb.v` is:

$$
\begin{aligned}
A &= \begin{bmatrix}
1 & 2 & -1 & 0 & 4 \\
-2 & 1 & 0 & 3 & -1 \\
0 & -3 & 2 & 1 & -2 \\
3 & 0 & -2 & -1 & 0 \\
-1 & 4 & 1 & -2 & 3
\end{bmatrix} \\
B &= \begin{bmatrix}
2 & -1 & 0 & 3 & -2 \\
0 & 3 & -2 & 1 & 0 \\
-1 & 0 & 4 & 0 & 2 \\
1 & 2 & -1 & 3 & -1 \\
3 & -2 & 1 & 0 & -3
\end{bmatrix}
\end{aligned}
$$

### Expected Verification Output

Upon completion of the computation window, the `print_matrix` task formats the 400-bit output vector into the following system log grid representation:

```text
Formatted matrix_out:
[15     -3      -3      7       10]
[-5     9       -6      3       -11]
[-10    -6      11      -10     -4]
[-2     6       0       4       1]
[3      1       -6      1       3]

Simulation finished.

```

---

## Execution Guide

### Prerequisites

* An IEEE-1364 compliant Verilog Simulator (e.g., Icarus Verilog, Verilator, or ModelSim/Questa).
* A waveform viewer tool (e.g., GTKWave) to interpret `.vcd` trace outputs.

### Compiling and Running via Icarus Verilog

Execute the following instructions from your terminal interface to compile the hardware description files and initiate the simulation:

```bash
# Compile design modules and testbench
iverilog -o systolic_sim.vvp src/BoothMultiplier.v src/PE.v src/systolic.v sim/systolic_tb.v

# Execute simulation binary to generate VCD log and console output
vvp systolic_sim.vvp
```

To examine the behavioral waveform characteristics, open the generated dump file:

```bash
gtkwave systolic_tb.vcd

```

## Additional features:
- Ready/Valid handshake to stream data
```text
module systolic_enhanced (
    input wire clk,
    input wire rst,
    
    // --- ENHANCED INPUT INTERFACE (Streaming Handshake) ---
    input wire  [7:0] in_data,   // Streams matrix elements sequentially
    input wire        in_valid,  // Asserted when host has valid data ready
    output reg        in_ready,  // Asserted when systolic array is ready to accept data
    
    // --- ENHANCED OUTPUT INTERFACE (Streaming Handshake) ---
    output reg [15:0] out_data,  // Streams out 16-bit products one element at a time
    output reg        out_valid, // Asserted when systolic array has computed a valid result element
    input wire        out_ready  // Asserted when downstream block is ready to read the output
);

```
