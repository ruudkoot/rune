datatype 'a env = Env of ('a binding) list
withtype 'a binding = string * 'a
fun lookup (Env bs) k = case List.find (fn (k', _) => k = k') bs of SOME (_, v) => SOME v | NONE => NONE
val e = Env [("a", 1), ("b", 2)]
val () = print (Int.toString (valOf (lookup e "b")) ^ Bool.toString (isSome (lookup e "z")) ^ "\n")
