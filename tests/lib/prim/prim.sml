(* _prim is the basis library's alone. *)
structure Prim =
struct
  val add = _prim "int_add" : int * int -> int
end
