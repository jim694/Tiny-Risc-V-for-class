import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8", errors="ignore")


class I2CStandardStructureTest(unittest.TestCase):
    def test_i2c_exposes_ack_error_without_changing_existing_ctrl_bits(self):
        i2c_v = read("rtl/perips/i2c.v")
        compact = re.sub(r"\s+", "", i2c_v)

        self.assertIn("regctrl_ack_error;", compact)
        self.assertIn(
            "2'b01:data_o={20'h0,ctrl_ack_error,ctrl_two_byte,ctrl_busy,1'b0,ctrl_rw,ctrl_addr};",
            compact,
        )

    def test_i2c_samples_address_and_write_ack_on_scl_high(self):
        i2c_v = read("rtl/perips/i2c.v")
        compact = re.sub(r"\s+", "", i2c_v)

        self.assertRegex(
            compact,
            r"ST_ADDR_ACK:beginif\(SCL_HIG\)beginif\(sda_in\)beginctrl_ack_error<=1'b1;state<=ST_PRE_STOP;",
        )
        self.assertRegex(
            compact,
            r"ST_WACK:beginif\(SCL_HIG\)beginif\(sda_in\)beginctrl_ack_error<=1'b1;.*?state<=ST_PRE_STOP;",
        )

    def test_i2c_uses_standard_read_nack_before_stop(self):
        i2c_v = read("rtl/perips/i2c.v")
        compact = re.sub(r"\s+", "", i2c_v)

        self.assertIn("localparamST_PRE_STOP=4'd11;", compact)
        self.assertRegex(
            compact,
            r"ST_RNACK:beginif\(SCL_LOW\)begin.*?sda_link<=1'b1;.*?sda_out_r<=1'b1;.*?endelseif\(SCL_NEG\).*?state<=ST_PRE_STOP;",
        )
        self.assertRegex(
            compact,
            r"ST_PRE_STOP:beginif\(SCL_LOW\)begin.*?sda_link<=1'b1;.*?sda_out_r<=1'b0;.*?state<=ST_STOP;",
        )

    def test_i2c_holds_bus_idle_high_when_not_busy(self):
        i2c_v = read("rtl/perips/i2c.v")
        compact = re.sub(r"\s+", "", i2c_v)

        self.assertIn("wirei2c_active=(state!=ST_IDLE);", compact)
        self.assertRegex(compact, r"if\(rst==`RstEnable\|\|!i2c_active\)")
        self.assertIn("if(rst==`RstEnable||!i2c_active)scl_r<=1'b1;", compact)
        self.assertIn("ST_IDLE:beginsda_link<=1'b1;sda_out_r<=1'b1;", compact)

    def test_i2c_scl_register_has_single_runtime_driver(self):
        i2c_v = read("rtl/perips/i2c.v")

        self.assertEqual(len(re.findall(r"scl_r\s*<=", i2c_v)), 3)


if __name__ == "__main__":
    unittest.main()
