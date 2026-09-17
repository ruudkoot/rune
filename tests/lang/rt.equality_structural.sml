datatype t = A | B of int * string | C of t list
val () = print (Bool.toString (B (1, "x") = B (1, "x")) ^ Bool.toString (B (1, "x") = B (2, "x")) ^ Bool.toString (C [A, B (1, "")] = C [A, B (1, "")]) ^ "\n")
val () = print (Bool.toString ([1, 2, 3] = [1, 2, 3]) ^ Bool.toString ([1, 2] = [1, 2, 3]) ^ Bool.toString ("abc" = "abc") ^ Bool.toString ("abc" = "abd") ^ "\n")
val r1 = ref 0 and r2 = ref 0
val () = print (Bool.toString (r1 = r2) ^ Bool.toString (r1 = r1) ^ Bool.toString (#"a" = #"a") ^ Bool.toString (0w1 = 0w1) ^ Bool.toString (() = ()) ^ "\n")
val a1 = Array.fromList [1] and a2 = Array.fromList [1]
val () = print (Bool.toString (a1 = a2) ^ Bool.toString (a1 = a1) ^ Bool.toString (Vector.fromList [1] = Vector.fromList [1]) ^ "\n")
val () = print (Bool.toString (SOME (1, [2]) <> SOME (1, [2])) ^ Bool.toString (NONE = (NONE : int option)) ^ "\n")
