structure Syntax =
struct
  datatype pattern = P of Source.pos * patternNode
  and patternNode = Variable of string | Wildcard | UnitPattern | TuplePattern of pattern list
  datatype expr = E of Source.pos * node
  and node = Integer of IntInf.int | Boolean of bool | String of string | Unit
           | Name of string | Binary of string * expr * expr
           | Apply of expr * expr | If of expr * expr * expr
           | Let of decl list * expr | Sequence of expr list
           | Fn of pattern * expr | Tuple of expr list
  and decl = Val of Source.pos * pattern * expr
           | Fun of Source.pos * string * pattern list * expr
  fun position (E (p, _)) = p
end
