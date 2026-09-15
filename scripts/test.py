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


def encode(code, *, locals=0, constants=(), source=b"fixture.sml", version=2,
           functions=None, entry=0):
    string = lambda s: struct.pack("<I", len(s)) + s
    if functions is None:
        functions = [(locals, 0, code)]
    bodies = []
    for slots, environment, instructions in functions:
        bodies.append(struct.pack("<III", slots, environment, len(instructions)) +
                      b"".join(struct.pack("<BIII", op, arg, 1, 1) for op, arg in instructions))
    return (b"RUNEBC\r\n" + struct.pack("<IIII", version, entry, len(functions), len(constants)) +
            string(source) + b"".join(map(string, constants)) + b"".join(bodies))


def vm_cases(vm, directory, options=()):
    valid = encode([(0, 0)])
    cases = {
        "magic": b"X" + valid[1:], "truncated": valid[:12],
        "version": encode([(0, 0)], version=1), "unknown-version": encode([(0, 0)], version=99), "trailing": valid + b"x",
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
        "count-limit": valid[:16] + struct.pack("<I", 65537) + valid[20:],
    }
    runtime = {
        "uninitialized": encode([(6, 0), (8, 0), (0, 0)], locals=1),
        "wrong-type": encode([(3, 0), (1, 1), (9, 0), (8, 0), (0, 0)]),
        "wrong-call": encode([(1, 1), (3, 0), (21, 0), (8, 0), (0, 0)]),
        "function-equality": encode([(5, 0), (5, 0), (15, 0), (8, 0), (0, 0)]),
    }
    def two(main, body, *, slots=1, environment=0):
        return encode([], functions=[(0, 0, main), (slots, environment, body)])

    cases.update({
        "no-functions": encode([], functions=[]),
        "entry-index": encode([(0, 0)], entry=1),
        "entry-environment": encode([], functions=[(0, 1, [(0, 0)])]),
        "no-argument": two([(0, 0)], [(3, 0), (27, 0)], slots=0),
        "entry-return": encode([(3, 0), (27, 0)]),
        "entry-tail": encode([(5, 0), (3, 0), (28, 0)]),
        "entry-self": encode([(25, 0), (8, 0), (0, 0)]),
        "callee-halt": two([(0, 0)], [(0, 0)]),
        "empty-return": two([(0, 0)], [(27, 0)]),
        "extra-return": two([(0, 0)], [(3, 0), (3, 0), (27, 0)]),
        "tail-underflow": two([(0, 0)], [(3, 0), (28, 0)]),
        "tail-extra": two([(0, 0)], [(3, 0), (5, 0), (3, 0), (28, 0)]),
        "callee-falloff": two([(0, 0)], [(3, 0)]),
        "cross-function-branch": two([(22, 2), (0, 0)], [(3, 0), (27, 0)]),
        "environment-index": two([(0, 0)], [(24, 1), (27, 0)], environment=1),
        "closure-entry": encode([(26, 0), (8, 0), (0, 0)]),
        "closure-index": encode([(26, 1), (8, 0), (0, 0)]),
        "closure-underflow": two([(26, 1), (8, 0), (0, 0)], [(24, 0), (27, 0)], environment=1),
        "tuple-underflow": encode([(3, 0), (29, 2), (8, 0), (0, 0)]),
        "tuple-arity-small": encode([(29, 1), (8, 0), (0, 0)]),
        "tuple-arity-big": encode([(29, 65537), (8, 0), (0, 0)]),
        "tuple-index-big": encode([(3, 0), (30, 65536), (8, 0), (0, 0)]),
        "unreachable-invalid": encode([(0, 0), (6, 0)]),
    })
    runtime.update({
        "get-wrong-tag": encode([(3, 0), (30, 0), (8, 0), (0, 0)]),
        "get-out-of-bounds": encode([(3, 0), (3, 0), (29, 2), (30, 2), (8, 0), (0, 0)]),
        "check-unit-tag": encode([(1, 0), (32, 0), (0, 0)]),
        "check-tuple-tag": encode([(3, 0), (33, 2), (8, 0), (0, 0)]),
        "check-tuple-arity": encode([(3, 0), (3, 0), (29, 2), (33, 3), (8, 0), (0, 0)]),
        "callee-uninitialized": two([(26, 1), (3, 0), (21, 0), (8, 0), (0, 0)],
                                    [(6, 1), (27, 0)], slots=2),
        "closure-equality": two([(26, 1), (31, 0), (15, 0), (8, 0), (0, 0)], [(6, 0), (27, 0)]),
        "nested-function-equality": encode([(5, 0), (3, 0), (29, 2), (31, 0), (15, 0), (8, 0), (0, 0)]),
        "tail-wrong-call": two([(26, 1), (3, 0), (21, 0), (8, 0), (0, 0)], [(1, 0), (3, 0), (28, 0)]),
        "frame-limit": two([(26, 1), (3, 0), (21, 0), (8, 0), (0, 0)],
                           [(25, 0), (6, 0), (21, 0), (27, 0)]),
        "operand-limit": two([(26, 1), (3, 0), (21, 0), (8, 0), (0, 0)],
                             [(3, 0), (3, 0), (25, 0), (6, 0), (21, 0), (8, 0), (8, 0), (27, 0)]),
    })
    # A shared tuple DAG can require exponential comparisons despite a small heap.
    dag = [(1, 0), (1, 0), (29, 2)] + [(31, 0), (29, 2)] * 20
    runtime["equality-work-limit"] = encode(dag + [(31, 0), (15, 0), (8, 0), (0, 0)])
    # Independently encoded closure call: capture 40, add argument 2, print 42.
    closure = two([(5, 0), (5, 1), (1, 40), (26, 1), (1, 2), (21, 0), (21, 0), (21, 0), (8, 0), (0, 0)],
                  [(24, 0), (6, 0), (9, 0), (27, 0)], environment=1)
    path = directory / "closure-golden.rbc"
    path.write_bytes(closure)
    run([vm, *options, path], stdout=b"42")
    # Actual v1 empty-file layout, rather than only changing a v2 version field.
    cases["legacy-v1"] = (b"RUNEBC\r\n" + struct.pack("<IIII", 1, 0, 0, 1) +
                          struct.pack("<I", 0) + struct.pack("<BIII", 0, 0, 1, 1))
    for name, blob in cases.items():
        path = directory / (name + ".rbc")
        path.write_bytes(blob)
        result = run([vm, *options, path], status=2, stdout=b"")
        assert result.stderr, name
    for name, blob in runtime.items():
        path = directory / (name + ".rbc")
        path.write_bytes(blob)
        result = run([vm, *options, path], status=3, stdout=b"")
        assert b"runtime:" in result.stderr, name
        expected = {"frame-limit": b"frame stack exceeds 65536",
                    "operand-limit": b"operand stack limit exceeded",
                    "equality-work-limit": b"equality exceeds 1000000 steps"}.get(name)
        if expected:
            assert expected in result.stderr, (name, result.stderr)
    # Exercise every truncation boundary, including captures/function metadata.
    for data in (valid, closure):
        for n in range(len(data)):
            path = directory / "truncated-each.rbc"
            path.write_bytes(data[:n])
            run([vm, *options, path], status=2, stdout=b"")
    mode = "GC stress" if options else "normal"
    print(f"VM ({mode}): {len(cases) + len(runtime) + len(valid) + len(closure)} malformed/runtime fixtures passed.")


def gc_cli_cases(vm, directory):
    path = directory / "heap-cli.rbc"
    path.write_bytes(encode([(0, 0)]))
    assert b"--heap-limit" in run([vm, "--help"]).stdout
    for options in ([], ["--gc-stress"], ["--heap-limit", "67108864"],
                    ["--heap-limit", "0004096", "--gc-stress"]):
        run([vm, *options, path], stdout=b"")
    for limit in ("", "0", "-1", "+1", " 1", "1 ", "1.0", "1KiB", "67108865", "9" * 100):
        result = run([vm, "--heap-limit", limit, path], status=1, stdout=b"")
        assert b"invalid heap limit" in result.stderr
    for options in ([], ["--"], ["--gc-stress"], ["--heap-limit"], ["--unknown"], [path, path]):
        run([vm, *options], status=1, stdout=b"")
    result = run([vm, "--heap-limit", "1", path], status=3, stdout=b"")
    assert b"heap limit exceeded" in result.stderr
    # Source metadata and constants remain rooted during loading, even before
    # execution has frames. A live pool must fail cleanly under a small heap.
    path.write_bytes(encode([(4, 0), (8, 0), (0, 0)], constants=[b"x" * 1024] * 32))
    for options in ([], ["--gc-stress"]):
        result = run([vm, "--heap-limit", "16384", *options, path], status=3, stdout=b"")
        assert b"heap limit exceeded" in result.stderr
        run([vm, "--heap-limit", "65536", *options, path], stdout=b"")
    special = directory / "--heap-limit"
    special.write_bytes(encode([(0, 0)]))
    run([vm, "--gc-stress", "--", special.name], cwd=directory, stdout=b"")
    print("VM: heap option boundaries, loading roots, and option-like filenames passed.")


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


def reference_rejections(hosts, cases, directory):
    eligible = [c for c in cases if c.get("reference_reject")]
    source = directory / "reject-reference.sml"
    for host in hosts:
        for case in eligible:
            source.write_text("structure Rejected = struct\n" + (ROOT / case["path"]).read_text() + "end\n")
            if host == "mlton":
                result = run([os.environ.get("MLTON") or "mlton", "-output", directory / "rejected", source], status=1)
            elif host == "polyml":
                result = run([os.environ.get("POLY") or "poly", "--script", source], status=1)
            else:
                result = run([os.environ.get("SML") or "sml"], cwd=directory, status=1,
                             input=b'(use "reject-reference.sml"; OS.Process.exit OS.Process.success) handle _ => OS.Process.exit OS.Process.failure;\n')
            assert result.stdout or result.stderr, (host, case)
    print(f"Reference SML: {len(eligible)} type/pattern rejections agree under {', '.join(hosts)}.")


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
                    for stress in ([], ["--gc-stress"]):
                        runtime = run([vm, *case.get("vm_args", []), *stress, output],
                                      status=3 if case["kind"] == "runtime" else 0,
                                      stdout=bytes.fromhex(case["stdout_hex"]) if "stdout_hex" in case else case.get("stdout", "").encode())
                        if case["kind"] == "runtime":
                            assert case["stderr"].encode() in runtime.stderr, (case, runtime.stderr)
                            assert re.search(rb":\d+:\d+: runtime: ", runtime.stderr), runtime.stderr
                            if "location" in case:
                                line, column = case["location"]
                                assert f"{source.name}:{line}:{column}: runtime:".encode() in runtime.stderr, runtime.stderr
                        else:
                            assert runtime.stderr == b"", runtime.stderr
                    assert b"Rune bytecode v2" in run([compiler, "--disassemble", output]).stdout
                if i in comparison:
                    assert comparison[i] == evidence, f"host divergence: {host}: {case['path']}"
                comparison[i] = evidence
            # The empty program has a independently specified byte encoding.
            empty = directory / "empty.sml"
            empty.write_text("")
            run([compiler, "-o", directory / "empty.rbc", empty])
            assert (directory / "empty.rbc").read_bytes() == encode([(0, 0)], source=b"empty.sml")
            # Both tools reject earlier and unknown format versions explicitly.
            for version in (1, 99):
                incompatible = directory / "incompatible.rbc"
                incompatible.write_bytes(encode([(0, 0)], version=version))
                rejected = run([compiler, "--disassemble", incompatible], status=1, stdout=b"")
                assert b"unsupported bytecode version" in rejected.stderr
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
            print(f"{host}: {len(cases)} fixtures (normal and GC stress), CLI, atomic output, and golden encoding passed.")
        vm_cases(vm, directory)
        vm_cases(vm, directory, ["--gc-stress"])
        gc_cli_cases(vm, directory)
        references(args.hosts, cases, directory)
        reference_rejections(args.hosts, cases, directory)
    if len(args.hosts) > 1:
        print("Cross-host bytecode and rejection diagnostics are identical.")


if __name__ == "__main__":
    main()
