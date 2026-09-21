val v = Vector.fromList [1, 2, 3]
val () = print (Int.toString (Vector.length v) ^ Int.toString (Vector.sub (v, 2)) ^ Int.toString (Vector.length (Vector.fromList [])) ^ "\n")
val w = Vector.tabulate (3, fn i => i * 2)
val () = print (Int.toString (Vector.foldl op+ 0 w) ^ Int.toString (Vector.foldr (fn (x, acc) => acc * 10 + x) 0 w) ^ Int.toString (Vector.foldli (fn (i, x, acc) => acc + i * x) 0 w) ^ Int.toString (Vector.foldri (fn (i, x, acc) => acc + i) 0 w) ^ "\n")
val () = Vector.app (fn x => print (Int.toString x)) v
val () = Vector.appi (fn (i, x) => print (Int.toString (i * x))) v
val () = print "\n"
val () = print (String.concatWith "," (map Int.toString (Vector.foldr (op ::) [] (Vector.map (fn x => x + 1) v))) ^ String.concatWith "," (map Int.toString (Vector.foldr (op ::) [] (Vector.mapi (fn (i, x) => i + x) v))) ^ "\n")
val () = print (Int.toString (Vector.length (Vector.concat [v, w, v])) ^ Int.toString (Vector.sub (Vector.update (v, 0, 9), 0)) ^ Int.toString (Vector.sub (v, 0)) ^ "\n")
val () = print (Int.toString (valOf (Vector.find (fn x => x > 1) v)) ^ Bool.toString (Vector.exists (fn x => x = 3) v) ^ Bool.toString (Vector.all (fn x => x < 3) v) ^ (case Vector.collate Int.compare (v, w) of GREATER => "G" | _ => "?") ^ "\n")
val () = print (Bool.toString (v = Vector.fromList [1, 2, 3]) ^ Bool.toString (v = w) ^ "\n")
val () = print ((Int.toString (Vector.sub (v, 3))) handle Subscript => "Subscript\n")
val () = print (Int.toString (Vector.length (vector [1, 2])) ^ "\n")
