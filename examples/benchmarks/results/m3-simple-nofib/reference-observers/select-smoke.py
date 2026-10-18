from pathlib import Path
import csv,shutil
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
names=['simple-nofib-lazy','simple-nofib-strict','simple-nofib-report-lazy','simple-nofib-report-strict']
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
for name in names:
 d=s/name;report='-report-'in name
 text=(d/'benchmark.sml').read_text();assert 'val gridMax=100'in text
 (d/'smoke-benchmark.sml').write_text(text.replace('val gridMax=100','val gridMax=8'))
 source=('state-'if report else'totals-')+'8-1.reference'
 shutil.copy(p/'data'/source,d/'smoke-8.reference')
 (d/'smoke-8.expected').write_text('1:'+('708'if report else'13')+'\n')
 for row in rows:
  if row['benchmark']==name and row['profile']=='smoke':
   row['args']='1 smoke-8.reference'
   row['input_files']='smoke-8.reference'
   row['expected']=name+'/smoke-8.expected'
   row['sources']=row['sources'].replace(name+'/benchmark.sml',name+'/smoke-benchmark.sml')
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
old='''| Smoke | 100 | 1 |'''
new='''| Smoke | 8 | 1 |'''
for file in [s/'README.md']+[s/n/'PROVENANCE.md'for n in names]:
 t=file.read_text().replace(old,new)
 t=t.replace('''All three preserve the original FAST/NORM/SLOW step counts. The driver accepts''','''All three preserve the original FAST/NORM/SLOW step counts. Smoke reduces
the compile-time grid maximum from 100 to 8 for bounded correctness checks;
normal and large retain the actual upstream grid maximum 100. A thin
profile-specific SML driver selects that constant; the numerical kernel and
data representation are identical. The full-grid source FAST observations
and initial attempts are retained separately. The driver accepts''')
 t=t.replace('''All main checks use the actual grid of 100; the bounded semantic target also
uses a separately recorded source-constant configuration with grid 8.''','''Normal and large use the actual grid of 100. Smoke and the bounded semantic
target use a separately recorded source-constant configuration with grid 8.
A complete one-step report has 708 cells at grid 8 and 110004 at grid 100.''')
 t=t.replace('''Retain exact operation grouping, table coefficients, boundary classifications,
reflection directions, sweep dependencies and traversal/reduction order.
The upstream source contains a stale size-10 comment; its actual grid_max is
100 and all registered profiles retain that value.''','''Retain exact operation grouping, table coefficients, boundary classifications,
reflection directions, sweep dependencies and traversal/reduction order.
The upstream source contains a stale size-10 comment; its actual grid_max is
100. Normal and large retain it; the smoke-only grid reduction is explicit.''')
 file.write_text(t)
# New program-list records can run while initial full-grid cases finish:
# none of their old source/expected/reference files is overwritten.
script=(p/'check-parallel.py').read_text().replace("row['profile']in{'smoke','normal'}","row['profile']=='smoke'").replace('final-simple-nofib-parallel.','final-simple-nofib-smoke.')
assert "row['profile']=='smoke'"in script
(p/'check-smoke.py').write_text(script)
