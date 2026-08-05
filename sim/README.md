# Simulation Flow

The active correctness flow uses the Verilog testbench in `../tb` and the
program/data files in `../tests`.

## Basic, Extend, and Other examples

Run from this directory with the `ai_dev_2026` environment:

```powershell
conda run -n ai_dev_2026 python test_basic_example_stage2.py
```

The runner reads `../tests/Basic_Inst_Example`, compiles the active RTL, and
stores all generated files under `.tmp/data/`. The source tree is not used as
the simulator working directory.

`sim_basic_example.py` can also run one `.data` program:

```powershell
conda run -n ai_dev_2026 python sim_basic_example.py ..\tests\Extend_Inst_Example\IF\IF_inst.data
```

`tests/Basic_Inst_Example` is the processor correctness gate. Stage2 contains
exactly the 20 RV32I cases supported by the reduced RTL; the deleted DIV/REM
programs are not enumerated by this runner.

## RTL compilation

```powershell
conda run -n ai_dev_2026 python compile_rtl.py ..
```

This low-level command writes `out.vvp` under `.tmp/rtl/`. The normal data
runner uses the separate `.tmp/data/` directory.

## Archived flows

The old ISA-bin and compliance wrappers are under `archive/legacy_isa/`.
They reference the pre-reduction RTL/TB path and are not part of the active
correctness flow.
