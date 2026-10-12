#!/usr/bin/env python3
"""The code the JIT made, as `runevm --jit-dump=DIR` wrote it
(runtime/register/jit/dump.c): each machine instruction with the bytecode
instruction it does and its role (runtime/register/jit/masm.h, MsRole), and,
from a callgrind run of the same process, how many times each ran.

  jit-dump.py DIR [FUNCTION...]
      the code of the functions named (by name or by their number in
      index.tsv; all without), disassembled by objdump, a line per machine
      instruction: offset, bytecode pc, role, instruction
  jit-dump.py --roles DIR
      the code of all of them by role: machine instructions and bytes
  jit-dump.py --callgrind CALLGRIND.OUT DIR [--by role|op|op/role|store] [--calls N] [--list FUNCTION]
      the instructions callgrind counted in the compiled code, by role (or
      by bytecode instruction, or both, or the stores apart), in total and per call where N
      calls are given; --list prints one function's code with the counts
  jit-dump.py --diff RUN1 RUN2 CALLS [role|op|op/role|store]
      what RUN2 executed in compiled code beyond RUN1, per call: the cost
      of CALLS more calls, where RUN1 and RUN2 are directories of the
      program run at two sizes, each with callgrind.out and dump/

A run under callgrind (the code is made as the program runs, which
--smc-check=all follows):

  valgrind --tool=callgrind --dump-instr=yes --smc-check=all \\
      --callgrind-out-file=RUN/callgrind.out runevm --jit-dump=RUN/dump PROG.rbc

The dump perturbs the count of the process a little (its writing), not of
the compiled code. perf's view of the same code: `perf record -k mono ...
runevm --jit-dump=DIR ...`, then `perf inject --jit -i perf.data -o
perf.jit.data` and `perf annotate -i perf.jit.data` (DIR/jit-PID.dump).
"""
import collections, os, re, subprocess, sys


def index(d):
    """the functions of the dump, in the order compiled"""
    rows = []
    for line in open(os.path.join(d, 'index.tsv')):
        f = line.rstrip('\n').split('\t')
        rows.append(dict(seq=f[0], func=int(f[1]), tier=int(f[2]), addr=int(f[3], 16), size=int(f[4]),
                         nlocals=int(f[5]), arity=int(f[6]), reps=f[7], homes=f[8], name=f[9]))
    return rows


def parts(d, seq):
    """the parts of a function's code: (offset, pc, role, text), by offset"""
    out = []
    for line in open(os.path.join(d, seq + '.lst')):
        f = line.rstrip('\n').split('\t')
        out.append((int(f[0]), int(f[1]), f[2], f[3] if len(f) > 3 else ''))
    return out


LINE = re.compile(r'^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)\s*(.*)$')
LINE_A64 = re.compile(r'^\s*([0-9a-f]+):\s+([0-9a-f]{8})\s+(.*)$')


def machine(d):
    """objdump's name of the machine the dump's code is for (from the
    jitdump's header: EM_X86_64 or EM_AARCH64)"""
    for n in os.listdir(d):
        if n.startswith('jit-') and n.endswith('.dump'):
            with open(os.path.join(d, n), 'rb') as f:
                h = f.read(16)
            if len(h) == 16 and int.from_bytes(h[12:16], 'little') == 183:
                return 'aarch64'
    return 'i386:x86-64'


def disasm(d, row, arch):
    """the machine instructions of a function: [offset, text, bytes]"""
    path = os.path.join(d, row['seq'] + '.bin')
    cmd = ['objdump', '-D', '-b', 'binary', '-m', arch, '--adjust-vma=0x%x' % row['addr'], path]
    if arch != 'aarch64':
        cmd[6:6] = ['-M', 'intel']
    txt = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    ins = []
    for line in txt.splitlines():
        m = (LINE_A64 if arch == 'aarch64' else LINE).match(line)
        if not m:
            continue
        a = int(m.group(1), 16)
        text = m.group(3).strip()
        nb = 4 if arch == 'aarch64' else len(m.group(2).split())
        if not text:   # the rest of a long instruction's bytes
            if ins:
                ins[-1][2] += nb
            continue
        ins.append([a - row['addr'], text, nb])
    return ins


def load(d, row, arch=None):
    """a function's machine instructions, each with its part's pc, role and
    bytecode instruction"""
    ps = parts(d, row['seq'])
    res = []
    k = -1
    for off, text, nb in disasm(d, row, arch or machine(d)):
        while k + 1 < len(ps) and ps[k + 1][0] <= off:
            k += 1
        pc, role, op = (ps[k][1], ps[k][2], ps[k][3]) if k >= 0 else (None, 'body', '')
        res.append(dict(off=off, pc=pc, role=role, op=op.split(' ')[0] if op else '', ins=op, text=text, nbytes=nb))
    return res


def wanted(rows, names):
    return [r for r in rows if not names or r['seq'] in names or r['name'] in names or str(r['func']) in names]


def show(d, names):
    arch = machine(d)
    for row in wanted(index(d), names):
        print('# %s function %d %s, tier %d, at %x, %d bytes, %d registers (arity %d), representations %s, homes %s'
              % (row['seq'], row['func'], row['name'], row['tier'], row['addr'], row['size'], row['nlocals'],
                 row['arity'], row['reps'], row['homes']))
        last = None
        for r in load(d, row, arch):
            if (r['pc'], r['role']) != last:
                print('#   %s  [%s]' % (r['ins'], r['role']))
                last = (r['pc'], r['role'])
            print('%6d  %6s  %-9s  %s' % (r['off'], r['pc'], r['role'], r['text']))


def roles(d):
    arch = machine(d)
    ins = collections.Counter()
    byt = collections.Counter()
    rows = index(d)
    for row in rows:
        for r in load(d, row, arch):
            ins[r['role']] += 1
            byt[r['role']] += r['nbytes']
    ti, tb = sum(ins.values()), sum(byt.values())
    print('%d functions, %d machine instructions, %d bytes' % (len(rows), ti, tb))
    for k, v in byt.most_common():
        print('%-10s %9d bytes %5.1f%%  %8d instructions %5.1f%%' % (k, v, 100.0 * v / tb, ins[k], 100.0 * ins[k] / ti))


def parse_callgrind(path):
    """the instructions (Ir) callgrind counted at each address, exclusive
    (a file of --dump-instr=yes; the counts of calls are skipped)"""
    counts = collections.Counter()
    last = 0
    npos = 1
    skip = False

    def at(tok, last):
        if tok.startswith('0x'):
            return int(tok, 16)
        if tok == '*':
            return last
        if tok[0] in '+-':
            v = tok[1:]
            n = int(v, 16) if v.startswith('0x') else int(v)
            return last + n if tok[0] == '+' else last - n
        return int(tok)
    for line in open(path):
        if line.startswith('positions:'):
            npos = len(line.split()) - 1
            continue
        if not line or line[0] not in '0123456789+-*':
            if line.startswith('calls='):
                skip = True
            continue
        p = line.split()
        addr = at(p[0], last)
        last = addr
        if skip:
            skip = False
            continue
        if len(p) > npos:
            counts[addr] += int(p[npos])
    return counts


def stores(text):
    """whether a machine instruction (objdump's text, Intel syntax on x86-64)
    writes memory: a destination in brackets, or aarch64's str and stp"""
    mnem, _, ops = text.partition(' ')
    if mnem.startswith(('str', 'stp', 'stur')):
        return True
    if mnem.startswith(('cmp', 'test', 'j', 'call', 'lea', 'nop', 'push', 'ucomi')):
        return mnem.startswith('push')
    return '[' in ops.split(',')[0]


def key(r, by):
    if by == 'store':
        return 'stores' if stores(r['text']) else 'other'
    return r['role'] if by == 'role' else r['op'] if by == 'op' else '%s/%s' % (r['op'], r['role'])


def counted(cg, d, by='role', listing=None):
    """the instructions of the compiled code by key, and the whole process's"""
    counts = parse_callgrind(cg)
    arch = machine(d)
    total = collections.Counter()
    for row in index(d):
        per = collections.Counter()
        for r in load(d, row, arch):
            n = counts.get(row['addr'] + r['off'], 0)
            if listing and listing in (row['seq'], row['name']):
                print('%12d  %6d %6s %-10s %-9s %s' % (n, r['off'], r['pc'], r['op'], r['role'], r['text']))
            if n:
                per[key(r, by)] += n
        total.update(per)
    return total, sum(counts.values())


def callgrind(args):
    cg, d = args[0], args[1]
    by, calls, listing = 'role', None, None
    i = 2
    while i < len(args):
        if args[i] == '--by':
            by = args[i + 1]
        elif args[i] == '--calls':
            calls = float(args[i + 1])
        elif args[i] == '--list':
            listing = args[i + 1]
        else:
            sys.exit('jit-dump.py: --callgrind: what is %s?' % args[i])
        i += 2
    total, process = counted(cg, d, by, listing)
    jit = sum(total.values())
    print('the compiled code: %d of the process\'s %d instructions (%.1f%%)' % (jit, process, 100.0 * jit / max(1, process)))
    for k, v in total.most_common():
        print('%-24s %14d  %5.1f%%' % (k, v, 100.0 * v / max(1, jit)) + ('  %8.2f per call' % (v / calls) if calls else ''))
    if calls:
        print('%-24s %14d  100.0%%  %8.2f per call' % ('total', jit, jit / calls))


def diff(args):
    r1, r2, calls = args[0], args[1], float(args[2])
    by = args[3] if len(args) > 3 else 'role'
    c1, t1 = counted(os.path.join(r1, 'callgrind.out'), os.path.join(r1, 'dump'), by)
    c2, t2 = counted(os.path.join(r2, 'callgrind.out'), os.path.join(r2, 'dump'), by)
    jit = sum(c2.values()) - sum(c1.values())
    for k in sorted(set(c1) | set(c2), key=lambda k: -(c2[k] - c1[k])):
        v = c2[k] - c1[k]
        if abs(v) / calls >= 0.005:
            print('%-24s %8.2f per call  %5.1f%%' % (k, v / calls, 100.0 * v / jit if jit else 0))
    print('%-24s %8.2f per call in the compiled code; %.2f in the whole process' % ('total', jit / calls, (t2 - t1) / calls))


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        print(__doc__)
        return
    if argv[0] == '--roles':
        roles(argv[1])
    elif argv[0] == '--callgrind':
        callgrind(argv[1:])
    elif argv[0] == '--diff':
        diff(argv[1:])
    else:
        show(argv[0], argv[1:])


if __name__ == '__main__':
    main(sys.argv[1:])
