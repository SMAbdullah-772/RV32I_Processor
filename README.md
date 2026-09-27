# RV32I Processor — Verilog

A **RISC-V RV32I single-cycle processor**, implemented in Verilog as a from-scratch RTL translation of an earlier Logisim design. The core is complete, integrated, and verified against real assembled RISC-V programs.

## Status: Single-Cycle Core Complete ✅

Every module has been implemented, cross-checked against its original Logisim schematic, integrated on a single top sheet, and verified end-to-end in simulation (Verilator) using hand-assembled RV32I machine code — not just unit-tested in isolation.

## Overview

This project began as a single-cycle RV32I CPU built and verified in Logisim, then translated module-by-module into synthesizable Verilog. The Logisim version served as the reference architecture: every control encoding, mux selection, and ALU operation code in the RTL was derived directly from the original schematics, rather than redesigned from scratch.

### Architecture

```text
                 ┌──────────────────┐
                 │ Program Counter  │──── pc+4 ────┐
                 └────────┬─────────┘              │
                          │                         │
                          ▼                         │
                 ┌──────────────────┐               │
                 │ Instruction Mem  │               │
                 └────────┬─────────┘               │
                          │                         │
                          ▼                         │
                 ┌──────────────────┐               │
                 │ Control Unit     │               │
                 │ (i_decode +      │               │
                 │  c_decode)       │               │
                 └────────┬─────────┘               │
                          │                         │
              ┌───────────┴───────────┐             │
              ▼                       ▼             │
       ┌──────────────┐       ┌──────────────┐      │
       │ Register File│       │ Immediate    │      │
       │ (FF-based)   │       │ Generator    │      │
       └──────┬───────┘       └──────┬───────┘      │
              │                      │              │
              └──────────┬───────────┘              │
                         ▼                           │
                  ┌─────────────┐    ┌─────────────┐ │
                  │ ALU Control │───▶│     ALU     │◀┘
                  └─────────────┘    └──────┬──────┘
                                             │
                                 ┌───────────┼───────────┐
                                 ▼           │           ▼
                          ┌─────────────┐    │    ┌─────────────┐
                          │ Data Memory │    │    │ JALR Target │
                          └──────┬──────┘    │    └─────────────┘
                                 │           │
                                 └─────┬─────┘
                                       ▼
                                  Write Back
                                       │
                                       ▼
                                  Next PC Mux
                          (pc+4 / branch / jal / jalr)
```

## Implemented Modules

| Module | Role |
|---|---|
| `PC` | Program counter register + `pc+4` adder |
| `imem` | Instruction memory (ROM, word-indexed via `addr[11:2]`) |
| `i_decode` | One-hot instruction-type decode from opcode |
| `c_decode` | Main control signal generation (RegWrite, MemRead/Write, ALUOp, operand/immediate/next-PC selects) |
| `control_unit` | Wraps `i_decode` + `c_decode` |
| `immediate_generator` | Produces I/S/B/U/J immediates; B/J types compute `PC + offset` directly |
| `registerfile` | 32×32-bit register file, FF-based, x0 hardwired to zero, synchronous write / combinational read |
| `alu` | Full arithmetic, logic, shift, and signed/unsigned comparison unit, plus branch-condition output |
| `alu_control` | Translates coarse `aluop` + `funct3`/`funct7[5]` into the ALU's 5-bit operation code |
| `Jalr_Target` | Dedicated `(rs1 + imm) & ~1` target computation for JALR |
| `dmem` | Data memory (RAM, word-indexed, synchronous write / combinational read) |
| `rv32i_core_top` | Top-level integration of all of the above, plus the OpA/OpB/ImmSel/Branch/PCSel/MemToReg muxes |

## Supported Instructions

**R-Type:** ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA
**I-Type:** ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
**Load/Store:** LW, SW
**Branch:** BEQ, BNE, BLT, BGE, BLTU, BGEU
**Jump:** JAL, JALR
**Upper Immediate:** LUI

All implemented and exercised by the verification programs below (RV32I base multiply/divide is out of scope — factorial computation is implemented via repeated addition, deliberately, to stay within the base ISA).

## Verification

The core has been verified in simulation (Verilator) against two independently hand-assembled RV32I programs, each checked two ways: an automated testbench assertion, and manual waveform inspection of register/memory contents against hand-computed expected values.

### 1. Fibonacci sequence (8 terms)
Exercises R-type arithmetic, I-type immediates, register read/write, and the branch/loop path (`beq`, `jal`).

```
x1, x2 → 0, 1, 1, 2, 3, 5, 8, 13, 21, 34
```
**Result: PASS** — final value `34` confirmed in both the register-file waveform and the testbench assertion.

### 2. Factorial series (1! through 5!)
Exercises nested looping, multiplication via repeated addition, and store (`sw`) to data memory — the running series is written out to `dmem` at each step rather than only the final result, making the full sequence inspectable.

```
dmem[0..16] → 1, 2, 6, 24, 120
```
**Result: PASS** — series and final value `120` confirmed in both the data-memory waveform and the testbench assertion. Verified to generalize to other N (e.g. `7!` = `5040`) by changing a single immediate value, with no other code changes required.

## Design Notes

A few deliberate, non-obvious decisions worth documenting for anyone reading the RTL:

- **`imem` and `dmem` use different address-bit conventions** — `imem` right-shifts by 2 (`addr[11:2]`) to convert a byte address into a word index; `dmem` uses the raw low bits unshifted. Both are internally consistent with their own Logisim source components; they were simply built as separate design decisions and were not reconciled to match each other.
- **ALU control is a two-stage decode**: `c_decode` produces a coarse 3-bit `aluop` category (R-type / I-type / branch / etc.), and a separate `alu_control` module resolves the exact 5-bit ALU operation code using `aluop` plus `funct3` and `funct7[5]`.
- **Branch resolution requires two signals ANDed together on the top sheet**: `c_decode`'s `branch` flag (category-only, decided at decode time) and the ALU's own comparison-result output (`Alu_branch`) — neither one alone is sufficient to know whether a branch is actually taken.
- **JALR's target is computed by a dedicated adder (`Jalr_Target`)**, not the main ALU, specifically to apply the spec-required LSB-clear (`& ~1`) that the ALU's plain pass-through path doesn't perform.

## Development Roadmap

```text
Phase 1 — RV32I Single-Cycle Processor            ✅ COMPLETE
└── Datapath, Control Unit, ALU, Register File,
    Memory, full top-sheet integration
        │
        ├── Verified: Fibonacci(8)                 ✅ PASS
        └── Verified: Factorial series (1!–5!)      ✅ PASS
                │
                ▼
Phase 2 — FPGA / Synthesis Testing                 ⏳ NEXT
                │
                ▼
Phase 3 — 5-Stage Pipelined RV32I                  ⏳ PLANNED
        │
        ├── IF / ID / EX / MEM / WB
        ├── Pipeline Registers
        ├── Hazard Detection
        ├── Data Forwarding
        └── Branch Handling
```

## Previous Implementation

This processor builds upon an earlier **RV32I single-cycle processor designed in Logisim**, which was used to design, wire, and empirically validate the full datapath and control architecture (including its own successful Fibonacci-sequence test) before translation into RTL.

## Tools

* **Verilog** (design)
* **SystemVerilog** (testbenches)
* **Verilator** (simulation)
* **EPWave / GTKWave** (waveform analysis)
* **RISC-V RV32I** (hand-assembled test programs)
* **FPGA toolchain / Vivado AMD** *(planned, Phase 2)*

## Learning Goals

Through this project:

* RISC-V processor architecture, from schematic to working RTL
* Verilog/SystemVerilog syntax and idioms (combinational vs. sequential design, blocking vs. non-blocking assignment, bit-slicing and concatenation as hardware primitives)
* CPU datapath and control design
* Instruction decoding and multi-stage control logic
* Hardware description, simulation, and waveform-based debugging
* Processor verification via hand-assembled test programs
* FPGA implementation *(next)*
* Pipeline architecture, data hazards, and forwarding *(planned)*

## Future Direction

With the single-cycle core complete and verified, the next step is FPGA synthesis and hardware testing, followed by extending the design into a 5-stage pipelined RV32I processor with hazard detection and forwarding.
