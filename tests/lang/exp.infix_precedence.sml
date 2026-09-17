val () = print (Int.toString (1 + 2 * 3 - 4 div 2) ^ " " ^ Int.toString (2 * 3 mod 4) ^ " " ^ Int.toString (10 - 3 - 2) ^ "\n")
val () = print (String.concatWith "," (map Int.toString (1 :: 2 :: [3] @ [4] @ [5])) ^ "\n")
val () = print (Bool.toString (1 + 1 = 2 andalso 3 > 2 orelse false) ^ "\n")
val r = ref 1
val () = r := !r + 1
val () = print (Int.toString (!r) ^ "\n")
val () = print ("a" ^ "b" ^ "c" ^ "\n")
val f = Int.toString o (fn x => x + 1) o (fn x => x * 2)
val () = print (f 5 ^ "\n")
val () = print (Int.toString (1 before print "before ") ^ "\n")
