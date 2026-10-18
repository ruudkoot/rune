from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'program-source';d.mkdir(exist_ok=True);up=p.parent/'upstreams/sandmark/benchmarks/stdlib'
source='''module OriginalHashtbl=Hashtbl
module OriginalSys=Sys
let created=ref []
let hook=ref(fun(_:Obj.t)->())
let find_hook=ref(fun(_:int option)->())
let hash_hook=ref(fun(_:int)->())
let iter_hook=ref(fun(_:int)(_:int)->())
module Sys=struct include OriginalSys
 let opaque_identity value=(!hook)(Obj.repr value);OriginalSys.opaque_identity value
end
module Hashtbl=struct include OriginalHashtbl
 let create n=let table=OriginalHashtbl.create ~random:false n in created:=Obj.repr table:: !created;table
 let find_opt table key=let result=OriginalHashtbl.find_opt table key in (!find_hook)result;result
 let hash value=let result=OriginalHashtbl.hash value in (!hash_hook)result;result
 let iter callback table=OriginalHashtbl.iter(fun key value->(!iter_hook)key value;callback key value)table
end
'''+(up/'hashtbl_bench.ml').read_text().split('let () =')[0]
(d/'Observed.ml').write_text(source)
names=['int_find1','int_find2','int_replace1','int_replace2','caml_hash_int','caml_hash_tuple','hashtbl_iter','hashtbl_fold','hashtbl_add_resizing','hashtbl_add_sized','hashtbl_add_duplicate','hashtbl_remove','hashtbl_find','hashtbl_filter_map']
calls=[(name,n)for name in names for n in [0,1,5,65]]
body='''module B=Observed
module H=OriginalHashtbl
let seed=Int32.of_string"0x811C9DC5"
let mix h v=Int32.mul(Int32.logxor h v)16777619l
let digest table=H.fold(fun k v acc->Int32.add acc(Int32.of_int(k+v)))table 0l
let run name iterations=
 let sum=ref seed in let observe value=sum:=mix !sum value in
 let generic=H.create ~random:false 2000 and integer=B.IntHashtbl.create 2000 in
 let replace1,find1=B.gen_test_int_replace_and_find 1000 generic in
 let replace2,find2=B.gen_test_int_replace_and_find_int_hash 1000 integer in
 B.created:=[];
 B.hook:=(fun _->());B.find_hook:=(fun _->());B.hash_hook:=(fun _->());B.iter_hook:=(fun _ _->());
 (match name with
 |"int_find1"->let found=ref 0 in B.find_hook:=(fun value->assert(value=None);incr found);
   for _=0 to iterations do let old= !found in find1();assert(!found=old+1000);observe 1000l done;
   assert(H.length generic=0)
 |"int_find2"->for _=0 to iterations do find2();assert(B.IntHashtbl.length integer=0);observe 1000l done
 |"int_replace1"->for _=0 to iterations do replace1();assert(H.length generic=1000);observe 1000l done
 |"int_replace2"->for _=0 to iterations do replace2();assert(B.IntHashtbl.length integer=1000);observe 1000l done
 |"caml_hash_int"->B.hash_hook:=(fun value->observe(Int32.of_int value));
   for _=0 to iterations do for i=0 to 999 do ignore(B.Hashtbl.hash i)done done
 |"caml_hash_tuple"->B.hash_hook:=(fun value->observe(Int32.of_int value));
   for _=0 to iterations do for i=0 to 999 do ignore(B.Hashtbl.hash(i,i))done done
 |"hashtbl_iter"->let visits=ref 0 in B.iter_hook:=(fun key value->assert(key=value);incr visits);
   B.hashtbl_iter iterations;assert(!visits=iterations*1000);
   for _=1 to iterations do observe 1000l done
 |"hashtbl_fold"->B.hook:=(fun obj->observe(Int32.of_int(Obj.obj obj)));B.hashtbl_fold iterations
 |"hashtbl_add_resizing"|"hashtbl_add_sized"->
   B.hashtbl_add(name="hashtbl_add_sized")iterations;
   (match !(B.created)with [table]->observe(digest(Obj.obj table))|_->assert false)
 |"hashtbl_add_duplicate"->B.hashtbl_add_duplicate iterations;
   (match !(B.created)with [table]->observe(digest(Obj.obj table))|_->assert false)
 |"hashtbl_remove"->B.hashtbl_remove iterations;
   assert(List.length !(B.created)=iterations/1000+1);
   List.iter(fun obj->let table=Obj.obj obj in assert(H.length table=0);observe(digest table))!(B.created)
 |"hashtbl_find"->B.hook:=(fun obj->observe(match Obj.obj obj with None->0l|Some value->Int32.of_int value));B.hashtbl_find iterations
 |"hashtbl_filter_map"->B.hashtbl_filter_map iterations;
   (match !(B.created)with [table]->observe(digest(Obj.obj table))|_->assert false)
 |_ ->failwith"selector");
 Printf.printf "%s %d:%lX\\n"name iterations !sum
let ()=List.iter(fun(name,n)->run name n)['''+';'.join('("'+name+'",'+str(n)+')'for name,n in calls)+']\n'
# Module alias is exported by the observed module.
body=body.replace('module H=OriginalHashtbl','module H=B.OriginalHashtbl')
(d/'Observer.ml').write_text(body)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','Observed.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=120);(p/'program.reference').write_bytes(out)
(p/'program-cases.json').write_text(json.dumps([dict(benchmark=name,iterations=n,expected=line.split()[1])for(name,n),line in zip(calls,out.decode().splitlines())],indent=2)+'\n')
assert len(out.decode().splitlines())==len(calls)
print('PASS',len(calls),'original source selector observations including 63-bit wraparound')
