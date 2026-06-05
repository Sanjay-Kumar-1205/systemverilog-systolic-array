# SystemVerilog Systolic Array Accelerator

This repository implements a parameterizable output-stationary systolic array in SystemVerilog, together with modular multiply-accumulate (MAC) units, processing elements (PEs), streamed matrix-loading logic, and self-checking verification collateral. The design targets small dense matrix multiplication as a pedagogical AI-accelerator kernel while preserving the structural ingredients used in larger tensor-compute datapaths: local forwarding, wavefront scheduling, accumulation reuse, and explicit valid/ready control at the array boundary.

## Project scope

The repository contains three architectural layers:

- `mac.sv`: signed multiply-accumulate primitive with enable, clear, and valid propagation.
- `pe.sv`: processing element that combines one MAC with eastbound data forwarding and southbound weight forwarding.
- `systolic_array.sv`: parameterized `N x N` array that streams one anti-diagonal of activations and weights per cycle and raises `output_valid` when a frame completes.

The fixed `systolic_2x2.sv` module is retained as a compact reference implementation and sanity-check target. The scalable `systolic_array.sv` is the main research-style artifact.

## Dataflow model

The top-level array uses an output-stationary schedule:

- Activations enter from the west edge and shift horizontally.
- Weights enter from the north edge and shift vertically.
- Each PE accumulates a partial sum locally until the full frame has traversed the mesh.
- A frame of an `N x N` matrix multiplication consumes `2N - 1` streamed input cycles.

For matrices `A` and `B`, the testbench injects:

- `data_in[row] = A[row][cycle - row]` when the index is in range, otherwise `0`
- `weight_in[col] = B[cycle - col][col]` when the index is in range, otherwise `0`

This diagonalized stream aligns operands inside the array without requiring global broadcast buses.

## Interface semantics

`systolic_array.sv` now enforces a safer frame protocol:

- `input_ready` is asserted only while the array is actively accepting a frame.
- Once `FRAME_CYCLES` transfers have been accepted, further inputs are blocked until the result is observed and the accumulator state is explicitly cleared.
- `output_valid` remains asserted under backpressure until `output_ready` is received.

This closes a subtle control bug where an upstream source could previously inject extra cycles after the frame was full but before `output_valid` was raised.

## Verification strategy

The verification collateral was upgraded from single-example smoke tests to self-checking benches:

- `tb_mac.sv`
  - checks signed accumulation
  - checks disable behavior
  - checks invalid-cycle behavior
  - checks accumulator clearing and restart
- `tb_systolic_array.sv`
  - instantiates a `3 x 3` parameterized array
  - computes a software golden matrix product internally
  - verifies a dense positive-valued case
  - verifies a mixed-sign case
  - checks backpressure by holding `output_ready` low while requiring `output_valid` to remain asserted
  - checks that `input_ready` deasserts after a frame is fully accepted
- `tb_systolic_consistency.sv`
  - cross-checks the fixed `systolic_2x2` implementation against `systolic_array` configured with `N = 2`
  - verifies that both implementations match the same golden matrix product
  - provides an equivalence-style regression between the hand-wired and generated datapaths

In addition, `systolic_array.sv` now includes embedded protocol assertions for bounded frame counting, sticky output-valid behavior under backpressure, and correct frame-completion gating.

## Verified results

Simulations completed successfully on June 3, 2026:

- `tb_mac.sv` passed under `iverilog`
- `tb_systolic_array.sv` passed under AMD Vivado `xsim`
- `tb_systolic_consistency.sv` passed under AMD Vivado `xsim`

The Vivado behavioral simulations currently exercise:

- the parameterized `3 x 3` array regression in `280 ns`
- the `2 x 2` generic-versus-reference consistency regression in `330 ns`

## Repository structure

```text
SystolicAI.srcs/
  sources_1/new/
    mac.sv
    pe.sv
    systolic_2x2.sv
    systolic_array.sv
  sim_1/new/
    tb_mac.sv
    tb_systolic_2x2.sv
    tb_systolic_array.sv
    tb_systolic_consistency.sv
SystolicAI.sim/sim_1/behav/xsim/
  compile.bat
  elaborate.bat
  simulate.bat
```

## How to run

### Vivado xsim flow

From `SystolicAI.sim/sim_1/behav/xsim`:

```powershell
$env:Path = 'E:\2025.2\Vivado\bin;' + $env:Path
cmd /c compile.bat
cmd /c elaborate.bat
cmd /c simulate.bat
```

### Icarus Verilog smoke test

From the repository root:

```powershell
& 'E:\iverilog\bin\iverilog.exe' -g2012 -o tb_mac.vvp `
  SystolicAI.srcs\sources_1\new\mac.sv `
  SystolicAI.srcs\sim_1\new\tb_mac.sv
& 'E:\iverilog\bin\vvp.exe' tb_mac.vvp
```

## Design limitations

This project is intentionally RTL-centric and stops short of a deployment-ready accelerator subsystem. In particular, it does not yet include:

- SRAM buffering or DMA-fed tiling
- quantization-aware scaling or saturation
- throughput/area/power characterization
- formal verification properties
- a standard streaming bus such as AXI-Stream

## Research-grade next steps

Natural directions for extending this into a stronger thesis or publication artifact include:

- adding tiled GEMM support with explicit memory hierarchy modeling
- introducing fixed-point quantization studies and error analysis
- measuring utilization under sparse or irregular operand streams
- synthesizing multiple array sizes and plotting area-frequency-throughput tradeoffs
- comparing output-stationary, weight-stationary, and row-stationary schedules on the same RTL substrate

## Summary

The repository now represents a coherent accelerator microarchitecture project rather than a minimal classroom demo: the control path is safer, the scalable array is regression-tested in Vivado, and the documentation explains the intended computation, protocol, and extension path in research terms.
