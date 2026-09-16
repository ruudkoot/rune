(* Resolved, typed syntax. Binding identities remain stable through shadowing. *)
structure Core =
struct
  datatype pattern = P of Source.pos * Types.ty * patternNode
  and patternNode = Bind of int | Wildcard | UnitPattern | TuplePattern of pattern list
                  | ConstructorPattern of int * pattern option
                  | IntegerPattern of IntInf.int | BooleanPattern of bool | StringPattern of string
  datatype expr = E of Source.pos * Types.ty * node
  and node = Integer of IntInf.int | Boolean of bool | String of string | Unit
           | Variable of int | Builtin of int | Binary of string * expr * expr
           | Apply of expr * expr | If of expr * expr * expr
           | Let of (pattern * expr) list * expr | Sequence of expr list
           | Function of {self : int option, param : pattern, body : expr}
           | Tuple of expr list
           | Constructor of int | Case of expr * (pattern * expr) list
  fun position (E (p,_,_)) = p
  fun typeOf (E (_,t,_)) = t
  fun patternType (P (_,t,_)) = t
end
