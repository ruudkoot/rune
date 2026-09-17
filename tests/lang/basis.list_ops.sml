val l = [3, 1, 2]
fun show l = "[" ^ String.concatWith "," (map Int.toString l) ^ "]"
val () = print (Bool.toString (List.null []) ^ Bool.toString (List.null l) ^ Int.toString (List.hd l) ^ show (List.tl l) ^ Int.toString (List.last l) ^ Int.toString (List.nth (l, 1)) ^ "\n")
val () = print (show (List.take (l, 2)) ^ show (List.drop (l, 2)) ^ Int.toString (List.length l) ^ show (List.rev l) ^ show (l @ [4]) ^ show (List.concat [[1], [2, 3]]) ^ show (List.revAppend ([1, 2], [3])) ^ "\n")
val () = print (show (List.map (fn x => x * 2) l) ^ show (List.mapPartial (fn x => if x > 1 then SOME x else NONE) l) ^ show (List.filter (fn x => x <> 1) l) ^ Int.toString (valOf (List.find (fn x => x > 1) l)) ^ Bool.toString (isSome (List.find (fn x => x > 5) l)) ^ "\n")
val (yes, no) = List.partition (fn x => x mod 2 = 1) l
val () = print (show yes ^ show no ^ Int.toString (List.foldl op+ 0 l) ^ Int.toString (List.foldr (fn (x, acc) => acc * 10 + x) 0 l) ^ show (List.foldl op:: [] l) ^ "\n")
val () = print (Bool.toString (List.exists (fn x => x = 2) l) ^ Bool.toString (List.all (fn x => x > 0) l) ^ Bool.toString (List.all (fn x => x > 1) l) ^ show (List.tabulate (4, fn i => i * i)) ^ "\n")
val () = List.app (fn x => print (Int.toString x)) l
val () = print ((case List.collate Int.compare ([1, 2], [1, 3]) of LESS => "L" | _ => "?") ^ (case List.collate Int.compare ([1, 2], [1]) of GREATER => "G" | _ => "?") ^ (case List.getItem [9, 8] of SOME (x, rest) => Int.toString x ^ show rest | NONE => "?") ^ "\n")
val () = print ((show (List.take (l, 5))) handle Subscript => "Subscript\n")
val () = print ((Int.toString (List.nth (l, ~1))) handle Subscript => "Subscript\n")
val () = print ((Int.toString (List.last [])) handle Empty => "Empty\n")
