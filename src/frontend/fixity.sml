(* Infix status of identifiers. Scoped lexically by the parser. *)
structure Fixity =
struct
  datatype fixity = Nonfix | Infix of int | Infixr of int

  (* The directives in scope, newest first, which a local declaration needs
     to drop those of its first part; and the same in a map, for the lookup
     that every identifier of an expression makes. *)
  type env = {list : (string * fixity) list, table : fixity StringMap.map}

  (* The directives added to env, the first of them the newest. *)
  fun extend ({list, table} : env, directives : (string * fixity) list) : env =
    {list = directives @ list,
     table = List.foldr (fn ((n, f), t) => StringMap.insert (t, n, f)) table directives}

  val initial : env =
    extend ({list = [], table = StringMap.empty},
     [("*", Infix 7), ("/", Infix 7), ("div", Infix 7), ("mod", Infix 7),
      ("+", Infix 6), ("-", Infix 6), ("^", Infix 6),
      ("::", Infixr 5), ("@", Infixr 5),
      ("=", Infix 4), ("<>", Infix 4), (">", Infix 4), (">=", Infix 4), ("<", Infix 4), ("<=", Infix 4),
      (":=", Infix 3), ("o", Infix 3),
      ("before", Infix 0)])

  fun lookup ({table, ...} : env, name) =
    case StringMap.find (table, name) of
      SOME f => f
    | NONE => Nonfix

  (* After `local d1 in d2 end`, where env0 was in scope before it, env1
     after d1 and env2 after d2: the directives of d2 on top of env0, those
     of d1 dropped. *)
  fun afterLocal (env0 : env, env1 : env, env2 : env) : env =
    extend (env0, List.take (#list env2, List.length (#list env2) - List.length (#list env1)))

  fun isInfix (env, name) = case lookup (env, name) of Nonfix => false | _ => true

  fun precedence (Infix p) = p
    | precedence (Infixr p) = p
    | precedence Nonfix = ~1

  fun isRight (Infixr _) = true
    | isRight _ = false
end
