(* dump: --passes=trees --dump-after=mid *)
(* A match on a datatype's tags is a Case of Mid (D8 of the haskell98
   roadmap): with decision trees, the tests of x's tag are one, an arm for
   each tag and a default where x has none of theirs, which Lower makes a
   SWITCH (three arms or more) or IFTAGs; g's inner match, of a copy of y,
   is a Case of its own in the outer one's default. *)
datatype t = A | B of int | C of int | D | E of t
fun f x = case x of A => 0 | B n => n | C n => n + 1 | D => 3 | E _ => 4
fun g (y : t) = case y of A => 1 | _ => (case y of A => 2 | B _ => 3 | _ => 4)
val n = f (E D) + g (C 1)
