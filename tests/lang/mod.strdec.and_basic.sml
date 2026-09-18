(* simultaneous structure bindings: B does not see A *)
val x = 10
structure A = struct val x = 1 end
and B = struct val y = x + 1 end
val () = print (Int.toString A.x ^ " " ^ Int.toString B.y ^ "\n")
structure C = A and D = B
val () = print (Int.toString (C.x + D.y) ^ "\n")
