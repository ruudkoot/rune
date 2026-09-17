(* Infix status of identifiers. Scoped lexically by the parser. *)
structure Fixity =
struct
  datatype fixity = Nonfix | Infix of int | Infixr of int

  type env = (string * fixity) list

  val initial : env =
    [("*", Infix 7), ("/", Infix 7), ("div", Infix 7), ("mod", Infix 7),
     ("+", Infix 6), ("-", Infix 6), ("^", Infix 6),
     ("::", Infixr 5), ("@", Infixr 5),
     ("=", Infix 4), ("<>", Infix 4), (">", Infix 4), (">=", Infix 4), ("<", Infix 4), ("<=", Infix 4),
     (":=", Infix 3), ("o", Infix 3),
     ("before", Infix 0)]

  fun lookup (env : env, name) =
    case List.find (fn (n, _) => n = name) env of
      SOME (_, f) => f
    | NONE => Nonfix

  fun isInfix (env, name) = case lookup (env, name) of Nonfix => false | _ => true

  fun precedence (Infix p) = p
    | precedence (Infixr p) = p
    | precedence Nonfix = ~1

  fun isRight (Infixr _) = true
    | isRight _ = false
end
