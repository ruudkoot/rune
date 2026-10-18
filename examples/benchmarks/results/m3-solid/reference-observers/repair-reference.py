from pathlib import Path
import shutil,subprocess,resource,json
p=Path(__file__).resolve().parent;d=p/'repaired-observer-source'
shutil.copytree(p/'observer-source',d,ignore=shutil.ignore_patterns('observer','*.hi','*.o'),dirs_exist_ok=True)
f=d/'Kernel.hs';s=f.read_text()
old='f_f_std_index a_lst a_n=(!!) a_lst a_n;'
new='f_f_std_index a_lst a_n=(!!) a_lst (a_n-1);'
assert s.count(old)==1;f.write_text(s.replace(old,new))
diff=subprocess.run(['diff','-u',str(p/'observer-source/Kernel.hs'),str(f)],capture_output=True);(p/'one-based-vector-index.patch').write_bytes(diff.stdout)
with(p/'repaired-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
for label,args in [('repaired-areas.reference',['areas','12']),('repaired-tables.reference',['tables'])]:
 r=subprocess.run([str(d/'observer'),*args],capture_output=True,check=True,timeout=120,preexec_fn=cap);(p/label).write_bytes(r.stdout)
for depth in range(10):
 r=subprocess.run([str(d/'observer'),'shape',str(depth)],capture_output=True,check=True,timeout=120,preexec_fn=cap)
 (p/('shape-'+str(depth)+'.reference')).write_bytes(r.stdout)
 print('shape',depth,len(r.stdout),flush=True)
independent=json.loads((p/'independent-results.json').read_text())
repaired={int(line.split()[0]):int(line.split()[2])for line in(p/'repaired-areas.reference').read_text().splitlines()}
for row in independent:assert repaired[row['depth']]==row['independent_inside']
print('PASS all10independent uniform-grid membership counts afterone-line index correction')
