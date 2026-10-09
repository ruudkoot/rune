#!/usr/bin/env python3
"""report.py -- the Markdown tables of the roadmap's gcbench-H*.md and
gcbench-fragmentation.md (docs/plans/garbage-collector-v2.md, *The
harness*) from measure.sh's merged rows (Python 3, for the tables only).

    report.py [OUTDIR [RESULTSDIR]]

OUTDIR holds measure.sh's NAME.tsv and NAME.log (tests/out/gcbench), with
the names roadmap.sh gives them; every table whose input is there is
written into RESULTSDIR (OUTDIR/report). ns are cycles over the core's
clock, GCB_CORE_GHZ (3.3: the reference machine's, measured by H10 as a
4-cycle L1 hit in 1.21 ns of TSC time)."""
import os, re, sys
from tables import rows

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "gcbench")
RES = sys.argv[2] if len(sys.argv) > 2 else os.path.join(OUT, "report")
CORE_GHZ = float(os.environ.get("GCB_CORE_GHZ", "3.3"))

def log_head(name):
    """the command and the loads of a run, from NAME.log"""
    p = os.path.join(OUT, name + ".log")
    if not os.path.exists(p):
        return "", [], False
    lines = open(p).read().splitlines()
    cmd = lines[0].lstrip("# ") if lines else ""
    loads = [float(m.group(1)) for l in lines for m in [re.search(r"starts at load ([\d.]+)", l)] if m]
    under = any("UNDER LOAD" in l for l in lines)
    return cmd, loads, under

def provenance(names):
    s = []
    for n in names:
        cmd, loads, under = log_head(n)
        if not cmd:
            continue
        lo = ("loads at start %.2f-%.2f" % (min(loads), max(loads))) if loads else ""
        s.append("- `%s`%s%s" % (cmd.split(" measure.sh ", 1)[-1] if " measure.sh " in cmd else cmd, (" (" + lo + ")") if lo else "",
                                 " **UNDER LOAD**" if under else ""))
    return "\n".join(s)

def get(name, evset="mem"):
    p = os.path.join(OUT, name + ".tsv")
    return rows(p, evset) if os.path.exists(p) else []

def table(head, body):
    out = ["| " + " | ".join(head) + " |", "|" + "|".join(["---"] + ["---:"] * (len(head) - 1)) + "|"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in body]
    return "\n".join(out)

def write(fname, text):
    os.makedirs(RES, exist_ok=True)
    with open(os.path.join(RES, fname), "w") as f:
        f.write(text.rstrip() + "\n")
    print("wrote", os.path.join(RES, fname))

# ---------------------------------------------------------------- H10
def h10():
    l3 = get("h10-l3") + get("h10-l3b")
    lat = get("h10-lat") + [r for r in l3 if r["case"].startswith("lat/")]
    bw = get("h10-bw")
    if not lat:
        return
    t = ["# gcbench H10: latency and bandwidth baselines", "",
         "Made by tests/gcbench, `gcbench h10`; one core (taskset -c 5), the least of 5 processes,",
         "each the least of 5 repetitions. Xeon E5-1680 v3 under WSL2 (Hyper-V). Core clock as measured: %.1f GHz" % CORE_GHZ,
         "(cycles are core cycles:u; ns are TSC time at 3.1926 GHz).", "", provenance(["h10-lat", "h10-l3", "h10-l3b", "h10-bw"]), "",
         "## A dependent load (a random cyclic chain over the lines of a buffer)", "",
         "`lat`: every load to a random line of the buffer (a TLB miss for nearly every load past 4 MiB with 4K",
         "pages). `latpg`: the same lines page by page (the 64 lines of a page in a random order, the pages in a",
         "random order): a TLB miss every 64 loads. 2M: the buffer in transparent huge pages (granted, AnonHugePages).", ""]
    seen = {}
    for r in lat + [x for x in l3 if x["case"].startswith("latpg")]:
        seen[r["case"]] = r
    def key(c):
        kind, pg, size = c.split("/")
        mult = {"K": 1 << 10, "M": 1 << 20, "G": 1 << 30}
        m = re.match(r"([\d.]+)([KMG])", size)
        return (kind, pg, float(m.group(1)) * mult[m.group(2)])
    body = []
    for c in sorted(seen, key=key):
        r = seen[c]
        body.append([c, "%.1f" % r["cyc"], "%.1f" % r["ns"], "%.2f" % r["l1d_repl"], "%.2f" % r["l2_miss"], "%.2f" % r["llc_miss"],
                     "%.2f" % r["dtlb_ld_walk"], "%.0f%%" % (100 * r["spread"])])
    t.append(table(["case", "cycles/load", "ns/load", "L1D repl.", "L2 miss", "LLC miss", "dTLB walks", "spread"], body))
    if bw:
        t += ["", "## Bandwidth (memcpy of a buffer into another, memset, a sum of 64-bit words)", ""]
        body = [[r["case"], "%.3f" % r["cyc"], "%.3f" % r["ns"], "%.1f" % (1 / r["ns"]), "%.4f" % r["l2_miss"], "%.4f" % r["llc_miss"],
                 "%.0f%%" % (100 * r["spread"])] for r in bw]
        t.append(table(["case", "cycles/byte", "ns/byte", "GB/s", "L2 miss/byte", "LLC miss/byte", "spread"], body))
    write("gcbench-H10.md", "\n".join(t))

# ---------------------------------------------------------------- H2
def fit(pts):
    n = len(pts); xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    mx = sum(xs) / n; my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx if sxx else 0
    return my - b * mx, b

def h2():
    rs = get("h2-small") + get("h2-big")
    if not rs:
        return
    t = ["# gcbench H2: copying and marking, per object and per byte", "",
         "Made by tests/gcbench, `gcbench h2`: heapgen.h's heaps traced by collect.h's loops (value.h's objects;",
         "runtime/heap.c's copy_obj). One core, the least of 5 processes (3 for 128M), each the least of 5 repetitions",
         "(3 for 128M); a repetition traces 8 MiB at least. Shapes: list (one pointer, the rest immediates), tree",
         "(two children), graph (a chain and a random pointer), array (every field a pointer, all but one random).",
         "alloc: placed in creation order; shuf: placed at random. live: the bytes reachable (copying needs twice).", "",
         provenance(["h2-small", "h2-big"]), "",
         "## The fit: cycles per object = a + b x size (bytes), least squares over the sizes", "",
         "ns = cycles / %.1f GHz. b includes the scan of the fields (one test a word)." % CORE_GHZ, ""]
    groups = {}
    for r in rs:
        m = re.match(r"([^/]+)/([^/]+)/(\d+)/([^/]+)/([^/]+)$", r["case"])
        if m:
            g, shape, size, order, live = m.groups()
            groups.setdefault((live, shape, order, g), []).append((int(size), r["cyc"], r))
    order_live = {"32K": 0, "1M": 1, "128M": 2}
    body = []
    for k in sorted(groups, key=lambda k: (order_live.get(k[0], 9), k[1], k[2], k[3])):
        pts = sorted(groups[k])
        if len(pts) < 2:
            continue
        a, b = fit([(p[0], p[1]) for p in pts])
        c32 = [p for p in pts if p[0] == 32]
        r32 = c32[0][2] if c32 else pts[0][2]
        body.append([k[0], k[1], k[2], k[3], "%.1f" % a, "%.3f" % b, "%.1f" % (a / CORE_GHZ), "%.3f" % (b / CORE_GHZ),
                     "%.1f" % r32["cyc"], "%.0f" % r32["ins"], "%.2f" % r32["l1d_repl"], "%.2f" % r32["l2_miss"], "%.2f" % r32["llc_miss"],
                     "%.2f" % r32["dtlb_ld_walk"]])
    t.append(table(["live", "shape", "order", "collector", "a cyc/obj", "b cyc/B", "a ns/obj", "b ns/B", "cyc/obj @32B",
                    "ins/obj @32B", "L1D @32B", "L2 miss @32B", "LLC miss @32B", "dTLB @32B"], body))
    t += ["", "## Every row (cycles, instructions and misses per object)", ""]
    body = [[r["case"], "%.1f" % r["cyc"], "%.0f" % r["ins"], "%.2f" % r["l1d_repl"], "%.2f" % r["l2_miss"], "%.2f" % r["llc_miss"],
             "%.2f" % r["dtlb_ld_walk"], "%.0f%%" % (100 * r["spread"])] for r in rs]
    t.append(table(["case (collector/shape/size/order/live)", "cyc/obj", "ins/obj", "L1D repl.", "L2 miss", "LLC miss", "dTLB walks", "spread"], body))
    write("gcbench-H2.md", "\n".join(t))

# ---------------------------------------------------------------- H8
def h8():
    rs = get("h8")
    if not rs:
        return
    t = ["# gcbench H8: the stack as roots, per frame and per slot", "",
         "Made by tests/gcbench, `gcbench h8`: runtime/heap.c's stack_roots over the VM's Frame and value",
         "stack, the liveness by runtime/register/live.c:123's binary search (live), a global hash on the return pc",
         "(hash), the binary search and no branch on a slot's data (bits), or every slot a root (all). Registers that",
         "hold pointers are fixed per function (half of them); a tenth of the pointers are young. One core, the least",
         "of 3 processes, each the least of 5 repetitions. rets: return points a function; funcs: distinct functions",
         "on the stack (each with its own random live masks: 4096 is a stack the branch predictor cannot learn).", "",
         provenance(["h8"]), "", "## Per frame (cycles), by locals; the per-slot slope from 4 to 64 locals", ""]
    d = {}
    for r in rs:
        m = re.match(r"(\w+)/frames=(\w+)/locals=(\d+)/rets=(\d+)/funcs=(\d+)", r["case"])
        if m:
            how, fr, lo, re_, fu = m.groups()
            d[(fr, how, int(re_), int(fu), int(lo))] = r
    body = []
    for fr in ["100", "10K", "1M"]:
        for how in ["all", "live", "hash", "bits"]:
            for re_ in [4, 64, 1024]:
                for fu in [1, 64, 4096]:
                    pts = [(lo, d[(fr, how, re_, fu, lo)]["cyc"]) for lo in [4, 16, 64] if (fr, how, re_, fu, lo) in d]
                    if len(pts) < 3:
                        continue
                    a, b = fit(pts)
                    r16 = d[(fr, how, re_, fu, 16)]
                    body.append([fr, how, re_, fu] + ["%.0f" % p[1] for p in pts] + ["%.1f" % a, "%.2f" % b, "%.0f" % r16["ins"],
                                "%.2f" % r16["l2_miss"], "%.2f" % r16["llc_miss"]])
    t.append(table(["frames", "how", "rets", "funcs", "4 locals", "16 locals", "64 locals", "per frame (fit)", "per slot (fit)",
                    "ins @16", "L2 miss @16", "LLC miss @16"], body))
    write("gcbench-H8.md", "\n".join(t))


# ---------------------------------------------------------------- generic per-row tables
def rowtable(name, title, intro, cols=("cyc", "ins", "l1d_repl", "l2_miss", "llc_miss", "dtlb_ld_walk"), extra=None, evset="mem", grep=None, names=None):
    rs = []
    for n in (names or [name]):
        rs += get(n, evset)
    if grep:
        rs = [r for r in rs if re.search(grep, r["case"])]
    if not rs:
        return None
    body = [[r["case"], r["unit"]] + ["%.2f" % r.get(c, float("nan")) for c in cols] + ["%.1f" % r["ns"], "%.0f%%" % (100 * r["spread"])] for r in rs]
    t = ["# " + title, "", intro, "", provenance(names or [name]), "",
         table(["case", "unit"] + list(cols) + ["ns (TSC)", "spread"], body)]
    if extra:
        t += ["", extra]
    return "\n".join(t)

def h3():
    s = rowtable("h3", "gcbench H3/H4: mark bits in the header or a bitmap; clearing and sweeping",
                 "Made by tests/gcbench, `gcbench h3` (h3.c says what each case does). Per object of the heap (alloc-*: per object allocated);\n"
                 "N objects of SIZE bytes side by side, a share LIVE of them marked at random; one core, the least of 3 processes x 5 repetitions.")
    if s: write("gcbench-H3.md", s)

def h6():
    s = rowtable("h6", "gcbench H6: write barriers",
                 "Made by tests/gcbench, `gcbench h6` (gen.h, h6k.h): per store into an existing object, the mutator's and the minor\n"
                 "collections' cycles, instructions and misses; nursery 1 MiB; one core, the least of 3 processes x 5 repetitions. The\n"
                 "slow-path counts (stderr) are in the table below.")
    if not s:
        return
    p = os.path.join(OUT, "h6.log")
    cnt = sorted(set(l.strip() for l in open(p) if l.startswith("# H6 ") and ("slow" in l or "stores" in l)))
    s += "\n\n## Counts (stores, old-to-young stores, slow paths, cards and remembered objects scanned)\n\n```\n" + "\n".join(cnt) + "\n```"
    write("gcbench-H6.md", s)

def h7():
    s = rowtable("h7", "gcbench H7: placement order and the mutator",
                 "Made by tests/gcbench, `gcbench h7`: a functional map built by path copying (map-find per lookup, map-walk per node)\n"
                 "and a list with garbage between its cells (list-sum per node), laid out as allocated with holes, slid, by Cheney (bfs), depth first (dfs).\n"
                 "One core, the least of 5 processes x 5 repetitions.")
    if s: write("gcbench-H7.md", s)

def h9():
    s = rowtable("h9", "gcbench H9: pages",
                 "Made by tests/gcbench, `gcbench h9`. The kernel's work: read the TSC column (ns, wall); cyc is user mode only.\n"
                 "Per 4 KiB page (unit page) or per call; one core, the least of 5 processes x 5 repetitions. Page faults per unit in the log.\n"
                 "Windows has the same operations as VirtualAlloc(MEM_RESERVE) / VirtualAlloc(MEM_COMMIT) / VirtualFree(MEM_DECOMMIT) and\n"
                 "DiscardVirtualMemory / OfferVirtualMemory (the MADV_FREE analogue); not measured here.")
    if s: write("gcbench-H9.md", s)

def h1():
    rs = get("h1") + get("h1-huge")
    rl2 = get("h1", "l2")
    if not rs:
        return
    surv = {}
    for n in ("h1", "h1-huge"):
        p = os.path.join(OUT, n + ".log")
        if os.path.exists(p):
            for l in open(p):
                m = re.match(r"# H1 n=(\S+) pf=(\d+) band=(\w+): (\d+) minors, promoted ([\d.]+) MiB of ([\d.]+) MiB \(survival ([\d.]+)%\)", l)
                if m:
                    surv[(m.group(1), m.group(2))] = (int(m.group(4)), float(m.group(5)), float(m.group(6)), float(m.group(7)))
    t = ["# gcbench H1: the nursery's size against the caches", "",
         "Made by tests/gcbench, `gcbench h1`: objects with the sizes and lifetimes of the bootstrap's 32 KiB census trace",
         "(band lo; the first 512 MiB of its allocation), a nursery of N bytes, a Cheney minor into an old space; mutator and minor",
         "counted apart, per KiB allocated (the trace's bytes). pf=256: prefetchw 256 bytes ahead of the bump pointer. huge: the",
         "nursery in transparent huge pages. One core, the least of 3 processes x 3 repetitions; the l2 event set from 3 more.", "",
         provenance(["h1", "h1-huge"]), ""]
    body = []
    l2 = {r["case"]: r for r in rl2}
    for r in rs:
        m = re.match(r"(mutator|minor)/n=(\w+)/pf=(\d+)/(\w+)(/huge)?", r["case"])
        if not m:
            continue
        kind, n, pf, band, huge = m.groups()
        s_ = surv.get((n, pf), (0, 0, 0, 0))
        x = l2.get(r["case"], {})
        per_prom = r["cyc"] / (s_[3] / 100) if kind == "minor" and s_[3] else float("nan")
        body.append([r["case"], "%.0f" % r["cyc"], "%.0f" % r["ins"], "%.1f" % r["l1d_repl"], "%.1f" % r["l2_miss"], "%.2f" % r["llc_miss"],
                     "%.2f" % r["dtlb_ld_walk"], "%.1f" % x.get("l2_rfo_miss", float("nan")), "%.1f" % x.get("l2_dmd_rd_miss", float("nan")),
                     "%d" % s_[0] if kind == "minor" else "", "%.2f%%" % s_[3] if kind == "minor" else "", "%.0f" % per_prom if kind == "minor" else "",
                     "%.0f%%" % (100 * r["spread"])])
    t.append(table(["case", "cyc/KiB", "ins/KiB", "L1D repl/KiB", "L2 miss/KiB", "LLC miss/KiB", "dTLB walks/KiB", "L2 RFO miss/KiB",
                    "L2 demand-read miss/KiB", "minors", "survival", "minor cyc/KiB promoted", "spread"], body))
    write("gcbench-H1.md", "\n".join(t))

def h5():
    names = [n[:-4] for n in sorted(os.listdir(OUT)) if n.startswith("h5-") and n.endswith(".tsv") and n != "h5-frag.tsv"]
    s = rowtable(None, "gcbench H5: allocators replaying the traces -- the timed rows",
                 "Made by tests/gcbench, `gcbench h5` (alloc.h): promote = cycles per object promoted (the trace's walk included),\n"
                 "major = per object promoted, the sweeps' share; traverse = per live object at the end (header and id; -graph: also the header\n"
                 "of every object it points to by graph.bin); ops-major = per major of the gcsim ops replay. Fragmentation: gcbench-fragmentation.md.",
                 names=names)
    if s: write("gcbench-H5.md", s)



# ---------------------------------------------------------------- fragmentation
FRAG_COLS = ["trace", "case", "peak_fp/peak_occ", "nursery", "factor", "min_MiB", "majors", "promoted_objs", "promoted_MiB",
             "peak_footprint_MiB", "peak_occupancy_MiB", "mean_frag", "max_frag", "final_live_MiB", "final_footprint_MiB", "internal_MiB", "los_MiB"]
def frag():
    p = os.path.join(OUT, "h5-frag.tsv")
    if not os.path.exists(p):
        return
    rows_ = sorted(set(l.rstrip("\n") for l in open(p) if l.strip()))
    t = ["# gcbench H5: fragmentation of the replay allocators (an independent check for the simulator)", "",
         "Made by tests/gcbench: `gcbench h5` (alloc.h: bump with sliding, Immix, OCaml 5 segregated fit, OCaml 4 best fit,",
         "first fit, next fit), replaying the census's W8 traces; and `gcbench h5 ops=FILE`, replaying gcsim's old-space",
         "operation stream (h5.c). The commands are in gcbench-H5.md and below.", "",
         "## Definitions", "",
         "- **Replay of a trace** (`h5 trace=T nursery=N factor=F min=M`): the ids in order; a minor at every N/every-th sample",
         "  (exact liveness there): the objects born since the last minor and alive at that sample (death >= sample) are promoted,",
         "  in id order (promotion at the first survival, no large-object bypass of the nursery). A major runs at a minor when the",
         "  old space holds more than F x max(live after the last major, M) bytes; every object is told live (death >= sample) or",
         "  dead; bump slides the live ones down. Objects over 8 KiB (Immix) or 128 words (segfit) go to a large-object space of",
         "  page-rounded mappings, counted in los_MiB and in the footprint.",
         "- **footprint** = what the allocator holds: bump its extent; Immix blocks in use x 32 KiB (+ LOS); segfit pools in use x 32",
         "  KiB (+ LOS); the free-list heaps their chunks (never returned). **occupancy** = bytes of the objects in the old space",
         "  (live or dead-not-yet-swept). **peak_fp/peak_occ** = peak footprint / peak occupancy: the allocator's own overhead at",
         "  the high-water mark (1.00 = none). **mean_frag / max_frag** = 1 - live/footprint after each major (it includes the",
         "  headroom a non-moving heap keeps: free memory not returned). internal_MiB = segfit's rounding of live objects.",
         "- MLton programs whose live data stays under min (4 MiB) have no major (majors = 0).", "",
         "The comparison with gcsim's own fragmentation is written by hand from these tables and gcsim's.", "",
         "## Replays of the traces", "",
         table(FRAG_COLS, [r.split("\t") for r in rows_ if not r.split("\t")[1].startswith("ops:")])]
    ops = [r.split("\t") for r in rows_ if r.split("\t")[1].startswith("ops:")]
    if ops:
        t += ["", "## Replays of gcsim's ops stream (same placements and frees for every allocator)", "",
              table(FRAG_COLS, ops)]
    mp = os.path.join(OUT, "ops", "bootstrap.majors.tsv")
    cmp_ = compare_ops()
    if cmp_:
        t += ["", "## Per major: gcbench's footprint against gcsim's old_committed (same op stream, same schedule)", "",
              "gcsim: `gcsim --trace T --nursery 1M --old MODEL --major-every 16M --events E` (segfit also `--ops`); gcbench:",
              "`gcbench h5 ops=T.segfit.ops majors=...`. gcsim's old_committed counts whole free blocks or pools still committed",
              "(column whole; for the free lists gcsim's whole is its own measure); gcbench returns empty pools and blocks.",
              "held: gcbench's is the live bytes in the old space; gcsim's is its own (lines or blocks held, for Immix and the free lists).", "", cmp_]
    write("gcbench-fragmentation.md", "\n".join(t))

def compare_ops():
    out = []
    d = os.path.join(OUT, "ops")
    if not os.path.isdir(d):
        return ""
    for trace in ("compile-sigs", "bootstrap"):
        mp = os.path.join(d, trace + ".majors.tsv")
        if trace == "compile-sigs" and not os.path.exists(mp):
            mp = os.path.join(d, "m.tsv")
        if not os.path.exists(mp):
            continue
        mine = {}
        for l in open(mp):
            f = l.rstrip("\n").split("\t")
            mine.setdefault(f[1], []).append((int(f[2]), int(f[3]), int(f[4])))
        body = []
        for model in ("segfit", "immix", "bestfit", "nextfit", "firstfit"):
            ev = os.path.join(d, "%s.%s.ev" % (trace, model))
            if not os.path.exists(ev) or model not in mine:
                continue
            gs = []
            for l in open(ev):
                f = l.split("\t")
                if len(f) >= 50 and f[1] == "major":
                    gs.append((int(f[37]), int(f[42]), int(f[49]), int(f[47])))   # live_old, old_committed, whole, held
            for (i, held, fp), g in zip(mine[model], gs):
                diff = (fp - (g[1] - g[2])) / (g[1] - g[2]) if g[1] - g[2] else 0
                diff0 = (fp - g[1]) / g[1] if g[1] else 0
                body.append([trace, model, i, "%.2f" % (held / 1048576), "%.2f" % (g[3] / 1048576), "%.2f" % (fp / 1048576),
                             "%.2f" % (g[1] / 1048576), "%.2f" % (g[2] / 1048576), "%+.1f%%" % (100 * diff0), "%+.1f%%" % (100 * diff)])
        if body:
            summ = {}
            for b in body:
                a0 = abs(float(b[8].rstrip("%"))); a1 = abs(float(b[9].rstrip("%")))
                x = summ.setdefault(b[1], [0, 0.0, 0.0, 0.0, 0.0]); x[0] += 1; x[1] += a0; x[2] = max(x[2], a0); x[3] += a1; x[4] = max(x[4], a1)
            out.append("Summary for %s, |gcbench - gcsim| per major:\n\n" % trace + table(["model", "majors", "mean vs old_committed", "max",
                       "mean vs old_committed - whole", "max"], [[m, x[0], "%.1f%%" % (x[1] / x[0]), "%.1f%%" % x[2], "%.1f%%" % (x[3] / x[0]), "%.1f%%" % x[4]] for m, x in summ.items()]))
            out.append(table(["trace", "model", "major", "held (gcbench) MiB", "held (gcsim) MiB", "footprint (gcbench) MiB",
                              "old_committed (gcsim) MiB", "whole (gcsim) MiB", "vs old_committed", "vs old_committed - whole"], body))
    return "\n\n".join(out)

if __name__ == "__main__":
    for f in (h10, h2, h8, h1, h3, h5, h6, h7, h9, frag):
        f()
