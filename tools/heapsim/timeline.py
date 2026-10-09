#!/usr/bin/env python3
"""tools/heapsim/timeline.py -- pauses, MMU and footprint from gcsim's
--events (or from a VM's --gc-log, docs/runtime.md, for the real VM).

    timeline.py [--coef FILE] [--tier interp|default|jit] [--ns-per-instr X]
                [--lazy-sweep] [--watermark] [--series FILE] [--tsv] EVENTS...
    timeline.py --gclog [--tier ...] GCLOG...

The mutator's clock is the instruction count at each collection (gcsim
interpolates it between the census samples), converted to time at
--ns-per-instr (by tier; the defaults are PLACEHOLDERS until measured).
Each collection costs a linear model in its work counts: the coefficients
(ns per unit) are read from --coef (key = value lines; the keys are the
names in DEFAULT_COEF); the defaults are the unit costs tests/gcbench
measured on the roadmap's reference machine (docs/plans/
garbage-collector-v2.md, *The harness*: H2, H8, H10) where they apply, and
PLACEHOLDERS where not (the list PLACEHOLDERS names them).
Collections at the same allocation clock are one pause (a minor and the
major it triggered). With --lazy-sweep the sweep's work is done by the
allocator (added to the mutator, not to the pause); with --watermark a
minor scans only the stack slots above the lowest frame touched since the
last minor (Cheng, Harper and Lee 1998).

Output: pauses, total GC time, the longest pause, percentiles, a pause
histogram, and the minimum mutator utilisation at 1, 2, 5, 10, 20, 50,
100 and 200 ms windows (Cheng and Blelloch 2001), and the footprint's peak
(committed, reserved, metadata). --series FILE writes (time ms, committed,
reserved, metadata, live) per collection for a plot. --tsv prints one
tab-separated row instead of the text report.

With --gclog the input is a VM's --gc-log: its measured pause_ns are the
pauses and its instrs the clock (no cost model)."""
import sys, bisect, argparse

# ns per unit. MEASURED where a source is named (tests/gcbench on the
# roadmap's reference machine: H2 copying and marking, H8 the stack,
# H10 memory); PLACEHOLDER where not (the names are in PLACEHOLDERS below).
DEFAULT_COEF = {
    'fixed_minor': 2000, 'fixed_major': 20000, 'fixed_satb': 1000,   # PLACEHOLDER: a collection's fixed cost
    'slot': 8.5,          # H8: per slot, frames of many functions (live and pointer tests mispredict): 8-9 ns
    'frame': 20.0,        # H8: per frame base 6 ns + the liveness lookup ~14 ns (4 return points); 16 slots + a frame ~ 156 ns (H8 typical 129-167)
    'stack_ptr': 0.0,     # folded into 'slot' (H8 measures every slot a root)
    'card': 30.0,         # PLACEHOLDER: a dirty card's crossing-map lookup and loop
    'card_byte': 0.1,     # H10: sequential read 0.027 ns/B (L3) + a pointer test a word (derived, not measured as such)
    'remset': 5.0, 'born_rem_field': 2.0,                    # PLACEHOLDER
    'mut_scan_byte': 0.1, # as card_byte (derived)
    'copy_obj': 5.3, 'copy_byte': 0.10,                      # H2: Cheney copy, L3, creation order, 1 MiB live (a minor's survivors): 4.6-5.9 + 0.08-0.13/B
    'mark_obj': 2.0, 'mark_field': 1.6,                      # H2: mark, header bit, DRAM, creation order: 0.3-4.2 ns + 0.17-0.25 ns/B (x 8 B a field)
    'sweep_byte': 0.03,                                      # PLACEHOLDER: a sweep per byte of space (line marks / bitmap)
    'move_obj': 6.0, 'move_byte': 0.4,                       # H2: Cheney copy, DRAM, creation order, 128 MiB: 2-10 ns + 0.2-0.55/B (list-tree middle)
    'evac_obj': 10.0, 'evac_byte': 0.55,                     # H2: as the copy, DRAM, tree (the upper end)
    'scan_obj_lisp2': 3.0, 'scan_byte_lisp2': 0.07,          # byte: H10 sequential read, DRAM 0.07 ns/B a pass; obj: PLACEHOLDER (header decode)
    'scan_obj_jonkers': 4.0, 'scan_byte_jonkers': 0.07,      # as Lisp-2; obj: PLACEHOLDER
    'ptr_jonkers': 3.0,                                      # PLACEHOLDER: threading and unthreading a pointer
    'satb_byte': 0.26,                                       # H2: mark, DRAM: 2 ns an object at the bootstrap's ~32 B mean + 0.2 ns/B
}
PLACEHOLDERS = ['fixed_minor', 'fixed_major', 'fixed_satb', 'card', 'remset', 'born_rem_field', 'sweep_byte', 'scan_obj_lisp2', 'scan_obj_jonkers', 'ptr_jonkers']
# ns per bytecode instruction of the mutator: the bootstrap's baseline (the roadmap's *The baselines*):
# (task-clock - GC) / 609.6M bytecode instructions: default tiering (2.57 - 0.43) s -> 3.5; --jit=off (4.68 - 0.45) s -> 6.9.
# 'jit' (every function compiled) is a PLACEHOLDER.
NS_PER_INSTR = {'interp': 6.9, 'default': 3.5, 'jit': 2.0}
WINDOWS_MS = [1, 2, 5, 10, 20, 50, 100, 200]

def read_coef(path):
    c = dict(DEFAULT_COEF)
    if path:
        for line in open(path):
            line = line.split('#')[0].strip()
            if not line or '=' not in line:
                continue
            k, v = (x.strip() for x in line.split('=', 1))
            if k not in c:
                sys.exit('timeline: unknown coefficient %s' % k)
            c[k] = float(v)
    return c

def read_events(path):
    rows, hdr = [], None
    for line in open(path):
        if line.startswith('#'):
            continue
        f = line.rstrip('\n').split('\t')
        if hdr is None:
            hdr = f
            continue
        r = dict(zip(hdr, f))
        for k, v in r.items():
            if k not in ('kind', 'how'):
                try:
                    r[k] = float(v) if '.' in v else int(v)
                except ValueError:
                    pass
        rows.append(r)
    return rows

def cost(e, c, lazy, watermark):
    """the pause of one gcsim event (ns), and the work it leaves to the mutator (lazy sweeping)"""
    k = e['kind']
    slots = e['slots'] - (e['low'] if watermark and k in ('minor', 'sticky-minor') else 0)
    stack = slots * c['slot'] + (e['frames'] * c['frame'] if e['slots'] else 0) + (e['stack_ptrs'] * c['stack_ptr'] if e['slots'] else 0)
    roots = e['cards'] * (c['card'] + 512 * c['card_byte']) + e['remset'] * c['remset'] + e['born_rem_fields'] * c['born_rem_field'] + e['mut_scan_bytes'] * c['mut_scan_byte']
    copy = e['copied_objs'] * c['copy_obj'] + e['copied_bytes'] * c['copy_byte']
    mark = e['marked_objs'] * c['mark_obj'] + e['marked_fields'] * c['mark_field']
    sweep = (e['sweep_scan_bytes'] + e['lazy_sweep_bytes']) * c['sweep_byte']
    move = e['moved_objs'] * c['move_obj'] + e['moved_bytes'] * c['move_byte'] + e['evac_objs'] * c['evac_obj'] + e['evac_bytes'] * c['evac_byte']
    how = e.get('how', '-')
    scan = 0
    if how == 'lisp2':
        scan = 3 * (e['heap_scan_objs'] * c['scan_obj_lisp2'] + e['heap_scan_bytes'] * c['scan_byte_lisp2'])
    elif how == 'jonkers':
        scan = 2 * (e['heap_scan_objs'] * c['scan_obj_jonkers'] + e['heap_scan_bytes'] * c['scan_byte_jonkers']) + 2 * e['marked_ptrs'] * c['ptr_jonkers']
    satb = e['satb_work'] * c['satb_byte']
    if k in ('minor', 'sticky-minor'):
        fixed = c['fixed_minor']
    elif k.startswith('satb'):
        fixed = c['fixed_satb']
        mark = 0   # a SATB cycle's marking is in its slices (satb_work); its end only sweeps
    else:
        fixed = c['fixed_major']
    if k == 'satb-end' and how == 'lazy':
        lazy_sweep = sweep; sweep = 0
    elif lazy:
        lazy_sweep = sweep; sweep = 0
    else:
        lazy_sweep = 0
    return fixed + stack + roots + copy + mark + sweep + move + scan + satb, lazy_sweep

def mmu(pauses, total, w):
    """Cheng and Blelloch's minimum mutator utilisation for windows of w (same unit as the pauses)"""
    if total <= w:
        return max(0.0, 1 - sum(e - s for s, e in pauses) / total) if total else 1.0
    starts = [s for s, e in pauses]
    ends = [e for s, e in pauses]
    pre = [0.0]
    for s, e in pauses:
        pre.append(pre[-1] + (e - s))
    def gc_in(a, b):   # GC time inside [a, b]
        i = bisect.bisect_right(ends, a)          # first pause ending after a
        j = bisect.bisect_left(starts, b)         # pauses starting before b
        if j <= i:
            return 0.0
        t = pre[j] - pre[i]
        s0, e0 = pauses[i]
        if s0 < a: t -= a - s0
        s1, e1 = pauses[j - 1]
        if e1 > b: t -= e1 - b
        return max(t, 0.0)
    worst = 0.0
    for s, e in pauses:
        for a in (s, e - w):                       # windows starting at a pause, or ending at one
            a = min(max(a, 0.0), total - w)
            worst = max(worst, gc_in(a, a + w))
    return max(0.0, 1 - worst / w)

def percentile(v, p):
    if not v:
        return 0.0
    v = sorted(v)
    return v[min(len(v) - 1, int(p / 100.0 * len(v)))]

def report(name, pauses_ns, mut_ns, footprint, args):
    # pauses_ns: list of (mutator time before it, pause); the timeline interleaves them
    t, iv = 0.0, []
    last_mut = 0.0
    for m, p in pauses_ns:
        t += m - last_mut; last_mut = m
        iv.append((t, t + p)); t += p
    t += mut_ns - last_mut
    total = t
    durs = [p for _, p in pauses_ns]
    gc = sum(durs)
    ms = 1e6
    mmus = {w: mmu(iv, total, w * ms) for w in WINDOWS_MS}
    hist = {}
    for d in durs:
        b = 0
        while d >= 1e5 * 2 ** b:  # buckets from 0.1 ms, doubling
            b += 1
        hist[b] = hist.get(b, 0) + 1
    if args.tsv:
        cols = [name, len(durs), '%.3f' % (gc / ms), '%.3f' % (total / ms), '%.4f' % (gc / total if total else 0), '%.3f' % (max(durs) / ms if durs else 0),
                '%.3f' % (percentile(durs, 50) / ms), '%.3f' % (percentile(durs, 90) / ms), '%.3f' % (percentile(durs, 99) / ms), '%.3f' % (percentile(durs, 99.9) / ms)]
        cols += ['%.4f' % mmus[w] for w in WINDOWS_MS]
        cols += [footprint.get('committed', 0), footprint.get('reserved', 0), footprint.get('metadata', 0)]
        print('\t'.join(str(x) for x in cols))
        return
    print('%s: %d pauses, GC %.1f ms of %.1f ms (%.1f%%), longest %.3f ms' % (name, len(durs), gc / ms, total / ms, 100 * gc / total if total else 0, max(durs) / ms if durs else 0))
    print('  percentiles (ms): p50 %.3f  p90 %.3f  p99 %.3f  p99.9 %.3f' % tuple(percentile(durs, p) / ms for p in (50, 90, 99, 99.9)))
    print('  MMU: ' + '  '.join('%dms %.3f' % (w, mmus[w]) for w in WINDOWS_MS))
    print('  histogram (ms): ' + '  '.join('<%g: %d' % (0.1 * 2 ** b, hist[b]) for b in sorted(hist)))
    if footprint:
        print('  footprint peak: committed %d, reserved %d, metadata %d bytes' % (footprint['committed'], footprint['reserved'], footprint['metadata']))

TSV_HEADER = ['name', 'pauses', 'gc_ms', 'total_ms', 'gc_share', 'max_ms', 'p50_ms', 'p90_ms', 'p99_ms', 'p999_ms'] + ['mmu_%dms' % w for w in WINDOWS_MS] + ['peak_committed', 'peak_reserved', 'peak_metadata']

def from_events(path, args, coef, nspi):
    rows = read_events(path)
    pauses, lazy_debt = [], 0.0
    fp = {'committed': 0, 'reserved': 0, 'metadata': 0}
    series = []
    last_clock, cur = None, None
    end_instr = 0
    for e in rows:
        p, lz = cost(e, coef, args.lazy_sweep, args.watermark)
        lazy_debt += lz
        m = e['instr'] * nspi
        end_instr = max(end_instr, e['instr'])
        if cur is not None and e['clock'] == last_clock:
            cur[1] += p
        else:
            cur = [m + lazy_debt, p]
            pauses.append(cur)
        last_clock = e['clock']
        for k in fp:
            fp[k] = max(fp[k], e[k])
        series.append((e['clock'], e['committed'], e['reserved'], e['metadata'], e['live_old']))
    total_instr = args.instructions or end_instr
    mut = total_instr * nspi + lazy_debt
    if args.series:
        with open(args.series, 'w') as f:
            f.write('clock\tcommitted\treserved\tmetadata\tlive_old\n')
            for s in series:
                f.write('\t'.join(str(x) for x in s) + '\n')
    return [tuple(x) for x in pauses], mut, fp

def from_gclog(path, args, nspi):
    pauses, end_instr, rss = [], 0, 0
    for line in open(path):
        if line.startswith('# end'):
            f = line.split()
            if 'instrs' in f:
                end_instr = int(f[f.index('instrs') + 1])
            continue
        if line.startswith('#'):
            continue
        f = line.split()
        instr, pause = int(f[5]), int(f[21])
        if pauses and pauses[-1][2] == int(f[2]):   # two passes of one vm_gc: one pause
            pauses[-1][1] += pause
        else:
            pauses.append([instr * nspi, pause, int(f[2])])
        rss = max(rss, int(f[23]))
    return [(m, p) for m, p, _ in pauses], end_instr * nspi, {'committed': rss, 'reserved': 0, 'metadata': 0}

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('files', nargs='+')
    ap.add_argument('--coef'); ap.add_argument('--tier', default='default', choices=sorted(NS_PER_INSTR))
    ap.add_argument('--ns-per-instr', type=float); ap.add_argument('--instructions', type=int, default=0)
    ap.add_argument('--lazy-sweep', action='store_true'); ap.add_argument('--watermark', action='store_true')
    ap.add_argument('--series'); ap.add_argument('--tsv', action='store_true'); ap.add_argument('--header', action='store_true')
    ap.add_argument('--gclog', action='store_true')
    args = ap.parse_args()
    coef = read_coef(args.coef)
    nspi = args.ns_per_instr or NS_PER_INSTR[args.tier]
    if args.tsv and args.header:
        print('\t'.join(TSV_HEADER))
    for path in args.files:
        if args.gclog:
            p, mut, fp = from_gclog(path, args, nspi)
        else:
            p, mut, fp = from_events(path, args, coef, nspi)
        report(path, p, mut, fp, args)

if __name__ == '__main__':
    main()
