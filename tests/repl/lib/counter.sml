(* used twice by usecache.in: each use runs it again, with globals of its own *)
structure Counter = struct val n = ref 0 end
val () = Counter.n := !Counter.n + 1
val () = print ("counted " ^ Int.toString (!Counter.n) ^ "\n")
