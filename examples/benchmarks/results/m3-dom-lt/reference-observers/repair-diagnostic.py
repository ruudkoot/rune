from pathlib import Path
import shutil,subprocess,resource,ast,json
p=Path(__file__).resolve().parent;original=p/'observer-source';graphs=p/'cases/graphs.in'
source=(original/'Dom.hs').read_text()
old='      when (su < sw)\n        (store sdnoE w su)'
new='      swNow <- sdnoM w\n      when (su < swNow)\n        (store sdnoE w su)'
assert old in source
oldBucket='      store domE v dv))'
newBucket='      store domE v dv)\n    modify(\\e->e{bucketE=IM.insert pw mempty (bucketE e)}))'
assert oldBucket in source
expected=[ast.literal_eval(line)for line in(p/'cases/model-parents.txt').read_text().splitlines()]
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
records=[]
for name,threshold,clear in [('threshold',True,False),('clear-bucket',False,True),('both',True,True)]:
 d=p/('repair-'+name);shutil.copytree(original,d,ignore=shutil.ignore_patterns('*.o','*.hi','original','observer'),dirs_exist_ok=True)
 text=source.replace(old,new)if threshold else source
 if clear:text=text.replace(oldBucket,newBucket)
 (d/'Dom.hs').write_text(text)
 with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run([str(d/'observer'),str(graphs),'+RTS','-M128m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
 (p/('repair-'+name+'.parents')).write_bytes(r.stdout)
 actual=[ast.literal_eval(line)for line in r.stdout.decode().splitlines()]
 mismatch=[i for i,(a,b)in enumerate(zip(actual,expected))if sorted(a)!=b]
 assert len(actual)==len(expected)
 record=dict(variant=name,total=len(actual),matches=len(actual)-len(mismatch),mismatches=mismatch);records.append(record);print(record,flush=True)
(p/'repair-diagnostic.json').write_text(json.dumps(records,indent=2)+'\n')
