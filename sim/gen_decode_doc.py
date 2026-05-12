import os, sys

def decode(w):
    op=w&0x7f; rd=(w>>7)&0x1f; f3=(w>>12)&7
    rs1=(w>>15)&0x1f; rs2=(w>>20)&0x1f; f7=(w>>25)&0x7f
    imm_i=(w>>20); imm_i=imm_i if imm_i<2048 else imm_i-4096
    imm_u=(w>>12)
    imm_s=((w>>20)&0xfe0)|((w>>7)&0x1f); imm_s=imm_s if imm_s<2048 else imm_s-4096
    imm_b=((w>>31)<<12)|((w&0x80)<<4)|((w>>20)&0x7e0)|((w>>7)&0x1e)
    imm_b=imm_b if imm_b<4096 else imm_b-8192
    imm_j=((w>>31)<<20)|((w>>12)&0xff)<<12|((w>>20)&1)<<11|((w>>21)&0x3ff)<<1
    imm_j=imm_j if imm_j<1048576 else imm_j-2097152
    xn=['x0','ra','sp','gp','tp','t0','t1','t2','s0','s1','a0','a1','a2','a3','a4','a5',
        'a6','a7','s2','s3','s4','s5','s6','s7','s8','s9','s10','s11','t3','t4','t5','t6']
    def r(n): return xn[n] if n<32 else f'x{n}'
    shamt=rs2
    if op==0x37: return f'lui     {r(rd)}, 0x{imm_u:05x}'
    if op==0x17: return f'auipc   {r(rd)}, 0x{imm_u:05x}'
    if op==0x6f:
        if rd==0 and imm_j==0: return 'j       0              # halt loop'
        return f'jal     {r(rd)}, {imm_j:+d}'
    if op==0x67: return f'jalr    {r(rd)}, {r(rs1)}, {imm_i}'
    if op==0x63:
        nm={0:'beq',1:'bne',4:'blt',5:'bge',6:'bltu',7:'bgeu'}.get(f3,'br?')
        return f'{nm:<7} {r(rs1)}, {r(rs2)}, {imm_b:+d}'
    if op==0x03:
        nm={0:'lb',1:'lh',2:'lw',4:'lbu',5:'lhu'}.get(f3,'ld?')
        return f'{nm:<7} {r(rd)}, {imm_i}({r(rs1)})'
    if op==0x23:
        nm={0:'sb',1:'sh',2:'sw'}.get(f3,'st?')
        return f'{nm:<7} {r(rs2)}, {imm_s}({r(rs1)})'
    if op==0x13:
        nm={0:'addi',1:'slli',2:'slti',3:'sltiu',4:'xori',
            5:'srli' if f7==0 else 'srai',6:'ori',7:'andi'}.get(f3,'imm?')
        if f3 in(1,5): return f'{nm:<7} {r(rd)}, {r(rs1)}, {shamt}'
        return f'{nm:<7} {r(rd)}, {r(rs1)}, {imm_i}'
    if op==0x33:
        nm={0:'add' if f7==0 else 'sub',1:'sll',2:'slt',3:'sltu',
            4:'xor',5:'srl' if f7==0 else 'sra',6:'or',7:'and'}.get(f3,'r?')
        return f'{nm:<7} {r(rd)}, {r(rs1)}, {r(rs2)}'
    if op==0x73:
        if f3==0: return 'ecall' if rs2==0 else 'ebreak'
        nm={1:'csrrw',2:'csrrs',3:'csrrc'}.get(f3,'csr?')
        return f'{nm:<7} {r(rd)}, 0x{(w>>20)&0xfff:03x}, {r(rs1)}'
    return 'nop' if w==0 else f'.word   0x{w:08x}'

def op_key(w):
    op=w&0x7f; f3=(w>>12)&7; f7=(w>>25)&0x7f
    if op==0x37: return 'LUI'
    if op==0x17: return 'AUIPC'
    if op==0x6f: return 'JAL'
    if op==0x67: return 'JALR'
    if op==0x63: return {0:'BEQ',1:'BNE',4:'BLT',5:'BGE',6:'BLTU',7:'BGEU'}.get(f3,'BR?')
    if op==0x03: return {2:'LW'}.get(f3,'LOAD')
    if op==0x23: return 'STORE'
    if op==0x13: return {0:'ADDI',1:'SLLI',2:'SLTI',3:'SLTIU',4:'XORI',
                          5:'SRLI' if f7==0 else 'SRAI',6:'ORI',7:'ANDI'}.get(f3,'IMM?')
    if op==0x33: return {0:'ADD' if f7==0 else 'SUB',1:'SLL',2:'SLT',3:'SLTU',
                          4:'XOR',5:'SRL' if f7==0 else 'SRA',6:'OR',7:'AND'}.get(f3,'R?')
    return 'NOP' if w==0 else 'OTHER'

base = '../tests/Basic_Inst_Example/'
files = sorted(f for f in os.listdir(base) if f.endswith('.data'))

PASS_SET = {'inst_andi','inst_auipc','inst_beq','inst_bge','inst_bgeu','inst_blt',
            'inst_bne','inst_div','inst_divu','inst_ori','inst_rem','inst_remu',
            'inst_simple','inst_xori'}

out = []
out.append('# Basic_Inst_Example 测试用例解码文档')
out.append('')
out.append('**日期：** 2026-05-12')
out.append('**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）')
out.append('')
out.append('---')
out.append('')
out.append('## 一、测试框架说明')
out.append('')
out.append('每个 `.data` 文件是 ASCII 十六进制格式，每行一条 32-bit RISC-V 机器指令，')
out.append('通过 `$readmemh` 加载到 ROM，处理器从地址 `0x0000` 开始顺序执行。')
out.append('')
out.append('**测试用例通用结构（以 inst_add 为例）：**')
out.append('')
out.append('```')
out.append('0x0000: addi s10, x0, 0        # x26 = 0（初始化，标记测试进行中）')
out.append('0x0004: addi s11, x0, 0        # x27 = 0')
out.append('')
out.append('# --- 测试向量 N ---')
out.append('        addi gp, x0, N          # x3 = N（测试编号，失败时保留用于输出）')
out.append('        <operand setup>          # 加载操作数')
out.append('        <被测指令>               # 执行被测 RISC-V 指令')
out.append('        <expected value setup>   # 计算期望结果')
out.append('        bne result, expected, FAIL  # 结果不符则跳到 FAIL 段')
out.append('')
out.append('# --- PASS 段（所有测试向量通过后到达）---')
out.append('PASS:   addi s10, x0, 1        # x26 = 1')
out.append('        addi s11, x0, 1        # x27 = 1')
out.append('        jal  x0, 0             # j 0  halt（无限循环在此地址）')
out.append('')
out.append('# --- FAIL 段（某向量失败时跳至此处）---')
out.append('FAIL:   addi s10, x0, 1        # x26 = 1')
out.append('        addi s11, x0, 0        # x27 = 0')
out.append('        jal  x0, 0             # j 0  halt')
out.append('```')
out.append('')
out.append('**Testbench 判断逻辑：**')
out.append('')
out.append('| 状态 | x26 | x27 | 说明 |')
out.append('|------|-----|-----|------|')
out.append('| PASS | 1 | 1 | 所有测试向量通过 |')
out.append('| FAIL | 1 | 0 | 某向量结果错误，x3 = 失败编号 |')
out.append('| 超时 | 0 | 0 | 程序未在 500000ns 内终止（通常为无限循环）|')
out.append('')
out.append('---')
out.append('')
out.append('## 二、当前测试结果汇总')
out.append('')
out.append('| 测试文件 | 有效指令数 | 主要指令类型 | 结果 |')
out.append('|---------|-----------|------------|------|')

# summary table first
for fname in files:
    name = fname.replace('.data','')
    status = 'PASS ✅' if name in PASS_SET else 'FAIL ❌'
    lines_raw = [l.strip() for l in open(base+fname) if l.strip()]
    non_nop = sum(1 for l in lines_raw if int(l,16)!=0)
    op_cnt={}
    for l in lines_raw:
        w=int(l,16)
        if w==0: continue
        k=op_key(w)
        op_cnt[k]=op_cnt.get(k,0)+1
    # Find the "main" tested instruction (non-framework)
    framework = {'ADDI','BNE','LUI','JAL','NOP'}
    main_ops = [f'{k}×{v}' for k,v in sorted(op_cnt.items()) if k not in framework]
    if not main_ops:
        main_ops = [f'{k}×{v}' for k,v in sorted(op_cnt.items())]
    main_str = ', '.join(main_ops[:3])
    out.append(f'| {name} | {non_nop} | {main_str} | {status} |')

out.append('')
out.append('---')
out.append('')
out.append('## 三、各测试文件完整解码')
out.append('')

for fname in files:
    name = fname.replace('.data','')
    status = 'PASS ✅' if name in PASS_SET else 'FAIL ❌（超时）'
    lines_raw = [l.strip() for l in open(base+fname) if l.strip()]
    non_nop = sum(1 for l in lines_raw if int(l,16)!=0)
    op_cnt={}
    for l in lines_raw:
        w=int(l,16)
        if w==0: continue
        k=op_key(w)
        op_cnt[k]=op_cnt.get(k,0)+1
    op_str = ', '.join(f'{k}×{v}' for k,v in sorted(op_cnt.items()))

    out.append(f'### {name}  \[{status}\]')
    out.append('')
    out.append(f'- **ROM 行数：** {len(lines_raw)} 行（含 NOP 填充），有效指令 {non_nop} 条')
    out.append(f'- **指令分布：** {op_str}')
    out.append('')
    out.append('```asm')
    for i, l in enumerate(lines_raw):
        w = int(l, 16)
        if w != 0:
            out.append(f'0x{i*4:04x}: {l}  {decode(w)}')
    out.append('```')
    out.append('')

doc = '\n'.join(out)
outpath = '../dev_log/20260512_02_basic_inst_example_decode.md'
with open(outpath, 'w', encoding='utf-8') as f:
    f.write(doc)
print(f'Written {len(out)} lines to {outpath}')
