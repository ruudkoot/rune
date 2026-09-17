structure Syntax =
struct
  datatype typeExpr = Ty of Source.pos * typeNode
  and typeNode = TypeVariable of string | TypeName of string * typeExpr list
               | Product of typeExpr list | Arrow of typeExpr * typeExpr
  datatype pattern = P of Source.pos * patternNode
  and patternNode = Variable of string | Wildcard | UnitPattern | TuplePattern of pattern list
                  | ConstructorPattern of string * pattern
                  | IntegerPattern of IntInf.int | BooleanPattern of bool | StringPattern of string
  datatype expr = E of Source.pos * node
  and node = Integer of IntInf.int | Boolean of bool | String of string | Unit
           | Name of string | Binary of string * expr * expr
           | Apply of expr * expr | If of expr * expr * expr
           | Let of decl list * expr | Sequence of expr list
           | Fn of (pattern * expr) list | Tuple of expr list
           | Case of expr * (pattern * expr) list
  and decl = Val of Source.pos * pattern * expr
           | Fun of Source.pos * string * (Source.pos * pattern list * expr) list
           | Datatype of Source.pos * string list * string * (Source.pos * string * typeExpr option) list
  fun position (E (p, _)) = p
end
