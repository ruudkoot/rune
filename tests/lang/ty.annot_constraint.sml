val f : int -> int = fn x => x
val g = fn x : real => x
val h = (fn x => x) : string -> string
val () = print (Int.toString (f 1) ^ Real.toString (g 1.0) ^ h "s" ^ "\n")
val l : (int * string) list = [(1, "a")]
val () = print (#2 (hd l) ^ "\n")
