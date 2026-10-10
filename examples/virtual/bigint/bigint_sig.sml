(* A big integer, as the program uses it: the signature its units are
   compiled against, and which both implementations export. *)
signature BIGINT =
sig
  type int
  val fromInt : Int.int -> int
  val + : int * int -> int
  val * : int * int -> int
  val compare : int * int -> order
  val toString : int -> string
end
