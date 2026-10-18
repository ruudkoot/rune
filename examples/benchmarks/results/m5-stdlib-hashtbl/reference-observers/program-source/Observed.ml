module OriginalHashtbl=Hashtbl
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
module IntHash = struct
  type t = int
  let equal i j = i = j
  let hash i = i land max_int
end

module IntHashtbl = Hashtbl.Make (IntHash)

let gen_test_int_replace_and_find n tbl =
  let replace () =
    for i = 0 to n - 1 do
      Hashtbl.replace tbl i i
    done
  in
  let find () =
    for i = 0 to n - 1 do
      let (_ : int option) = Hashtbl.find_opt tbl i in
      ()
    done
  in
  (replace, find)

let gen_test_int_replace_and_find_int_hash n tbl =
  let replace () =
    for i = 0 to n - 1 do
      IntHashtbl.replace tbl i i
    done
  in
  let find () =
    for i = 0 to n - 1 do
      let (_ : int option) = IntHashtbl.find_opt tbl i in
      ()
    done
  in
  (replace, find)

let n = 1_000

let create_hashtbl size =
  let h = Hashtbl.create size in
  for i = 1 to size do
    Hashtbl.add h i i
  done ;
  h

let hashtbl_iter iterations =
  let h = create_hashtbl n in
  for i = 1 to iterations do
    Hashtbl.iter (fun key data_ -> Sys.opaque_identity ()) h
  done

let hashtbl_fold iterations =
  let h = create_hashtbl n in
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Hashtbl.fold (fun c k v -> c + k + v) h 0))
  done

let hashtbl_add sized iterations =
  let h = Hashtbl.create (if sized then iterations else 1) in
  for i = 1 to iterations do
    Hashtbl.add h i i
  done

let hashtbl_add_duplicate iterations =
  let h = Hashtbl.create 1 in
  for i = 1 to iterations do
    Hashtbl.add h i i ; Hashtbl.add h i i
  done

let hashtbl_remove iterations =
  for _ = 1 to (iterations / n) + 1 do
    let h = create_hashtbl n in
    for i = 1 to n do
      Hashtbl.remove h i
    done
  done

let hashtbl_find iterations =
  let h = create_hashtbl n in
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Hashtbl.find_opt h i))
  done

let hashtbl_filter_map iterations =
  let h = create_hashtbl n in
  for i = 1 to iterations do
    Hashtbl.filter_map_inplace (fun _a b -> Some (2 * b)) h
  done

