from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;d=p/'source';up=p.parent/'upstreams/sandmark/benchmarks/multicore-numerical'
shutil.copyfile(up/'nbody.ml',d/'nbody.ml')
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
with(d/'original-build.log').open('w')as log:subprocess.run(['ocamlopt','-o','original','nbody.ml'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
(d/'kernel.ml').write_text((d/'nbody.ml').read_text().replace('%.9f','%.17g'))
(d/'observer.ml').write_text('''let () =
 Array.iter (fun (b:Kernel.planet) ->
   Printf.printf "%.17g %.17g %.17g %.17g %.17g %.17g %.17g\\n" b.x b.y b.z b.vx b.vy b.vz b.mass) Kernel.bodies
''')
with(d/'observer-build.log').open('w')as log:subprocess.run(['ocamlopt','-o','observer','kernel.ml','observer.ml'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
meta=[]
for profile,steps,count in [('one',0,1),('small-zero',0,4),('small-one',1,4),('small-two',2,4),('smoke',1,16),('normal',20,256),('large',500,1024),('normal-zero',0,256),('large-zero',0,1024)]:
 args=[str(steps),str(count)]
 raw=subprocess.check_output([str(d/'original'),*args],cwd=d,preexec_fn=cap,timeout=3600)
 observed=subprocess.check_output([str(d/'observer'),*args],cwd=d,preexec_fn=cap,timeout=3600)
 lines=observed.splitlines();assert ('\n'.join(format(float(line),'.9f')for line in lines[:2])+'\n').encode()==raw;assert len(b' '.join(lines[2:]).split())==7*count
 (p/(profile+'.stdout')).write_bytes(raw);(p/(profile+'.state')).write_bytes(observed)
 meta.append(dict(profile=profile,steps=steps,bodies=count,stdout=raw.decode().splitlines(),state_numbers=7*count));print(meta[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ocamlopt=subprocess.check_output(['ocamlopt','-version'],text=True).strip(),options=[],sandmark_revision='5605805954a00497ed197c930641cddd580e1507',profiles=meta),indent=2)+'\n')
