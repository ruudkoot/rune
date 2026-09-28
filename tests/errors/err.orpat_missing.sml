(* ... and nothing else. *)
datatype t = A of int | B of int
fun f (A x | B _) = x
