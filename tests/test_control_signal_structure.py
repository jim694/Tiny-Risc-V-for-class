import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8", errors="ignore")


class ControlSignalStructureTest(unittest.TestCase):
    def test_ex_stage_does_not_receive_full_instruction_word(self):
        ex_v = read("rtl/core/ex.v")
        self.assertNotIn("input wire[`InstBus] inst_i", ex_v)
        self.assertNotIn("assign opcode = inst_i[6:0]", ex_v)
        self.assertRegex(ex_v, r"input wire\[`ExCtrlBus\]\s+ex_ctrl_i")
        self.assertNotIn("funct3_i", ex_v)
        self.assertNotIn("bit30_i", ex_v)
        self.assertNotIn("shamt_i", ex_v)
        self.assertNotIn("csr_uimm_i", ex_v)

    def test_id_ex_no_longer_registers_full_instruction_word(self):
        id_ex_v = read("rtl/core/id_ex.v")
        self.assertNotIn("gen_pipe_dff #(32) inst_ff", id_ex_v)
        self.assertNotIn("output wire[`InstBus] inst_o", id_ex_v)
        self.assertRegex(id_ex_v, r"gen_pipe_dff #\(`ExCtrlWidth\)\s+ex_ctrl_ff")
        self.assertNotIn("funct3_ff", id_ex_v)
        self.assertNotIn("bit30_ff", id_ex_v)
        self.assertNotIn("shamt_ff", id_ex_v)
        self.assertNotIn("csr_uimm_ff", id_ex_v)
        self.assertNotIn("reg1_rdata_ff", id_ex_v)
        self.assertNotIn("op1_jump_ff", id_ex_v)
        self.assertNotIn("op2_jump_ff", id_ex_v)
        self.assertIn("jump_addr_ff", id_ex_v)

    def test_instruction_control_is_decoded_before_execute_stage(self):
        defines_v = read("rtl/core/defines.v")
        id_v = read("rtl/core/id.v")
        tinyriscv_v = read("rtl/core/tinyriscv.v")
        self.assertIn("`define ExCtrlBus", defines_v)
        self.assertIn("output reg[`ExCtrlBus] ex_ctrl_o", id_v)
        self.assertIn(".ex_ctrl_i(id_ex_ctrl_o)", tinyriscv_v)
        self.assertNotIn(".inst_i(ie_inst_o)", tinyriscv_v)

    def test_custom_instruction_transactions_are_outside_execute_stage(self):
        custom_unit_v = read("rtl/core/custom_unit.v")
        ex_v = read("rtl/core/ex.v")
        tinyriscv_v = read("rtl/core/tinyriscv.v")

        self.assertIn("module custom_unit", custom_unit_v)
        self.assertIn("custom_valid_i", custom_unit_v)
        self.assertIn("custom_busy_o", custom_unit_v)
        self.assertIn("custom_done_o", custom_unit_v)

        for signal in (
            "sid_active",
            "sid_done",
            "sid_wait_cnt",
            "rt_active",
            "rt_done",
            "rt_state",
            "if_active",
            "if_done",
            "if_wait_cnt",
        ):
            self.assertNotIn(signal, ex_v)

        self.assertIn("custom_valid_o", ex_v)
        self.assertIn("custom_busy_i", ex_v)
        self.assertIn("custom_done_i", ex_v)
        self.assertIn("custom_unit u_custom_unit", tinyriscv_v)
        self.assertIn(".custom_valid_i(ex_custom_valid_o)", tinyriscv_v)

    def test_uart_download_mode_keeps_cpu_in_reset_without_resetting_uart_debug(self):
        soc_top_v = read("rtl/soc/tinyriscv_soc_top.v")
        compact = re.sub(r"\s+", "", soc_top_v)
        cpu_inst = re.search(r"tinyriscv_clusteru_tinyriscv\((.*?)\);", compact)
        uart_debug_inst = re.search(r"uart_debugu_uart_debug\((.*?)\);", compact)

        self.assertIn("wirecpu_rst=rst&~uart_debug_pin;", compact)
        self.assertIsNotNone(cpu_inst)
        self.assertIn(".rst(cpu_rst)", cpu_inst.group(1))
        self.assertIsNotNone(uart_debug_inst)
        self.assertIn(".rst(rst)", uart_debug_inst.group(1))

    def test_uart_download_mode_clears_board_test_indicators(self):
        soc_top_v = read("rtl/soc/tinyriscv_soc_top.v")
        compact = re.sub(r"\s+", "", soc_top_v)

        self.assertIn("if(cpu_rst==`RstEnable)beginover<=1'b1;succ<=1'b1;", compact)

    def test_soc_top_exposes_external_memory_bus_without_fpga_memory_model(self):
        soc_top_v = read("rtl/soc/tinyriscv_soc_top.v")
        compact = re.sub(r"\s+", "", soc_top_v)

        self.assertIn("outputwire[7:0]ext_mem_out", compact)
        self.assertIn("inputwire[7:0]ext_mem_in", compact)
        self.assertIn(".ext_out_o(ext_mem_out)", compact)
        self.assertIn(".ext_in_i(ext_mem_in)", compact)
        self.assertNotIn("fpga_mem_bridgeu_fpga_mem_bridge", compact)

    def test_fpga_top_wraps_soc_with_fpga_memory_bridge(self):
        fpga_top_v = read("rtl/soc/tinyriscv_fpga_top.v")
        compact = re.sub(r"\s+", "", fpga_top_v)

        self.assertIn("moduletinyriscv_fpga_top", compact)
        self.assertIn("wire[7:0]ext_mem_out_w;", compact)
        self.assertIn("wire[7:0]ext_mem_in_w;", compact)
        self.assertIn("tinyriscv_soc_topu_soc", compact)
        self.assertIn("fpga_mem_bridgeu_fpga_mem_bridge", compact)
        self.assertIn(".ext_mem_out(ext_mem_out_w)", compact)
        self.assertIn(".ext_mem_in(ext_mem_in_w)", compact)
        self.assertIn(".ext_in_i(ext_mem_out_w)", compact)
        self.assertIn(".ext_out_o(ext_mem_in_w)", compact)


if __name__ == "__main__":
    unittest.main()
