val () = print (Int.toString (foldl op+ 0 [1, 2, 3]) ^ " " ^ Int.toString (foldl op* 1 [1, 2, 3, 4]) ^ "\n")
val () = print (String.concatWith "" (map op^ [("a", "b"), ("c", "d")]) ^ "\n")
val cons = op::
val () = print (Int.toString (length (cons (1, [2]))) ^ "\n")
val eq = op=
val () = print (Bool.toString (eq (1, 1)) ^ "\n")
val () = print (Int.toString (op- (10, 3)) ^ Int.toString (Int.- (10, 3)) ^ "\n")
