#!/usr/bin/env python3
"""The scores of a candidate VM against a baseline on the evaluation set.

    python3 scripts/gc-eval-score.py DIR

DIR is what scripts/gc-eval.sh made: the set it ran (set.tsv), and for each
run NAME the files runs/NAME/{candidate,baseline}-R.* of its rounds. For
each run the round with the least task-clock is taken, on each VM, and
compared (candidate / baseline, so below 1 is better):

  T  task-clock (perf's, or user + system time without perf)
  M  peak resident memory (/usr/bin/time's maximum resident set)
  P  the mean of three ratios: the longest pause, the 99th-percentile pause
     (a pause under 1 ms counts as 1 ms) and 1 - MMU at 10 ms on the wall
     clock (at least 0.01), from the --gc-log by tools/mmu.py. The set wrote
     the MMU part as the ratio of the MMUs, baseline / candidate, which has no
     value where the copier's MMU at 10 ms is 0, as it is on most runs: its
     complement is compared instead.

A group's ratio is the geometric mean of its runs', and a score the
geometric mean of the groups' weighted by the set's column. The M and P
columns of the set sum to 95, not 100, a slip found after the set was fixed;
the scores divide by the weight present, which is the same as scaling each
weight by 100/95, and also leaves out the groups not run. A run whose
candidate failed is left out of its group and named under the problems.

Checked beside the scores: every run exits 0; a program of examples/benchmarks
prints PASS; every run's standard output, and the compiler's output file, is
the baseline's; and the bytes and objects allocated (the log's end line) are
the same in every run of both VMs, since what a program allocates does not
depend on its collector (docs/testing.md).
"""
import filecmp
import glob
import math
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import mmu  # noqa: E402

WHO = ("candidate", "baseline")


def load_set(path):
    """[(group, (T, M, P), name, kind, arguments, expected)] in the set's order"""
    out = []
    for line in open(path):
        if line.startswith("#") or not line.strip():
            continue
        c = line.rstrip("\n").split("\t")
        out.append((c[0], (int(c[1]), int(c[2]), int(c[3])), c[4], c[5], c[6], c[7]))
    return out


def read(path):
    try:
        with open(path, errors="replace") as stream:
            return stream.read()
    except OSError:
        return None


def run(base):
    """one run's files as a dict; None when it was not made"""
    status = read(base + ".exit")
    if status is None:
        return None
    r = {"base": base, "exit": status.strip(), "time": None, "tc": None, "instructions": None}
    t = read(base + ".time")
    if t and t.strip():
        u, s, e, m = t.strip().splitlines()[-1].split()[:4]
        r["time"] = (float(u), float(s), float(e), int(m))
        r["tc"] = float(u) + float(s)
    for line in (read(base + ".perf") or "").splitlines():
        parts = line.split(",")
        if len(parts) > 2 and parts[0][:1].isdigit():
            event = parts[2].split(":")[0]
            if event == "task-clock":   # in ns, or in ms where the unit says msec
                r["tc"] = float(parts[0]) / (1e3 if parts[1] == "msec" else 1e9)
            elif event == "instructions":
                r["instructions"] = float(parts[0])
    log = base + ".gclog"
    r["gc"] = mmu.analyse(log, r["time"][2] if r["time"] else None) if os.path.exists(log) and os.path.getsize(log) else None
    return r


def best(runs):
    ok = [r for r in runs if r["exit"] == "0" and r["tc"] is not None]
    return min(ok, key=lambda r: r["tc"]) if ok else None


def metrics(r):
    """task-clock s, peak RSS MiB, longest ms, p99 ms, 1 - MMU(10), pauses, MB copied"""
    g = r["gc"]
    m = {"tc": r["tc"], "rss": r["time"][3] / 1024 if r["time"] else None}
    if g:
        m10 = g["mmu_wall"].get(10)
        m.update(longest=g["longest_ns"] / 1e6, p99=g["p99_ns"] / 1e6, gcfrac=None if m10 is None else 1 - m10,
                 pauses=g["pauses"], copied=g["copied"] / 1e6, clock=g["wall_clock"])
    else:
        m.update(longest=None, p99=None, gcfrac=None, pauses=None, copied=None, clock=None)
    return m


def ratio(a, b, floor):
    if a is None or b is None:
        return None
    return max(a, floor) / max(b, floor)


def ratios(c, b):
    t = ratio(c["tc"], b["tc"], 1e-3)
    m = ratio(c["rss"], b["rss"], 1e-3)
    parts = [x for x in (ratio(c["longest"], b["longest"], 1.0), ratio(c["p99"], b["p99"], 1.0),
                         ratio(c["gcfrac"], b["gcfrac"], 0.01)) if x is not None]
    return t, m, (sum(parts) / len(parts) if parts else None)


def geomean(xs):
    xs = [x for x in xs if x]
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else None


def f3(x):
    return "-" if x is None else "%.3f" % x


def pair(b, c, fmt):
    return "-" if b is None or c is None else (fmt % b) + " -> " + (fmt % c)


def checks(name, kind, expected, runs, problems):
    """the run's correctness against the baseline's, into PROBLEMS"""
    every = [(who, r) for who in WHO for r in runs[who]]
    for who, r in every:
        if r["exit"] != "0":
            problems.append("%s: the %s's run %s exited %s (%s)" % (name, who, os.path.basename(r["base"]), r["exit"],
                                                                   (read(r["base"] + ".stderr") or "").strip()[-200:]))
        elif kind == "bench":
            text = read(r["base"] + ".stdout") or ""
            if not re.search(r"^PASS ", text, re.M):
                problems.append("%s: the %s's run %s did not print PASS: %s" % (
                    name, who, os.path.basename(r["base"]), " ".join(text.split()[:12])))
    ok = [(who, r) for who, r in every if r["exit"] == "0"]
    if not ok:
        return
    ref = next(((w, r) for w, r in ok if w == "baseline"), ok[0])
    stdout = read(ref[1]["base"] + ".stdout")
    output = ref[1]["base"] + ".output"
    counts = None
    if ref[1]["gc"] and ref[1]["gc"]["bytes_allocated"] is not None:
        counts = (ref[1]["gc"]["bytes_allocated"], ref[1]["gc"]["objects_allocated"])
    for who, r in ok:
        label = "%s %s" % (who, os.path.basename(r["base"]))
        if read(r["base"] + ".stdout") != stdout:
            problems.append("%s: the standard output of %s is not that of %s" % (name, label, os.path.basename(ref[1]["base"])))
        mine = r["base"] + ".output"
        if os.path.exists(output) and (not os.path.exists(mine) or not filecmp.cmp(output, mine, shallow=False)):
            problems.append("%s: the output file of %s is not that of %s" % (name, label, os.path.basename(ref[1]["base"])))
        g = r["gc"]
        if counts and g and g["bytes_allocated"] is not None and (g["bytes_allocated"], g["objects_allocated"]) != counts:
            problems.append("%s: %s allocated %d bytes and %d objects, where %s allocated %d and %d" % (
                name, label, g["bytes_allocated"], g["objects_allocated"], os.path.basename(ref[1]["base"]), counts[0], counts[1]))


def main(argv):
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    d = argv[0]
    setfile = os.path.join(d, "set.tsv")
    if not os.path.exists(setfile):
        setfile = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gc-eval.tsv")
    meta = dict(line.rstrip("\n").split(" ", 1) for line in open(os.path.join(d, "meta")) if " " in line) if os.path.exists(os.path.join(d, "meta")) else {}
    problems, clocks, rows, groups = [], set(), [], {}
    order = []
    for group, weights, name, kind, args, expected in load_set(setfile):
        runs = {}
        for who in WHO:
            files = sorted(glob.glob(os.path.join(d, "runs", name, who + "-*.exit")),
                           key=lambda p: int(re.search(r"-(\d+)\.exit$", p).group(1)))
            runs[who] = [x for x in (run(p[:-5]) for p in files) if x]
        if not runs["candidate"] and not runs["baseline"]:
            continue
        if group not in groups:
            groups[group] = {"weights": weights, "ratios": [], "runs": 0}
            order.append(group)
        groups[group]["runs"] += 1
        checks(name, kind, expected, runs, problems)
        c, b = best(runs["candidate"]), best(runs["baseline"])
        rounds = "%d/%d" % (len(runs["candidate"]), len(runs["baseline"]))
        longest = [r["gc"]["longest_ns"] / 1e6 for who in WHO for r in runs[who] if r["exit"] == "0" and r["gc"]]
        if longest:
            rounds = "%.1f-%.1f" % (min(longest), max(longest)) + " | " + rounds
        else:
            rounds = "- | " + rounds
        if not c or not b:
            rows.append((group, name, None, None, None, rounds))
            continue
        mc, mb = metrics(c), metrics(b)
        clocks.update(x for x in (mc["clock"], mb["clock"]) if x)
        rt, rm, rp = ratios(mc, mb)
        groups[group]["ratios"].append((rt, rm, rp))
        rows.append((group, name, (rt, rm, rp), mb, mc, rounds))

    print("# gc-eval: %s against %s" % (meta.get("candidate", "the candidate"), meta.get("baseline", "the baseline")))
    print()
    print("%s rounds, %s; revision %s; %s; task-clock from %s. The wall clock of the pauses: %s." % (
        meta.get("rounds", "?"), meta.get("date", "?"), meta.get("revision", "?"), meta.get("machine", "?"),
        "perf" if meta.get("perf") == "1" else "user + system time", "; ".join(sorted(clocks)) or "-"))
    print()
    print("Ratios are candidate / baseline of each run's round with the least task-clock (below 1 is better); "
          "the other columns are baseline -> candidate of those rounds. A pause varies from round to round "
          "(the first touch of a new space, the host): the range of the longest over every round of both VMs "
          "is beside them.")
    print()
    print("| Run | T | M | P | Task-clock s | Peak RSS MiB | Longest ms | p99 ms | 1-MMU(10) | Pauses | Copied MB | Longest ms, every round | Rounds |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    shown = None
    for group, name, rs, mb, mc, rounds in rows:
        if group != shown:
            w = groups[group]["weights"]
            print("| **%s** (%s) | | | | | | | | | | | | |" % (group, "weights %d/%d/%d" % w if any(w) else "not weighted"))
            shown = group
        if rs is None:
            print("| %s | - | - | - | (no successful run on %s) | | | | | | | %s |" % (
                name, "both VMs" if mb is None and mc is None else "one VM", rounds))
            continue
        print("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            name, f3(rs[0]), f3(rs[1]), f3(rs[2]), pair(mb["tc"], mc["tc"], "%.2f"), pair(mb["rss"], mc["rss"], "%.1f"),
            pair(mb["longest"], mc["longest"], "%.1f"), pair(mb["p99"], mc["p99"], "%.2f"), pair(mb["gcfrac"], mc["gcfrac"], "%.3f"),
            pair(mb["pauses"], mc["pauses"], "%d"), pair(mb["copied"], mc["copied"], "%.0f"), rounds))
    print()

    weighted = [(name, rs) for group, name, rs, _, _, _ in rows if rs and any(groups[group]["weights"])]
    print("## The worst cases")
    print()
    for k, label in enumerate(("T", "M", "P")):
        worst = sorted((rs[k], name) for name, rs in weighted if rs[k] is not None)[::-1][:5]
        print("* %s: %s" % (label, ", ".join("%s %.3f" % (n, x) for x, n in worst) or "-"))
    over = [(name, k) for name, rs in weighted for k, label in ((0, "T"), (1, "M")) if rs[k] is not None and rs[k] > 1.10]
    print("* More than 1.10 in T or M (D1 holds every run of the set to 1.10): %s" % (
        ", ".join("%s (%s %.3f)" % (n, "TM"[k], dict(weighted)[n][k]) for n, k in over) or "none"))
    print()

    print("## The scores")
    print()
    print("| Group | T | M | P | Weights T/M/P | Runs scored |")
    print("|---|---:|---:|---:|---|---:|")
    total = {k: [0.0, 0] for k in "TMP"}
    for group in order:
        g = groups[group]
        rs = [geomean([x[k] for x in g["ratios"]]) for k in range(3)]
        print("| %s | %s | %s | %s | %d/%d/%d | %d of %d |" % (group, f3(rs[0]), f3(rs[1]), f3(rs[2]), *g["weights"], len(g["ratios"]), g["runs"]))
        for k, key in enumerate("TMP"):
            if rs[k] and g["weights"][k]:
                total[key][0] += g["weights"][k] * math.log(rs[k])
                total[key][1] += g["weights"][k]
    score = {k: math.exp(v[0] / v[1]) if v[1] else None for k, v in total.items()}
    print("| **score** | **%s** | **%s** | **%s** | present: %d/%d/%d | |" % (
        f3(score["T"]), f3(score["M"]), f3(score["P"]), total["T"][1], total["M"][1], total["P"][1]))
    print()
    print("Each score is the weighted geometric mean of the groups present, divided by the weight present "
          "(T %d, M %d, P %d of the set's 100, 95 and 95: the set's M and P columns sum to 95, a slip found after it was "
          "fixed, so a full run divides those two by 95)." % (total["T"][1], total["M"][1], total["P"][1]))
    print()
    print("## Problems")
    print()
    for p in problems:
        print("* " + p)
    if not problems:
        print("None: every run exited 0, every program of examples/benchmarks printed PASS, and every output and "
              "every count of bytes and objects allocated is the baseline's.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
