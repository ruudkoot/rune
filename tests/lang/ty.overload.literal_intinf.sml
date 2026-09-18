(* Integer constants and the overloaded operators at IntInf.int; a constant
   without a constraint is still an int. *)
val a : IntInf.int = 123456789012345678901234567890
val b = a * a + 1
val () = print (IntInf.toString b ^ "\n")
val () = print (Bool.toString (a < b) ^ " " ^ IntInf.toString (~ a) ^ " " ^ IntInf.toString (abs (~ a) div 7) ^ "\n")
fun fact (0 : IntInf.int) = 1
  | fact n = n * fact (n - 1)
val () = print (IntInf.toString (fact 25) ^ "\n")
(* constants in patterns: a computed zero, in either order of the factors, is the constant 0 *)
fun name (0 : IntInf.int) = "zero"
  | name 18446744073709551616 = "2^64"
  | name ~5 = "minus five"
  | name _ = "other"
val () = print (name (fact 25 * 0) ^ " " ^ name (0 * fact 25) ^ " " ^ name (IntInf.pow (2, 64)) ^ " "
                ^ name (2 - 7) ^ " " ^ name 5 ^ "\n")
val () = print (IntInf.toString (0 * fact 25 + ~6) ^ "\n")
val small = 3 + 4
val () = print (Int.toString small ^ "\n")
val plus : IntInf.int * IntInf.int -> IntInf.int = op +
val () = print (IntInf.toString (plus (9223372036854775807, 1)) ^ "\n")
val () = print (IntInf.toString (LargeInt.max (10, 20) mod 7) ^ "\n")
