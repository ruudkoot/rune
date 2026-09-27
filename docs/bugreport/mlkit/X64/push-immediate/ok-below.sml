(* f takes three arguments; MLKit's X64 backend passes the third on the
   stack. The call below pushes the word constant 0w1073741823 as an
   immediate, which the assembler rejects. Expected output: 3FFFFFFF 3 *)
fun f (a : int, b : int, w : word) =
  if a > 100 then f (a - 1, b, w) else Word.toString w ^ " " ^ Int.toString (a + b)
val () = print (f (1, 2, 0w1073741823) ^ "\n")
