(* The same word constant as the second of two arguments, which are passed
   in registers. Expected output: 773593FF 1 *)
fun f (a : int, w : word) =
  if a > 100 then f (a - 1, w) else Word.toString w ^ " " ^ Int.toString a
val () = print (f (1, 0w1999999999) ^ "\n")
