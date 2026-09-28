(* Or-patterns are not Standard ML: without --or-patterns they are rejected. *)
datatype t = A of int | B of int
fun f (A x | B x) = x
