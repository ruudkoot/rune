from pathlib import Path
import subprocess,shutil,json,resource,hashlib,time
p=Path(__file__).resolve().parent;up=p.parent/'upstreams/sandmark/benchmarks/graph500seq';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
shutil.copy(up.parent/'graph500par/graphTypes.mli',d/'graphTypes.mli')
library=Path(subprocess.check_output(['ocamlc','-where'],text=True).strip())
stdlib=p/'ocaml-stdlib';stdlib.mkdir(exist_ok=True)
for name in ['array.ml','list.ml','random.ml','stdlib.mli']:
 file=library/name
 if file.is_file():shutil.copy(file,stdlib/name)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:
 for command in [['ocamlopt','-c','graphTypes.mli'],['ocamlopt','-c','generateSeq.mli'],['ocamlopt','-c','generateSeq.ml'],['ocamlopt','-c','sparseGraphSeq.mli'],['ocamlopt','-c','sparseGraphSeq.ml'],['ocamlopt','-c','kernel1Seq.mli'],['ocamlopt','-c','kernel1Seq.ml'],
   ['ocamlopt','-o','original-gen','unix.cmxa','generateSeq.cmx','gen.ml'],
   ['ocamlopt','-o','original-kernel1','unix.cmxa','generateSeq.cmx','sparseGraphSeq.cmx','kernel1Seq.cmx','kernel1_run.ml'],
   ['ocamlopt','-o','original-kronecker','kronecker.ml']]:
  subprocess.run(command,cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
seeded=(d/'gen.ml').read_text().replace('Random.self_init ();','(* Fixed fresh default Random state replaces self_init for reference fixtures. *)')
(d/'seeded_gen.ml').write_text(seeded)
with(d/'seed-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','seeded-gen','unix.cmxa','generateSeq.cmx','seeded_gen.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
# Keep original Marshal bytes, including header/object counts and float endianness.
records=[]
for name,scale,ef in [('smoke',6,4),('normal',12,16),('large',14,16)]:
 target=p/(name+'.marshal');start=time.monotonic()
 r=subprocess.run([str(d/'seeded-gen'),'-scale',str(scale),'-edgefactor',str(ef),str(target)],
   stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 (p/('gen-'+name+'.stdout')).write_bytes(r.stdout);(p/('gen-'+name+'.stderr')).write_bytes(r.stderr)
 raw=target.read_bytes()
 row=dict(mode='generateSeq',profile=name,scale=scale,edge_factor=ef,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),header_hex=raw[:25].hex(),elapsed_seconds=time.monotonic()-start)
 records.append(row);print(row,flush=True)
 r=subprocess.run([str(d/'original-kernel1'),str(target)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 (p/('kernel1-'+name+'.stdout')).write_bytes(r.stdout);(p/('kernel1-'+name+'.stderr')).write_bytes(r.stderr)
for name,scale,ef in [('smoke',3,1),('normal',8,4),('large',10,4)]:
 run=p/('prototype-'+name);run.mkdir(exist_ok=True);start=time.monotonic()
 r=subprocess.run([str(d/'original-kronecker'),str(scale),str(ef)],cwd=run,
   stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 raw=(run/'kronecker.txt').read_bytes();shutil.copy(run/'kronecker.txt',p/(name+'.csv'))
 (p/('prototype-'+name+'.stdout')).write_bytes(r.stdout);(p/('prototype-'+name+'.stderr')).write_bytes(r.stderr)
 row=dict(mode='prototype',profile=name,scale=scale,edge_factor=ef,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),elapsed_seconds=time.monotonic()-start)
 records.append(row);print(row,flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ocaml=subprocess.check_output(['ocamlopt','-version'],text=True).strip(),seed_policy='fresh default Random state; gen self_init removed only in seeded fixture adapter; prototype retains its original default',runs=records),indent=2)+'\n')
