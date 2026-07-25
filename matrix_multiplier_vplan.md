# Verification Plan: Matrix Multiplier Hardware Accelerator

## 1. Document Overview

| Field | Value |
|---|---|
| DUT | Matrix Multiplier Accelerator (MMA) |
| Version | v0.1 (draft — adjust to match actual RTL) |
| Author | |
| Status | Draft |

This plan assumes a generic parameterizable matrix-multiply accelerator (systolic array, MAC-array, or streaming-MAC style). Adjust the "Assumed Architecture" section to match your actual RTL before treating this as final.

---

## 2. Assumed Architecture (fill in / confirm against your RTL)

- Computes `C = A × B` (+ optional `C += A × B` accumulate mode, and optional bias add)
- Matrix dimensions: `M × K` times `K × N` → `M × N`, with configurable or fixed `M, N, K` (state which)
- Data type: fixed-point (specify width, signed/unsigned, Q-format) or floating-point (specify FP16/BF16/FP32)
- PE array: e.g. `PE_ROWS × PE_COLS` systolic array with weight-stationary / input-stationary / output-stationary dataflow (state which — this drives a lot of the verification, especially timing of data loads)
- Interfaces:
  - Control/config: APB/AXI-Lite register interface (mode, dimensions, start/done, interrupt)
  - Data: AXI-Stream or AXI-MM burst interface for A, B, C (in/out)
  - Memory: on-chip SRAM/BRAM buffers for operand tiles if tiling is used
- Tiling: does the accelerator handle matrices larger than the PE array natively (internal tiling/looping) or does software have to tile and call it repeatedly? This materially changes the test plan.

**Action item:** Replace this section with the actual spec/microarchitecture doc reference before review.

---

## 3. Verification Strategy

No UVM — this is a **plain SystemVerilog testbench**: a directed/random stimulus generator using `randomize()` + `constraint` blocks, a simple driver/monitor pair (tasks, not full class-based agents unless you want them), a scoreboard, and `covergroup`s sampled from a monitor. Everything below is scoped to that style.

- **Testbench structure (simple, non-UVM):**
  - A top-level `tb_top.sv` that instantiates the DUT and clock/reset generation.
  - A `transaction` class (or even just a `struct`) holding: matrix A, matrix B, dimensions, mode/precision config — this is what you randomize.
  - A **generator/driver task** that randomizes a transaction, drives it onto the DUT's interface (register writes + data stream), and waits for `done`.
  - A **monitor task** that watches the output interface and captures the result matrix as it comes out.
  - A **scoreboard task/function** that compares the monitor's captured output against a golden-model result.
  - A **coverage collector** — one or more `covergroup`s, sampled either on every transaction completion or via an interface clocking block, whichever is easier to wire up in your testbench.
- **Reference model:** Bit-accurate golden model, written in SystemVerilog (functions), C via DPI, or Python via DPI — whichever is fastest for you to get exactly right. It must match the DUT's exact fixed-point rounding/saturation/overflow behavior bit-for-bit. This is the single most important piece of infrastructure to get right before writing any random test, since any mismatch here shows up as a wall of false failures.
- **Levels of verification:**
  - **Unit level:** PE (MAC) cell, control FSM, buffer/FIFO, register interface — each with its own small standalone testbench, easiest place to start.
  - **Top level (accelerator IP):** Full DUT, driven through its real control/data interfaces, single self-checking testbench.
  - **System level (if applicable):** Skip unless you have an actual SoC/CPU environment to integrate into — not needed for IP-level constrained-random verification.
- **Assertions (SVA):** Use `assert property` directly in the testbench or bound into the DUT for protocol/FSM legality checks — this gives you a lot of the safety net people use UVM for, without needing the full methodology.

---

## 4. Features to Verify (Feature List)

### 4.1 Functional / Datapath
- [ ] Basic correctness: `C = A × B` for representative dimensions
- [ ] Accumulate mode: `C += A × B`
- [ ] Bias/offset add (if supported)
- [ ] All supported data types/precisions (e.g., INT8×INT8→INT32, FP16×FP16→FP32) — including mixed precision if supported
- [ ] Saturation / overflow / underflow handling per data type
- [ ] Rounding mode(s) if configurable (round-to-nearest, truncate, stochastic rounding, etc.)
- [ ] Signed vs unsigned operand combinations
- [ ] Zero matrices, identity matrices, all-max-value matrices, all-min-value (most negative) matrices
- [ ] Non-square matrices (M ≠ N ≠ K), including highly rectangular shapes (1×K, Kx1, etc.)
- [ ] Matrix dimensions smaller than PE array (array under-utilized)
- [ ] Matrix dimensions exactly matching PE array
- [ ] Matrix dimensions requiring internal tiling (larger than PE array in one or more dims), if supported
- [ ] Odd/non-power-of-2 dimensions, and dimensions that don't divide evenly into tile size (edge/remainder tile handling — classic bug source)
- [ ] Sparse matrices (if sparsity acceleration is a feature) — including fully dense as the degenerate case

### 4.2 Control / Sequencing
- [ ] Start/stop/done handshake correctness
- [ ] Back-to-back operations (new job issued immediately after previous `done`, no idle gap)
- [ ] Config-register updates while idle vs while busy (should the latter be blocked/ignored/erred?)
- [ ] Abort/flush/soft-reset mid-computation
- [ ] Interrupt generation on completion / on error
- [ ] Multiple queued operations (if job queue/descriptor-based dispatch is supported)
- [ ] Mode switching between successive operations (e.g., precision change, dimension change job-to-job)

### 4.3 Data Movement / Memory Interface
- [ ] Correct AXI burst behavior for operand fetch and result writeback (burst length, alignment, wrap vs incr)
- [ ] Back-pressure handling on input stream (producer stalls) and output stream (consumer stalls)
- [ ] Buffer full/empty conditions on internal FIFOs/SRAMs
- [ ] Double-buffering / ping-pong correctness if used to overlap load/compute/store
- [ ] Unaligned base addresses, if allowed
- [ ] Byte-enable / partial-word handling at matrix edges (if data isn't cleanly word-aligned)

### 4.4 Register Interface
- [ ] Every register: reset value, read, write, read-only bits stay read-only, write-only/self-clearing bits behave correctly
- [ ] Reserved bits/fields don't affect functionality when written with garbage
- [ ] Register access during active computation (should reads of status be always legal? Should writes to config be blocked?)

### 4.5 Error Handling
- [ ] Illegal configuration (e.g., dimension = 0, dimension exceeding max supported, invalid mode encoding) — check for graceful error flag vs. hang vs. corrupted output
- [ ] Bus error response handling (e.g., AXI SLVERR/DECERR on operand fetch)
- [ ] ECC/parity error injection on internal memories, if implemented

### 4.6 Power / Clocking (if applicable)
- [ ] Clock gating doesn't corrupt state (PEs idle when array under-utilized should still hold correct values)
- [ ] Low-power state entry/exit around active computation
- [ ] Reset behavior: async reset assertion mid-computation, deassertion, and first operation after reset

### 4.7 Performance
- [ ] Cycle count for a given matrix size matches expected throughput model (e.g., PE-array utilization, no unexpected bubble cycles)
- [ ] Sustained throughput back-to-back across many operations (no cumulative buffer starvation)

---

## 5. Test Plan (Directed + Random)

### 5.1 Directed Tests
| Test | Purpose |
|---|---|
| `basic_smoke` | Single small matrix multiply, known golden values, sanity check of full path |
| `identity_matrix` | A × I = A, verifies no unintended scaling/truncation |
| `zero_matrix` | A × 0 = 0, checks no residual accumulator garbage |
| `max_value_saturation` | All-max operands to force overflow, check saturation logic |
| `min_value_edge` | Most-negative signed values, checks two's-complement edge handling |
| `non_divisible_dims` | Dimensions that don't divide evenly by tile/array size |
| `back_to_back_ops` | Two+ jobs issued with zero idle gap between `done` and next `start` |
| `abort_mid_op` | Assert abort/soft-reset partway through, verify clean recovery |
| `illegal_config` | Zero or out-of-range dimension, verify error flag and no hang |
| `bus_backpressure` | Consumer/producer stalls at various points in the pipeline |
| `precision_sweep` | Every supported data type/precision combination once, directed |
| `reset_mid_compute` | Async reset asserted mid-computation, verify clean restart |

### 5.2 Constrained-Random Tests

Write one `transaction` (class or struct) with `rand` fields for: M, N, K, data values (or a mode selecting how they're generated), operation mode, precision. Example skeleton:

```systemverilog
class mm_txn;
  rand int M, N, K;
  rand bit signed [DW-1:0] A[][];
  rand bit signed [DW-1:0] B[][];
  rand mode_e mode;         // MULT_ONLY, ACCUMULATE
  rand bit backpressure_en; // whether to randomly stall ready/valid this txn

  constraint c_dims {
    M inside {[1:MAX_M]};
    N inside {[1:MAX_N]};
    K inside {[1:MAX_K]};
    // weight toward edge cases
    M dist {1 := 5, [2:PE_ROWS-1] := 20, PE_ROWS := 30, [PE_ROWS+1:MAX_M] := 45};
  }

  constraint c_values {
    foreach (A[i,j]) A[i][j] dist {
      0                      := 5,
      MAX_VAL                := 5,
      MIN_VAL                := 5,
      [MIN_VAL+1:MAX_VAL-1]  := 85
    };
    // same pattern for B
  }
endclass
```

Then a simple driver loop:

```systemverilog
repeat (NUM_RANDOM_TESTS) begin
  mm_txn t = new();
  assert(t.randomize());
  drive_transaction(t);        // task: writes config regs, streams A/B in
  wait_for_done();
  capture_result(actual);      // task: reads/streams C out
  golden_model(t.A, t.B, t.mode, expected);
  scoreboard_check(actual, expected, t);  // flags mismatch with full txn context
end
```

- **Randomize:** dimensions (weighted toward edge sizes — 1, array-size boundary, multi-tile), data values (weighted toward min/max/zero vs. uniform-random mix), operation mode, precision, and interface timing (randomized stall cycles on input/output if you're modeling backpressure).
- **Run count:** not a fixed number up front — keep running with new seeds until the coverage report (Section 6) shows all bins hit, then lock a regression seed list from that run.
- **Constrain toward realistic usage** even while randomizing, so failures are actionable and not just artifacts of stimulus nobody would ever actually send (e.g., don't generate dimensions outside what software would ever configure, unless you're specifically doing the illegal-config negative tests, which should be separate directed tests, not part of the random constraint set).

### 5.3 Regression
- Every RTL change: full directed suite + a fixed regression seed list (seeds saved from earlier runs that are known to hit different coverage bins) — fast turnaround.
- Nightly / pre-milestone: directed suite + N fresh random seeds (pick N based on runtime budget), re-check coverage report for regressions in bin closure.
- Track a simple seed log (seed → pass/fail → date) so any prior failure is trivially reproducible by re-running that seed alone.

---

## 6. Functional Coverage Plan

Define covergroups/coverpoints for at least:

- **Dimension coverage:** M, N, K each swept across: 1, small (< array size), exactly array size, > array size (multi-tile), max supported, and cross-coverage between all three (M×N×K combinations, not just each independently — this is where corner-case bugs actually live)
- **Data value coverage:** zero, max positive, max negative (most negative), random, saturating combinations
- **Mode coverage:** multiply-only, accumulate, all supported precisions, all rounding modes
- **Sequencing coverage:** back-to-back ops, gapped ops, abort during each major phase (load/compute/store), config-write during idle vs busy
- **Interface timing coverage:** input stall at every pipeline phase, output stall at every pipeline phase, cross-coverage of input-stall × output-stall combinations
- **Error coverage:** every defined error condition hit at least once, each error's interrupt/flag observed

Coverage closure target: 100% on directed-testable bins, negotiated target (e.g. 95%+) on pure cross-coverage bins with a documented waiver process for anything unreachable.

**Example covergroup**, sampled once per completed transaction (call `mm_cov.sample()` from the same point in your driver loop where you call the scoreboard check):

```systemverilog
covergroup mm_cov with function sample(mm_txn t, bit err);
  option.per_instance = 1;

  cp_M: coverpoint t.M {
    bins small       = {[1:PE_ROWS-1]};
    bins exact       = {PE_ROWS};
    bins multi_tile  = {[PE_ROWS+1:MAX_M]};
  }
  cp_N: coverpoint t.N {
    bins small       = {[1:PE_COLS-1]};
    bins exact       = {PE_COLS};
    bins multi_tile  = {[PE_COLS+1:MAX_N]};
  }
  cp_K: coverpoint t.K {
    bins small       = {[1:PE_ARRAY_K-1]};
    bins exact       = {PE_ARRAY_K};
    bins multi_tile  = {[PE_ARRAY_K+1:MAX_K]};
  }
  cp_mode: coverpoint t.mode;
  cp_backpressure: coverpoint t.backpressure_en;
  cp_error: coverpoint err;

  // cross coverage catches the corner cases individual coverpoints miss
  x_dims:  cross cp_M, cp_N, cp_K;
  x_mode_bp: cross cp_mode, cp_backpressure;
endgroup

mm_cov cov_inst = new();
// call cov_inst.sample(t, err) after each transaction completes
```

Run with your simulator's coverage flag (e.g. `-cm` for VCS, `+cover` style flags for Questa/Xcelium — check your tool's docs) and generate the HTML/text coverage report after each regression run; that report is what you check against the closure targets above.

---

## 7. Checking Strategy

- **Scoreboard:** Golden-model-based, bit-exact comparison against reference model output, transaction-by-transaction (per output matrix, or per output element if you want finer-grained failure localization — recommended, since "whole matrix mismatch" gives you almost no debug info).
- **Protocol checkers:** Standard AXI/APB VIP assertions (or SVA-based custom checkers) for every bus interface — valid/ready handshake rules, burst legality, no protocol violations, independent of the datapath scoreboard.
- **Internal assertions (SVA):**
  - No illegal FSM state reachable
  - No simultaneous conflicting control signals (e.g., load and compute asserted same cycle if mutually exclusive)
  - FIFO/buffer never overflows or underflows
  - `done` only asserted after a legal sequence of internal states (not spuriously early/late)
- **End-of-test checks:** all expected interrupts fired, all outstanding transactions completed, no dangling/incomplete jobs in a queue.

---

## 8. Debug & Traceability

- Every test failure should log: input matrices (or a seed + generator params to reconstruct them), the specific output element(s) that mismatched, expected vs. actual value, and DUT internal state dump (control FSM state, buffer occupancy) at time of failure.
- Maintain a requirements-traceability matrix mapping each item in Section 4 to the specific test(s)/covergroup bin(s) that verify it, so gaps are visible at a glance rather than only being caught by intuition. A four-column table (Feature → Test(s) → Coverage bin(s) → Status) is usually enough.

---

## 9. Open Questions / Assumptions to Confirm

- [ ] Confirm exact data types and precision(s) supported
- [ ] Confirm whether internal tiling exists or software must tile
- [ ] Confirm PE array dataflow style (affects load/drain latency modeling in the reference model)
- [ ] Confirm rounding/saturation rules exactly (must match golden model bit-for-bit)
- [ ] Confirm bus protocol(s) used for control and data
- [ ] Confirm max supported matrix dimensions and any alignment requirements

---

*This is a template scoped to a generic MAC-array/systolic matrix multiplier. Replace Section 2 with your actual microarchitecture and prune/expand Sections 4–6 to match — e.g., drop sparsity items if not applicable, add specific dataflow-related corner cases (weight reload timing, drain-pipe latency) if your array is weight-stationary.*
