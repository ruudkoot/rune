from pathlib import Path
import subprocess,json,shutil,random,collections
p=Path(__file__).resolve().parent;d=p/'observer-source';d.mkdir(exist_ok=True)
shutil.copy(p/'library/hashtbl.ml',d/'Reference.ml')
rng=random.Random(19790601)
seqs=[[(0,i,i)for i in range(n)]for n in [0,1,16,32,33,65,130]]
seqs += [[(rng.randrange(3),rng.randrange(-12,13),rng.randrange(-25,26))for _ in range(80)]for _ in range(16)]
cases='['+';'.join('['+';'.join('('+str(op)+','+str(key)+','+str(value)+')'for op,key,value in seq)+']'for seq in seqs)+']'
source='''module H=Reference
let show table=
 let text=ref[] in
 Array.iteri(fun i bucket->
  let rec collect=function H.Empty->[]|H.Cons{key;data;next}->(string_of_int key^":"^string_of_int data)::collect next in
  let cells=collect bucket in if cells<>[]then text:=(string_of_int i^"="^String.concat "," cells):: !text)table.H.data;
 string_of_int(H.length table)^"/"^string_of_int(Array.length table.H.data)^"|"^String.concat "|"(List.rev !text)
let cases='''+cases+'''
let ()=List.iter(fun seq->
 let h=H.create ~random:false 1 in
 List.iter(fun(op,k,v)->match op with 0->H.add h k v|1->H.replace h k v|_->H.remove h k)seq;
 print_endline(show h);
 let bindings=H.fold(fun k v xs->(k,v)::xs)h[]in
 print_endline(String.concat ","(List.map(fun(k,v)->string_of_int k^":"^string_of_int v)(List.sort compare bindings)));
 H.filter_map_inplace(fun k v->if k mod 3=0 then None else Some(v+1))h;
 print_endline(show h))cases
let ()=List.iter(fun n->Printf.printf "%d %d %d\\n" n(H.hash n)(H.hash(n,n)))(List.init 1000 Fun.id@[-1000000;-100;-13;-1;1000000])
'''
(d/'Observer.ml').write_text(source)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','Reference.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=60);(p/'results.reference').write_bytes(out)
lines=out.decode().splitlines();assert len(lines)==3*len(seqs)+1005
for i,seq in enumerate(seqs):
 model={}
 for op,k,v in seq:
  if op==0:model[k]=[v]+model.get(k,[])
  elif op==1:
   if model.get(k):model[k][0]=v
   else:model[k]=[v]
  elif model.get(k):model[k].pop(0)
 bindings=sorted((k,v)for k,vs in model.items()for v in vs)
 assert lines[3*i+1]==','.join(str(k)+':'+str(v)for k,v in bindings)
def rotate(v,n):return((v<<n)|(v>>(32-n)))&0xffffffff
def mix(h,d):
 d=(d*0xcc9e2d51)&0xffffffff;d=rotate(d,15);d=(d*0x1b873593)&0xffffffff
 return(rotate(h^d,13)*5+0xe6546b64)&0xffffffff
def finish(h):
 h^=h>>16;h=(h*0x85ebca6b)&0xffffffff;h^=h>>13;h=(h*0xc2b2ae35)&0xffffffff;h^=h>>16
 return h&0x3fffffff
for line in lines[3*len(seqs):]:
 n,integer,pair=map(int,line.split());tag=(2*n+1)&0xffffffff
 assert integer==finish(mix(0,tag))and pair==finish(mix(mix(mix(0,2048),tag),tag))
(p/'sequences.json').write_text(json.dumps(seqs,indent=2)+'\n')
(p/'table-results.json').write_text(json.dumps([dict(sequence=seq,before=lines[3*i],sorted=lines[3*i+1],after=lines[3*i+2])for i,seq in enumerate(seqs)],indent=2)+'\n')
(p/'hash-results.json').write_text(json.dumps([list(map(int,line.split()))for line in lines[3*len(seqs):]],indent=2)+'\n')
print('PASS',len(seqs),'original bucket layouts and independent duplicate-binding models;',1005,'integer/tuple hash pairs and independent modular model')
