import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8", errors="ignore")


class TestRunnerDescriptionsTest(unittest.TestCase):
    def test_board_flow_uses_key1_without_reset_prompt(self):
        runner_py = read("tests/test_runner.py")

        self.assertNotIn("RESET", runner_py)
        self.assertNotIn("Reset", runner_py)
        self.assertIn("释放 UART", runner_py)
        self.assertIn("按下并保持 Key1", runner_py)


if __name__ == "__main__":
    unittest.main()
