#!/usr/bin/env python3
"""tools/heapsim/report3.py LOGDIR OUTDIR -- sim-validation.md and
sim-pretenure.md, the validation of gcsim and its pretenuring table
(docs/plans/garbage-collector-v2.md, *The simulator*), from what the tools
left in LOGDIR (tests/out/gcsim by default for all of them):

  LOGDIR/test2.log         sh tools/heapsim/test2.sh > LOGDIR/test2.log
  LOGDIR/*.log, *.txt      the lines of bin/gcsim --trace T --check, the rows
                           of validate2.sh and of validate-proto.sh, kept in
                           any file of these names (told apart by their shape)
  LOGDIR/pretenure/*.tsv   pretenure.sh --out LOGDIR"""
import csv
import glob
import os
import re
import sys


def lines_of(logdir):
    out = []
    for p in sorted(glob.glob(os.path.join(logdir, '*.log')) + glob.glob(os.path.join(logdir, '*.txt'))):
        out += [l.rstrip('\n') for l in open(p)]
    return out


def val2_table(rows):
    out = ['| trace | heap | fill | stock: coll. semispace copied | lo | hi | band width | clock max diff | verdict |',
           '|---|---:|---:|---|---|---|---:|---:|---|']
    for f in rows:
        st, lo, hi = (x.strip('| ').split() for x in f[3:6])

        def fmt(v):
            return '%s, %d MiB, %.1f MiB' % (v[0], int(v[1]) >> 20, int(v[2]) / 1048576.0)
        out.append('| %s | %dM | %s | %s | %s | %s | %s | %s | %s |' % (f[0], int(f[1]) >> 20, f[2], fmt(st), fmt(lo), fmt(hi),
                                                                      f[6].strip('| '), f[7].replace('maxdiff=', ''), f[8]))
    return '\n'.join(out)


def main():
    if len(sys.argv) != 3:
        sys.exit('usage: tools/heapsim/report3.py LOGDIR OUTDIR')
    logdir, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    cmd = 'tools/heapsim/report3.py ' + ' '.join(sys.argv[1:])
    log = lines_of(logdir)
    o = ['# Validation of the simulator (gcsim)\n',
         'Made by `%s` from the outputs of `tools/heapsim/test2.sh`, `bin/gcsim --trace T --check`, '
         '`tools/heapsim/validate2.sh T...` (the stock VM, --jit=off, with --gc-log) and `tools/heapsim/validate-proto.sh T...` '
         '(a VM with a nursery) on census traces of format 2 (docs/census.md).\n' % cmd]
    # 1. closed forms and identities
    p = os.path.join(logdir, 'test2.log')
    t2 = open(p).read().splitlines() if os.path.exists(p) else []
    ok = [l for l in t2 if l.startswith('ok')]
    bad = [l for l in t2 if l.startswith('FAIL')]
    o.append('\n## 1. Closed-form traces and identities (test2.sh)\n\n%d checks, %d failures. `bin/heapsim-gen --pattern` writes traces whose every '
             'death and sample is placed; each model\'s answer is known beforehand. The identities hold gcsim to sim.c, an independent '
             'implementation, on gen.c\'s random traces in both bands.\n\n```\n%s\n```\n' % (len(ok), len(bad), '\n'.join(t2)))
    # 2. --check
    chk = [l.strip() for l in log if l.startswith('check ') and 'mismatching ' in l]
    nmis = sum(1 for l in chk if 'mismatching 0 ' not in l)
    o.append('\n## 2. Reading the traces (gcsim --check)\n\ndeath.bin with the trace\'s sizes against the census\'s own live bytes at every sample: '
             '%d traces, %d with a mismatching sample.\n\n```\n%s\n```\n' % (len(chk), nmis, '\n'.join(chk)))
    # 3. the copier against the stock VM: validate2.sh's rows (9 fields, the second a heap size)
    v = [f for f in (l.split('\t') for l in log) if len(f) == 9 and f[1].isdigit() and f[3].startswith('|')]
    verdicts = {}
    for r in v:
        verdicts[r[8]] = verdicts.get(r[8], 0) + 1
    coll = [r for r in v if not r[3].strip('| ').startswith('0 ')]
    o.append('\n## 3. The copying model against the stock VM (validate2.sh)\n\nVerdicts over %d rows: %s. ok = the lower band\'s collections '
             'and semispace equal the stock\'s and the stock\'s copied bytes lie in the band (half its width as slack); band = the stock between '
             'the bands; FAIL otherwise. The rows with collections:\n\n%s\n'
             % (len(v), ', '.join('%s %d' % kv for kv in sorted(verdicts.items())) or 'none', val2_table(coll)))
    # 4. the nursery against a VM with one: validate-proto.sh's rows (7 fields)
    vp = [l for l in log if '\t|' in l and len(l.split('\t')) == 7]
    o.append('\n## 4. The nursery against a VM with a nursery (validate-proto.sh)\n\nThe VM (`--nursery N --gc-log`, promotion at the first '
             'survival, a full collection when old space has less room than the nursery holds) against gcsim\'s nursery and copying old space '
             'with the same policy (`--full appel`). Columns: minors, full collections, promoted bytes, dirty cards (summed over the minors; '
             'gcsim\'s cards_any counts stores only, so not comparable exactly). ok = minors and fulls equal the lower band\'s, promoted in the band; '
             'nepotism = promoted above the band (dead old objects keeping young ones alive, which the simulator cannot see); band = the VM\'s '
             'counts between the bands; the percentage is the VM\'s promoted bytes against the band\'s middle.\n\n```\n'
             'trace N | VM: minors fulls promoted cards | lo: ... | hi: ... | vs middle | verdict\n%s\n```\n' % '\n'.join(vp))
    open(os.path.join(outdir, 'sim-validation.md'), 'w').write('\n'.join(o) + '\n')
    # pretenuring: pretenure.sh's LEARN-APPLY.NURSERY.OLD.tsv, its rows naming the trace applied to
    p = ['# Pretenuring by allocation site\n',
         'Made by `%s` from `tools/heapsim/pretenure.sh LEARN APPLY` (gcsim): the survival of each site\'s objects '
         'through their first minor is learned on one run (or its first half, then applied to its second half), '
         'and the sites at or above X%% survival (and 64 KiB allocated) allocate straight into the old space. Sites are bytecode pcs: only runs '
         'of one program share them (the compiler: bootstrap, compile-sigs, compile-hello). saved = bytes a minor would have copied; '
         'garbage = pretenured bytes dead before the next minor (old-space garbage until a major).\n' % cmd,
         '| learn -> apply | nursery, old space | X | promoted MiB | pretenured MiB | copying saved MiB | garbage added MiB | majors | marked MiB | peak committed MiB |',
         '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for f in sorted(glob.glob(os.path.join(logdir, 'pretenure', '*.tsv')), key=lambda x: ('bootstrap' not in x, x)):
        base = os.path.basename(f)[:-4]
        pair, n, old = base.rsplit('.', 2) if base.count('.') >= 2 else (base, '-', '-')
        rows = list(csv.DictReader(open(f), delimiter='\t'))
        apply_ = rows[0].get('workload', '') if rows else ''
        learn = pair[:-len(apply_) - 1] if apply_ and pair.endswith('-' + apply_) else pair
        name = '%s -> %s' % (learn, apply_ or '?') if learn != apply_ else '%s (half -> half)' % learn
        for r in rows:
            m = re.search(r'pretenure=([0-9.]+)', r['config'])

            def mb(k):
                return '%.1f' % (int(r[k]) / 1048576.0)
            p.append('| %s | %s, %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (name, n, old, m.group(1) if m else 'none', mb('promoted'), mb('pt_bytes'),
                                                                              mb('pt_saved'), mb('pt_garbage'), r['majors'], mb('marked_major'), mb('peak_committed')))
    open(os.path.join(outdir, 'sim-pretenure.md'), 'w').write('\n'.join(p) + '\n')


if __name__ == '__main__':
    main()
