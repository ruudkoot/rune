(* Real constants and the overloaded operators at Real32.real: a constant is
   read to binary32 (0.1 is 0.100000001490116119384765625), the operators
   round to binary32, and a constant without a constraint is still a real. *)
fun show (x : Real32.real) = Real.fmt (StringCvt.SCI (SOME 20)) (Real32.toLarge x)
val a : Real32.real = 0.1
val () = print (show a ^ "\n")
val b = a + 0.2
val () = print (Real32.toString b ^ " " ^ Real32.fmt StringCvt.EXACT b ^ "\n")
(* 1 + 2^-24 is a tie, which goes to the even 1.0 *)
val () = print (show (1.0 + 5.9604644775390625E~8 : Real32.real) ^ "\n")
val () = print (Bool.toString (a < 0.10000001) ^ " " ^ show (~ a) ^ " " ^ show (abs ~2.5E~3 / 3.0) ^ "\n")
fun sum (x : Real32.real, n) = if n = 0 then x else sum (x + 0.1, n - 1)
val () = print (Real32.toString (sum (0.0, 10)) ^ "\n")
val c = 0.1 + 0.2
val () = print (Real.toString c ^ "\n")
val times : Real32.real * Real32.real -> Real32.real = op *
val () = print (show (times (3.4E38, 10.0)) ^ " " ^ show (1E~46 : Real32.real) ^ "\n")
