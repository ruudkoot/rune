from pathlib import Path
import csv,hashlib,shutil
root=Path.cwd();out=root/'examples/benchmarks/results/m3-simple-nofib'
records=list(csv.DictReader((out/'correctness-attempts.tsv').open(),delimiter='\t'))
groups={};plans=[];rows=[]
for record in records:
 directory=root/'examples/benchmarks'/record['artifact_directory']
 source=directory/'matrix.log';data=source.read_bytes();canonical=directory.parent/'matrix.log'
 if canonical in groups:assert groups[canonical]==data,canonical
 else:groups[canonical]=data
 rows.append([str(directory.relative_to(out)),str(canonical.relative_to(out)),len(data),hashlib.sha256(data).hexdigest()])
 plans.append(source)
for canonical,data in groups.items():
 if canonical.exists():assert canonical.read_bytes()==data,canonical
 else:canonical.write_bytes(data)
with(out/'matrix-log-copies.tsv').open('w')as f:
 w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(['artifact_directory','matrix_log','bytes','sha256']);w.writerows(rows)
before=sum(path.stat().st_size for path in plans)
for source in plans:source.unlink()
dest=out/'reference-observers/compact-matrix-logs.py';shutil.copy(Path(__file__).resolve(),dest)
with(out/'source-identities.tsv').open('a')as f:f.write(hashlib.sha256(dest.read_bytes()).hexdigest()+'\t'+str(dest.relative_to(out))+'\n')
print('Preserved',len(groups),'complete byte-verified matrix logs; mapped',len(plans),'per-configuration copies;',before-sum(map(len,groups.values())),'duplicate bytes removed; individual stdout/stderr retained')
