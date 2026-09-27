(* The same with an int constant: the backend checks the tagged value of
   an int against the range of a 32-bit immediate. Expected output:
   1999999999 3 *)
fun f (a : int, b : int, w : int) =
  if a > 100 then f (a - 1, b, w) else Int.toString w ^ " " ^ Int.toString (a + b)
val () = print (f (1, 2, 1999999999) ^ "\n")
