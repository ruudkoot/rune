(* dump: --passes=shake,workers --dump-after=workers *)
(* Workers (performance M8): a function of two pairs it only takes apart
   takes the four ints, the fields of the fields, and a variable bound to a
   parameter is the parameter. A call passes the fields it takes, which the
   simplifier finds where the pairs were made. *)
fun sub ((a, b) : int * int, (c, d) : int * int) = (a - c, b - d)
fun use (p, q) = let val r = p in sub (r, q) end
val r = use ((5, 6), (1, 2))
