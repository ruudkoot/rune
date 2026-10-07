#!/usr/bin/env python3
"""Pauses and minimum mutator utilisation from a collector log.

    python3 tools/mmu.py [--wall S] [--windows LIST] [--passes] [--json | --row [--label NAME]] LOG...
    python3 tools/mmu.py --row-header
    python3 tools/mmu.py --self-test

LOG is what `runevm --gc-log LOG` writes: one line per pass of the
collector, the column names on the second '#' line, and '# end' and
'# wall_ns' lines at exit (docs/runtime.md). The columns are found by name,
so a log with more columns than these reads the same; the ones used are
kind, vmgc, bytes, instrs, copied, promoted, live_after, heap_size,
pause_ns, cpu_ns, rss_bytes and, when there, t_ns.

A pause is what the program sees: the passes of one vm_gc call together (a
copier that grows its heap collects twice in one call), from the first
pass's start to the last one's end; --passes makes every pass a pause. For
each log it prints the passes and pauses, what was allocated, copied and
promoted, the most live data after a collection and the heap at its
largest, the collector's total time and share of the run, the longest
pause, the mean and the 50th, 90th, 99th and 99.9th percentiles (nearest
rank), a histogram of the pauses, and the minimum mutator utilisation (MMU:
of all windows of a length, the least share left to the program; Cheng and
Blelloch, PLDI 2001) at windows of 1, 2, 5, 10, 20, 50, 100 and 200 ms, on
two clocks:

  wall   CLOCK_MONOTONIC, which the log's pause_ns and t_ns are read from
         (never the program's Time.now, which a virtual machine may step).
         Exact when the log has t_ns, the start of each pass since the log
         was opened; the run ends at '# wall_ns', or at --wall S, or at the
         last pause. Without t_ns the mutator's time (the run's, from
         '# wall_ns' or --wall, less the pauses) is shared out between the
         collections in proportion to the instructions run: an estimate.
  instr  the instruction clock: each collection falls where its instruction
         count (column instrs, the same in every run of one engine) puts it,
         the mutator runs at its mean rate, and each pause keeps its
         measured length. It takes the mutator's own noise out of the
         timeline, so where the pauses fall is repeatable.

A window longer than the run has no MMU ('-'). --json prints one JSON
object per log, --row one Markdown row (the columns of --row-header).
--self-test checks the MMU against closed forms and a brute-force scan.
"""
import bisect
import json
import math
import os
import random
import sys

WINDOWS_MS = [1, 2, 5, 10, 20, 50, 100, 200]
HISTOGRAM_MS = [0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]


def parse(path):
    """The log's header settings, its end line, its wall_ns and its passes."""
    head, end, wall_ns, passes, cols = {}, {}, None, [], None
    with open(path) as stream:
        for line in stream:
            words = line.split()
            if not words:
                continue
            if words[0].startswith("#"):
                words = (words[0][1:].split() if words[0] != "#" else []) + words[1:]
                if not words:
                    continue
                if words[0] == "rune-gc-log":
                    head["version"] = words[1] if len(words) > 1 else "?"
                    for w in words[2:]:
                        k, _, v = w.partition("=")
                        head[k] = int(v) if v.isdigit() else v
                elif words[0] == "seq":
                    cols = words
                elif words[0] == "end":
                    for k, v in zip(words[1::2], words[2::2]):
                        end[k] = int(v) if v.isdigit() else v
                elif words[0] == "wall_ns" and len(words) > 1:
                    wall_ns = int(words[1])
                continue
            if cols is None:
                raise ValueError("%s: a collection before the column names" % path)
            passes.append({k: (v if k == "kind" else int(v)) for k, v in zip(cols, words)})
    return head, end, wall_ns, passes


def pauses_of(passes, per_pass):
    """[(start ns or None, end ns or None, info)], one per vm_gc call (or pass)"""
    groups = []
    for p in passes:
        if not per_pass and groups and groups[-1][-1]["vmgc"] == p["vmgc"]:
            groups[-1].append(p)
        else:
            groups.append([p])
    out = []
    for g in groups:
        info = {"kind": "+".join(sorted(set(p["kind"] for p in g))), "passes": len(g),
                "pause_ns": sum(p["pause_ns"] for p in g), "instrs": g[0]["instrs"]}
        if "t_ns" in g[0]:
            out.append((g[0]["t_ns"], g[-1]["t_ns"] + g[-1]["pause_ns"], info))
        else:
            out.append((None, None, info))
    return out


def instruction_timeline(pauses, instrs, mutator_ns):
    """The pauses placed by their instruction counts, the mutator at its
    mean rate: (intervals, the end of the run), in ns."""
    rate = instrs / mutator_ns if mutator_ns > 0 else 1.0
    out, before = [], 0
    for _, _, info in pauses:
        start = info["instrs"] / rate + before
        out.append((start, start + info["pause_ns"]))
        before += info["pause_ns"]
    return out, instrs / rate + before


def mmu(intervals, total, window):
    """The least share of any window of WINDOW within [0, TOTAL] that the
    sorted, disjoint INTERVALS (the pauses) leave to the mutator. The
    collector's time in a window is piecewise linear in where the window
    starts, so it is largest where the window starts at a pause's start or
    ends at a pause's end (or at an end of the run): only those are tried."""
    if window <= 0 or window > total:
        return None
    if not intervals:
        return 1.0
    starts = [a for a, _ in intervals]
    ends = [b for _, b in intervals]
    prefix = [0.0]
    for a, b in intervals:
        prefix.append(prefix[-1] + (b - a))

    def collector(lo, hi):
        i = bisect.bisect_right(ends, lo)        # the first pause ending after lo
        j = bisect.bisect_left(starts, hi) - 1   # the last one starting before hi
        if j < i:
            return 0.0
        s = prefix[j + 1] - prefix[i]
        if starts[i] < lo:
            s -= lo - starts[i]
        if ends[j] > hi:
            s -= ends[j] - hi
        return s

    last = total - window
    tries = {0.0, last}
    for a, b in intervals:
        tries.add(min(max(a, 0.0), last))
        tries.add(min(max(b - window, 0.0), last))
    return max(0.0, min(1.0 - collector(lo, lo + window) / window for lo in tries))


def percentile(ordered, q):
    """nearest rank"""
    if not ordered:
        return 0
    return ordered[max(0, min(len(ordered) - 1, int(math.ceil(q * len(ordered))) - 1))]


def histogram(pauses_ms):
    counts = [0] * (len(HISTOGRAM_MS) + 1)
    for p in pauses_ms:
        counts[bisect.bisect_right(HISTOGRAM_MS, p)] += 1
    labels = ["%g-%g ms" % (lo, hi) for lo, hi in zip([0] + HISTOGRAM_MS, HISTOGRAM_MS)] + [">%g ms" % HISTOGRAM_MS[-1]]
    return list(zip(labels, counts))


def analyse(path, wall_s=None, windows=WINDOWS_MS, per_pass=False):
    """Everything this tool reports of one log, as a dict (--json's)."""
    head, end, wall_ns, passes = parse(path)
    pauses = pauses_of(passes, per_pass)
    lengths = [info["pause_ns"] for _, _, info in pauses]
    gc_ns = sum(lengths)
    instrs = end.get("instrs") or (passes[-1]["instrs"] if passes else 0)
    exact = bool(passes) and "t_ns" in passes[0]
    if wall_ns is None and wall_s is not None:
        wall_ns = int(wall_s * 1e9)

    if not passes:
        wall_iv, wall_total, clock = [], wall_ns or 0, "no collections"
    elif exact:
        wall_iv = [(a, b) for a, b, _ in pauses]
        wall_total = max([wall_ns or 0] + [b for _, b in wall_iv])
        clock = "exact (t_ns)"
    elif wall_ns:
        wall_iv, wall_total = instruction_timeline(pauses, instrs, max(wall_ns - gc_ns, 1))
        clock = "estimated (no t_ns: the mutator's time shared out by instructions)"
    else:
        wall_iv, wall_total = None, None
        clock = "unknown (no t_ns, no wall_ns, no --wall)"
    run_ns = wall_total if wall_total else None

    mutator_ns = max(run_ns - gc_ns, 1) if run_ns else None
    if mutator_ns and instrs:
        instr_iv, instr_total = instruction_timeline(pauses, instrs, mutator_ns)
    else:
        instr_iv, instr_total = None, None

    ordered = sorted(lengths)
    res = {
        "log": path,
        "header": head,
        "passes": len(passes),
        "pauses": len(pauses),
        "kinds": {k: sum(1 for p in passes if p["kind"] == k) for k in sorted(set(p["kind"] for p in passes))},
        "bytes_allocated": end.get("bytes"),
        "objects_allocated": end.get("objects"),
        "instructions": instrs,
        "copied": sum(p.get("copied", 0) for p in passes),
        "promoted": sum(p.get("promoted", 0) for p in passes),
        "max_live_after": max((p.get("live_after", 0) for p in passes), default=0),
        "max_heap_size": max((p.get("heap_size", 0) for p in passes), default=0),
        "final_heap_size": passes[-1].get("heap_size", 0) if passes else 0,
        "max_rss_at_gc": max((p.get("rss_bytes", 0) for p in passes), default=0),
        "vmpeak_kb": end.get("vmpeak_kb"),
        "vmhwm_kb": end.get("vmhwm_kb"),
        "complete": bool(end),
        "gc_ns": gc_ns,
        "cpu_ns": sum(p.get("cpu_ns", 0) for p in passes),
        "run_ns": run_ns,
        "wall_clock": clock,
        "gc_share": gc_ns / run_ns if run_ns else None,
        "longest_ns": ordered[-1] if ordered else 0,
        "mean_ns": gc_ns / len(ordered) if ordered else 0,
        "p50_ns": percentile(ordered, 0.50),
        "p90_ns": percentile(ordered, 0.90),
        "p99_ns": percentile(ordered, 0.99),
        "p999_ns": percentile(ordered, 0.999),
        "histogram": histogram([p / 1e6 for p in lengths]),
        "mmu_wall": {},
        "mmu_instr": {},
    }
    for w in windows:
        res["mmu_wall"][w] = mmu(wall_iv, wall_total, w * 1e6) if wall_iv is not None else None
        res["mmu_instr"][w] = mmu(instr_iv, instr_total, w * 1e6) if instr_iv is not None else None
    return res


def ms(ns):
    return "%.3f" % (ns / 1e6)


def share(v):
    return "-" if v is None else "%.3f" % v


def text(res, windows):
    o = ["log: %s" % res["log"],
         "passes %d, pauses (vm_gc calls) %d, kinds %s" % (res["passes"], res["pauses"], res["kinds"])]
    if res["bytes_allocated"] is not None:
        o.append("allocated %d bytes, %s objects, %d instructions" % (res["bytes_allocated"], res["objects_allocated"], res["instructions"]))
    else:
        o.append("no '# end' line: the run did not exit normally")
    o.append("copied %d bytes, promoted %d; live after a collection at most %d; heap at most %d, at the end %d"
             % (res["copied"], res["promoted"], res["max_live_after"], res["max_heap_size"], res["final_heap_size"]))
    o.append("resident at a collection at most %d bytes; VmPeak %s kB, VmHWM %s kB" % (res["max_rss_at_gc"], res["vmpeak_kb"], res["vmhwm_kb"]))
    run = "" if res["run_ns"] is None else " (%.1f%% of a run of %.3f s)" % (100 * res["gc_share"], res["run_ns"] / 1e9)
    o.append("collector: %s ms in pauses%s; %s ms of processor time" % (ms(res["gc_ns"]), run, ms(res["cpu_ns"])))
    o.append("pauses: longest %s ms, mean %s, p50 %s, p90 %s, p99 %s, p99.9 %s ms"
             % (ms(res["longest_ns"]), ms(res["mean_ns"]), ms(res["p50_ns"]), ms(res["p90_ns"]), ms(res["p99_ns"]), ms(res["p999_ns"])))
    o.append("histogram:")
    o.extend("  %-16s %d" % (label, n) for label, n in res["histogram"] if n)
    o.append("MMU (window: wall | instr); the wall clock is %s" % res["wall_clock"])
    o.extend("  %5g ms: %s | %s" % (w, share(res["mmu_wall"][w]), share(res["mmu_instr"][w])) for w in windows)
    return "\n".join(o)


ROW = ["workload", "pauses", "copied MB", "max live MB", "heap MB", "GC ms", "longest ms", "p50 ms", "p90 ms", "p99 ms",
       "MMU 1", "MMU 10", "MMU 50", "MMU 100", "MMU 10 (instr)", "MMU 50 (instr)"]


def row(res, label):
    def mb(b):
        return "%.1f" % (b / 1e6)
    w, i = res["mmu_wall"], res["mmu_instr"]
    cells = [label, str(res["pauses"]), mb(res["copied"]), mb(res["max_live_after"]), mb(res["max_heap_size"]),
             "%.1f" % (res["gc_ns"] / 1e6), ms(res["longest_ns"]), ms(res["p50_ns"]), ms(res["p90_ns"]), ms(res["p99_ns"]),
             share(w.get(1)), share(w.get(10)), share(w.get(50)), share(w.get(100)), share(i.get(10)), share(i.get(50))]
    return "| " + " | ".join(cells) + " |"


def self_test():
    """closed forms, then 300 random cases against a scan at a fine step"""
    def near(a, b):
        return a is not None and abs(a - b) < 1e-9
    checks = [
        (mmu([], 10.0, 5.0), 1.0),
        (mmu([(4.0, 5.0)], 10.0, 1.0), 0.0),
        (mmu([(4.0, 5.0)], 10.0, 2.0), 0.5),
        (mmu([(4.0, 5.0)], 10.0, 10.0), 0.9),
        (mmu([(0.0, 1.0)], 10.0, 4.0), 0.75),
        (mmu([(9.0, 10.0)], 10.0, 4.0), 0.75),
        (mmu([(1.0, 2.0), (3.0, 4.0)], 10.0, 3.0), 1 / 3),
        (mmu([(1.0, 2.0), (3.0, 4.0)], 10.0, 4.0), 0.5),
        (mmu([(1.0, 2.0), (6.0, 7.0)], 10.0, 4.0), 0.75),
    ]
    bad = [n for n, (got, want) in enumerate(checks) if not near(got, want)]
    if mmu([(4.0, 5.0)], 10.0, 11.0) is not None:
        bad.append("window longer than the run")
    rng = random.Random(1)
    for case in range(300):
        total = 100.0
        cuts = sorted(rng.choice(range(1, 100)) for _ in range(2 * rng.randint(1, 6)))
        intervals = [(float(a), float(b)) for a, b in zip(cuts[0::2], cuts[1::2]) if b > a]
        window = float(rng.randint(1, 60))
        steps = [k / 4 for k in range(int((total - window) * 4) + 1)]
        scan = min(1 - sum(max(0.0, min(b, lo + window) - max(a, lo)) for a, b in intervals) / window for lo in steps)
        if not near(mmu(intervals, total, window), scan):
            bad.append("random case %d" % case)
    if bad:
        print("mmu.py: self-test FAILED: %s" % bad)
        return 1
    print("mmu.py: self-test OK (%d closed forms, 300 random cases against a scan)" % len(checks))
    return 0


def main(argv):
    wall_s, windows, mode, per_pass, label, logs = None, WINDOWS_MS, "text", False, None, []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--wall", "--windows", "--label") and i + 1 >= len(argv):
            print("mmu.py: %s needs a value" % a, file=sys.stderr)
            return 2
        if a == "--wall":
            wall_s = float(argv[i + 1]); i += 1
        elif a == "--windows":
            windows = [float(x) if "." in x else int(x) for x in argv[i + 1].split(",")]; i += 1
        elif a == "--label":
            label = argv[i + 1]; i += 1
        elif a in ("--json", "--row"):
            mode = a[2:]
        elif a == "--passes":
            per_pass = True
        elif a == "--row-header":
            print("| " + " | ".join(ROW) + " |")
            print("|---|" + "---:|" * (len(ROW) - 1))
            return 0
        elif a == "--self-test":
            return self_test()
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        elif a.startswith("-"):
            print("mmu.py: unknown option %s" % a, file=sys.stderr)
            return 2
        else:
            logs.append(a)
        i += 1
    if not logs:
        print(__doc__, file=sys.stderr)
        return 2
    for n, path in enumerate(logs):
        res = analyse(path, wall_s, windows, per_pass)
        if mode == "json":
            print(json.dumps(res))
        elif mode == "row":
            print(row(res, label or os.path.basename(path)))
        else:
            print(("\n" if n else "") + text(res, windows))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
