#!/usr/bin/env python3
"""tools/heapsim/report2.py SWEEPDIR OUTDIR [TRACE...]
The simulator's tables of docs/plans/garbage-collector-v2.md (*The
simulator*) from tools/heapsim/sweep2.sh's TSVs (SWEEPDIR/QUESTION/TRACE.tsv:
sweep2.sh --out DIR writes DIR/sweep), one Markdown file per question in OUTDIR
(sim-survival.md, sim-nursery.md, sim-oldspaces.md, sim-fragmentation.md,
sim-remset.md, sim-mutable.md, sim-satb.md, sim-order.md, sim-image.md,
sim-footprint.md). TRACE... limits the traces (default: all, the
bootstrap first). Modelled GC times use timeline.py's PLACEHOLDER
coefficients and say so."""
import csv, os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import timeline

C = timeline.DEFAULT_COEF
MB = 1048576.0

def load(sweep, q, trace):
    p = os.path.join(sweep, q, trace + '.tsv')
    if not os.path.exists(p):
        return []
    rows = list(csv.DictReader(open(p), delimiter='\t'))
    for r in rows:
        for k, v in list(r.items()):
            try:
                r[k] = int(v)
            except (ValueError, TypeError):
                try:
                    r[k] = float(v)
                except (ValueError, TypeError):
                    pass
    return rows

def f(x, d=1):
    return ('%.' + str(d) + 'f') % x

def mb(x):
    return f(x / MB, 1)

def gc_ms(r):
    """a run's GC work from its totals, with the placeholder coefficients (ms)"""
    t = r['minors'] * C['fixed_minor'] + r['majors'] * C['fixed_major']
    t += r['slots_total'] * C['slot'] + r['cards_total'] * (C['card'] + 512 * C['card_byte']) + r['remset_total'] * C['remset']
    t += r['born_rem_fields'] * C['born_rem_field'] + r['mut_scan_total'] * C['mut_scan_byte']
    objs = r['promoted_objs'] if r['promoted_objs'] else 0
    avg = r['copied_minor'] / objs if objs else 32.0
    t += r['copied_minor'] * C['copy_byte'] + (r['copied_minor'] / avg if avg else 0) * C['copy_obj']
    t += r['marked_major_objs'] * C['mark_obj'] + r['marked_fields'] * C['mark_field']
    t += r['sweep_scan'] * C['sweep_byte']
    t += r['moved_objs'] * C['move_obj'] + r['moved_bytes'] * C['move_byte'] + r['evac_objs'] * C['evac_obj'] + r['evac_bytes'] * C['evac_byte']
    if 'jonkers' in r['config'] or r['old'] == 'mlton':
        t += 2 * (r['heap_scan_objs'] * C['scan_obj_jonkers'] + r['heap_scan_bytes'] * C['scan_byte_jonkers']) + 2 * r['marked_ptrs'] * C['ptr_jonkers']
    elif r['old'] == 'mc' or r['compactions']:
        t += 3 * (r['heap_scan_objs'] * C['scan_obj_lisp2'] + r['heap_scan_bytes'] * C['scan_byte_lisp2'])
    t += r['satb_work'] * C['satb_byte']
    return t / 1e6

def label(r):
    c = r['config'].split(',')
    extra = [x for x in c[6:]]
    s = r['old']
    if r['old'] == 'mc' and 'jonkers' in r.get('_args', ''):
        s += ' (Jonkers)'
    return s + (' ' + ' '.join(extra) if extra else '')

def table(head, rows):
    out = ['| ' + ' | '.join(head) + ' |', '|' + '|'.join('---' if i == 0 else '---:' for i in range(len(head))) + '|']
    for r in rows:
        out.append('| ' + ' | '.join(str(x) for x in r) + ' |')
    return '\n'.join(out) + '\n'

def write(outdir, name, title, body, cmd):
    with open(os.path.join(outdir, name), 'w') as fh:
        fh.write('# %s\n\nMade by `%s` from `tools/heapsim/sweep2.sh` (bin/gcsim) over census traces of format 2 (docs/census.md). '
                 'Liveness between census samples is banded; band lo unless a column says otherwise. MB = 2^20 bytes. GC times (where given) use '
                 'timeline.py\'s cost model: the unit costs tests/gcbench measured where they apply, placeholders for the fixed costs, cards, the remembered '
                 'set, sweeping and the compactors\' per-object terms (timeline.PLACEHOLDERS); old-space questions run with --no-stores (no card costs). '
                 'Calibration (the roadmap\'s *The simulator*): on the bootstrap the model gave the stock copier 0.26 s of GC at 64M against 0.43-0.45 s '
                 'measured: the creation-order copy costs are optimistic for a major, whose copy order lies between creation order and shuffled; read GC ms '
                 'as relative.\n\n' % (title, cmd))
        fh.write(body)

def main():
    sweep, outdir = sys.argv[1], sys.argv[2]
    traces = sys.argv[3:] or sorted({os.path.basename(p)[:-4] for p in glob.glob(os.path.join(sweep, '*', '*.tsv'))}, key=lambda t: (not t.startswith('bootstrap'), t))
    cmd = 'tools/heapsim/report2.py ' + ' '.join(sys.argv[1:])
    os.makedirs(outdir, exist_ok=True)
    # --- survival and the nursery ---
    body_s, body_n, body_r = '', '', ''
    for t in traces:
        rows = load(sweep, 'nursery', t)
        if not rows:
            continue
        by = {(r['nursery'], r['promote'], r['band']): r for r in rows}
        ns = sorted({r['nursery'] for r in rows})
        r0 = rows[0]
        body_s += '\n## %s\n\n%d objects, %s MB allocated, max live %s MB (at the samples).\n\n' % (t, r0['objects'], mb(r0['bytes']), mb(r0['max_live']))
        body_s += table(['nursery', 'minors', 'survival lo', 'survival near', 'survival hi', 'promoted p1', 'promoted p2 (lo)', 'survivor copies p2'],
                        [[('%dK' % (n // 1024)) if n < MB else '%dM' % (n // MB), by[(n, 1, 'lo')]['minors'], f(100 * by[(n, 1, 'lo')]['survival'], 2) + '%', (f(100 * by[(n, 1, 'near')]['survival'], 2) + '%') if (n, 1, 'near') in by else '-', f(100 * by[(n, 1, 'hi')]['survival'], 2) + '%',
                          f(100 * by[(n, 1, 'lo')]['promoted_frac'], 2) + '%', f(100 * by[(n, 2, 'lo')]['promoted_frac'], 2) + '%', mb(by[(n, 2, 'lo')]['surv_copied']) + ' MB'] for n in ns if (n, 1, 'lo') in by and (n, 2, 'lo') in by and (n, 1, 'hi') in by])
        body_n += '\n## %s\n\n' % t
        body_n += table(['nursery', 'promote', 'minors', 'majors', 'copied minor MB', 'copied major MB', 'copied total MB', 'peak committed MB', 'stack slots (all)', 'slots above watermark', 'GC ms (model)'],
                        [[('%dK' % (n // 1024)) if n < MB else '%dM' % (n // MB), p, by[(n, p, 'lo')]['minors'], by[(n, p, 'lo')]['majors'], mb(by[(n, p, 'lo')]['copied_minor']), mb(by[(n, p, 'lo')]['copied_major']),
                          mb(by[(n, p, 'lo')]['copied_total']), mb(by[(n, p, 'lo')]['peak_committed']), by[(n, p, 'lo')]['slots_total'], by[(n, p, 'lo')]['watermark_slots_total'], f(gc_ms(by[(n, p, 'lo')]))]
                         for n in ns for p in (1, 2) if (n, p, 'lo') in by])
        body_r += '\n## %s\n\nStores: %d (SETENV %d, ref_set %d, array_update %d), of them into old objects at a 1M nursery: %d.\n\n' % (t, r0['stores'], r0['stores_setenv'], r0['stores_ref'], r0['stores_array'], by.get((MB, 1, 'lo'), r0)['stores_old_src'])
        body_r += table(['nursery', 'promote', 'remset max', 'remset total', 'cards max', 'cards total (old->young)', 'cards total (pointer stores)', 'cards total (all stores)', 'old->young SETENV', 'ref', 'array', 'born-remembered objs'],
                        [[('%dK' % (n // 1024)) if n < MB else '%dM' % (n // MB), p, by[(n, p, 'lo')]['remset_max'], by[(n, p, 'lo')]['remset_total'], by[(n, p, 'lo')]['cards_max'], by[(n, p, 'lo')]['cards_total'],
                          by[(n, p, 'lo')]['cards_ptr_total'], by[(n, p, 'lo')]['cards_any_total'], by[(n, p, 'lo')]['oy_setenv'], by[(n, p, 'lo')]['oy_ref'], by[(n, p, 'lo')]['oy_array'], by[(n, p, 'lo')]['born_rem_total']]
                         for n in ns for p in (1, 2) if (n, p, 'lo') in by])
    write(outdir, 'sim-survival.md', 'Survival by nursery size', body_s, cmd)
    write(outdir, 'sim-nursery.md', 'The nursery: copying, collections, stack', body_n, cmd)
    write(outdir, 'sim-remset.md', 'The remembered set, cards and barrier traffic', body_r, cmd)
    # --- old spaces at equal memory ---
    body_o, body_i, body_f = '', '', ''
    for t in traces:
        rows = load(sweep, 'old', t)
        if not rows:
            continue
        ml = rows[0]['max_live']
        body_o += '\n## %s (max live %s MB, 1M nursery)\n\n' % (t, mb(ml))
        out = []
        for r in rows:
            lim = 'none' if not r['limit'] else f(r['limit_x'], 2) + 'x'
            name = r['old'] + (' (Jonkers)' if 'jonkers' in r['config'] else '')
            out.append([name, lim, r['majors'], mb(r['marked_major']), mb(r['copied_major']), mb(r['moved_bytes'] + r['evac_bytes']), mb(r['sweep_scan']), mb(r['peak_committed']), f(r['peak_committed'] / ml, 2) if ml else '-',
                        f(100 * r['frag_int_mean'], 1), f(100 * r['frag_ext_mean'], 1), r['limit_over'], f(gc_ms(r))])
        body_o += table(['old space', 'limit', 'majors', 'marked MB', 'copied (major) MB', 'moved+evac MB', 'swept MB', 'peak committed MB', 'peak / max live', 'frag int %', 'frag ext %', 'majors over limit', 'GC ms (model)'], out)
        nl = [r for r in rows if not r['limit']]
        body_i += '\n## %s\n\n' % t
        body_i += table(['old space', 'majors', 'marked MB (all majors)', 'share born in first 1%', '5%', '10%', '25%'],
                        [[r['old'], r['majors'], mb(r['marked_major']), f(100 * r['phase01_share'], 1) + '%', f(100 * r['phase05_share'], 1) + '%', f(100 * r['phase10_share'], 1) + '%', f(100 * r['phase25_share'], 1) + '%'] for r in nl[:1] + [x for x in nl if x['old'] in ('immix', 'segfit')]])
        fr = load(sweep, 'frag', t)
        if fr:
            body_f += '\n## %s\n\n' % t
            body_f += table(['config', 'limit', 'majors', 'peak committed MB', 'frag int %', 'frag ext %', 'evacuated MB', 'overflows'],
                            [[r['config'].replace('immix,', 'immix ').replace(',fill=50', '') + (' line=%d block=%dK' % (r['line'], r['block'] // 1024) if r['old'] == 'immix' else '') + (' exact' if r['exact_lines'] else '') + ('' if r['defrag'] else ' nodefrag') if r['old'] == 'immix' else r['config'],
                              'none' if not r['limit'] else f(r['limit_x'], 2) + 'x', r['majors'], mb(r['peak_committed']), f(100 * r['frag_int_mean'], 1), f(100 * r['frag_ext_mean'], 1), mb(r['evac_bytes']), r['limit_over']] for r in fr])
    write(outdir, 'sim-oldspaces.md', 'Old spaces at equal memory', body_o, cmd)
    write(outdir, 'sim-image.md', 'An image or immortal space: the share of marked bytes born early', body_i, cmd)
    write(outdir, 'sim-fragmentation.md', 'Fragmentation: Immix lines, blocks, evacuation; LOS thresholds', body_f, cmd)
    # --- mutable space, SATB, order, 32-bit ---
    for q, name, title, cols in [
        ('mut', 'sim-mutable.md', 'A mutable space scanned at every minor (Poly/ML) vs a barrier',
         [('config', 'config'), ('minors', 'minors'), ('remset total', 'remset_total'), ('cards total', 'cards_total'), ('mutable space MB (allocated)', 'mut_bytes'), ('scanned per run MB', 'mut_scan_total'), ('max scan MB', 'mut_scan_max'), ('stores into it', 'mut_stores'), ('peak committed MB', 'peak_committed'), ('GC ms (model)', None)]),
        ('satb', 'sim-satb.md', 'Incremental snapshot marking: overhead and floating garbage against k',
         [('config', 'config'), ('k', 'satb_k'), ('start', 'satb_theta'), ('cycles', 'satb_cycles'), ('degenerate', 'satb_degenerate'), ('duty', 'satb_duty'), ('float mean MB', 'satb_float_mean'), ('float max MB', 'satb_float_max'), ('peak occupancy MB', 'satb_occ_peak'), ('peak committed MB', 'peak_committed'), ('SATB log (old value ptr)', 'satb_log'), ('of them old', 'satb_log_old'), ('marked by slices MB', 'satb_work')]),
        ('order', 'sim-order.md', 'Placement order: promotion order vs shuffles within each minor',
         [('config', 'config'), ('majors', 'majors'), ('peak committed MB', 'peak_committed'), ('mean committed MB', 'mean_committed'), ('frag int %', 'frag_int_mean'), ('frag ext %', 'frag_ext_mean')]),
        ('bits32', 'sim-footprint.md', 'Footprint: committed, reserved, metadata; the 32-bit sensitivity rows',
         [('config', 'config'), ('size', 'size'), ('ptr', 'ptr_bytes'), ('limit', 'limit_x'), ('bytes MB', 'bytes'), ('max live MB', 'max_live'), ('majors', 'majors'), ('peak committed MB', 'peak_committed'), ('peak reserved MB', 'peak_reserved'), ('peak metadata KB', 'peak_metadata'), ('mean committed MB', 'mean_committed'), ('final committed MB', 'final_committed')])]:
        body = ''
        for t in traces:
            rows = load(sweep, q, t)
            if not rows:
                continue
            body += '\n## %s\n\n' % t
            out = []
            for r in rows:
                line = []
                for h, k in cols:
                    if k is None:
                        line.append(f(gc_ms(r)))
                    elif k == 'config':
                        line.append(r[k])
                    elif k.endswith('_mean') and k.startswith('frag'):
                        line.append(f(100 * r[k], 1))
                    elif 'MB' in h:
                        line.append(mb(r[k]))
                    elif 'KB' in h:
                        line.append(f(r[k] / 1024.0, 0))
                    elif isinstance(r[k], float):
                        line.append(f(r[k], 3))
                    else:
                        line.append(r[k])
                out.append(line)
            body += table([h for h, _ in cols], out)
        write(outdir, name, title, body, cmd)

if __name__ == '__main__':
    main()
