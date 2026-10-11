#!/usr/bin/env python3
"""The test of runevm --jit-dump (runtime/register/jit/dump.c; performance M1):

  jit-dump.py RUNEVM PROG.rbc DIR

runs PROG.rbc with every function compiled at tier 2 and the code dumped
into DIR, and holds the dump to what dump.c says it is: a line of index.tsv,
the bytes and the parts of every function compiled, each part of a known
role at an offset inside the code, the protocol of a call in its roles
(PROG.rbc must make a known call: tests/perf/fib.sml does), and perf's
jitdump with a record of each function's parts and code, the code the
bytes of the dump. Where objdump is, scripts/jit-dump.py gives every
machine instruction a role."""
import os, shutil, struct, subprocess, sys

ROLES = {'body', 'count', 'poll', 'writeback', 'args', 'room', 'frameroom', 'frame', 'jump',
         'fill', 'land', 'ret', 'slow', 'sync', 'closure', 'ptrload', 'tag', 'alloc'}
CALL = {'count', 'body', 'poll', 'writeback', 'args', 'room', 'frameroom', 'frame', 'jump', 'ret', 'fill', 'land', 'slow'}


def fail(msg):
    sys.exit('jit-dump: ' + msg)


def main():
    vm, rbc, d = sys.argv[1:4]
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    run = subprocess.run([vm, '--jit=all', '--jit-tier=2', '--jit-dump=' + d, rbc], capture_output=True, text=True)
    if run.returncode != 0:
        fail('runevm failed: %s' % run.stderr)
    rows = [line.rstrip('\n').split('\t') for line in open(os.path.join(d, 'index.tsv'))]
    if not rows:
        fail('no function in index.tsv')
    seen = set()
    for seq, f in enumerate(rows):
        if len(f) != 10 or f[0] != '%05d' % seq:
            fail('index.tsv: line %d: %r' % (seq + 1, f))
        size = int(f[4])
        code = open(os.path.join(d, f[0] + '.bin'), 'rb').read()
        if len(code) != size:
            fail('%s.bin: %d bytes, index.tsv says %d' % (f[0], len(code), size))
        last = -1
        for line in open(os.path.join(d, f[0] + '.lst')):
            p = line.rstrip('\n').split('\t')
            off, role = int(p[0]), p[2]
            if role not in ROLES:
                fail('%s.lst: an unknown role %r' % (f[0], role))
            if off <= last or off >= size:
                fail('%s.lst: offset %d out of order or outside the code' % (f[0], off))
            if last < 0 and off != 0:
                fail('%s.lst: the first part is at %d, not 0' % (f[0], off))
            last = off
            if f[9] == 'fib':
                seen.add(role)
    if not CALL <= seen:
        fail('fib: roles missing from its code: %s' % ' '.join(sorted(CALL - seen)))
    check_perf(d, rows)
    if shutil.which('objdump'):
        here = os.path.dirname(os.path.abspath(__file__))
        out = subprocess.run([sys.executable, os.path.join(here, '..', '..', 'scripts', 'jit-dump.py'), d, 'fib'],
                             capture_output=True, text=True, check=True).stdout
        lines = [l.split() for l in out.splitlines() if l and not l.startswith('#')]
        if not lines or any(len(l) < 4 or l[2] not in ROLES for l in lines):
            fail('scripts/jit-dump.py: a machine instruction without a role')
        print('jit-dump: %d functions dumped; fib has %d machine instructions, each with a role' % (len(rows), len(lines)))
    else:
        print('jit-dump: %d functions dumped (no objdump: the disassembly not checked)' % len(rows))


def check_perf(d, rows):
    dumps = [n for n in os.listdir(d) if n.startswith('jit-') and n.endswith('.dump')]
    if len(dumps) != 1:
        fail('not one jitdump: %s' % dumps)
    data = open(os.path.join(d, dumps[0]), 'rb').read()
    magic, version, hsize, mach, _, pid, _, _ = struct.unpack_from('<IIIIIIQQ', data, 0)
    if magic != 0x4A695444 or version != 1 or hsize != 40 or mach not in (62, 183) or dumps[0] != 'jit-%d.dump' % pid:
        fail('%s: not a jitdump header' % dumps[0])
    at, seq, entries = hsize, 0, None
    while at < len(data):
        rid, total, _ = struct.unpack_from('<IIQ', data, at)
        if rid == 2:    # JIT_CODE_DEBUG_INFO: the parts of the next code, as lines
            addr, n = struct.unpack_from('<QQ', data, at + 16)
            q, entries = at + 32, []
            for _ in range(n):
                a, line, _ = struct.unpack_from('<QiI', data, q)
                end = data.index(b'\0', q + 16)
                entries.append((a, line, data[q + 16:end].decode()))
                q = end + 1
            if q > at + total:
                fail('a debug record longer than it says')
        elif rid == 0:  # JIT_CODE_LOAD
            if seq >= len(rows):
                fail('more code in the jitdump than in index.tsv')
            f = rows[seq]
            _, _, vma, addr, size, index = struct.unpack_from('<IIQQQQ', data, at + 16)
            end = data.index(b'\0', at + 56)
            name = data[at + 56:end].decode()
            code = data[end + 1:end + 1 + size]
            if (vma, addr, size, index) != (int(f[3], 16), int(f[3], 16), int(f[4]), seq) or name != 'jit%s:%s' % (f[2], f[9]):
                fail('the jitdump\'s code %d is not index.tsv\'s %r' % (seq, f))
            if code != open(os.path.join(d, f[0] + '.bin'), 'rb').read() or at + total != end + 1 + size:
                fail('the jitdump\'s code %d is not %s.bin' % (seq, f[0]))
            parts = [int(l.split('\t')[0]) for l in open(os.path.join(d, f[0] + '.lst'))]
            lst = os.path.abspath(os.path.join(d, f[0] + '.lst'))
            if entries is None or [(addr + o, i + 1, lst) for i, o in enumerate(parts)] != entries:
                fail('the jitdump\'s lines of code %d are not %s.lst' % (seq, f[0]))
            seq, entries = seq + 1, None
        else:
            fail('a record of kind %d' % rid)
        at += total
    if seq != len(rows):
        fail('the jitdump has %d functions, index.tsv %d' % (seq, len(rows)))


if __name__ == '__main__':
    main()
