(* Every alternative of an or-pattern binds the variables of the first. *)
datatype t = A of int | B of int
fun f (A x | B y) = x
