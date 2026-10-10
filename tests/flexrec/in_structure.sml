(* determined by the next declaration inside one structure *)
structure S = struct fun f r = #a r val x = f {a = 1, b = 2} end
val () = print (Int.toString S.x ^ "\n")
