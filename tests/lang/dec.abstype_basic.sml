(* abstype: the constructors are visible in the body only (rule 19) *)
abstype 'a stack = Stack of 'a list
withtype 'a pair = 'a stack * 'a stack
with
  val empty = Stack []
  fun push (x, Stack xs) = Stack (x :: xs)
  fun pop (Stack []) = NONE | pop (Stack (x :: xs)) = SOME (x, Stack xs)
  fun size (Stack xs) = List.length xs
  fun both (s : 'a stack) : 'a pair = (s, s)
  val sameInside = Stack [1] = Stack [1]        (* equality is available inside the body *)
end
val s = push (2, push (1, empty))
val () = print (Int.toString (size s) ^ Bool.toString sameInside ^ "\n")
val () = case pop s of SOME (x, rest) => print (Int.toString x ^ Int.toString (size rest) ^ "\n") | NONE => print "empty\n"
val p : int pair = both s
val () = print (Int.toString (size (#1 p) + size (#2 p)) ^ "\n")
