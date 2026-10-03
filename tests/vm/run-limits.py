#!/usr/bin/env python3
"""Saved resource policies and stricter limits supplied when restoring."""
import argparse
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--rune', default='bin/rune-stack')
parser.add_argument('--vm', default='bin/runevm')
args = parser.parse_args()
compiler = str(Path(args.rune).resolve())
vm = str(Path(args.vm).resolve())
out = Path('tests/out/limits')
out.mkdir(parents=True, exist_ok=True)


def run(*args):
    return subprocess.run([vm, *map(str, args)], capture_output=True, timeout=60)


with tempfile.TemporaryDirectory(dir=out) as d:
    directory = Path(d)
    source = directory / 'limits.sml'
    bytecode = directory / 'limits.rbc'
    image = directory / 'limits.img'
    source.write_text('''datatype tree = Leaf | Node of tree * tree
fun make 0 = Leaf | make n = let val t = make (n - 1) in Node (t, t) end
val left = make 4
val right = make 4
val phase = Runtime.save "''' + str(image) + '''"
val () = case phase of Runtime.Saved => print "saved\\n"
                    | Runtime.Restored => print (Bool.toString (left = right) ^ "\\n")
''')
    compiled = subprocess.run([compiler, '-o', str(bytecode), str(source)],
                              capture_output=True, timeout=60)
    assert compiled.returncode == 0, compiled.stderr
    for budget, restored_status in ((10, 2), (1000, 0)):
        p = run('--equality-work', budget, bytecode)
        assert p.returncode == 0 and p.stdout == b'saved\n', p.stderr
        p = run('--restore', image)
        assert p.returncode == restored_status, (budget, p.stderr)
        if restored_status:
            assert p.stderr.startswith(b'runevm: equality work limit exceeded\n'), p.stderr
        else:
            assert p.stdout == b'true\n', p.stdout
            p = run('--equality-work', 1, '--restore', image)
            assert p.returncode == 2 and b'equality work limit exceeded' in p.stderr, p.stderr

    source.write_text('''val phase = Runtime.save "''' + str(image) + '''"
val xs = List.tabulate (100, fn i => i)
val () = Runtime.collect ()
val () = print ((if #heapSize (Runtime.stats ()) <= 65536 then "limited:" else "unlimited:")
                ^ Int.toString (List.length xs) ^ "\\n")
''')
    compiled = subprocess.run([compiler, '-o', str(bytecode), str(source)],
                              capture_output=True, timeout=60)
    assert compiled.returncode == 0, compiled.stderr
    p = run('--heap-limit', 65536, '--heap-fill', 1, bytecode)
    assert p.returncode == 0 and p.stdout == b'limited:100\n', p.stderr
    p = run('--restore', image)
    assert p.returncode == 0 and p.stdout == b'limited:100\n', (p.stdout, p.stderr)
    p = run('--heap-limit', 4096, '--restore', image)
    assert p.returncode == 2 and b'heap limit exceeded' in p.stderr, p.stderr
print('PASS saved resource policies and stricter restore limits')
