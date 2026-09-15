#!/usr/bin/env python3
"""One semantic corpus for every host-built Rune; standalone bytecode VM checks."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(args, *, cwd=ROOT, input=None, status=0, stdout=None):
    result = subprocess.run(list(map(str, args)), cwd=cwd, input=input,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    assert result.returncode == status, (args, result.returncode, result.stdout, result.stderr)
    if stdout is not None:
        assert result.stdout == stdout, (args, result.stdout, stdout, result.stderr)
    return result


def encode(code, *, locals=0, constants=(), source=b"fixture.sml", version=1):
    string = lambda s: struct.pack("<I", len(s)) + s
    return (b"RUNEBC\r\n" + struct.pack("<IIII", version, locals, len(constants), len(code)) +
            string(source) + b"".join(map(string, constants)) +
            b"".join(struct.pack("<BIII", op, arg, 1, 1) for op, arg in code))


def vm_cases(vm, directory):
    valid = encode([(0, 0)])
    cases = {
        "magic": b"X" + valid[1:], "truncated": valid[:12],
        "version": encode([(0, 0)], version=2), "trailing": valid + b"x",
        "zero-code": encode([]), "unknown-op": encode([(255, 0)]),
        "unused-operand": encode([(0, 1)]), "bad-bool": encode([(2, 2), (8, 0), (0, 0)]),
        "bad-builtin": encode([(5, 4), (8, 0), (0, 0)]),
        "bad-local": encode([(6, 0), (8, 0), (0, 0)]),
        "bad-constant": encode([(4, 0), (8, 0), (0, 0)]),
        "bad-target": encode([(22, 9), (0, 0)]),
        "backward": encode([(22, 0), (0, 0)]),
        "falloff": encode([(3, 0), (8, 0)]),
        "underflow": encode([(8, 0), (0, 0)]),
        "halt-stack": encode([(3, 0), (0, 0)]),
        "join": encode([(2, 1), (23, 4), (3, 0), (22, 5), (22, 5), (0, 0)]),
        "nul-source": encode([(0, 0)], source=b"x\0y"),
        "position": valid[:-8] + bytes(8),
        "truncated-string": valid[:24] + struct.pack("<I", 999) + b"x",
        "oversized-string": valid[:24] + struct.pack("<I", 1048577),
        "count-limit": valid[:12] + struct.pack("<I", 65537) + valid[16:],
    }
    runtime = {
        "uninitialized": encode([(6, 0), (8, 0), (0, 0)], locals=1),
        "wrong-type": encode([(3, 0), (1, 1), (9, 0), (8, 0), (0, 0)]),
        "wrong-call": encode([(1, 1), (3, 0), (21, 0), (8, 0), (0, 0)]),
        "function-equality": encode([(5, 0), (5, 0), (15, 0), (8, 0), (0, 0)]),
    }
    for name, blob in cases.items():
        path = directory / (name + ".rbc")
        path.write_bytes(blob)
        result = run([vm, path], status=2, stdout=b"")
        assert result.stderr, name
    for name, blob in runtime.items():
        path = directory / (name + ".rbc")
        path.write_bytes(blob)
        result = run([vm, path], status=3, stdout=b"")
        assert b"runtime:" in result.stderr, name
    # Exercise every truncation boundary in a small valid file.
    for n in range(len(valid)):
        path = directory / "truncated-each.rbc"
        path.write_bytes(valid[:n])
        run([vm, path], status=2, stdout=b"")
    print(f"VM: {len(cases) + len(runtime) + len(valid)} malformed/runtime fixtures passed.")


def references(hosts, cases, directory):
    eligible = [c for c in cases if c.get("reference")]
    text = "structure Reference = struct\n"
    for i, case in enumerate(eligible):
        text += f'val () = print "RUNE_REFERENCE_BEGIN_{i}\\n"\nlocal\n'
        text += (ROOT / case["path"]).read_text() + "\nin val () = () end\n"
        text += f'val () = print "RUNE_REFERENCE_END_{i}\\n"\n'
    text += "end\nval () = TextIO.flushOut TextIO.stdOut\nval () = OS.Process.terminate OS.Process.success\n"
    source = directory / "reference.sml"
    source.write_text(text)
    for host in hosts:
        if host == "mlton":
            exe = directory / "reference"
            run([os.environ.get("MLTON") or "mlton", "-output", exe, source])
            result = run([exe])
        elif host == "polyml":
            result = run([os.environ.get("POLY") or "poly", "--script", source])
        else:
            # No application arguments go through this wrapper. The distribution
            # wrapper sets SMLNJ_HOME, which the interactive Basis autoloader needs.
            sml = os.environ.get("SML") or "sml"
            result = run([sml], cwd=directory,
                         input=b'(use "reference.sml"; OS.Process.exit OS.Process.success) handle _ => OS.Process.exit OS.Process.failure;\n')
        for i, case in enumerate(eligible):
            begin, end = f"RUNE_REFERENCE_BEGIN_{i}\n".encode(), f"RUNE_REFERENCE_END_{i}\n".encode()
            assert result.stdout.count(begin) == result.stdout.count(end) == 1, (host, case, result.stdout)
            actual = result.stdout.split(begin)[1].split(end)[0]
            assert actual == case.get("stdout", "").encode(), (host, case, actual)
    print(f"Reference SML: {len(eligible)} programs agree under {', '.join(hosts)}.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hosts", nargs="+", choices=["smlnj", "polyml", "mlton"], required=True)
    parser.add_argument("--vm", default="build/vm/rune-vm")
    args = parser.parse_args()
    vm = (ROOT / args.vm).resolve()
    cases = json.loads((ROOT / "tests/cases.json").read_text())
    comparison = {}
    with tempfile.TemporaryDirectory(prefix="rune tests ") as temp:
        directory = Path(temp)
        for host in args.hosts:
            compiler = ROOT / "build" / host / "rune"
            assert run([compiler, "--version"]).stdout.startswith(b"Rune ")
            assert b"Usage:" in run([compiler, "--help"]).stdout
            run([compiler], status=1)
            run([compiler, "--unknown"], status=1)
            run([compiler, "--eval", "print \"host options must not execute\""], status=1, stdout=b"")
            run([compiler, "missing.sml"], cwd=directory, status=1)
            for i, case in enumerate(cases):
                source = ROOT / case["path"]
                output = directory / f"{i}.rbc"
                output.write_bytes(b"preserve previous output")
                result = run([compiler, "-o", output, source], status=1 if case["kind"] == "reject" else 0, stdout=b"")
                if case["kind"] == "reject":
                    assert (": " + case["stderr"] + ": ").encode() in result.stderr, (case, result.stderr)
                    assert re.search(rb":\d+:\d+: ", result.stderr), result.stderr
                    assert output.read_bytes() == b"preserve previous output", case
                    evidence = result.stderr
                else:
                    assert result.stderr == b"", result.stderr
                    evidence = output.read_bytes()
                    run([compiler, "--check", source], stdout=b"")
                    runtime = run([vm, output], status=3 if case["kind"] == "runtime" else 0,
                                  stdout=bytes.fromhex(case["stdout_hex"]) if "stdout_hex" in case else case.get("stdout", "").encode())
                    if case["kind"] == "runtime":
                        assert case["stderr"].encode() in runtime.stderr, (case, runtime.stderr)
                    else:
                        assert runtime.stderr == b"", runtime.stderr
                    assert b"Rune bytecode v1" in run([compiler, "--disassemble", output]).stdout
                if i in comparison:
                    assert comparison[i] == evidence, f"host divergence: {host}: {case['path']}"
                comparison[i] = evidence
            # The empty program has a independently specified byte encoding.
            empty = directory / "empty.sml"
            empty.write_text("")
            run([compiler, "-o", directory / "empty.rbc", empty])
            assert (directory / "empty.rbc").read_bytes() == encode([(0, 0)], source=b"empty.sml")
            # Launch outside the checkout, preserving relative paths and argv.
            spaced = directory / "source file.sml"
            shutil.copyfile(ROOT / "examples/hello.sml", spaced)
            run([compiler, "-o", "output file.rbc", "source file.sml"], cwd=directory)
            run([vm, "output file.rbc"], cwd=directory, stdout=b"42\n")
            shutil.copyfile(spaced, directory / "-input.sml")
            run([compiler, "-o", "dash.rbc", "--", "-input.sml"], cwd=directory)
            run([vm, "dash.rbc"], cwd=directory, stdout=b"42\n")
            for special in ("--help", "@SMLverbose", "@MLton"):
                shutil.copyfile(spaced, directory / special)
                run([compiler, "-o", "special.rbc", "--", special], cwd=directory)
                run([vm, "special.rbc"], cwd=directory, stdout=b"42\n")
            previous = spaced.read_bytes()
            run([compiler, "-o", spaced, spaced], status=1)
            assert spaced.read_bytes() == previous
            run([compiler, "-o", directory / "missing" / "out.rbc", spaced], status=1)
            assert not list(directory.glob(".*.rbc.*")), "temporary outputs leaked"
            print(f"{host}: {len(cases)} fixtures, CLI, atomic output, and golden encoding passed.")
        vm_cases(vm, directory)
        references(args.hosts, cases, directory)
    if len(args.hosts) > 1:
        print("Cross-host bytecode and rejection diagnostics are identical.")


if __name__ == "__main__":
    main()
