from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;up=p.parent/'upstreams/sandmark/benchmarks/stdlib';d=p/'primitive-source';d.mkdir(exist_ok=True)
header='''module Sys=struct
 include Sys
 let calls=ref 0
 let total=ref 0L
 let negative=ref 0
 let zero=ref 0
 let positive=ref 0
 let opaque_identity x =
  let v : int=Obj.obj(Obj.repr x) in
  incr calls;total:=Int64.add !total(Int64.of_int v);
  if v<0 then incr negative else if v=0 then incr zero else incr positive;
  x
end
'''
footer='''let ()=Printf.printf "%d:%Ld:%d:%d:%d\\n" !Sys.calls !Sys.total !Sys.negative !Sys.zero !Sys.positive\n'''
cases=['array_iter','array_forall','array_fold','pervasives_compare_lists','pervasives_compare_ints','pervasives_compare_floats','pervasives_compare_strings','pervasives_equal_ints'];rows=[]
for family in ['array','pervasives']:
 original=up/(family+'_bench.ml');shutil.copyfile(original,d/original.name);(d/('observe_'+family+'.ml')).write_text(header+original.read_text()+'\n'+footer)
 for filename,exe in [(original.name,'original-'+family),('observe_'+family+'.ml','observe-'+family)]:
  with(d/(exe+'-build.log')).open('w')as log:subprocess.run(['ocamlopt','-o',exe,filename],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
for name in cases:
 family=name.split('_',1)[0]
 for profile,count,length in [('smoke',64,16),('normal',10000,1000),('large',10000,10000)]if family=='array'else[('smoke',64,None),('normal',100000,None),('large',1000000,None)]:
  args=[name,str(length),str(count)]if length is not None else[name,str(count)]
  raw=subprocess.check_output([str(d/('original-'+family)),*args],cwd=d,timeout=120);assert raw==b''
  observed=subprocess.check_output([str(d/('observe-'+family)),*args],cwd=d,timeout=120)
  values=list(map(int,observed.decode().strip().split(':')));assert len(values)==5 and values[0]==count and sum(values[2:])==count
  if name=='array_fold':expected=[count,count*length*(length-1)//2,0,0 if length>1 else count,count if length>1 else 0]
  elif name.startswith('array_'):expected=[count,0,0,count,0]
  elif name in ['pervasives_compare_lists','pervasives_compare_strings']:expected=[count,-count,count,0,0]
  elif name=='pervasives_equal_ints':
   n=int(count>=42);expected=[count,n,0,count-n,n]
  else:
   pivot=42 if name=='pervasives_compare_ints'else 5;neg=min(count,pivot-1);zero=int(count>=pivot);pos=max(count-pivot,0);expected=[count,pos-neg,neg,zero,pos]
  assert values==expected,(name,profile,values,expected)
  (p/(name+'-'+profile+'.observe')).write_bytes(observed)
  rendered=f'{values[0]}:{values[1]&0xffffffff:X}:{values[2]}:{values[3]}:{values[4]}\n'
  (p/(name+'-'+profile+'.expected')).write_text(rendered)
  rows.append(dict(benchmark=name,profile=profile,iterations=count,length=length,expected=rendered.strip(),raw_statistics=values))
  print(rows[-1],flush=True)
(p/'primitives-reference.json').write_text(json.dumps(dict(ocamlopt=subprocess.check_output(['ocamlopt','-version'],text=True).strip(),sandmark_revision='5605805954a00497ed197c930641cddd580e1507',observer_scope='Only unit/int/bool results selected; Sys.opaque_identity reference-only override records strict results; unmodified originals checked separately',profiles=rows),indent=2)+'\n')
