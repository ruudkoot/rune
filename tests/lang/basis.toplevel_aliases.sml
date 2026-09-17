val () = print (Int.toString (length (map (fn x => x) [1, 2])) ^ Int.toString (hd (rev [1, 2])) ^ Int.toString (length (tl [1, 2])) ^ Bool.toString (null []) ^ Int.toString (foldl op+ 0 [1, 2]) ^ Int.toString (foldr op- 0 [5, 2]) ^ "\n")
val () = app print ["a", "b", "\n"]
val () = print (Int.toString (size "abc") ^ str #"x" ^ concat ["c", "d"] ^ implode [#"e"] ^ Int.toString (length (explode "fg")) ^ substring ("hijk", 1, 2) ^ ("l" ^ "m") ^ "\n")
val () = print (Int.toString (ord #"A") ^ str (chr 66) ^ Real.toString (real 3) ^ Int.toString (floor 2.5) ^ Int.toString (ceil 2.5) ^ Int.toString (round 2.4) ^ Int.toString (trunc ~2.5) ^ "\n")
val () = print (Int.toString (length ([1] @ [2, 3])) ^ Int.toString (Vector.length (vector [1, 2, 3])) ^ "\n")
