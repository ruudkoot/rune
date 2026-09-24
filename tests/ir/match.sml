(* dump: --dump-after=translate *)
(* A match of two rules on a list: the first rule's test, a Try whose
   fallback is the second rule, and Match raised after the last. *)
fun len [] = 0
  | len (_ :: rest) = 1 + len rest
