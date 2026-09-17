val l = [1, 2, 3]
val l2 = 0 :: l
val l3 = l @ [4]
val () = print (Int.toString (length l2 + length l3 + length []) ^ "\n")
val () = print (String.concatWith "," (map Int.toString (1 :: 2 :: [3, 4] @ [5])) ^ "\n")
val nested = [[1], [], [2, 3]]
val () = print (Int.toString (length (List.concat nested)) ^ "\n")
