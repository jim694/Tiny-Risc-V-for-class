# Resource Reduction and Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the non-required processor resources and introduce a four-core, mutually exclusive shared-resource integration while keeping the current single-core Basic instruction verification flow runnable.

**Architecture:** Keep each processor as a core implementation with a stable external register-file and instruction/data-memory contract. A cluster-level wrapper decodes binary `chip_sel[2:0]` (`0..3` select cores 0..3; `4..7` select none), gates reset/enable for unselected cores, and multiplexes the selected core into one physical `regs`, one RIB/memory path, one PWM, one UART, and one UART-debug block. Individual core modules do not depend on `chip_sel` encoding.

**Tech Stack:** Verilog RTL, existing Python/iverilog simulation scripts, Vivado 2025.2 Tcl batch flow, existing `Basic_Inst_Example`, `Extend_Inst_Example`, and `Other_Example` tests.

---

### Task 1: Freeze the interface and verification baseline

**Files:**
- Create: `doc/shared_resource_interface.md`
- Modify: `sim/README.md` only if command examples need correction
- Test: `sim/test_basic_example_stage2.py` against the fixed 20-case Basic scope

- [ ] **Step 1: Record the resource whitelist and blacklist.**

  The whitelist is RV32I, the project custom instructions, register file, ROM/RAM bridge, PWM, UART, and UART-debug download path. The deletion list is MUL/DIV, CSR/CLINT/exception handling, timer, SPI, GPIO, and JTAG. I2C is retained as one existing single-instance peripheral; it is not made a per-core resource and is not part of this deletion change.

- [ ] **Step 2: Write the stable core contract.**

  `doc/shared_resource_interface.md` must define the following signals without exposing `chip_sel`:

  ```verilog
  // register file: two combinational reads, one clocked write
  rf_raddr1_o, rf_rdata1_i,
  rf_raddr2_o, rf_rdata2_i,
  rf_we_o, rf_waddr_o, rf_wdata_o

  // instruction path
  ibus_addr_o, ibus_data_i

  // data path
  dbus_req_o, dbus_we_o, dbus_addr_o, dbus_wdata_o, dbus_rdata_i,
  dbus_hold_i
  ```

  The individual core receives only `clk` and its local reset. A slot wrapper, not the personal core, converts `selected_i` into that reset and masks write/request outputs.

- [ ] **Step 3: Run the unchanged Basic regression and store the command/output in the work log.**

  Run from `sim/`:

  ```powershell
  conda run -n ai_dev_2026 python sim/test_basic_example_stage2.py
  ```

  Repeat for every `tests/Basic_Inst_Example/*.data.bin`; expected baseline is 24 passes before RTL edits. After resource deletion, `inst_div`, `inst_divu`, `inst_rem`, and `inst_remu` are explicitly N/A, while the remaining 20 Basic cases remain mandatory.

- [ ] **Step 4: Commit the interface document and baseline record.**

  ```powershell
  git add doc/shared_resource_interface.md sim/README.md
  git commit -m "docs: define shared core resource interface"
  ```

### Task 2: Remove non-required resources from the core

**Files:**
- Modify: `rtl/core/tinyriscv.v`
- Modify: `rtl/core/ex.v`
- Modify: `rtl/core/id.v`
- Modify: `rtl/core/id_ex.v`
- Modify: `rtl/core/defines.v`
- Modify: `rtl/core/ctrl.v`
- Modify: `rtl/core/regs.v`
- Delete from filelists (do not delete history): `rtl/core/div.v`, `rtl/core/csr_reg.v`, `rtl/core/clint.v`, `rtl/perips/timer.v`, `rtl/perips/spi.v`, `rtl/perips/gpio.v`, and all JTAG source files under `rtl/debug/`
- Test: current Basic data files plus compile-only RTL check

- [ ] **Step 1: Add a failing compile gate for the reduced source list.**

  Update `sim/compile_rtl.py` or its source discovery so the reduced list excludes the deleted modules. Compile the current core and expect failure until all references to `div`, `csr`, `clint`, and JTAG are removed.

- [ ] **Step 2: Remove M/D and CSR/exception control paths.**

  Remove M/D and CSR decode constants and decode branches from `defines.v` and `id.v`. Remove the corresponding ports, wires, state, and writeback selection from `ex.v`, `id_ex.v`, and `tinyriscv.v`. Replace the interrupt input with the existing no-interrupt constant at the top-level contract, then remove CLINT hold/jump inputs from `ctrl.v`.

- [ ] **Step 3: Remove JTAG-only ports and logic.**

  Delete JTAG register access, halt, and PC-reset ports from the core. Remove JTAG instantiation and pins from the SoC top. Keep UART-debug as the only download/debug path.

- [ ] **Step 4: Externalize the register file.**

  Remove `regs u_regs` from `tinyriscv.v`. Connect the pipeline's register addresses and writeback signals to the stable `rf_*` ports. Simplify `regs.v` to the two-read/one-write interface; retain `x0` hardwiring and write-after-read bypass behavior. Do not add four core ports to `regs.v`.

- [ ] **Step 5: Compile and run the Basic suite.**

  Run the reduced Basic runner. Expected result: no references to deleted modules, 20 applicable Basic cases retain their previous architectural result, and the four removed DIV/REM cases are reported as N/A.

- [ ] **Step 6: Commit the resource deletion as an isolated change.**

  ```powershell
  git add rtl sim
  git commit -m "refactor: remove non-required processor resources"
  ```

### Task 3: Add a single-core compatibility wrapper

**Files:**
- Create: `rtl/core/tinyriscv_single.v`
- Modify: `rtl/soc/tinyriscv_soc_top.v`
- Modify: `tb/tinyriscv_soc_tb.v`
- Test: all Basic cases, then Extend and Other cases

- [ ] **Step 1: Write the wrapper with one core and one `regs`.**

  `tinyriscv_single` instantiates the reduced core and one `regs`, ties `selected_i` to `1'b1`, and connects its memory ports to the existing SoC signals. It must expose stable internal observability signals for `x3`, `x26`, and `x27`; tests must not depend on `u_tinyriscv.u_regs` because `regs` is now outside the core.

- [ ] **Step 2: Move `over`/`succ` observation to the wrapper.**

  Drive `over` and `succ` from the shared register instance in `tinyriscv_single`, preserving the existing active-low reset behavior and the x26/x27 convention.

- [ ] **Step 3: Update the valid TB hierarchy once.**

  Change `tb/tinyriscv_soc_tb.v` to use the wrapper's explicit observation signals. Do not update `tests/example` or `tests/isa`; those flows are intentionally out of scope after the RAM/ROM change.

- [ ] **Step 4: Run the three valid test groups.**

  Run the 20 applicable Basic cases first, then the existing Extend and Other cases through the current simulation/board scripts. Any applicable Basic failure blocks the next task; four DIV/REM cases must report N/A.

- [ ] **Step 5: Commit the compatibility layer.**

  ```powershell
  git add rtl/core/tinyriscv_single.v rtl/soc/tinyriscv_soc_top.v tb/tinyriscv_soc_tb.v
  git commit -m "refactor: preserve single-core verification wrapper"
  ```

### Task 4: Implement the four-core selection and shared register file

**Files:**
- Create: `rtl/cluster/core_select.v`
- Create: `rtl/cluster/tinyriscv_cluster.v`
- Create: `tb/core_select_tb.v`
- Test: `tb/core_select_tb.v` with iverilog or the project simulator

- [ ] **Step 1: Write selection tests before RTL.**

  Verify binary mapping `chip_sel=3'b000/001/010/011` to core 0/1/2/3, and verify `100..111` produces `selected[3:0]=4'b0000`. Verify that an unselected core has reset asserted and its register write/request outputs are masked.

- [ ] **Step 2: Implement `core_select.v`.**

  Decode `chip_sel[2:0]` to one-hot `selected[3:0]`. The module is the only place that knows binary encoding. It also selects one core's register read addresses, writeback request, instruction address, and data request; responses are returned only to the selected core. No clocked arbitration state is added.

- [ ] **Step 3: Implement the cluster with four core slots and one `regs`.**

  Instantiate four identical core-slot interfaces. Feed selected register read addresses into the single `regs`; route its two read data values to the selected core; gate the single write port with `selected[core_id]`. Feed the selected core's instruction/data requests to the existing shared RIB. Use `selected_i` to hold non-selected cores in reset.

- [ ] **Step 4: Add the focused selection test.**

  Drive distinct read addresses and writeback values on all four mock slots. For each legal `chip_sel`, assert that only the selected slot receives shared register data and only its write reaches `regs`. For illegal values, assert no write and zeroed response data.

- [ ] **Step 5: Commit the cluster layer.**

  ```powershell
  git add rtl/cluster tb/core_select_tb.v
  git commit -m "feat: add mutually exclusive four-core shared register cluster"
  ```

### Task 5: Share memory and peripherals at the SoC boundary

**Files:**
- Modify: `rtl/soc/tinyriscv_soc_top.v`
- Modify: `rtl/soc/tinyriscv_fpga_top.v` only for the new `chip_sel[2:0]` pins/default tie-off
- Modify: `rtl/bridge/rib_mem_bridge.v` only if the selected-core bus timing requires an explicit enable
- Modify: `rtl/perips/pwm.v`, `rtl/perips/uart.v`, `rtl/debug/uart_debug.v` only to preserve their existing single-instance ports
- Test: `tb/tinyriscv_soc_tb.v`, Basic/Extend/Other simulations

- [ ] **Step 1: Replace the single core instance with the cluster.**

  Connect one selected instruction/data bus to the existing RIB and bridge. Keep one ROM/RAM path and one `mem_bridge_stall`; return the hold signal only to the selected core.

- [ ] **Step 2: Keep one instance of shared peripherals.**

  Leave PWM, UART, UART-debug, and the retained I2C block outside the core cluster. Their memory slave ports are driven by the shared RIB, so no individual core gets a private peripheral copy.

- [ ] **Step 3: Add binary `chip_sel` to the integration top only.**

  Add `input wire [2:0] chip_sel` to the final FPGA/SoC integration top and pass it to `core_select.v`. For single-core simulation and current FPGA smoke tests, tie it to `3'b000`.

- [ ] **Step 4: Verify no per-core resource instances remain.**

  Search the RTL source list and elaborated hierarchy for exactly one `regs`, one `rib_mem_bridge`, one `pwm`, one `uart`, and one `uart_debug`. Four core slots may exist, but none may instantiate those shared resources internally.

- [ ] **Step 5: Run valid functional regressions.**

  Run all 20 applicable Basic cases, then Extend and Other. Include a directed PWM case and UART download case with `chip_sel=0`. Expected result: the previous single-core behavior is unchanged and four DIV/REM cases report N/A.

- [ ] **Step 6: Commit the SoC integration.**

  ```powershell
  git add rtl/soc rtl/bridge rtl/perips rtl/debug fpga tb
  git commit -m "feat: integrate shared memory and peripheral resources"
  ```

### Task 6: Update Vivado filelist and run FPGA verification

**Files:**
- Modify: `D:/project/tiny-risc-v/tiny_risc_v_verilog/tiny_risc_v_vivado/tiny_risc_v_vivado.xpr`
- Modify: `rtl/soc/tinyriscv_fpga_top.v` and current XDC as required by the final top ports
- Test artifacts: Vivado `synth_1`, `impl_1`, XSim compile/elaborate, bitstream

- [ ] **Step 1: Remove deleted RTL files from the Vivado fileset.**

  Update the project source list so the files excluded in Task 2 are not compiled. Ensure `tinyriscv_fpga_top` remains the synthesis top and `tinyriscv_soc_tb` remains the simulation top.

- [ ] **Step 2: Add the cluster sources in dependency order.**

  Add `rtl/cluster/core_select.v`, `rtl/cluster/tinyriscv_cluster.v`, and the reduced core sources. Update compile order and confirm there is one active definition for every module name.

- [ ] **Step 3: Run synthesis and implementation.**

  Use Vivado batch Tcl to reset `synth_1`/`impl_1`, launch synthesis, launch implementation, and write the bitstream. Expected: zero synthesis/implementation errors, zero unrouted nets, and timing reports generated for the 50 MHz clock.

- [ ] **Step 4: Run XSim compile and elaborate.**

  Run compile first and elaborate second; do not invoke elaborate against a deleted compile library. Expected: `Built simulation snapshot tinyriscv_soc_tb_behav` with no missing design units.

- [ ] **Step 5: Record resource and timing deltas.**

  Compare LUT/FF/DSP/BRAM utilization and WNS/WHS against the pre-change baseline. Check that resource deletion is reflected in synthesis and that shared peripherals are not replicated four times.

- [ ] **Step 6: Commit only repository-owned Vivado/source changes.**

  Do not commit generated `.runs`, `.cache`, `.Xil`, or stale absolute-path simulation artifacts. Commit the source/project changes and the final interface document.

### Task 6.5: Run a non-blocking VIO core-selection smoke flow

**Files:**
- Create: `fpga/vio_debug_wrapper.v`
- Create: `fpga/vivado_vio_smoke.tcl`
- Modify: `rtl/soc/tinyriscv_fpga_top.v` only to add a `DEBUG_VIO` generate branch
- Modify: `D:/project/tiny-risc-v/tiny_risc_v_verilog/tiny_risc_v_vivado/tiny_risc_v_vivado.xpr` only if the VIO IP is retained
- Test artifacts: generated `vio_0.xci`, VIO-enabled synthesis/implementation reports, optional Hardware Manager session

- [ ] **Step 1: Generate the smallest useful VIO IP.**

  In a Vivado Tcl smoke script, create `vio_0` with one 3-bit output probe and three input probes (`selected[3:0]`, `x26`, and `x27`). Generate the target and simulation products, then add the `.xci` to the project. Do not add VIO to the Verilog simulator fileset.

- [ ] **Step 2: Keep the VIO connection outside the processor core.**

  `vio_debug_wrapper.v` connects `vio_0.probe_out0[2:0]` to the integration-layer `chip_sel` source and exposes the selected one-hot status plus x26/x27 to VIO input probes. The wrapper must not modify the core contract or instantiate any processor resource.

- [ ] **Step 3: Make VIO opt-in.**

  Add a synthesis parameter `DEBUG_VIO` to the FPGA integration top. When `DEBUG_VIO=0`, `chip_sel` comes from the normal top-level pin/default tie-off and no VIO instance is elaborated. When `DEBUG_VIO=1`, VIO drives `chip_sel`; the two sources must be mutually exclusive in a generate block.

- [ ] **Step 4: Run the VIO-enabled Vivado smoke build.**

  Run IP generation, synthesis, implementation, and bitstream generation with `DEBUG_VIO=1`. Expected: the VIO IP is present in the synthesized hierarchy, the debug hub is created, and there are no multiple-driver errors on `chip_sel`. Record the added LUT/FF/clocking overhead separately from processor utilization.

- [ ] **Step 5: Exercise selection through Hardware Manager when a board is connected.**

  After programming the VIO-enabled bitstream, use Hardware Manager to set `probe_out0` to `000`, `001`, `010`, and `011`, observing `selected[3:0]` and x26/x27 after reset between changes. Values `100` through `111` must select no core. If no board is connected, the bitstream and hierarchy checks are still a complete smoke-flow result; this step must not block RTL verification.

- [ ] **Step 6: Rebuild the release configuration without VIO.**

  Set `DEBUG_VIO=0`, rerun XSim compile/elaborate and the normal synthesis/implementation flow, and use this configuration for the processor correctness and resource reports. VIO is an optional debug aid, not a release or Basic-test requirement.

- [ ] **Step 7: Commit VIO only if the smoke build is clean.**

  Commit `vio_debug_wrapper.v`, the reproducible Tcl script, the `.xci`, and project-file changes only after the opt-in build passes. Do not commit generated debug output directories.

### Task 7: Integration handoff checks

**Files:**
- Modify: `doc/shared_resource_interface.md` with final port table and test commands
- Test: all valid test groups and selection-directed test

- [ ] **Step 1: Verify the per-member merge contract.**

  A member contribution may replace only its core implementation or custom instruction block. It must preserve the slot wrapper port names and must not add private `regs`, RIB, PWM, UART, UART-debug, or `chip_sel` decoding.

- [ ] **Step 2: Verify selection behavior at reset boundaries.**

  Change `chip_sel` only while global reset is asserted in the integration test. Confirm the newly selected core starts from reset while the shared register state follows the agreed single physical `regs` instance.

- [ ] **Step 3: Run the release gate.**

  The gate is: all 20 applicable Basic cases pass and four DIV/REM cases report N/A; Extend and Other cases pass where applicable; core-select directed test passes; Vivado synthesis/implementation/XSim compile/elaborate pass with `DEBUG_VIO=0`; no deleted resource appears in the source list or hierarchy. VIO smoke-build results are reported separately and are not a processor-correctness gate.

- [ ] **Step 4: Commit the handoff documentation.**

  ```powershell
  git add doc/shared_resource_interface.md
  git commit -m "docs: document four-core integration handoff"
  ```
