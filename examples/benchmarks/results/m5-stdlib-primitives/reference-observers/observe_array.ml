module Sys=struct
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
let bench_type = Sys.argv.(1)
let length = int_of_string Sys.argv.(2)
let iterations = int_of_string Sys.argv.(3)

let create_array size =
  let a = Array.make size 0 in
  Array.mapi (fun i _ -> i) a

let array_iter iterations =
  let a = create_array length in
  for i = 1 to iterations do
    Sys.opaque_identity
      (Array.iter (fun i -> if i > 2 * length then assert false) a)
  done

let array_forall iterations =
  let a = create_array length in
  for i = 1 to iterations do
    Sys.opaque_identity (assert (Array.for_all (fun i -> i < 2 * length) a))
  done

let array_fold iterations =
  let a = create_array length in
  for i = 1 to iterations do
    ignore (Sys.opaque_identity (Array.fold_left (fun c s -> c + s) 0 a))
  done

let () =
  match bench_type with
  | "array_fold" ->
      array_fold iterations
  | "array_forall" ->
      array_forall iterations
  | "array_iter" ->
      array_iter iterations
  | _ ->
      ()

let ()=Printf.printf "%d:%Ld:%d:%d:%d\n" !Sys.calls !Sys.total !Sys.negative !Sys.zero !Sys.positive
