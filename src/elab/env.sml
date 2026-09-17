(* Static environments for elaboration. *)
structure Env =
struct
  open Types

  datatype valstatus =
      Val of {scheme : scheme, stamp : int, global : bool}
    | Con of {scheme : scheme, info : Ast.coninfo}
    | Exn of {ty : ty, info : Ast.exninfo}
    | Prim of {scheme : scheme, name : string}          (* builtin (overloaded) operator *)

  datatype tystatus =
      Tycon of {tycon : tycon, cons : (string * valstatus) list}
    | Abbrev of {params : int list, body : ty}          (* params: ids of parameter variables in body *)

  datatype env = Env of {vals : valstatus StringMap.map, tys : tystatus StringMap.map, strs : env StringMap.map}

  val empty = Env {vals = StringMap.empty, tys = StringMap.empty, strs = StringMap.empty}

  fun vals (Env e) = #vals e
  fun tys (Env e) = #tys e
  fun strs (Env e) = #strs e

  fun bindVal (Env {vals, tys, strs}, name, v) = Env {vals = StringMap.insert (vals, name, v), tys = tys, strs = strs}
  fun bindTy (Env {vals, tys, strs}, name, t) = Env {vals = vals, tys = StringMap.insert (tys, name, t), strs = strs}
  fun bindStr (Env {vals, tys, strs}, name, s) = Env {vals = vals, tys = tys, strs = StringMap.insert (strs, name, s)}

  (* e2 shadows e1 *)
  fun plus (Env e1, Env e2) =
    Env {vals = StringMap.unionWith #2 (#vals e1, #vals e2),
         tys = StringMap.unionWith #2 (#tys e1, #tys e2),
         strs = StringMap.unionWith #2 (#strs e1, #strs e2)}

  fun findStr (env, []) = SOME env
    | findStr (env, s :: rest) =
      case StringMap.find (strs env, s) of
        SOME e => findStr (e, rest)
      | NONE => NONE

  fun findVal (env, (path, name)) =
    case findStr (env, path) of
      SOME e => StringMap.find (vals e, name)
    | NONE => NONE

  fun findTy (env, (path, name)) =
    case findStr (env, path) of
      SOME e => StringMap.find (tys e, name)
    | NONE => NONE

  (* --- initial environment --- *)
  fun generic (id, eq) = TVar (ref (Unbound {id = id, level = genericLevel, kind = KPlain, eq = eq}))
  fun overloaded (id, names) = TVar (ref (Unbound {id = id, level = genericLevel, kind = KOverload names, eq = false}))

  val a = generic (~1, false)
  val b = generic (~2, false)

  fun conInfo (name, tag, hasArg, ncons) : Ast.coninfo =
    {name = name, tag = tag, hasArg = hasArg, ncons = ncons, isRef = false}

  val boolCons =
    [("false", Con {scheme = boolTy, info = conInfo ("false", 0, false, 2)}),
     ("true", Con {scheme = boolTy, info = conInfo ("true", 1, false, 2)})]
  val listCons =
    [("nil", Con {scheme = listTy a, info = conInfo ("nil", 0, false, 2)}),
     ("::", Con {scheme = TArrow (tupleTy [a, listTy a], listTy a), info = conInfo ("::", 1, true, 2)})]
  val refCons =
    [("ref", Con {scheme = TArrow (a, refTy a),
                  info = {name = "ref", tag = 0, hasArg = true, ncons = 1, isRef = true}})]

  val builtinExns = ["Match", "Bind", "Overflow", "Div", "Subscript", "Size", "Chr", "Domain"]

  fun builtinExn (name, k) =
    (name, Exn {ty = exnTy, info = {name = name, stamp = ~1, isGlobal = true, hasArg = false, builtin = SOME k}})

  val numeric = ["int", "word", "real"]
  val ordered = ["int", "word", "real", "char", "string"]

  fun binop (name, class, id) =
    let val o' = overloaded (id, class)
    in (name, Prim {scheme = TArrow (tupleTy [o', o'], o'), name = name}) end
  fun unop (name, class, id) =
    let val o' = overloaded (id, class)
    in (name, Prim {scheme = TArrow (o', o'), name = name}) end
  fun cmpop (name, class, id) =
    let val o' = overloaded (id, class)
    in (name, Prim {scheme = TArrow (tupleTy [o', o'], boolTy), name = name}) end

  val builtinVals =
    boolCons @ listCons @ refCons @
    List.rev (#1 (List.foldl (fn (n, (acc, k)) => (builtinExn (n, k) :: acc, k + 1)) ([], 0) builtinExns)) @
    [binop ("+", numeric, ~10), binop ("-", numeric, ~11), binop ("*", numeric, ~12),
     binop ("div", ["int", "word"], ~13), binop ("mod", ["int", "word"], ~14),
     binop ("/", ["real"], ~15),
     unop ("~", numeric, ~16), unop ("abs", ["int", "real"], ~17),
     cmpop ("<", ordered, ~18), cmpop ("<=", ordered, ~19), cmpop (">", ordered, ~20), cmpop (">=", ordered, ~21),
     ("=", Prim {scheme = TArrow (tupleTy [a, a], boolTy), name = "="}),
     ("<>", Prim {scheme = TArrow (tupleTy [a, a], boolTy), name = "<>"}),
     (":=", Prim {scheme = TArrow (tupleTy [refTy a, a], unitTy), name = ":="}),
     ("!", Prim {scheme = TArrow (refTy a, a), name = "!"})]

  val builtinTys =
    [("int", Tycon {tycon = intTycon, cons = []}),
     ("word", Tycon {tycon = wordTycon, cons = []}),
     ("real", Tycon {tycon = realTycon, cons = []}),
     ("char", Tycon {tycon = charTycon, cons = []}),
     ("string", Tycon {tycon = stringTycon, cons = []}),
     ("bool", Tycon {tycon = boolTycon, cons = boolCons}),
     ("list", Tycon {tycon = listTycon, cons = listCons}),
     ("ref", Tycon {tycon = refTycon, cons = refCons}),
     ("exn", Tycon {tycon = exnTycon, cons = []}),
     ("array", Tycon {tycon = arrayTycon, cons = []}),
     ("vector", Tycon {tycon = vectorTycon, cons = []}),
     ("unit", Abbrev {params = [], body = unitTy})]

  val initial =
    Env {vals = StringMap.fromList builtinVals,
         tys = StringMap.fromList builtinTys,
         strs = StringMap.empty}
end
