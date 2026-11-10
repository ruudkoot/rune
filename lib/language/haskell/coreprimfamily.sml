(* The values and the exception of a family of Core's primitives
   (coreprimfamily_sig.sml). *)
structure CorePrimFamily : CORE_PRIM_FAMILY =
struct
  datatype value = Int of int | Str of string | Bool of bool | Unit
  exception IOError of int * string * string * int
  type prim = {name : string, ty : string, doc : string, run : value list -> value, mid : string}
  type family = {name : string, prims : prim list, midText : string}
end
