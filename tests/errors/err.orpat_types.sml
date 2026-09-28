(* The alternatives of an or-pattern have one type. *)
datatype t = A of int | B of string
fun f (A x | B x) = 0
