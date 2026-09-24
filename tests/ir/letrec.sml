(* dump: --dump-after=translate *)
(* A local recursive function is a letrec; a top-level one is a global set
   before it is called. *)
fun count 0 = 0
  | count n = count (n - 1)
val z = let fun down 0 = 0 | down n = down (n - 1) in down 3 end
