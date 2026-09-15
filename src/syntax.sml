structure Syntax =
struct
  datatype expr = E of Source.pos * node
  and node = Integer of IntInf.int | Boolean of bool | String of string | Unit
           | Name of string | Binary of string * expr * expr
           | Apply of expr * expr | If of expr * expr * expr
           | Let of decl list * expr | Sequence of expr list
  and decl = Val of Source.pos * string option * expr
  fun position (E (p, _)) = p
end
