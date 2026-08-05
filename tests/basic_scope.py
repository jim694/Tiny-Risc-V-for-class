from pathlib import Path


NOT_APPLICABLE_BASIC = frozenset(
    {
        "inst_div.data",
        "inst_divu.data",
        "inst_rem.data",
        "inst_remu.data",
    }
)

BASIC_STAGE2_CASES = frozenset(
    {
        "inst_add.data",
        "inst_andi.data",
        "inst_auipc.data",
        "inst_beq.data",
        "inst_bge.data",
        "inst_bgeu.data",
        "inst_blt.data",
        "inst_bltu.data",
        "inst_bne.data",
        "inst_jal.data",
        "inst_jalr.data",
        "inst_lui.data",
        "inst_ori.data",
        "inst_simple.data",
        "inst_slli.data",
        "inst_slti.data",
        "inst_sltiu.data",
        "inst_srai.data",
        "inst_srli.data",
        "inst_xori.data",
    }
)


def normalized_basic_name(path_or_name):
    name = Path(path_or_name).name
    if name.endswith(".bin"):
        name = name[:-4]
    return name


def is_basic_applicable(path_or_name):
    return normalized_basic_name(path_or_name) not in NOT_APPLICABLE_BASIC
