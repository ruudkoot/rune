(* A library written on the toy library. *)
structure Toy2 =
struct
  fun quadruple (n : int) : int = Toy.double (Toy.double n)
end
