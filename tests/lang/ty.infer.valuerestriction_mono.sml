(* an expansive binding stays monomorphic; it can still be used at one type *)
val r = ref []
val () = r := [1]
val () = print (Int.toString (hd (!r)) ^ "\n")
val f = (fn x => x) (fn y => y)
val () = print (Int.toString (f 3) ^ "\n")
