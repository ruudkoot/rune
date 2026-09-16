fun classify xs = case xs of
  [] => 0 | [] :: _ => 1 | (true :: _) :: _ => 42 | (false :: _) :: _ => 3
val _ = print (Int.toString (classify [[true]]) ^ "\n")
fun size xs = case xs of [] => 0 | _ :: tail => 1 + size tail
val _ = print (Int.toString (size [[],[1],[2,3]]) ^ "\n")
