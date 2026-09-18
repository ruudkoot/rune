(* Static environments for elaboration. *)
structure Env =
struct
  open Types

  datatype valstatus =
      Val of {scheme : scheme, stamp : int, global : bool}
    | Con of {scheme : scheme, info : Ast.coninfo}
    | Exn of {ty : ty, info : Ast.exninfo}
    | Prim of {scheme : scheme, name : string}          (* builtin (overloaded) operator *)
    | ConAsVal of {scheme : scheme, info : Ast.coninfo} (* constructor matched by a val specification: a plain value *)
    | ExnAsVal of {ty : ty, info : Ast.exninfo}         (* likewise for an exception constructor *)

  (* A type structure (Section 4.9): a type function and, for a datatype,
     its constructors (in declaration order). *)
  datatype tystatus = TyStr of {fcn : tyfcn, cons : (string * valstatus) list}

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

  (* Union of environments that must not overlap (rule 77: specifications). *)
  fun plusDisjoint (Env e1, Env e2, sp) =
    let
      fun check (what, m1, m2) =
        StringMap.appi (fn (n, _) =>
                           if StringMap.member (m1, n) then
                             Error.error (sp, "duplicate specification of " ^ what ^ " '" ^ n ^ "'")
                           else ()) m2
    in
      check ("value", #vals e1, #vals e2);
      check ("type", #tys e1, #tys e2);
      check ("structure", #strs e1, #strs e2);
      plus (Env e1, Env e2)
    end

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

  fun tyStrName (TyStr {fcn = TName c, ...}) = SOME c
    | tyStrName _ = NONE

  (* --- realisation of environments --- *)
  fun realizeVal (phi : realisation, v : valstatus) : valstatus =
    case v of
      Val {scheme, stamp, global} => Val {scheme = realize (phi, scheme), stamp = stamp, global = global}
    | Con {scheme, info} => Con {scheme = realize (phi, scheme), info = info}
    | Exn {ty, info} => Exn {ty = realize (phi, ty), info = info}
    | Prim {scheme, name} => Prim {scheme = realize (phi, scheme), name = name}
    | ConAsVal {scheme, info} => ConAsVal {scheme = realize (phi, scheme), info = info}
    | ExnAsVal {ty, info} => ExnAsVal {ty = realize (phi, ty), info = info}

  fun realizeTyStr (phi : realisation, TyStr {fcn, cons}) : tystatus =
    TyStr {fcn = realizeFcn (phi, fcn), cons = List.map (fn (n, v) => (n, realizeVal (phi, v))) cons}

  fun realizeEnv (phi : realisation, Env {vals, tys, strs}) : env =
    Env {vals = StringMap.map (fn v => realizeVal (phi, v)) vals,
         tys = StringMap.map (fn t => realizeTyStr (phi, t)) tys,
         strs = StringMap.map (fn e => realizeEnv (phi, e)) strs}

  (* --- initial environment --- *)
  fun generic (id, eq) = TVar (ref (Unbound {id = id, level = genericLevel, kind = KPlain, eq = eq}))
  fun overloaded (id, names) = TVar (ref (Unbound {id = id, level = genericLevel, kind = KOverload names, eq = false}))

  val a = generic (~1, false)
  val b = generic (~2, false)
  val eqa = generic (~3, true)          (* ''a: the type of = and <> (Appendix C) *)

  fun conInfo (name, tag, hasArg, siblings) : Ast.coninfo =
    {name = name, tag = tag, hasArg = hasArg, ncons = List.length siblings, isRef = false, siblings = siblings}

  val boolSiblings = [("false", false), ("true", false)]
  val listSiblings = [("nil", false), ("::", true)]
  val boolCons =
    [("false", Con {scheme = boolTy, info = conInfo ("false", 0, false, boolSiblings)}),
     ("true", Con {scheme = boolTy, info = conInfo ("true", 1, false, boolSiblings)})]
  val listCons =
    [("nil", Con {scheme = listTy a, info = conInfo ("nil", 0, false, listSiblings)}),
     ("::", Con {scheme = TArrow (tupleTy [a, listTy a], listTy a), info = conInfo ("::", 1, true, listSiblings)})]
  val refCons =
    [("ref", Con {scheme = TArrow (a, refTy a),
                  info = {name = "ref", tag = 0, hasArg = true, ncons = 1, isRef = true, siblings = [("ref", true)]}})]

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
     ("=", Prim {scheme = TArrow (tupleTy [eqa, eqa], boolTy), name = "="}),
     ("<>", Prim {scheme = TArrow (tupleTy [eqa, eqa], boolTy), name = "<>"}),
     (":=", Prim {scheme = TArrow (tupleTy [refTy a, a], unitTy), name = ":="}),
     ("!", Prim {scheme = TArrow (refTy a, a), name = "!"})]

  fun nameStr (c, cons) = TyStr {fcn = TName c, cons = cons}

  val builtinTys =
    [("int", nameStr (intTycon, [])),
     ("word", nameStr (wordTycon, [])),
     ("real", nameStr (realTycon, [])),
     ("char", nameStr (charTycon, [])),
     ("string", nameStr (stringTycon, [])),
     ("bool", nameStr (boolTycon, boolCons)),
     ("list", nameStr (listTycon, listCons)),
     ("ref", nameStr (refTycon, refCons)),
     ("exn", nameStr (exnTycon, [])),
     ("array", nameStr (arrayTycon, [])),
     ("vector", nameStr (vectorTycon, [])),
     ("unit", TyStr {fcn = TAbbrev ([], unitTy), cons = []})]

  val initial =
    Env {vals = StringMap.fromList builtinVals,
         tys = StringMap.fromList builtinTys,
         strs = StringMap.empty}
end
