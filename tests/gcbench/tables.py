#!/usr/bin/env python3
"""tables.py -- Markdown tables from measure.sh's merged rows (Python 3, for the
tables only).

    tables.py FILE.tsv [--grep REGEX] [--evset mem] [--cols cyc,ins,l1d_repl,...]
              [--per-byte] [--ns]

Prints one row per case of FILE.tsv (measure.sh's NAME.tsv: for each case the
run with the fewest cycles), the counters per unit; --per-byte divides by
the object size found in the case (the number after the shape in H2's
cases); --ns adds the nanoseconds."""
import argparse, re, sys

EVNAMES = {
    "mem": ["l1d_repl", "l2_miss", "llc_miss", "dtlb_ld_walk"],
    "l2": ["l2_dmd_rd_miss", "l2_rfo_miss", "l2_pf_miss", "dtlb_st_walk"],
    "br": ["br_miss", "l1d_repl", "l2_dmd_rd_miss", "llc_miss"],
    "tlb": ["dtlb_ld_walk", "dtlb_walk_cyc", "dtlb_st_walk", "stlb_hit"],
}

def rows(path, evset=None):
    out = []
    for line in open(path):
        if line.startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) < 15:
            continue
        r = {"exp": f[0], "case": f[1], "unit": f[2], "n": float(f[3]), "cyc": float(f[4]), "ins": float(f[5]),
             "tsc": float(f[10]), "ns": float(f[11]), "cyc_med": float(f[12]), "reps": f[13], "evset": f[14],
             "spread": float(f[16]) if len(f) > 16 else 0.0}
        for i, name in enumerate(EVNAMES.get(f[14], ["e0", "e1", "e2", "e3"])):
            r[name] = float(f[6 + i])
        if evset and r["evset"] != evset:
            continue
        out.append(r)
    return out

def fit_h2(rs):
    """H2: cycles per object = a + b * size, per (collector, shape, order, live),
    least squares over the sizes; also ns."""
    groups = {}
    for r in rs:
        m = re.match(r"([^/]+)/([^/]+)/(\d+)/([^/]+)/([^/]+)$", r["case"])
        if not m:
            continue
        g, shape, size, order, live = m.groups()
        groups.setdefault((g, shape, order, live), []).append((int(size), r["cyc"], r["ns"], r["ins"]))
    print("| collector | shape | order | live | sizes | cyc/obj (a) | cyc/byte (b) | ns/obj (a) | ns/byte (b) | ins/obj at 32 B |")
    print("|---|---|---|---|---|---:|---:|---:|---:|---:|")
    for (g, shape, order, live), pts in sorted(groups.items(), key=lambda kv: (kv[0][3], kv[0][1], kv[0][2], kv[0][0])):
        pts.sort()
        n = len(pts)
        if n < 2:
            continue
        def ls(idx):
            xs = [p[0] for p in pts]; ys = [p[idx] for p in pts]
            mx = sum(xs) / n; my = sum(ys) / n
            sxx = sum((x - mx) ** 2 for x in xs)
            b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx if sxx else 0
            return my - b * mx, b
        a, b = ls(1); an, bn = ls(2)
        i32 = [p[3] for p in pts if p[0] == 32]
        print("| %s | %s | %s | %s | %s | %.1f | %.3f | %.2f | %.4f | %s |" % (g, shape, order, live, ",".join(str(p[0]) for p in pts), a, b, an, bn, "%.0f" % i32[0] if i32 else ""))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--grep", default=None)
    ap.add_argument("--evset", default="mem")
    ap.add_argument("--cols", default="cyc,ins,l1d_repl,l2_miss,llc_miss,dtlb_ld_walk")
    ap.add_argument("--per-byte", action="store_true")
    ap.add_argument("--ns", action="store_true")
    ap.add_argument("--fit-h2", action="store_true")
    a = ap.parse_args()
    cols = a.cols.split(",")
    rs = rows(a.file, a.evset)
    if a.grep:
        rs = [r for r in rs if re.search(a.grep, r["case"])]
    if a.fit_h2:
        fit_h2(rs)
        return
    head = ["case", "unit"] + cols + (["ns"] if a.ns else []) + ["spread"]
    if a.per_byte:
        head += ["cyc/B"]
    print("| " + " | ".join(head) + " |")
    print("|" + "|".join(["---"] + ["---:"] * (len(head) - 1)) + "|")
    for r in rs:
        cells = [r["case"], r["unit"]] + ["%.2f" % r.get(c, float("nan")) for c in cols]
        if a.ns:
            cells.append("%.2f" % r["ns"])
        cells.append("%.0f%%" % (100 * r["spread"]))
        if a.per_byte:
            m = re.search(r"/(\d+)/(alloc|shuf)", r["case"])
            cells.append("%.3f" % (r["cyc"] / int(m.group(1))) if m else "")
        print("| " + " | ".join(cells) + " |")

if __name__ == "__main__":
    main()
