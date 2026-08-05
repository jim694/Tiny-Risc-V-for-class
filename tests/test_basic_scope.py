import unittest
from pathlib import Path

from tests.basic_scope import NOT_APPLICABLE_BASIC


SCOPE_MODULE = Path(__file__).with_name("basic_scope.py")


def load_scope_function():
    if not SCOPE_MODULE.exists():
        raise AssertionError("tests/basic_scope.py is missing")
    from tests.basic_scope import is_basic_applicable
    return is_basic_applicable


class ReducedBasicScopeTest(unittest.TestCase):
    def test_stage2_scope_contains_exactly_twenty_cases(self):
        from tests.basic_scope import BASIC_STAGE2_CASES

        self.assertEqual(len(BASIC_STAGE2_CASES), 20)
        self.assertTrue(BASIC_STAGE2_CASES.isdisjoint(NOT_APPLICABLE_BASIC))

    def test_removed_division_cases_are_not_applicable(self):
        is_basic_applicable = load_scope_function()

        for name in ("inst_div.data", "inst_divu.data", "inst_rem.data", "inst_remu.data"):
            with self.subTest(name=name):
                self.assertFalse(is_basic_applicable(name))

    def test_rv32i_basic_cases_remain_applicable(self):
        is_basic_applicable = load_scope_function()

        for name in ("inst_add.data", "inst_beq.data", "inst_lw.data", "inst_srai.data"):
            with self.subTest(name=name):
                self.assertTrue(is_basic_applicable(name))


if __name__ == "__main__":
    unittest.main()
