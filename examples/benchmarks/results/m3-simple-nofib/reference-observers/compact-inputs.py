from pathlib import Path
import hashlib,csv,json,shutil
root=Path.cwd();out=root/'examples/benchmarks/results/m3-simple-nofib'
epochs=[('current',root/'tests/benchmarks/data/simple-nofib'),
        ('point-sum-checker',out/'development/aggregate-check-development')]
variants={};identities={}
for epoch,directory in epochs:
 for source in sorted(directory.iterdir()):
  if not source.is_file()or(source.suffix!='.reference'and source.name!='FILES'):continue
  data=source.read_bytes();identity=epoch+'/'+source.name
  record=(identity,source,data,hashlib.sha256(data).hexdigest())
  variants.setdefault(source.name,[]).append(record);identities[identity]=record
plans=[];copies=[];groups={};used=set()
directories=set()
for scope in ['semantics','development','legacy-diagnostics','total-diagnostics']:
 directories.update(path for path in(out/scope).rglob('program')if path.is_dir())
 directories.update(path.parent for path in(out/scope).rglob('driver.sml'))
for directory in sorted(directories):
 present=[]
 for name,choices in sorted(variants.items()):
  file=directory/name
  if not file.is_file():continue
  data=file.read_bytes()
  match=next((r for r in choices if r[2]==data),None)
  assert match is not None,('unknown fixture epoch',file)
  identity,source,_,digest=match
  present.append((name,identity));used.add(identity);plans.append(file)
 if not present:continue
 group=hashlib.sha256(json.dumps(present).encode()).hexdigest()
 groups.setdefault(group,present);copies.append((str(directory.relative_to(out)),group))
def table(path,fields,rows):
 with path.open('w')as f:w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(fields);w.writerows(rows)
table(out/'input-identities.tsv',['identity','canonical_path','bytes','sha256'],[
 (identity,str(identities[identity][1].relative_to(root)),len(identities[identity][2]),identities[identity][3])for identity in sorted(used)])
table(out/'input-groups.tsv',['group','relative_path','identity'],[
 (group,name,identity)for group,rows in sorted(groups.items())for name,identity in rows])
table(out/'input-copies.tsv',['artifact_directory','group'],copies)
total=sum(file.stat().st_size for file in plans)
for file in plans:file.unlink()
dst=out/'reference-observers/compact-inputs.py';shutil.copy(Path(__file__).resolve(),dst)
with(out/'source-identities.tsv').open('a')as f:f.write(hashlib.sha256(dst.read_bytes()).hexdigest()+'\t'+str(dst.relative_to(out))+'\n')
print('Replaced',len(plans),'byte-verified duplicate inputs across both checker epochs;',total,'bytes;',len(used),'canonical identities;',len(copies),'configuration inputs; raw outcomes retained')
