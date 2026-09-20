(* Baseline: Takeuchi's function, calls and comparisons. *)
fun tak (x, y, z) = if y < x then tak (tak (x - 1, y, z), tak (y - 1, z, x), tak (z - 1, x, y)) else z
val () = print (Int.toString (tak (18, 12, 6)) ^ "\n")
