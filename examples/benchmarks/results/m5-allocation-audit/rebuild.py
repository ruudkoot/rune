from pathlib import Path
import copy,csv,importlib.util,io,subprocess
root=Path.cwd();suite=root/'examples/benchmarks';spec=importlib.util.spec_from_file_location('audit',root/'scripts/benchmark-inventory.py');audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
locks={r['source']:r for r in audit.table(suite/'upstreams.tsv')};up=root/'tests/out/benchmarks/upstreams/sandmark'
assert subprocess.check_output(['git','-C',str(up),'rev-parse','HEAD'],text=True).strip()==locks['sandmark']['revision']
assert not subprocess.check_output(['git','-C',str(up),'status','--porcelain'],text=True).strip()
before=subprocess.check_output(['git','show','HEAD:examples/benchmarks/inventory.tsv'],text=True);old=list(csv.DictReader(io.StringIO(before),delimiter='\t'))
rows=[copy.deepcopy(r)for r in old if r['source']!='sandmark']+audit.build('sandmark',up,locks['sandmark']);audit.names(rows);rows.sort(key=lambda r:(r['source'],r['path']));audit.related(rows)
assert len(rows)==len(old)==861
for a,b in zip(old,rows):
 assert(a['source'],a['path'])==(b['source'],b['path'])
 # Reconciliation validates relationships as sets and retains historical order.
 assert set(a['related'].split(';'))==set(b['related'].split(';'))
 b['related']=a['related']
audit.validate(rows,locks)
differences=[(a,b)for a,b in zip(old,rows)if a!=b];assert len(differences)==4
expected={'benchmarks/simple-tests/'+name+'.exe'for name in ['alloc','lists','stacks','stress']}
assert {a['path']for a,b in differences}==expected
for oldrow,newrow in differences:
 assert {k for k in oldrow if oldrow[k]!=newrow[k]}=={'disposition','reason'}
 assert oldrow['disposition']=='import'and newrow['disposition']=='defer'
lines=before.splitlines(keepends=True);assert len(lines)==len(old)+1;output=[lines[0]]
for a,b,line in zip(old,rows,lines[1:]):
 if a==b:output.append(line)
 else:
  stream=io.StringIO();csv.DictWriter(stream,fieldnames=audit.FIELDS,delimiter='\t',lineterminator='\n').writerow(b);output.append(stream.getvalue())
(suite/'inventory.tsv').write_text(''.join(output))
print('Rebuilt all 143 pinned Sandmark entries; only four reviewed microprobe dispositions/reasons changed; 861 entries and alias order preserved')
