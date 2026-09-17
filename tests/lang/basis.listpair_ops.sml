fun show l = "[" ^ String.concatWith "," (map Int.toString l) ^ "]"
val () = print (Int.toString (length (ListPair.zip ([1, 2, 3], ["a", "b"]))) ^ "\n")
val (xs, ys) = ListPair.unzip [(1, "a"), (2, "b")]
val () = print (show xs ^ String.concat ys ^ "\n")
val () = print (show (ListPair.map op+ ([1, 2], [10, 20, 30])) ^ Int.toString (ListPair.foldl (fn (a, b, acc) => a * b + acc) 0 ([1, 2], [3, 4])) ^ Int.toString (ListPair.foldr (fn (a, b, acc) => a - b + acc) 0 ([5, 6], [1, 2])) ^ "\n")
val () = ListPair.app (fn (a, b) => print (Int.toString a ^ b)) ([1, 2], ["x", "y"])
val () = print (Bool.toString (ListPair.all (fn (a, b) => a < b) ([1, 2], [2, 3])) ^ Bool.toString (ListPair.exists (fn (a, b) => a = b) ([1, 2], [2, 2])) ^ Bool.toString (ListPair.allEq (fn (a, b) => a = b) ([1], [1, 2])) ^ "\n")
val () = print ((Int.toString (length (ListPair.zipEq ([1], [1, 2])))) handle ListPair.UnequalLengths => "UnequalLengths\n")
