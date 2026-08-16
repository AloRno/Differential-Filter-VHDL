# 🔌 Differential Filter - VHDL Project

Memory-mapped hardware module in VHDL that applies a differential filter (order 3 or order 5) to a sequence of signed 8-bit samples read from RAM, built from a finite-state machine with datapath (FSMD).

## 📄 Overview
This project implements a synchronous HW component that interfaces with an external memory to read a sequence of `K` signed 8-bit values, apply a differential filter, and write the filtered (and saturated) results back to memory.

Developed as the final project ("Prova Finale") for the *Reti Logiche* (Logic Networks / Digital Systems) course at Politecnico di Milano, in pairs with [Mirco Poma](https://github.com/MircoPoma), following a specification provided by the course.

**Documentation:**
* [Project Report](docs/Report.pdf) — architecture, FSM design, design choices, and test results (Italian)
* [Full Specification](docs/Specification.pdf) — official assignment provided by the course (Italian)

## 🧩 The Challenge
* **Memory-mapped interface:** the component has no data ports besides a start address (`ADD`); every input (sequence length, filter type, coefficients, samples) must be fetched byte-by-byte from RAM via `o_mem_addr`/`i_mem_data`, and results written back via `o_mem_data`/`o_mem_we`.
* **Two selectable filters:** a 1-bit flag read from memory selects between an order-3 filter (5 coefficients, normalization `n=12`) and an order-5 filter (7 coefficients, `n=60`), each with its own coefficient block layout in memory.
* **Fixed-point division without a divider:** normalization (`1/12`, `1/60`) must be approximated using only right shifts and additions, with an explicit rounding correction for negative operands (specified bit-exactly by the assignment).
* **Saturation arithmetic:** filtered results outside `[-128, 127]` must be clamped to the range instead of overflowing/wrapping.
* **Boundary handling:** samples before the start and after the end of the sequence are treated as `0` (zero-padding), so edge elements are filtered correctly without extra branching in the datapath.

## ⚙️ Architecture
The module is implemented as an 11-state Moore-style FSM (`S0`…`S9`, `DONE`) driving a small datapath, described over three cooperating processes:

* **`funzione_stato_prossimo`** — combinational next-state logic and memory control signals (`o_mem_addr`, `o_mem_en`, `o_mem_we`, `o_done`).
* **`gestione_stati`** — synchronous datapath registers: sequence length `K`, filter-type flag, coefficient array, sliding input window, and read/write address counters.
* **`filtro`** — synchronous combinational-style process that computes the weighted sum of coefficients × samples, applies the shift-based normalization with sign-aware rounding, and saturates the result to 8 bits.

Control flow: read header (`K1`, `K2`, filter-type `S`) → read the filter's coefficient block → for each output sample, load the 3 or 5 needed input samples (zero-padded at the boundaries) → compute and write the normalized, saturated result → repeat until `K` outputs have been produced → assert `o_done`.

## 🧪 Verification
Validated against the official course-provided testbench ([`testbench/tb2425.vhd`](testbench/tb2425.vhd)), which models the memory, drives `i_clk`/`i_rst`/`i_start`/`i_add`, and checks both the order-3 and order-5 filter paths against precomputed reference outputs. See [`docs/Report.pdf`](docs/Report.pdf) for the full simulation and post-synthesis results.

## 🚀 Tech Stack
* **Language:** VHDL (synthesizable, IEEE `std_logic_1164` / `numeric_std`)
* **Toolchain:** Xilinx Vivado (WebPACK), target-agnostic FPGA (e.g. Artix-7)
* **Design style:** Finite State Machine with Datapath (FSMD), fully synchronous except for the asynchronous reset

## 🛠️ Build & Run
### Prerequisites
* Xilinx Vivado 

### Simulation
1. Add [`project_reti_logiche.vhd`](project_reti_logiche.vhd) and [`testbench/tb2425.vhd`](testbench/tb2425.vhd) to a new project/simulation.
2. Set `tb2425` as the simulation top module.
3. Run the simulation and inspect `tb_done` / the scenario pass-fail report in the console.
