(* A toy library: a structure that the basis library does not have. *)
structure Toy =
struct
  fun double (n : int) : int = 2 * n
  fun show (n : int) : string = "toy " ^ Int.toString n
end
