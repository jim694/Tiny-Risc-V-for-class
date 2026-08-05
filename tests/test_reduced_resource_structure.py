from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8", errors="ignore")


class ReducedResourceStructureTest(unittest.TestCase):
    def test_core_has_no_csr_or_clint_path(self):
        files = [
            "rtl/core/tinyriscv.v",
            "rtl/core/id.v",
            "rtl/core/id_ex.v",
            "rtl/core/ex.v",
            "rtl/core/ctrl.v",
            "rtl/core/if_id.v",
        ]
        text = "\n".join(read(path) for path in files)
        self.assertNotRegex(text, re.compile(r"\bcsr_", re.IGNORECASE))
        self.assertNotRegex(text, re.compile(r"\bclint", re.IGNORECASE))
        self.assertNotRegex(text, re.compile(r"\bint_(?:i|flag|assert|addr)", re.IGNORECASE))

    def test_active_core_path_has_no_jtag_interface(self):
        files = [
            "rtl/core/tinyriscv.v",
            "rtl/core/pc_reg.v",
            "rtl/core/ctrl.v",
            "rtl/core/regs.v",
            "rtl/soc/tinyriscv_soc_top.v",
        ]
        text = "\n".join(read(path) for path in files)
        self.assertNotRegex(text, re.compile(r"\bjtag", re.IGNORECASE))

    def test_soc_does_not_instantiate_removed_peripherals(self):
        text = read("rtl/soc/tinyriscv_soc_top.v")
        for module_name in ("timer", "spi", "gpio", "jtag_top"):
            with self.subTest(module=module_name):
                self.assertNotRegex(
                    text,
                    re.compile(rf"\b{module_name}\s+(?:#\s*\([^;]*\)\s*)?\w+\s*\(", re.DOTALL),
                )

    def test_reduced_filelist_and_decode_have_no_m_or_d(self):
        compile_script = read("sim/compile_rtl.py")
        defines = read("rtl/core/defines.v")
        for source_name in ("clint.v", "csr_reg.v", "div.v", "jtag_top.v"):
            self.assertNotIn("/" + source_name, compile_script)
        self.assertNotRegex(defines, re.compile(r"EX_CTRL_(?:MUL|DIV)|INST_(?:MUL|DIV|REM)"))

    def test_shared_register_file_is_owned_by_cluster(self):
        core = read("rtl/core/tinyriscv.v")
        cluster = read("rtl/cluster/tinyriscv_cluster.v")
        soc = read("rtl/soc/tinyriscv_soc_top.v")
        self.assertNotRegex(core, re.compile(r"\bregs\s+u_", re.IGNORECASE))
        self.assertEqual(len(re.findall(r"\bregs\s+u_regs\s*\(", cluster)), 1)
        self.assertRegex(soc, re.compile(r"\btinyriscv_cluster\s+u_tinyriscv\s*\("))

    def test_cluster_only_populates_local_core_slot(self):
        cluster = read("rtl/cluster/tinyriscv_cluster.v")
        self.assertIn("input wire [2:0] chip_sel_i", cluster)
        self.assertEqual(len(re.findall(r"\btinyriscv\s+u_core\s*\(", cluster)), 1)
        self.assertNotRegex(cluster, re.compile(r"\bgenerate\b|\bcore_select\s+u_"))
        self.assertRegex(cluster, re.compile(r"chip_sel_i\s*==\s*3'b000"))
        self.assertRegex(cluster, re.compile(r"selected_o\s*=\s*core_selected\s*\?\s*4'b0001\s*:\s*4'b0000"))

    def test_main_filelist_excludes_standalone_and_jtag_helpers(self):
        compile_script = read("sim/compile_rtl.py")
        for source_name in ("tinyriscv_single.v", "core_select.v", "full_handshake_rx.v", "full_handshake_tx.v"):
            self.assertNotIn(source_name, compile_script)


if __name__ == "__main__":
    unittest.main()
