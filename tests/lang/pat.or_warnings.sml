(* Or-patterns and the checks of matches: a rule that its alternatives do
   not make useful is redundant, and the alternatives count towards
   exhaustiveness (compiled with --or-patterns). *)
datatype c = R | G | B
fun covered (R | G | B) = 0
fun partial (R | G) = 1
fun redundant (R | G) = 1
  | redundant (G | R) = 2
  | redundant B = 3
val () = print (Int.toString (covered B + partial R + redundant B) ^ "\n")
