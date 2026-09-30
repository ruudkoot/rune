fun loop (n, total) =
  if n = 0 then total
  else let
    val text = Int.toString n ^ "!"
    val next = fn x => if text = "1!" then x + 1 else x
  in loop (n - 1, next total) end
val _ = print (Int.toString (loop (100000, 0)) ^ "\n")
