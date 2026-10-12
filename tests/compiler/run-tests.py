#!/usr/bin/env python3
"""Compiler resource budgets and preservation of source/build artifacts."""
import argparse
import resource
import subprocess
import tempfile
from pathlib import Path


parser = argparse.ArgumentParser()
parser.add_argument('--rune', default='bin/rune-stack')
args = parser.parse_args()
compiler = str(Path(args.rune).resolve())
out = Path('tests/out/compiler')
out.mkdir(parents=True, exist_ok=True)


def run(*args, file_limit=None):
    def limits():
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        if file_limit is not None:
            resource.setrlimit(resource.RLIMIT_FSIZE, (file_limit, file_limit))
    return subprocess.run([compiler, *map(str, args)], capture_output=True,
                          timeout=60, preexec_fn=limits)


with tempfile.TemporaryDirectory(dir=out) as d:
    directory = Path(d)
    source = directory / 'input.sml'
    original = b'val _ = print "42\\n"\n'
    source.write_bytes(original)
    second = directory / 'second.sml'
    second.write_text('val answer = 42\n')
    second_original = second.read_bytes()
    for dest in (source, source.parent / '.' / source.name, second):
        result = run('-o', dest, source, second)
        assert result.returncode != 0 and b'output must differ' in result.stderr, result.stderr
        assert source.read_bytes() == original and second.read_bytes() == second_original
    for alias, create in [('symlink.sml', lambda p: p.symlink_to(source.resolve())),
                          ('hardlink.sml', lambda p: p.hardlink_to(source))]:
        target = directory / alias
        create(target)
        result = run('-o', target, source)
        assert result.returncode != 0 and b'output must differ' in result.stderr, result.stderr
        assert source.read_bytes() == original

    target = directory / 'output.rbc'
    old = b'previous bytecode'
    target.write_bytes(old)
    source.write_text('val _ = print "' + 'x' * 8192 + '"\n')
    result = run('-o', target, source, file_limit=64)
    assert result.returncode != 0, 'file-size limit must interrupt the write'
    assert target.read_bytes() == old, 'failed write replaced the previous artifact'
    result = run('-o', target, source)
    assert result.returncode == 0, result.stderr
    assert target.read_bytes().startswith(b'RUNE')
    source.write_text('val x = missingName\n')
    before = target.read_bytes()
    result = run('-o', target, source)
    assert result.returncode != 0 and target.read_bytes() == before

    for flag in ('--type-work', '--match-work'):
        for bad in ('', '0', '-1', '+1', '1x', '1.5', '999999999999999999999999'):
            result = run(flag + '=' + bad, source)
            assert result.returncode != 0 and b'requires a positive integer' in result.stderr, (flag, bad, result.stderr)
    source.write_text('val f = fn true => 1 | false => 2\n')
    result = run('--no-prelude', '--typecheck-only', '--match-work=1', source)
    assert result.returncode != 0 and b'match analysis exceeds 1 steps' in result.stderr, result.stderr
    result = run('--no-prelude', '--typecheck-only', '--match-work=1000', source)
    assert result.returncode == 0, result.stderr
    result = run('--no-prelude', '--typecheck-only', '--type-work=1', source)
    assert result.returncode != 0 and b'type inference exceeds 1 steps' in result.stderr, result.stderr
    result = run('--no-prelude', '--typecheck-only', '--type-work=10000', source)
    assert result.returncode == 0, result.stderr
    # types shared while inferred, 2^12 nodes once translated (MLton's regression exponential)
    source.write_text('fun f x = x\nfun g y = f f f f f f f f f f f f y\nval _ = g 3\n')
    result = run('--no-prelude', '--typecheck-only', '--type-work=2000', source)
    assert result.returncode == 0, result.stderr
    result = run('--no-prelude', '--type-work=2000', '-o', target, source)
    assert result.returncode != 0 and b'type translation exceeds 2000 steps' in result.stderr, result.stderr
    result = run('--no-prelude', '--type-work=1000000', '-o', target, source)
    assert result.returncode == 0, result.stderr
print('PASS compiler output protection and resource budgets')

# --pass-stats accounts for the whole compile (docs/plans/performance.md, M1):
# a line `pass NAME: N nodes, T s` per stage, then
# `total: T s processor time, S s in the stages (P%)`, the process's processor
# time from its start and the sum of the outermost stages. The stages must add
# up to the total, to within the rounding of the lines and 2%, and the process
# must have taken no more than the total, but for what the VM does after the
# last line (it exits). A piece of the compile that no stage times shows here.
# (SML/NJ's processor time counts the collector's twice, so a total may be
# more than what the process took.)
with tempfile.TemporaryDirectory(dir=out) as d:
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    result = run('--pass-stats', '-o', Path(d) / 'sigs.rbc', 'tests/perf/compile-sigs.sml')
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    assert result.returncode == 0, result.stderr
    process = (after.ru_utime - before.ru_utime) + (after.ru_stime - before.ru_stime)
    lines = result.stderr.decode().splitlines()
    stages = []
    for line in lines[:-1]:
        name, rest = line.split(': ', 1)
        nodes, seconds = rest.split(', ')
        assert name.startswith('pass ') and nodes.endswith(' nodes') and seconds.endswith(' s'), line
        stages.append((name[5:], float(seconds[:-2].replace('~', '-'))))
    names = [n for n, _ in stages]
    for wanted in ('startup', 'lex', 'select', 'parse', 'elaborate', 'translate', 'mid', 'midcanon',
                   'lower', 'stack', 'emit', 'stats'):
        assert wanted in names, (wanted, names)
    words = lines[-1].split()
    assert words[0] == 'total:' and words[2:5] == ['s', 'processor', 'time,'], lines[-1]
    total, inside = float(words[1]), float(words[5])
    added = sum(t for _, t in stages)
    assert abs(added - inside) <= 0.0005 * len(stages) + 0.001, (added, inside)
    assert total - added <= 0.001 * len(stages) + 0.02 * total, (total, added, lines)
    assert all(t >= 0 for _, t in stages), lines
    assert process <= 1.10 * total + 0.05, (total, process)
print('PASS --pass-stats: the stages add up to the compile')
