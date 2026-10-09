#!/usr/bin/env python3
"""tools/heapsim/pauses.py EVENTSDIR VALIDATEDIR OUT.md [TRACE...]
The pause and MMU table of the simulator (sim-pauses.md of
docs/plans/garbage-collector-v2.md, *The simulator*): timeline.py over
every gcsim --events file of sweep2.sh's events question
(EVENTSDIR/TRACE.CONFIG.ev: sweep2.sh --out DIR writes DIR/events), with its
coefficients, at the default tier and the interpreter's; then, for
calibration, the stock copier's MEASURED pauses from validate2.sh's --gc-log
files (VALIDATEDIR/TRACE.HEAP.FILL.gclog; the VM ran --jit=off) beside the
model's for the same collections (gcsim --nursery 0 --old copy at the same
heap: the events question's first two configurations), and the ratio."""
import os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import timeline as T

class A:   # timeline's options
    lazy_sweep = False; watermark = False; series = None; tsv = True; instructions = 0

def stats(pauses, mut):
    t, iv, last = 0.0, [], 0.0
    for m, p in pauses:
        t += m - last; last = m; iv.append((t, t + p)); t += p
    t += mut - last
    d = [p for _, p in pauses]
    return {'n': len(d), 'gc': sum(d) / 1e6, 'total': t / 1e6, 'max': max(d) / 1e6 if d else 0, 'p99': T.percentile(d, 99) / 1e6,
            'mmu': {w: T.mmu(iv, t, w * 1e6) for w in (1, 10, 50, 100)}}

def row(name, s):
    return '| %s | %d | %.1f | %.1f%% | %.2f | %.2f | %.3f | %.3f | %.3f | %.3f |' % (
        name, s['n'], s['gc'], 100 * s['gc'] / s['total'] if s['total'] else 0, s['max'], s['p99'], s['mmu'][1], s['mmu'][10], s['mmu'][50], s['mmu'][100])

HEAD = '| config | pauses | GC ms | GC share | longest ms | p99 ms | MMU 1ms | 10ms | 50ms | 100ms |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|'

def main():
    evd, vd, out = sys.argv[1], sys.argv[2], sys.argv[3]
    traces = sys.argv[4:] or sorted({os.path.basename(p).split('.')[0] for p in glob.glob(os.path.join(evd, '*.ev'))}, key=lambda t: (not t.startswith('bootstrap'), t))
    coef = T.read_coef(None)
    o = ['# Pauses and MMU (modelled)\n',
         'Made by `tools/heapsim/pauses.py %s` from gcsim\'s `--events` (`tools/heapsim/sweep2.sh`, question events). '
         'Each collection costs timeline.py\'s linear model: the unit costs tests/gcbench measured (the roadmap\'s *The harness*: H2 copy and mark, H8 '
         'stack slots and frames, H10 sequential reads) where they apply; still PLACEHOLDERS: %s. The mutator\'s time is the bytecode instruction '
         'clock at %.1f ns/instruction (default tier) and %.1f (interpreter), from the bootstrap\'s baseline. Collections at the same allocation clock are one pause; sweeping in the pause '
         '(no --lazy-sweep); minors scan the whole stack (no --watermark). MMU after Cheng and Blelloch (2001). The fixed costs being placeholders, '
         'compare configurations more than milliseconds.\n' % (' '.join(sys.argv[1:]), ', '.join(T.PLACEHOLDERS), T.NS_PER_INSTR['default'], T.NS_PER_INSTR['interp'])]
    for t in traces:
        files = sorted(glob.glob(os.path.join(evd, t + '.*.ev')))
        if not files:
            continue
        o.append('\n## %s\n\n%s' % (t, HEAD))
        for tier in ('default', 'interp'):
            for f in files:
                cfg = os.path.basename(f)[len(t) + 1:-3]
                p, mut, fp = T.from_events(f, A, coef, T.NS_PER_INSTR[tier])
                o.append(row('%s (%s)' % (cfg.replace('_', ' ').replace('nursery', 'n').replace('old ', ''), tier), stats(p, mut)))
        # the copier measured against the model: the same heap settings
        meas = []
        for heap, tag in (('67108864', 'nursery_0_old_copy_heapsize_64M'), ('4194304', 'nursery_0_old_copy_heapsize_4M')):
            g = os.path.join(vd, '%s.%s.50.gclog' % (t, heap))
            ev = os.path.join(evd, '%s.%s.ev' % (t, tag))
            if os.path.exists(g) and os.path.exists(ev):
                pm, mm, _ = T.from_gclog(g, A, T.NS_PER_INSTR['interp'])
                pe, me, _ = T.from_events(ev, A, coef, T.NS_PER_INSTR['interp'])
                sm, se = stats(pm, mm), stats(pe, me)
                meas.append((heap, sm, se))
        if meas:
            o.append('\nThe stock copier, measured (runevm --jit=off --gc-log, pause_ns) against the model at the same heap (measured where validate2.sh ran, which is not an idle machine); '
                     'the mutator at the interpreter\'s placeholder %.1f ns/instruction for both:\n\n%s' % (T.NS_PER_INSTR['interp'], HEAD))
            for heap, sm, se in meas:
                o.append(row('copier %dM measured' % (int(heap) >> 20), sm))
                o.append(row('copier %dM model' % (int(heap) >> 20), se))
                o.append('\nGC time measured / modelled at %dM: %.2f.\n' % (int(heap) >> 20, sm['gc'] / se['gc'] if se['gc'] else 0))
    open(out, 'w').write('\n'.join(o) + '\n')

if __name__ == '__main__':
    main()
