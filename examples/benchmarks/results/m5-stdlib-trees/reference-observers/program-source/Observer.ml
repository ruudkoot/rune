module M=Map_observed
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
 Printf.printf "%s %d %lX\n" name n !sum
let ()=List.iter(fun name->List.iter(run name)[0;1;5;1001])["map_iter";"map_add";"map_add_duplicate";"map_remove";"map_fold";"map_for_all";"map_find";"map_map";"set_fold";"set_mem";"set_add_rem"]
