#!/usr/bin/env python3
"""Exercise the packed-storage ABI, including malformed bytecode arguments."""
import argparse
import os
from pathlib import Path
import random
import re
import subprocess

root = Path(__file__).resolve().parents[2]
os.chdir(root)
parser = argparse.ArgumentParser()
parser.add_argument('--vm', default='bin/runevm-stack')
args = parser.parse_args()
vm = str(Path(args.vm).resolve())
out = Path('tests/out/intinf/storage-'+Path(vm).name)
out.mkdir(parents=True, exist_ok=True)
count = 0


def run(body, data=None, message=None, expected=b''):
    global count
    count += 1
    source = out/f'{count}.rasm'
    rbc = source.with_suffix('.rbc')
    header = '' if data is None else 'const mag string "'+'a'*len(data)+'"\n'
    source.write_text(header+'function main 1\n'+body+'\nHALT\n')
    assembled = subprocess.check_output(['awk','-v','opdefs=runtime/stack/opcodes.def',
        '-v','primdefs=runtime/prims.def','-f','tests/opt/rbcasm.awk',str(source)])
    assert assembled.startswith(b'RUNE') and re.fullmatch(rb'(\\[0-7]{3})+',assembled[4:])
    program = bytearray(b'RUNE')
    program.extend(int(b,8) for b in re.findall(rb'\\([0-7]{3})',assembled[4:]))
    if data is not None:
        # The assembler only quotes newlines. Replace the equally long ASCII
        # placeholder in its first constant with arbitrary binary bytes.
        assert program[:4] == b'RUNE' and program[12:17] == b'\1\0\0\0\3'
        assert int.from_bytes(program[17:21],'little') == len(data)
        program[21:21+len(data)] = data
    rbc.write_bytes(program)
    p = subprocess.run([vm,str(rbc)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=15)
    source.with_suffix('.stdout').write_bytes(p.stdout)
    source.with_suffix('.stderr').write_bytes(p.stderr)
    if message is None:
        assert p.returncode == 0 and p.stdout == expected, (source,p.returncode,p.stdout,p.stderr)
    else:
        assert p.returncode == 2 and message.encode() in p.stderr, (source,p.returncode,p.stderr)


rng = random.Random(0x5041434B)
for bits in (15,30):
    for length in (0,1,2,3,4,7,8,15,16,31,32,65):
        for data in (bytes(length),bytes([255])*length,bytes(rng.randrange(256) for _ in range(length))):
            digits = (length*8+bits-1)//bits
            run(f'CONST %mag\nINT {bits}\nPRIM intinf_unpack\nINT {digits}\nINT {bits}\nPRIM intinf_pack\nPRIM print\nPOP',
                data=data,expected=data.rstrip(b'\0'))
            if digits:
                n = digits//2
                value = int.from_bytes(data,'little') & ((1 << (n*bits))-1)
                expected = value.to_bytes((value.bit_length()+7)//8,'little')
                run(f'CONST %mag\nINT {bits}\nPRIM intinf_unpack\nINT {n}\nINT {bits}\nPRIM intinf_pack\nPRIM print\nPOP',
                    data=data,expected=expected)
    run(f'CONST %mag\nINT 0\nPRIM intinf_unpack',data=b'x',message='invalid limb width')
    for n in (-1,2):
        run(f'INT 1\nINT 0\nPRIM array_new\nINT {n}\nINT {bits}\nPRIM intinf_pack',message='invalid limb count')
    for digit in (-1,1 << bits):
        run(f'INT 1\nINT {digit}\nPRIM array_new\nINT 1\nINT {bits}\nPRIM intinf_pack',message='invalid limb')
run('UNIT\nINT 15\nPRIM intinf_unpack',message='wrong argument type')
run('UNIT\nINT 0\nINT 15\nPRIM intinf_pack',message='wrong argument type')
print(f'PASS {count} packed-storage boundary checks')
