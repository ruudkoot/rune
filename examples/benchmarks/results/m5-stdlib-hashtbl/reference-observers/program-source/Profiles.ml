module B=Observed
module H=B.OriginalHashtbl
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
 Printf.printf "%s %d:%lX\n"name iterations !sum
let ()=List.iter(fun(name,n)->run name n)[("int_find1",0);("int_find1",1000);("int_find2",0);("int_find2",1000);("int_replace1",0);("int_replace1",1000);("int_replace2",0);("int_replace2",1000);("caml_hash_int",0);("caml_hash_int",1000);("caml_hash_int",10000);("caml_hash_tuple",0);("caml_hash_tuple",1000);("hashtbl_iter",1);("hashtbl_iter",1000);("hashtbl_fold",1);("hashtbl_fold",1000);("hashtbl_add_resizing",33);("hashtbl_add_resizing",100000);("hashtbl_add_resizing",1000000);("hashtbl_add_sized",33);("hashtbl_add_sized",100000);("hashtbl_add_sized",1000000);("hashtbl_add_duplicate",17);("hashtbl_add_duplicate",100000);("hashtbl_add_duplicate",500000);("hashtbl_remove",0);("hashtbl_remove",100000);("hashtbl_find",1001);("hashtbl_find",100000);("hashtbl_filter_map",1);("hashtbl_filter_map",100);("hashtbl_filter_map",10000)]
