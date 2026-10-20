#!/usr/bin/env python3
"""Rebuild one theory of HOL4 and time it (docs/performance.md, *Measuring*;
docs/plans/performance.md, E7):

    scripts/hol-theory.py HOL THEORY [--runs N] [--out DIR] [--vm RUNEVM]
                          [--vm-opts OPTS] [--cache DIR] [--no-perf]

HOL is a HOL4 tree that has been built (bin/build), by Poly/ML or by Rune.
THEORY is logroot, mergesort, string or toto, or DIR:NAME for the theory NAME
of HOL's directory DIR (relative to HOL). A core theory (arithmetic, pair)
cannot be rebuilt so: its ancestors are in the heap already.

Each run rebuilds the theory with HOL's Holmake on a fresh copy of its
directory, made under --out (tests/out/hol by default) with only the
theory's own outputs removed, under `perf stat` (unless --no-perf) and
/usr/bin/time. It prints per run HOL's own clock ("Theory ... took", from
new_theory to export_theory), and perf's task-clock (the whole Holmake),
cycles:u and instructions:u, and the largest resident set.

A HOL built by Rune (it has tools-rune) runs on the runevm it was built
with, or on --vm (with --vm-opts; a VM of the same instruction set restores
its images), and with a cache of units of the script's own: --cache, by
default a copy of HOL's tools-rune/cache made once under --out. Nothing is
ever written into HOL.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

# a theory's directory in HOL, by name
THEORIES = {"logroot": "src/num/extra_theories", "mergesort": "src/sort",
            "string": "src/string", "toto": "src/finite_maps"}


def fresh_copy(hol, directory, theory, work):
    """HOL's DIRECTORY copied to WORK, the theory's outputs removed, and a
    Holmakefile's relative HOLHEAP made absolute (its time kept, so that
    Holmake does not take it for an edit)."""
    src = os.path.join(hol, directory)
    if os.path.exists(work):
        shutil.rmtree(work)
    shutil.copytree(src, work, symlinks=True)
    objs = os.path.join(work, ".hol", "objs")
    if os.path.isdir(objs):
        for f in os.listdir(objs):
            if f.startswith(theory + "Theory."):
                os.remove(os.path.join(objs, f))
    hm = os.path.join(work, "Holmakefile")
    if os.path.exists(hm):
        txt = open(hm).read()
        new = re.sub(r"HOLHEAP\s*=\s*(\.\./\S+)",
                     lambda m: "HOLHEAP = " + os.path.normpath(os.path.join(src, m.group(1))), txt)
        if new != txt:
            st = os.stat(hm)
            with open(hm + ".tmp", "w") as f:
                f.write(new)
            os.replace(hm + ".tmp", hm)
            os.utime(hm, ns=(st.st_atime_ns, st.st_mtime_ns))


def main():
    ap = argparse.ArgumentParser(description="Rebuild one theory of HOL4 and time it.")
    ap.add_argument("hol", help="a built HOL4 tree")
    ap.add_argument("theory", help="logroot, mergesort, string, toto, or DIR:NAME")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--out", default="tests/out/hol")
    ap.add_argument("--vm", help="the runevm a HOL built by Rune runs on")
    ap.add_argument("--vm-opts", default="", help="options of that runevm")
    ap.add_argument("--cache", help="the cache of units of a HOL built by Rune")
    ap.add_argument("--no-perf", action="store_true", help="without perf stat")
    a = ap.parse_args()

    hol = os.path.abspath(a.hol)
    if ":" in a.theory:
        directory, theory = a.theory.split(":", 1)
    elif a.theory in THEORIES:
        directory, theory = THEORIES[a.theory], a.theory
    else:
        sys.exit(f"hol-theory: no theory {a.theory} (logroot, mergesort, string, toto, or DIR:NAME)")
    holmake = os.path.join(hol, "bin", "Holmake")
    if not os.path.exists(holmake):
        sys.exit(f"hol-theory: {holmake} is missing: HOL is not built")
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    label = os.path.basename(hol.rstrip("/"))
    env = dict(os.environ)
    if a.vm and not os.access(os.path.abspath(a.vm), os.X_OK):
        sys.exit(f"hol-theory: {a.vm} is not an executable VM")
    if os.path.isdir(os.path.join(hol, "tools-rune")):
        cache = os.path.abspath(a.cache) if a.cache else os.path.join(out, "cache-" + label)
        if not os.path.exists(cache):
            shutil.copytree(os.path.join(hol, "tools-rune", "cache"), cache, symlinks=True)
        env["RUNE_CACHE"] = cache
        if a.vm:
            env["RUNEVM"] = os.path.abspath(a.vm)
        if a.vm_opts:
            env["RUNEVM_OPTS"] = a.vm_opts
    elif a.vm or a.vm_opts or a.cache:
        sys.exit("hol-theory: --vm, --vm-opts and --cache are for a HOL built by Rune")

    tag = f"{label}-{theory}"
    work = os.path.join(out, "work", tag)
    for i in range(a.runs):
        fresh_copy(hol, directory, theory, work)
        perf_out = os.path.join(out, f"{tag}.{i}.perf")
        log = os.path.join(out, f"{tag}.{i}.log")
        cmd = ["/usr/bin/time", "-f", "MAXRSS %M KB", holmake, "--nolmbc", f"{theory}Theory.uo"]
        if not a.no_perf:
            cmd = ["perf", "stat", "-x", ",", "-e", "task-clock,cycles:u,instructions:u", "-o", perf_out, *cmd]
        with open(log, "w") as lf:
            r = subprocess.run(cmd, cwd=work, env=env, stdout=lf, stderr=subprocess.STDOUT)
        txt = open(log, errors="replace").read()
        hollog = os.path.join(work, ".hol", "logs", theory + "Theory")
        t = ""
        if os.path.exists(hollog):
            t = open(hollog, errors="replace").read()
            shutil.copy(hollog, os.path.join(out, f"{tag}.{i}.hollog"))
        took = re.findall(r'Theory "\w+" took ([0-9.]+)s', t)
        rss = re.findall(r"MAXRSS (\d+) KB", txt)
        stats = {}
        if not a.no_perf and os.path.exists(perf_out):
            for line in open(perf_out):
                p = line.strip().split(",")
                if len(p) > 3 and p[0] and p[0][0].isdigit():
                    stats[p[2].replace(":u", "")] = (p[0], p[1])
        clock = "?"
        if "task-clock" in stats:
            value, unit = stats["task-clock"]
            # perf prints it in milliseconds (msec), or in nanoseconds with no unit
            clock = "%.2f" % (float(value) / (1e3 if unit == "msec" else 1e9))
        print(f"{tag} run {i}: exit {r.returncode}, took {took[-1] if took else '?'} s, "
              f"task-clock {clock} s, cycles {stats.get('cycles', ('?',))[0]}, "
              f"instructions {stats.get('instructions', ('?',))[0]}, max RSS {rss[-1] if rss else '?'} KB", flush=True)
        if r.returncode != 0:
            sys.exit(f"hol-theory: Holmake failed: {log}")
        if not took:
            sys.exit(f"hol-theory: the theory was not rebuilt (no \"took\" in HOL's log): {log}")


if __name__ == "__main__":
    main()
