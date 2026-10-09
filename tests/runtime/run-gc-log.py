#!/usr/bin/env python3
"""runevm --gc-log FILE (docs/runtime.md, *Watching it*): a line for every
pass of the collector, in the columns its header names, and lines at exit
that agree with --count and --stats; and the run itself unchanged by it.
With no nursery every pass is a full one; with one, minor passes promote
and full ones copy the old space."""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--rune', default='bin/rune-stack')
parser.add_argument('--vm', default='bin/runevm-stack')
args = parser.parse_args()
compiler = str(Path(args.rune).resolve())
vm = str(Path(args.vm).resolve())
out = Path('tests/out/gc-log')
out.mkdir(parents=True, exist_ok=True)

COLUMNS = ('seq kind vmgc bytes objects instrs boxes box_bytes used_before copied copied_objs promoted '
           'slots live_slots frames other_roots cards_dirty cards_scanned remembered live_after heap_size '
           'pause_ns cpu_ns rss_bytes t_ns cards_young fields_scanned').split()


def run(*options):
    return subprocess.run([vm, *map(str, options)], capture_output=True, timeout=120)


def count_of(stderr):
    m = re.search(rb'runevm: count: (\d+) instructions, (\d+) bytes, (\d+) objects', stderr)
    assert m, stderr
    return tuple(int(x) for x in m.groups())


with tempfile.TemporaryDirectory(dir=out) as d:
    directory = Path(d)
    source = directory / 'gclog.sml'
    bytecode = directory / 'gclog.rbc'
    log = directory / 'gclog.log'
    # lists made and dropped, and a list of their lengths that grows, so
    # that a small heap is collected often and has to grow
    source.write_text('''fun build 0 acc = acc | build n acc = build (n - 1) (n :: acc)
fun loop 0 keep = keep
  | loop k keep = loop (k - 1) (List.length (build 2000 []) :: build 20 keep)
val kept = loop 300 []
val () = print (Int.toString (List.foldl op+ 0 kept) ^ "\\n")
''')
    compiled = subprocess.run([compiler, '-o', str(bytecode), str(source)],
                              capture_output=True, timeout=60)
    assert compiled.returncode == 0, compiled.stderr

    plain = run('--count', '--nursery', 0, '--heap-size', 65536, bytecode)
    logged = run('--count', '--stats', '--nursery', 0, '--heap-size', 65536, '--gc-log', log, bytecode)
    assert plain.returncode == 0 and logged.returncode == 0, logged.stderr
    assert logged.stdout == plain.stdout, 'the log changed the output'
    count = count_of(plain.stderr)
    assert count_of(logged.stderr) == count, 'the log changed --count'
    collections = int(re.search(rb'runevm: (\d+) collections', logged.stderr).group(1))

    lines = log.read_text().splitlines()
    assert re.fullmatch(r'# rune-gc-log 1 nursery=0 heap=65536 fill=50 limit=0', lines[0]), lines[0]
    assert lines[1].split() == ['#'] + COLUMNS, lines[1]
    rows = [line.split() for line in lines[2:] if not line.startswith('#')]
    assert len(rows) == collections > 1, (len(rows), collections)
    previous = None
    for seq, row in enumerate(rows, 1):
        assert len(row) == len(COLUMNS), row
        r = dict(zip(COLUMNS, row))
        assert r['kind'] == 'full', row
        v = {k: int(x) for k, x in r.items() if k != 'kind'}
        assert v['seq'] == seq, row
        assert v['copied'] == v['live_after'] <= v['heap_size'], row
        assert v['live_slots'] <= v['slots'] and v['pause_ns'] >= 0, row
        assert v['promoted'] == v['cards_dirty'] == v['cards_scanned'] == v['remembered'] == 0, row
        if previous:
            for k in ('vmgc', 'bytes', 'objects', 'instrs', 't_ns'):
                assert v[k] >= previous[k], (k, row)
        previous = v
    assert rows and int(rows[0][2]) == 1
    assert int(rows[-1][2]) < len(rows), 'no collection grew the heap in two passes'
    end = re.fullmatch(r'# end bytes (\d+) objects (\d+) instrs (\d+) boxes \d+ box_bytes \d+ collections (\d+) '
                       r'gc_ns \d+ vmpeak_kb \d+ vmhwm_kb \d+', lines[-2])
    assert end, lines[-2]
    assert (int(end.group(3)), int(end.group(1)), int(end.group(2))) == count, lines[-2]
    assert int(end.group(4)) == collections, lines[-2]
    assert re.fullmatch(r'# wall_ns \d+', lines[-1]), lines[-1]

    # with a nursery: minor passes, whose copy is what they promote, and full
    # ones where the old space would pass the heap's size
    log = directory / 'gclog-nursery.log'
    logged = run('--count', '--stats', '--nursery', 16384, '--nursery-max', 0, '--heap-size', 65536, '--gc-log', log, bytecode)
    assert logged.returncode == 0, logged.stderr
    assert logged.stdout == plain.stdout, 'the nursery changed the output'
    assert count_of(logged.stderr) == count, 'the nursery changed --count'
    collections = int(re.search(rb'runevm: (\d+) collections', logged.stderr).group(1))
    minors, fulls, promoted = map(int, re.search(
        rb'runevm: nursery 16384 bytes: (\d+) minor and (\d+) full collections, promoted (\d+)', logged.stderr).groups())
    lines = log.read_text().splitlines()
    assert re.fullmatch(r'# rune-gc-log 1 nursery=16384 heap=65536 fill=50 limit=0', lines[0]), lines[0]
    rows = [dict(zip(COLUMNS, line.split())) for line in lines[2:] if not line.startswith('#')]
    assert len(rows) == collections == minors + fulls and minors > 1 and fulls > 1, (len(rows), minors, fulls)
    assert sum(int(r['promoted']) for r in rows) == promoted > 0
    for seq, r in enumerate(rows, 1):
        v = {k: int(x) for k, x in r.items() if k != 'kind'}
        assert v['seq'] == seq, r
        if r['kind'] == 'minor':
            assert v['copied'] == v['promoted'] <= v['used_before'], r
            assert v['cards_dirty'] <= v['cards_scanned'] and v['cards_young'] <= v['cards_dirty'], r
        else:
            assert r['kind'] == 'full' and v['promoted'] == 0 and v['copied'] <= v['live_after'], r

    # a file that cannot be written is refused before the program runs
    refused = run('--gc-log', directory, bytecode)
    assert refused.returncode == 2 and b'--gc-log' in refused.stderr and refused.stdout == b'', refused.stderr

print('gc-log: ok')
