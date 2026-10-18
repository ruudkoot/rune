from pathlib import Path
import hashlib,csv,json,shutil
root=Path.cwd();out=root/'examples/benchmarks/results/m3-solid';canonical=root/'tests/benchmarks/data/solid'
files={str(p.relative_to(canonical)):(p,p.read_bytes())for p in canonical.rglob('*')if p.is_file()and p.name!='.gitattributes'}
plans=[];groups={};copies=[];used=set()
for scope in ['semantics']:
 for program in sorted((out/scope).rglob('program')):
  if not program.is_dir():continue
  present=[]
  for relative,(source,expected)in sorted(files.items()):
   file=program/relative
   if not file.is_file():continue
   data=file.read_bytes();assert data==expected,(file,source)
   digest=hashlib.sha256(data).hexdigest()
   present.append((relative,digest));used.add(relative);plans.append(file)
  if not present:continue
  identity=hashlib.sha256(json.dumps(present).encode()).hexdigest()
  groups.setdefault(identity,present)
  copies.append((str(program.relative_to(out)),identity))
def table(path,fields,rows):
 with path.open('w')as f:w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(fields);w.writerows(rows)
table(out/'input-identities.tsv',['relative_path','canonical_path','bytes','sha256'],[
 (relative,str(files[relative][0].relative_to(root)),len(files[relative][1]),hashlib.sha256(files[relative][1]).hexdigest())for relative in sorted(used)])
table(out/'input-groups.tsv',['group','relative_path'],[(group,relative)for group,rows in sorted(groups.items())for relative,_ in rows])
table(out/'input-copies.tsv',['artifact_directory','group'],copies)
total=sum(file.stat().st_size for file in plans)
for file in plans:file.unlink()
dst=out/'reference-observers/compact-inputs.py';shutil.copy(Path(__file__).resolve(),dst)
with(out/'source-identities.tsv').open('a')as f:f.write(hashlib.sha256(dst.read_bytes()).hexdigest()+'\t'+str(dst.relative_to(out))+'\n')
print('Replaced',len(plans),'byte-verified duplicate inputs,',total,'bytes;',len(used),'canonical identities;',len(groups),'input groups;',len(copies),'configurations; raw outcomes retained')
