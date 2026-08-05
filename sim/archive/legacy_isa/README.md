# Legacy ISA and Compliance Wrappers

These scripts belong to the pre-resource-reduction flow. They target the old
ISA/compliance testbench and should not be used to judge the current RTL.

`test_basic_example_pre_stage2.py` is the former 24-file Basic runner. The
active 20-file runner is `sim/test_basic_example_stage2.py`.

Current correctness uses:

- `tests/Basic_Inst_Example`
- `tests/Extend_Inst_Example`
- `tests/Other_Example`
- `tb/tinyriscv_soc_tb.v`
