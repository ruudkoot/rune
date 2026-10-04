#!/usr/bin/env python3
"""report.py [RESULTS_DIR]: turns results/sweep-*.tsv into Markdown tables,
one file per question, results/sim-*.md, each headed by the command that made it."""
import csv, glob, os, sys, collections
D = sys.argv[1] if len(sys.argv) > 1 else 'tests/out/heapsim'
CMD = 'python3 tools/heapsim/report.py' + (' ' + sys.argv[1] if len(sys.argv) > 1 else '')
rows = []
for f in sorted(glob.glob(f'{D}/sweep-*.tsv')):
    with open(f) as fh:
        for r in csv.DictReader(fh, delimiter='\t'):
            for k, v in r.items():
                try: r[k] = int(v)
                except (ValueError, TypeError):
                    try: r[k] = float(v)
                    except (ValueError, TypeError): pass
            r['lv'] = r['layout'] + ('' if r['variant'] == '-' else '+' + r['variant'])
            rows.append(r)
if not rows: sys.exit('no sweep-*.tsv in ' + D)
def sel(**kw):
    out = []
    for r in rows:
        ok = True
        for k, v in kw.items():
            if callable(v):
                if not v(r[k]): ok = False; break
            elif r[k] != v: ok = False; break
        if ok: out.append(r)
    return out
def params(r, key):
    for p in r['params'].split(','):
        k, v = p.split('=')
        if k == key: return int(v)
    return None
WL_ORDER = ['bootstrap', 'compile-sigs', 'compile-hello', 'runedoc-ir', 'runedoc-page', 'fib', 'tak', 'word_bits', 'real_nbody',
            'list_ops', 'string_ops', 'array_sieve', 'intinf_fact']
workloads = sorted({r['workload'] for r in rows}, key=lambda w: (WL_ORDER.index(w) if w in WL_ORDER else 100, w))
LV_ORDER = ['L0', 'L1', 'L1+REALIMM', 'L1+PAIRS', 'L1+HDR4', 'L1+ALIGN16', 'L1+COMPACT', 'L2', 'L2+HDR4', 'L2+ALIGN16', 'L2+COMPACT',
            'L3', 'L3+NAN51', 'L3+HDR4', 'L3+ALIGN16', 'L3+COMPACT', 'L4', 'L4+L4UNIFORM', 'L4+PAIRS', 'L4+HDR4', 'L4+ALIGN16', 'L4+COMPACT']
lvs = sorted({r['lv'] for r in rows}, key=lambda l: (LV_ORDER.index(l) if l in LV_ORDER else 100, l))
NSIZES = [262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432]
def human(n):
    if n >= 1 << 30 and n % (1 << 30) == 0: return f'{n >> 30}G'
    if n >= 1 << 20 and n % (1 << 20) == 0: return f'{n >> 20}M'
    if n >= 1 << 10 and n % (1 << 10) == 0: return f'{n >> 10}K'
    return str(n)
def mb(n): return f'{n / 1048576:.2f}'
def pct(a, b): return f'{100.0 * a / b:.1f}%' if b else '-'
def ratio(a, b): return f'{a / b:.3f}' if b else '-'
def table(hdr, lines):
    out = ['| ' + ' | '.join(hdr) + ' |', '|' + '|'.join(['---'] * len(hdr)) + '|']
    out += ['| ' + ' | '.join(str(x) for x in l) + ' |' for l in lines]
    return '\n'.join(out)
def write(name, title, body):
    with open(f'{D}/{name}', 'w') as f:
        f.write(f'# {title}\n\nMade by: `{CMD}` (from sweep.sh\'s results/sweep-*.tsv; sim.c of sim/).\n\n{body}\n')
    print('wrote', name)
IDX = {}
for r in rows:
    IDX.setdefault((r['workload'], r['lv'], r['collector'], r['params'], r['band'], r.get('real_level', 'store')), r)
def one(**kw):
    if callable(kw.get('params')):
        s = sel(**kw)
        return s[0] if s else None
    return IDX.get((kw['workload'], kw['lv'], kw['collector'], kw['params'], kw['band'], kw.get('real_level', 'store')))
def copier64(wl, lv, band='lo'):
    return one(workload=wl, lv=lv, collector='copier', band=band, real_level='store', params='heap=67108864,fill=50')

# 1. heap bytes vs L0 per workload x layout (first-order: bytes_allocated, boxes included; independent of the collector)
lines = []
for wl in workloads:
    base = copier64(wl, 'L0')
    if not base: continue
    l = [wl, mb(base['bytes_L0'])]
    for lv in lvs:
        r = copier64(wl, lv)
        l.append(ratio(r['bytes_allocated'], base['bytes_L0']) if r else '-')
    lines.append(l)
write('sim-heap-bytes.md', 'Heap bytes allocated vs L0 (ratio; boxes included; store-level boxing)',
      'bytes_allocated(L)/bytes_L0. A store-level box count: boxes for INT/WORD/REAL fields at allocation and for stored values; not for values that only cross calls or registers.\n\n' +
      table(['workload', 'L0 MiB'] + lvs, lines))

# 2. boxes per workload x layout: count and bytes, split int/word/real; unrepresentable; plus call/result levels
lines = []
for wl in workloads:
    for lv in lvs:
        if lv == 'L0': continue
        for level in ['store', 'call', 'result']:
            r = one(workload=wl, lv=lv, collector='copier', band='lo', real_level=level, params='heap=67108864,fill=50')
            if not r: continue
            if level != 'store' and r['hist_boxes'] == 0: continue
            lines.append([wl, lv, level, r['extra_boxes'], mb(r['extra_box_bytes']), r['boxes_int'], r['boxes_word'], r['boxes_real'],
                          mb(r['box_bytes_int']), mb(r['box_bytes_word']), mb(r['box_bytes_real']), r['unrepresentable'],
                          pct(r['extra_box_bytes'], r['bytes_L0']), r['objects']])
write('sim-boxes.md', 'Extra boxes per workload x layout (count and bytes, by tag)',
      'level: store = boxes at heap stores only (fields at allocation + ref/array/SETENV stores); call = store + every INT/WORD/REAL crossing CALL/RET per census.txt; result = store + every primitive result (upper bound; a result later stored is counted twice). unrepresentable = L1 64-bit ints/words (counted, never boxed). L1/L2 store-level real boxes assume stored reals are value-encodable and stored ints small (stores.bin has no bits class).\n\n' +
      table(['workload', 'layout', 'level', 'boxes', 'box MiB', 'int', 'word', 'real', 'int MiB', 'word MiB', 'real MiB', 'unrepresentable', 'box bytes / L0 bytes', 'objects'], lines))

# 3. bytes copied and collections per workload x layout at 64 MiB (copier), both bands
lines = []
for wl in workloads:
    base = copier64(wl, 'L0')
    if not base: continue
    for lv in lvs:
        lo = copier64(wl, lv, 'lo'); hi = copier64(wl, lv, 'hi')
        if not lo or not hi: continue
        lines.append([wl, lv, mb(lo['bytes_allocated']), ratio(lo['bytes_allocated'], base['bytes_L0']),
                      mb(lo['bytes_copied']), mb(hi['bytes_copied']), ratio(lo['bytes_copied'], base['bytes_copied']) if base['bytes_copied'] else '-',
                      lo['collections_major'], hi['collections_major'], human(lo['final_semispace']), human(hi['final_semispace']),
                      mb(lo['final_live']), mb(hi['final_live']), f"{lo['band_width_pct']:.2f}%"])
write('sim-copied-64M.md', 'Bytes copied and collections at --heap-size 64 MiB (copier), per workload x layout',
      'ratio columns are against L0 of the same workload (lo band). band = the pointwise width of the liveness band the lo run saw at its own triggers.\n\n' +
      table(['workload', 'layout', 'alloc MiB', 'alloc/L0', 'copied lo MiB', 'copied hi MiB', 'copied/L0 (lo)', 'coll lo', 'coll hi', 'semispace lo', 'semispace hi', 'live@exit lo', 'live@exit hi', 'band'], lines))

# 4. collections per workload x layout x heap size (copier), lo/hi
lines = []
HS = [4194304, 16777216, 67108864, 268435456, 1073741824]
for wl in workloads:
    for lv in lvs:
        l = [wl, lv]
        any_ = False
        for h in HS:
            lo = one(workload=wl, lv=lv, collector='copier', band='lo', params=f'heap={h},fill=50')
            hi = one(workload=wl, lv=lv, collector='copier', band='hi', params=f'heap={h},fill=50')
            if lo and hi:
                any_ = True
                l.append(f"{lo['collections_major']}/{hi['collections_major']} ({mb(lo['bytes_copied'])}-{mb(hi['bytes_copied'])})")
            else: l.append('-')
        if any_: lines.append(l)
write('sim-collections.md', 'Collections lo/hi (bytes copied lo-hi, MiB) per workload x layout x initial semispace (copier, fill 50)',
      table(['workload', 'layout'] + [human(h) for h in HS], lines))

# 5. survival fraction by nursery size (per workload; L0 and a few layouts), promote 1 (first survival) and promote 2 (promoted share)
lines = []
for wl in workloads:
    for lv in ['L0', 'L1', 'L4']:
        for band in ['lo', 'hi']:
            l = [wl, lv, band]; any_ = False
            for n in NSIZES:
                r1 = one(workload=wl, lv=lv, collector='nursery', band=band, params=f'nursery={n},promote=1,heap=4194304,fill=50')
                r2 = one(workload=wl, lv=lv, collector='nursery', band=band, params=f'nursery={n},promote=2,heap=4194304,fill=50')
                if r1: any_ = True; l.append(f"{100 * r1['survival_fraction']:.2f}%" + (f" / {100 * r2['promoted_fraction']:.2f}%" if r2 else ''))
                else: l.append('-')
            if any_: lines.append(l)
write('sim-survival.md', 'Nursery survival by nursery size: % of nursery bytes surviving their first minor / % promoted under promote-at-second-survival',
      'Minors are aligned to the census samples (every 256 KiB of L0 allocation, so liveness at a minor is exact and lo = hi); the effective nursery is the first sample at or past N bytes of L-allocation. survival = bytes surviving the first minor / bytes allocated.\n\n' +
      table(['workload', 'layout', 'band'] + [human(n) for n in NSIZES], lines))

# 6. remembered set by nursery size and by site
lines = []
for wl in workloads:
    for lv in ['L0']:
        for n in NSIZES:
            r = one(workload=wl, lv=lv, collector='nursery', band='lo', params=f'nursery={n},promote=1,heap=4194304,fill=50')
            m = one(workload=wl, lv=lv, collector='mutseg', band='lo', params=f'nursery={n},promote=1,heap=4194304,fill=50')
            r2 = one(workload=wl, lv=lv, collector='nursery', band='lo', params=f'nursery={n},promote=2,heap=4194304,fill=50')
            if not r: continue
            lines.append([wl, human(n), r['collections_minor'], r['max_remset_entries'], r['max_remset_cards'], r['remset_entries_total'], r['remset_cards_total'],
                          r['oy_setenv'], r['oy_ref'], r['oy_array'], r['setenv_old_src'], r['stores_setenv'], r['stores_ref'], r['stores_array'],
                          m['max_remset_entries'] if m else '-', m['remset_entries_total'] if m else '-',
                          r2['max_remset_entries'] if r2 else '-', r2['oy_setenv'] if r2 else '-'])
write('sim-remset.md', 'Remembered set by nursery size (L0, promote at first survival): distinct (object, field) entries and 512-byte cards per cycle (max, total over cycles); old->young stores by site',
      'old->young: a store whose object was born before the last minor and whose value was born after it. Cards use the object\'s allocation offset as its address (objects are compacted by copying; approximation). mutseg = the remembered set without SETENV entries (barrier only on REF/ARRAY). setenv_old_src = SETENV stores into an old closure at all (any value). promote2 columns: the same under promote-at-second-survival (old = born before the minor before last).\n\n' +
      table(['workload', 'nursery', 'minors', 'max entries', 'max cards', 'entries total', 'cards total', 'oy SETENV', 'oy ref_set', 'oy array_update', 'SETENV old src', 'SETENV stores', 'ref_set stores', 'array_update stores', 'mutseg max entries', 'mutseg entries total', 'promote2 max entries', 'promote2 oy SETENV'], lines))

# 7. sticky vs copying old space
lines = []
for wl in workloads:
    for n in NSIZES:
        c = one(workload=wl, lv='L0', collector='nursery', band='lo', params=f'nursery={n},promote=1,heap=4194304,fill=50')
        s = one(workload=wl, lv='L0', collector='sticky', band='lo', params=f'nursery={n},heap=4194304,fill=50')
        if not c or not s: continue
        lines.append([wl, human(n), mb(c['bytes_copied_minor']), mb(c['bytes_copied_major']), c['collections_major'], mb(c['max_heap']),
                      mb(s['bytes_marked_minor']), mb(s['bytes_marked_major']), mb(s['sweep_bytes']), s['collections_major'], mb(s['max_heap'])])
write('sim-sticky.md', 'Sticky mark bits vs a copying old space (L0, by nursery size)',
      'copying: promoted bytes (copied once at the minor) + bytes copied by old-space majors (Cheney, initial 4 MiB, fill 50). sticky: survivors marked in place (bytes marked at minors), majors = full mark (bytes) + sweep (bytes of heap swept), heap grown by doubling until live + nursery fit under 50%; no fragmentation model.\n\n' +
      table(['workload', 'nursery', 'promoted MiB', 'major copied MiB', 'majors', 'max heap MiB', 'minor marked MiB', 'major marked MiB', 'swept MiB', 'majors', 'max heap MiB'], lines))

# 8. LOS savings
lines = []
for wl in workloads:
    c = copier64(wl, 'L0'); nur = one(workload=wl, lv='L0', collector='nursery', band='lo', params='nursery=1048576,promote=1,heap=4194304,fill=50')
    if not c: continue
    l = [wl, mb(c['bytes_copied']), mb(c['los_copied_2k']), mb(c['los_copied_8k']), mb(c['los_copied_32k'])]
    l += [mb(nur['bytes_copied']), mb(nur['los_copied_2k']), mb(nur['los_copied_8k']), mb(nur['los_copied_32k'])] if nur else ['-'] * 4
    for t in [2048, 8192, 32768]:
        r = one(workload=wl, lv='L0', collector='los', band='lo', params=f'heap=67108864,fill=50,los={t}')
        l += [f"{r['los_objects']} / {mb(r['los_bytes'])} / {mb(r['los_live_max'])} / {mb(r['bytes_copied'])} / {r['collections_major']}"] if r else ['-']
    lines.append(l)
write('sim-los.md', 'Large-object space: bytes the copier (64 MiB) and the 1 MiB nursery would not copy with objects >= T in a LOS',
      'los collector columns: objects / bytes allocated in the LOS / max live in the LOS / bytes copied by the semispace / collections, with the LOS collected at the same triggers and large objects not counted toward the semispace.\n\n' +
      table(['workload', 'copier copied', '>=2K of it', '>=8K', '>=32K', 'nursery(1M) copied', '>=2K', '>=8K', '>=32K', 'los 2K', 'los 8K', 'los 32K'], lines))

# 9. L4 mono / uniform bracket, plus L1, L2, L5 (PAIRS) vs L0
lines = []
for wl in workloads:
    base = copier64(wl, 'L0')
    if not base: continue
    for lv in ['L1', 'L1+REALIMM', 'L2', 'L3', 'L4', 'L4+L4UNIFORM', 'L1+PAIRS', 'L4+PAIRS']:
        lo = copier64(wl, lv, 'lo'); hi = copier64(wl, lv, 'hi')
        if not lo: continue
        lines.append([wl, lv, ratio(lo['bytes_allocated'], base['bytes_L0']), lo['extra_boxes'], mb(lo['extra_box_bytes']),
                      ratio(lo['bytes_copied'], base['bytes_copied']) if base['bytes_copied'] else '-', ratio(hi['bytes_copied'], copier64(wl, 'L0', 'hi')['bytes_copied']) if hi and base['bytes_copied'] else '-',
                      f"{lo['collections_major']}/{base['collections_major']}"])
write('sim-layouts-vs-L0.md', 'Layouts vs L0 at the 64 MiB copier: heap bytes, boxes, bytes copied (lo and hi bands), collections',
      table(['workload', 'layout', 'alloc/L0', 'boxes', 'box MiB', 'copied/L0 lo', 'copied/L0 hi', 'collections L/L0'], lines))

# 10. coupling: does the layout change the collector's numbers other than proportionally?
lines = []
for wl in workloads:
    base = copier64(wl, 'L0'); bn = one(workload=wl, lv='L0', collector='nursery', band='lo', params='nursery=1048576,promote=1,heap=4194304,fill=50')
    if not base or not bn: continue
    for lv in lvs:
        r = copier64(wl, lv); n = one(workload=wl, lv=lv, collector='nursery', band='lo', params='nursery=1048576,promote=1,heap=4194304,fill=50')
        if not r or not n: continue
        a = r['bytes_allocated'] / base['bytes_L0'] if base['bytes_L0'] else 0
        lines.append([wl, lv, f'{a:.3f}', ratio(r['bytes_copied'], base['bytes_copied']) if base['bytes_copied'] else '-',
                      f"{r['bytes_copied'] / base['bytes_copied'] / a:.3f}" if base['bytes_copied'] and a else '-',
                      f"{r['collections_major']}/{base['collections_major']}", f"{100 * n['survival_fraction']:.2f}% / {100 * bn['survival_fraction']:.2f}%",
                      ratio(n['bytes_copied'], bn['bytes_copied']) if bn['bytes_copied'] else '-', f"{n['collections_minor']}/{bn['collections_minor']}", f"{n['max_remset_entries']}/{bn['max_remset_entries']}"])
write('sim-coupling.md', 'Coupling: the collector\'s numbers under each layout relative to L0, and relative to the layout\'s own heap-bytes ratio',
      'copied/L0/alloc = (bytes copied under L / under L0) / (bytes allocated under L / under L0): 1.000 means the copier\'s work scales exactly with the layout\'s heap bytes; the survival fraction and minor count at the 1 MiB nursery show whether the nursery\'s behaviour changes (a smaller layout fits more objects per nursery, so more of them die before the minor).\n\n' +
      table(['workload', 'layout', 'alloc/L0', 'copied/L0 (64M)', 'copied/L0/alloc', 'collections L/L0', 'survival 1M L / L0', 'nursery copied/L0', 'minors L/L0', 'max remset L/L0'], lines))

# 11. the answers, for the bootstrap and compile-sigs
lines = []
for wl in [w for w in ['bootstrap', 'compile-sigs'] if w in workloads]:
    base = copier64(wl, 'L0'); baseh = copier64(wl, 'L0', 'hi')
    if not base: continue
    for lv in ['L1', 'L1+REALIMM', 'L2', 'L3', 'L4', 'L4+L4UNIFORM', 'L1+PAIRS', 'L4+PAIRS', 'L1+HDR4', 'L1+COMPACT', 'L1+ALIGN16']:
        lo = copier64(wl, lv); hi = copier64(wl, lv, 'hi')
        if not lo: continue
        lines.append([wl, lv, mb(lo['bytes_allocated']), pct(base['bytes_L0'] - lo['bytes_allocated'], base['bytes_L0']),
                      mb(lo['bytes_copied']), mb(hi['bytes_copied']) if hi else '-',
                      pct(base['bytes_copied'] - lo['bytes_copied'], base['bytes_copied']) if base['bytes_copied'] else '-',
                      pct(baseh['bytes_copied'] - hi['bytes_copied'], baseh['bytes_copied']) if hi and baseh and baseh['bytes_copied'] else '-',
                      f"{lo['collections_major']} vs {base['collections_major']}", mb(lo['max_live']), mb(base['max_live']),
                      lo['extra_boxes'], f"int {lo['boxes_int']} word {lo['boxes_word']} real {lo['boxes_real']}", mb(lo['extra_box_bytes']), lo['unrepresentable']])
t1 = table(['workload', 'layout', 'alloc MiB', 'heap bytes saved vs L0', 'copied lo MiB', 'copied hi MiB', 'copied saved (lo)', 'copied saved (hi)', 'collections L vs L0', 'max live L', 'max live L0', 'boxes', 'by tag', 'box MiB', 'unrepresentable'], lines)
lines = []
for wl in [w for w in ['bootstrap', 'compile-sigs'] if w in workloads]:
    for n in [262144, 1048576, 4194304]:
        r = one(workload=wl, lv='L0', collector='nursery', band='lo', params=f'nursery={n},promote=1,heap=4194304,fill=50')
        r2 = one(workload=wl, lv='L0', collector='nursery', band='lo', params=f'nursery={n},promote=2,heap=4194304,fill=50')
        m = one(workload=wl, lv='L0', collector='mutseg', band='lo', params=f'nursery={n},promote=1,heap=4194304,fill=50')
        s = one(workload=wl, lv='L0', collector='sticky', band='lo', params=f'nursery={n},heap=4194304,fill=50')
        if not r: continue
        lines.append([wl, human(n), r['collections_minor'], human(r['nursery_effective']), f"{100 * r['survival_fraction']:.2f}%",
                      f"{100 * r2['promoted_fraction']:.2f}%" if r2 else '-', mb(r['bytes_copied_minor']), mb(r['bytes_copied_major']), r['collections_major'],
                      r['max_remset_entries'], r['max_remset_cards'], r['remset_entries_total'], r['oy_setenv'], r['oy_ref'], r['oy_array'], r['setenv_old_src'],
                      m['max_remset_entries'] if m else '-', mb(s['bytes_marked_major']) if s else '-', mb(s['sweep_bytes']) if s else '-', s['collections_major'] if s else '-'])
t2 = table(['workload', 'nursery', 'minors', 'effective nursery', 'survival (first minor)', 'promoted (2nd survival)', 'promoted MiB', 'old-space copied MiB', 'majors', 'max remset entries', 'max cards', 'entries total', 'old->young SETENV', 'ref_set', 'array_update', 'SETENV into old closure', 'mutseg max entries', 'sticky major marked MiB', 'sticky swept MiB', 'sticky majors'], lines)
lines = []
for wl in [w for w in ['bootstrap', 'compile-sigs'] if w in workloads]:
    c = copier64(wl, 'L0'); nur = one(workload=wl, lv='L0', collector='nursery', band='lo', params='nursery=1048576,promote=1,heap=4194304,fill=50')
    if not c: continue
    for t in [2048, 8192, 32768]:
        r = one(workload=wl, lv='L0', collector='los', band='lo', params=f'heap=67108864,fill=50,los={t}')
        key = {2048: 'los_copied_2k', 8192: 'los_copied_8k', 32768: 'los_copied_32k'}[t]
        lines.append([wl, human(t), mb(c['bytes_copied']), mb(c[key]), pct(c[key], c['bytes_copied']), mb(nur['bytes_copied']) if nur else '-', mb(nur[key]) if nur else '-',
                      r['los_objects'] if r else '-', mb(r['los_bytes']) if r else '-', mb(r['los_live_max']) if r else '-', mb(r['bytes_copied']) if r else '-', r['collections_major'] if r else '-'])
t3 = table(['workload', 'T', 'copier(64M) copied', 'of it objects >= T', 'share', 'nursery(1M) copied', 'of it >= T', 'LOS objects', 'LOS alloc MiB', 'LOS max live', 'semispace copied with LOS', 'collections with LOS'], lines)
write('sim-answers.md', 'The answers for the bootstrap and compile-sigs',
      '## Layouts vs L0 (64 MiB copier; boxes at store level)\n\n' + t1 + '\n\n## Nursery, remembered set, sticky (L0)\n\n' + t2 + '\n\n## Large-object space\n\n' + t3)

# 12. the MLton aggregate: reals, L1's boxes, L1r's effect, 64-bit ints, heap bytes and copying vs L0
lines = []
mlton = [w for w in workloads if w.startswith('mlton-')]
for wl in mlton:
    b = copier64(wl, 'L0'); l1 = copier64(wl, 'L1'); l1r = copier64(wl, 'L1+REALIMM'); l2 = copier64(wl, 'L2'); l4 = copier64(wl, 'L4'); l4u = copier64(wl, 'L4+L4UNIFORM'); l5 = copier64(wl, 'L1+PAIRS')
    n1 = one(workload=wl, lv='L0', collector='nursery', band='lo', params='nursery=1048576,promote=1,heap=4194304,fill=50')
    if not b or not l1: continue
    lines.append([wl, mb(b['bytes_L0']), b['objects'], b['collections_major'], mb(b['bytes_copied']),
                  ratio(l1['bytes_allocated'], b['bytes_L0']), ratio(l5['bytes_allocated'], b['bytes_L0']) if l5 else '-',
                  ratio(l1['bytes_copied'], b['bytes_copied']) if b['bytes_copied'] else '-',
                  l1['boxes_real'], mb(l1['box_bytes_real']), pct(l1['box_bytes_real'], b['bytes_L0']),
                  l1r['boxes_real'] if l1r else '-', l1['unrepresentable'], l2['boxes_word'] + l2['boxes_int'] if l2 else '-',
                  l4['extra_boxes'] if l4 else '-', l4u['extra_boxes'] if l4u else '-',
                  f"{100 * n1['survival_fraction']:.1f}%" if n1 else '-', n1['max_remset_entries'] if n1 else '-', n1['oy_setenv'] if n1 else '-',
                  b['stores_mode'] if 'stores_mode' in b else 'file'])
write('sim-mlton.md', 'The MLton benchmarks (reduced sweep: 7 layouts, copier 64M/4M, nursery 1M/4M, band lo)',
      'L0 columns: bytes allocated, objects, collections and bytes copied at the 64 MiB copier. L1 real boxes = every REAL field at allocation and every REAL stored later (store level); L1r = L1+REALIMM boxes only the reals outside the 63-bit value-encodable range (NaN, inf, huge/tiny exponents, and 0.0 under FORMAT.md\'s rule). unrepresentable = 64-bit ints/words L1 cannot hold (L2 boxes them: next column). stores_mode census-only = stores.bin over 1 GB was not read: stored reals/pointer stores from census.txt\'s counts, no remembered set.\n\n' +
      table(['workload', 'L0 MiB', 'objects', 'coll', 'copied MiB', 'L1 alloc/L0', 'L5 alloc/L0', 'L1 copied/L0', 'L1 real boxes', 'real box MiB', 'of L0 bytes', 'L1r real boxes', 'L1 unrepresentable', 'L2 int/word boxes', 'L4-mono boxes', 'L4-uniform boxes', 'survival 1M', 'max remset 1M', 'oy SETENV', 'stores'], lines))
