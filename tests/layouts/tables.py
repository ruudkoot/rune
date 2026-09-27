#!/usr/bin/env python3
"""tables.py -- the tables of results/harness-*.md from results/harness-raw.tsv
(measure.sh) and results/harness-micro.tsv (micro.sh).
  harness-cycles.md        cycles ratio to L0 per kernel x configuration
  harness-instructions.md  instructions ratio to L0
  harness-l1d.md           L1d load misses ratio to L0
  harness-gc.md            collector share of the cycles (rdtscp around gc_collect) and
                           collector cycles ratio to L0
  harness-counters.md      the raw least-of-5 numbers per (compiler, configuration, kernel)
  harness-micro.md         the primitive operations, cycles per operation
A ratio cell shows gcc's value; clang's is added in parentheses when the two
compilers' ratios differ by more than 10%. Only differences beyond 15% count
as conclusions (WSL noise); cells within 15% of 1.00 are marked '~'."""
import csv, sys, os, collections
D = (sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)) + "/../out/layouts") + "/"
KERNELS = ["list_ops", "intmap", "strmap", "inttable", "closures", "int_loop", "word_loop",
           "real_regs", "real_array", "strings", "poly_eq_tree", "gc_churn8", "gc_churn64"]
CONFIGS = ["L0", "L1", "L2", "L3", "L4MONO", "L4UNI", "L1+PAIRS", "L4MONO+PAIRS", "L4UNI+PAIRS",
           "L1+HDR4", "L1+ALIGN16", "L3+NAN51", "L1+REALIMM", "L2+REALIMM", "L1+UNBOXED",
           "L1+FLATREAL", "L4UNI+FLATREAL", "L1+COMPACT", "L4MONO+COMPACT", "L1+BARRIER"]
CCS = ["gcc-13", "clang-18"]
CMD = ("cd $D/harness && make CC=gcc-13 && make CC=clang-18 && ./check.sh gcc-13 && ./check.sh clang-18 "
       "&& ./measure.sh && ./micro.sh && ./tables.py")

def load():
    rows = {}
    with open(D + "harness-raw.tsv") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            rows[(r["cc"], r["config"], r["kernel"])] = r   # the last measurement wins
    return rows

def fmt_ratio(v):
    if v is None: return "-"
    mark = "~" if 1 / 1.15 < v < 1.15 else ""
    return f"{v:.2f}{mark}"

def ratio_table(rows, col, title, note, integer=False):
    out = [f"# {title}", "", f"Command: `{CMD}`", "",
           note, "",
           "Ratio to L0 with the same compiler (< 1 = fewer than L0). gcc-13's ratio; "
           "clang-18's in parentheses when the two differ by more than 10%. "
           "`~` = within 15% of L0, which WSL noise can produce: not a conclusion. "
           "`-` = not measured (a variant is measured only for the kernels it affects).", ""]
    out.append("| config | " + " | ".join(KERNELS) + " |")
    out.append("|---|" + "---|" * len(KERNELS))
    for cfg in CONFIGS:
        cells = []
        for k in KERNELS:
            vals = {}
            for cc in CCS:
                r = rows.get((cc, cfg, k)); b = rows.get((cc, "L0", k))
                if r and b and float(b[col]) > 0: vals[cc] = float(r[col]) / float(b[col])
            if "gcc-13" not in vals and "clang-18" not in vals: cells.append("-"); continue
            g = vals.get("gcc-13"); c = vals.get("clang-18")
            if g is None: cells.append(f"(clang {fmt_ratio(c)})")
            elif c is not None and abs(g - c) / max(g, c) > 0.10: cells.append(f"{fmt_ratio(g)} ({fmt_ratio(c)})")
            else: cells.append(fmt_ratio(g))
        out.append(f"| {cfg} | " + " | ".join(cells) + " |")
    return "\n".join(out) + "\n"

def gc_table(rows):
    out = ["# Collector share and collector cycles", "", f"Command: `{CMD}`", "",
           "Per (configuration, kernel): the collector's share of the kernel's cycles "
           "(rdtscp around gc_collect, gcc-13 build, least-of-5 run) as a percentage, and in "
           "parentheses the collector's cycles as a ratio to L0's collector cycles "
           "(`-` where L0 never collects). Every layout runs with the same 64 MiB "
           "semispace (128 MiB for gc_churn64), so a layout with smaller objects "
           "collects less often and copies fewer bytes: that is the point. "
           "Differences below 15% are noise.", ""]
    out.append("| config | " + " | ".join(KERNELS) + " |")
    out.append("|---|" + "---|" * len(KERNELS))
    for cfg in CONFIGS:
        cells = []
        for k in KERNELS:
            r = rows.get(("gcc-13", cfg, k)); b = rows.get(("gcc-13", "L0", k))
            if not r: cells.append("-"); continue
            share = float(r["gc_share"]) * 100
            gcc_ = float(r["gc_cycles"]); gcb = float(b["gc_cycles"]) if b else 0
            rat = f"{gcc_ / gcb:.2f}" if gcb > 0 else "-"
            cells.append(f"{share:.1f}% ({rat})")
        out.append(f"| {cfg} | " + " | ".join(cells) + " |")
    return "\n".join(out) + "\n"

def counters_table(rows):
    out = ["# Raw counters (least-of-5 run)", "", f"Command: `{CMD}`", "",
           "perf stat -x, -e cycles:u,instructions:u,task-clock,page-faults,cache-misses,"
           "L1-dcache-load-misses,dTLB-load-misses,branch-misses,r0203:u -- taskset -c 5 ./harness kernel n; "
           "the run with the fewest cycles of 5 (10 when the spread of 5 exceeded 5%). "
           "sfb = LD_BLOCKS.STORE_FORWARD (r0203). gc% = the collector's share by rdtscp. "
           "spread = (max-min)/min cycles over the runs.", ""]
    out.append("| cc | config | kernel | n | Gcycles | Ginstr | IPC | L1d miss (M) | dTLB miss (K) | branch miss (M) | sfb (K) | cache miss (M) | ms | gc% | spread | runs |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for cc in CCS:
        for cfg in CONFIGS:
            for k in KERNELS:
                r = rows.get((cc, cfg, k))
                if not r: continue
                cyc = float(r["cycles"]); ins = float(r["instructions"])
                out.append(f"| {cc} | {cfg} | {k} | {r['n']} | {cyc/1e9:.3f} | {ins/1e9:.3f} | {ins/cyc:.2f} | "
                           f"{float(r['l1d_misses'])/1e6:.1f} | {float(r['dtlb_misses'])/1e3:.0f} | "
                           f"{float(r['branch_misses'])/1e6:.2f} | {float(r['store_fwd_blocks'])/1e3:.0f} | "
                           f"{float(r['cache_misses'])/1e6:.2f} | {float(r['task_clock_ms']):.0f} | "
                           f"{float(r['gc_share'])*100:.1f} | {r['spread']} | {r['runs']} |")
    return "\n".join(out) + "\n"

def micro_table():
    p = D + "harness-micro.tsv"
    if not os.path.exists(p): return None
    data = collections.defaultdict(dict); ops = []
    with open(p) as f:
        for r in csv.DictReader(f, delimiter="\t"):
            data[(r["cc"], r["config"], r["semispace_mib"])][r["op"]] = float(r["cycles_per_op"])
            if r["op"] not in ops: ops.append(r["op"])
    out = ["# The primitive operations alone", "", f"Command: `{CMD}` (micro.sh: `harness micro -s 8` and `-s 64`, least of 3)", "",
           "rdtsc cycles per operation (the TSC runs at the nominal 3.2 GHz; the core may turbo, so "
           "compare across the row, not with the perf cycles). tagtest: is_int then the int or a "
           "field of the object (3 ints, 1 pointer, predictable); addov: a dependent chain of "
           "add_ov on tagged ints (the latency of add + overflow check + tagging); realadd: a "
           "dependent chain of real adds through the value representation (box/unbox or "
           "encode/decode per add); fieldload: a MONO int field of a 5-field node (1024 nodes, "
           "cache-resident); chase: tail after tail through a 64-cell cyclic list (the pointer "
           "decode plus an L1 hit); cons: allocate a cons cell of a POLY int (the heap reset "
           "every 100k cells, no collection): with an 8 MiB semispace the cells stay in the L3 "
           "cache, with 64 MiB they stream to memory (the write-allocate cost of the object size).", ""]
    for s in ["8", "64"]:
        out.append(f"## semispace {s} MiB"); out.append("")
        out.append("| config | cc | " + " | ".join(ops) + " |")
        out.append("|---|---|" + "---|" * len(ops))
        for cfg in CONFIGS:
            for cc in CCS:
                d = data.get((cc, cfg, s))
                if not d: continue
                out.append(f"| {cfg} | {cc} | " + " | ".join(f"{d.get(op, float('nan')):.1f}" for op in ops) + " |")
        out.append("")
    return "\n".join(out) + "\n"

if __name__ == "__main__":
    rows = load()
    open(D + "harness-cycles.md", "w").write(ratio_table(rows, "cycles", "Cycles (cycles:u) relative to L0",
        "The mutator and collector cost a native or JIT-tier-2 program would pay under each layout, "
        "on SML-shaped kernels (harness/kernels.c) with a copying collector of the layout's own "
        "(harness/gc_core.h). Each kernel does identical work in every layout (check.sh: one "
        "checksum over the results' unboxed bits)."))
    open(D + "harness-instructions.md", "w").write(ratio_table(rows, "instructions", "Instructions (instructions:u) relative to L0",
        "Instruction counts are deterministic per binary (the spread is 0): a ratio here is a "
        "property of the layout's code, not of the machine's moment; still, only cycles are cost."))
    open(D + "harness-l1d.md", "w").write(ratio_table(rows, "l1d_misses", "L1d load misses (L1-dcache-load-misses) relative to L0",
        "Bytes touched: object size, boxes, and the collector's copying show up here first."))
    open(D + "harness-gc.md", "w").write(gc_table(rows))
    open(D + "harness-counters.md", "w").write(counters_table(rows))
    m = micro_table()
    if m: open(D + "harness-micro.md", "w").write(m)
    print("tables written to", D)
