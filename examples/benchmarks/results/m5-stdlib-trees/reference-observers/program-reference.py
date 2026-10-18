from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;up=p.parent/'upstreams/sandmark/benchmarks/stdlib';d=p/'program-source';d.mkdir(exist_ok=True)
m=(up/'map_bench.ml').read_text().split('let () =')[0]
m='let hook=ref(fun(_:Obj.t)->())\nlet iter_hook=ref(fun(_:int)(_:int)->())\nlet ignore x=(!hook)(Obj.repr x)\n'+m
m=m.replace('(fun key data_ -> Sys.opaque_identity ())','(fun key data_ -> (!iter_hook) key data_)')
(d/'map_observed.ml').write_text(m)
s=(up/'set_bench.ml').read_text().split('let () =')[0]
s='let hook=ref(fun(_:Obj.t)->())\nlet bool_hook=ref(fun(_:bool)->())\nlet ignore x=(!hook)(Obj.repr x)\n'+s
s=s.replace('Sys.opaque_identity (assert (IntSet.mem i s == (i <= length)))','let present=IntSet.mem i s in (!bool_hook) present; Sys.opaque_identity(assert(present == (i <= length)))')
(d/'set_observed.ml').write_text(s)
observer='''module M=Map_observed
module S=Set_observed
let sum=ref 0l
let add n=sum:=Int32.add !sum(Int32.of_int n)
let digest_map t=M.IntMap.fold(fun k v acc->Int32.add acc(Int32.of_int(k+v)))t 0l
let digest_set t=S.IntSet.fold(fun k acc->Int32.add acc(Int32.of_int k))t 0l
let run name n=
 sum:=0l;
 (match name with
 |"map_iter"->M.iter_hook:=(fun _ _->add 1);M.map_iter n
 |"map_fold"->M.hook:=(fun x->add(Obj.obj x));M.map_fold n
 |"map_for_all"->M.hook:=(fun x->add(if Obj.obj x then 1 else 0));M.map_for_all n
 |"map_find"->M.hook:=(fun x->add(match Obj.obj x with None->0|Some _->1));M.map_find n
 |"map_map"->M.hook:=(fun x->sum:=Int32.add !sum(digest_map(Obj.obj x)));M.map_map n
 |"map_add"->sum:=digest_map(M.map_add n)
 |"map_add_duplicate"->sum:=digest_map(M.map_add_duplicate n)
 |"map_remove"->sum:=digest_map(M.map_remove n)
 |"set_fold"->S.hook:=(fun x->add(Obj.obj x));S.set_fold n
 |"set_mem"->S.bool_hook:=(fun b->add(if b then 1 else 0));S.set_mem n
 |"set_add_rem"->S.hook:=(fun x->sum:=digest_set(Obj.obj x));S.set_add_rem n
 |_ -> failwith "selector");
 Printf.printf "%s %d %lX\\n" name n !sum
let ()=List.iter(fun name->List.iter(run name)[0;1;5;1001])["map_iter";"map_add";"map_add_duplicate";"map_remove";"map_fold";"map_for_all";"map_find";"map_map";"set_fold";"set_mem";"set_add_rem"]
'''
(d/'Observer.ml').write_text(observer)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','map_observed.ml','set_observed.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=120);(p/'program.reference').write_bytes(out)
def expected(name,n):
 if name=='map_iter':return n*10000
 if name in ['map_add','map_add_duplicate']:return n*(n+1)
 if name=='map_remove':return 99990000 # zero key contributes zero in both cases
 if name=='map_fold':return n*99990000
 if name=='map_for_all':return n
 if name=='map_find':return min(n,9999)
 if name=='map_map':return n*149985000
 if name=='set_fold':return n*500500
 if name=='set_mem':return min(n,1000)
 if name=='set_add_rem':return sum(range(min(n,1000)+1,1001))
for line in out.decode().splitlines():
 name,n,digest=line.split();assert int(digest,16)==expected(name,int(n))%(2**32),(line,expected(name,int(n)))
print('PASS 44 original selector/edge-count digests and independent closed-form/ordered-set models')
