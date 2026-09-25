(* dump: --passes=trees --dump-after=translate *)
(* A match as a decision tree: f's rules are a matrix whose first row
   tests the pair's first field, so that field (v6) is tested first, once,
   on every way through; where it is B or C, rule 2 -- which matches any
   first field with the empty list -- is still in play, so the list (v7) is
   tested there too, before B's or C's own rule; D, the constructor left
   when A, B and C are not, is not tested (the datatype has four). The
   rules' bodies are join points (j1..j5), the variables of each its
   parameters, which the leaves of the tree jump to. In g, the list is
   tested once for [], and its tail once for []: :: is what is left. *)
datatype t = A | B of int | C of int * int | D
fun f (A, _) = 0
  | f (_, []) = 1
  | f (B n, x :: _) = n + x
  | f (C (a, b), _) = a + b
  | f (D, _) = 9
fun g xs = case xs of [] => 0 | [x] => x | x :: y :: _ => x + y
