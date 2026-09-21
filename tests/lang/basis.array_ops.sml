val a = Array.array (3, 0)
val () = Array.update (a, 1, 5)
val () = print (Int.toString (Array.length a) ^ Int.toString (Array.sub (a, 1)) ^ Int.toString (Array.sub (a, 0)) ^ "\n")
val b = Array.fromList [1, 2, 3]
val () = Array.modify (fn x => x * 10) b
val () = print (String.concatWith "," (map Int.toString (Array.foldr (op ::) [] b)) ^ "\n")
val c = Array.tabulate (4, fn i => i + 1)
val () = Array.modifyi (fn (i, x) => i * x) c
val () = print (Int.toString (Array.foldl op+ 0 c) ^ Int.toString (Array.foldr (fn (x, acc) => acc * 10 + x) 0 c) ^ Int.toString (Array.foldli (fn (i, x, acc) => acc + i) 0 c) ^ "\n")
val () = Array.app (fn x => print (Int.toString x)) c
val () = Array.appi (fn (i, x) => print (Int.toString (i + x))) c
val () = print "\n"
val () = print (Int.toString (valOf (Array.find (fn x => x > 3) c)) ^ Bool.toString (Array.exists (fn x => x = 9) c) ^ Bool.toString (Array.all (fn x => x >= 0) c) ^ Int.toString (#1 (valOf (Array.findi (fn (i, x) => x = 6) c))) ^ "\n")
val v = Array.vector c
val () = print (Int.toString (Vector.length v) ^ Int.toString (Vector.sub (v, 3)) ^ "\n")
val d = Array.array (5, ~1)
val () = Array.copy {src = b, dst = d, di = 1}
val () = print (String.concatWith "," (map Int.toString (Array.foldr (op ::) [] d)) ^ "\n")
val () = print ((Int.toString (Array.sub (a, 3))) handle Subscript => "Subscript\n")
val () = print ((Int.toString (Array.length (Array.array (~1, 0)))) handle Size => "Size\n")
val () = print (Bool.toString (a = a) ^ Bool.toString (Array.fromList [] = Array.fromList []) ^ "\n")
