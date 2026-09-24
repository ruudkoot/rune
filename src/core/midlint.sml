(* What every Mid keeps (docs/ir.md), checked after the stage that made it
   when --lint is given:
   * scope: every variable is used where its binder is in scope, and every
     global is defined once, by a definition of the top level;
   * unique stamps: every binder's stamp is bound once in the program;
   * join points: a jump is to a join point in scope, which is never one of
     a function around the function the jump is in, with an argument for
     each parameter;
   * types: every expression is checked against the type its context wants
     -- a function's result, the join point's, the global's -- and every
     step's type is found from its atoms; a use of a variable gives a type
     for each variable its binder abstracts over, and has the type its
     scheme has at them.
   Functions take one parameter until the calling convention (M8) gives
   them more. A breach is a bug of the compiler, raised as Error.Bug. *)
structure MidLint =
struct
  open Mid

  fun check (p : program) : unit =
    let
      fun bug msg = Error.bug msg
      val bound : unit IntMap.map ref = ref IntMap.empty
      fun bind x =
        if IntMap.member (!bound, x) then bug ("variable v" ^ Int.toString x ^ " is bound twice")
        else bound := IntMap.insert (!bound, x, ())
      fun expect (what, t, want) =
        if Ty.equal (t, want) then ()
        else bug (what ^ " has type " ^ Ty.toString t ^ " where " ^ Ty.toString want ^ " is wanted")

      (* the globals, from their definitions *)
      val globals : scheme IntMap.map ref = ref IntMap.empty
      fun define (g, s) =
        if IntMap.member (!globals, g) then bug ("global g" ^ Int.toString g ^ " is defined twice")
        else globals := IntMap.insert (!globals, g, s)
      fun schemeOf (f : fundef) : scheme = (#tyvars f, funTy f)
      val () =
        List.app (fn Val (g, s, _) => define (g, s)
                   | Funs fs => List.app (fn f => define (#name f, schemeOf f)) fs
                   | Do (gs, _) => List.app define gs) p

      fun instance (what, (tyvars, t) : scheme, args) =
        if List.length tyvars <> List.length args then
          bug (what ^ " abstracts over " ^ Int.toString (List.length tyvars) ^ " variables and is given "
               ^ Int.toString (List.length args) ^ " types")
        else if null tyvars then t
        else Ty.subst (ListPair.foldl (fn (a, u, s) => IntMap.insert (s, a, u)) IntMap.empty (tyvars, args)) t

      fun conArg (what, t, tag) =
        case t of
          Ty.Con (stamp, _, args) =>
            (case Ty.conArg (stamp, args, tag) of
               SOME a => a
             | NONE => bug (what ^ ": " ^ Ty.toString t ^ " has no constructor " ^ Int.toString tag))
        | _ => bug (what ^ ": " ^ Ty.toString t ^ " is no datatype")

      fun atom (env : scheme IntMap.map, a : atom) : Ty.ty =
        case a of
          Var (x, args) =>
            (case IntMap.find (env, x) of
               SOME s => instance ("v" ^ Int.toString x, s, args)
             | NONE => bug ("variable v" ^ Int.toString x ^ " is not in scope"))
        | Global (g, args) =>
            (case IntMap.find (!globals, g) of
               SOME s => instance ("g" ^ Int.toString g, s, args)
             | NONE => bug ("global g" ^ Int.toString g ^ " is not defined"))
        | Const (_, t) => t
        | Con0 (tag, t) =>
            (case conArg ("a nullary constructor", t, tag) of
               NONE => t
             | SOME _ => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " is not nullary"))
        | Unit => Ty.unit

      fun rhs (env, r : rhs) : Ty.ty =
        let fun at a = atom (env, a)
        in
          case r of
            Atom a => at a
          | App (f, [a]) =>
              (case at f of
                 Ty.Arrow (d, res) => (expect ("an argument", at a, d); res)
               | t => bug ("an application of what has type " ^ Ty.toString t))
          | App _ => bug "an application to other than one argument"
          | Prim (p, t, args) =>
              (case t of
                 Ty.Arrow (d, res) =>
                   (case (args, d) of
                      ([a], _) => expect ("the argument of " ^ p, at a, d)
                    | (xs, Ty.Tuple ds) =>
                        if List.length xs = List.length ds then
                          ListPair.app (fn (x, d) => expect ("an argument of " ^ p, at x, d)) (xs, ds)
                        else bug ("primitive " ^ p ^ " of type " ^ Ty.toString t ^ " given "
                                  ^ Int.toString (List.length xs) ^ " arguments")
                    | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t);
                    res)
               | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t))
          | Tuple xs => Ty.Tuple (List.map at xs)
          | Select (i, a) =>
              (case at a of
                 Ty.Tuple ts =>
                   if i < List.length ts then List.nth (ts, i)
                   else bug ("field " ^ Int.toString i ^ " of a tuple of " ^ Int.toString (List.length ts))
               | t => bug ("a field of what has type " ^ Ty.toString t))
          | Con (tag, t, a) =>
              (case conArg ("a constructor", t, tag) of
                 SOME arg => (expect ("the argument of a constructor", at a, arg); t)
               | NONE => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " takes no argument"))
          | Decon (tag, a) =>
              let val t = at a
              in
                case conArg ("a deconstruction", t, tag) of
                  SOME arg => arg
                | NONE => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " has no argument")
              end
          | ConTag a =>
              (case at a of
                 Ty.Con _ => Ty.int
               | t => bug ("the tag of what has type " ^ Ty.toString t))
          | NewExn _ => Ty.ExnCon
          | BuiltinExn _ => Ty.ExnCon
          | MkExn (c, p) => (expect ("an exception constructor", at c, Ty.ExnCon); ignore (at p); Ty.exn)
          | ExnCon a => (expect ("an exception", at a, Ty.exn); Ty.ExnCon)
          | ExnArg (t, a) => (expect ("an exception", at a, Ty.exn); t)
          | SetGlobal (g, a) =>
              (case IntMap.find (!globals, g) of
                 SOME (_, t) => (expect ("the value of global g" ^ Int.toString g, at a, t); Ty.unit)
               | NONE => bug ("global g" ^ Int.toString g ^ " is not defined"))
        end

      (* e in env, where the join points in labels are in scope, wanted to
         have type want *)
      fun exp (env : scheme IntMap.map, labels : Ty.ty list IntMap.map, e : exp, want : Ty.ty) : unit =
        case e of
          Let (x, s as (_, t), r, b) =>
            (expect ("the value of v" ^ Int.toString x, rhs (env, r), t);
             bind x;
             exp (IntMap.insert (env, x, s), labels, b, want))
        | Fun (fs, b) =>
            let val env' = List.foldl (fn (f, env) => (bind (#name f); IntMap.insert (env, #name f, schemeOf f))) env fs
            in List.app (fn f => fundef (env', f)) fs; exp (env', labels, b, want) end
        | Join (j, params, body, scope) =>
            (bind j;
             List.app (fn (x, _) => bind x) params;
             exp (List.foldl (fn ((x, t), env) => IntMap.insert (env, x, ([], t))) env params, labels, body, want);
             exp (env, IntMap.insert (labels, j, List.map #2 params), scope, want))
        | Jump (j, args) =>
            (case IntMap.find (labels, j) of
               SOME ts =>
                 if List.length ts = List.length args then
                   ListPair.app (fn (a, t) => expect ("an argument of join point j" ^ Int.toString j, atom (env, a), t)) (args, ts)
                 else bug ("join point j" ^ Int.toString j ^ " given " ^ Int.toString (List.length args) ^ " arguments")
             | NONE => bug ("join point j" ^ Int.toString j ^ " is not in scope"))
        | If (c, t, f) => (expect ("a condition", atom (env, c), Ty.bool); exp (env, labels, t, want); exp (env, labels, f, want))
        | Handle (a, x, h) =>
            (exp (env, labels, a, want); bind x; exp (IntMap.insert (env, x, ([], Ty.exn)), labels, h, want))
        | Raise a => expect ("what is raised", atom (env, a), Ty.exn)
        | Return r => expect ("a result", rhs (env, r), want)
        | Mark (_, a) => exp (env, labels, a, want)

      and fundef (env, f as {params, result, body, ...} : fundef) =
        case params of
          [(x, t)] => (bind x; exp (IntMap.insert (env, x, ([], t)), IntMap.empty, body, result))
        | _ => bug ("function v" ^ Int.toString (#name f) ^ " has " ^ Int.toString (List.length params) ^ " parameters")

      fun def d =
        case d of
          Val (g, (_, t), e) => (bind g; exp (IntMap.empty, IntMap.empty, e, t))
        | Funs fs => List.app (fn f => (bind (#name f); fundef (IntMap.empty, f))) fs
        | Do (gs, e) => (List.app (fn (g, _) => bind g) gs; exp (IntMap.empty, IntMap.empty, e, Ty.unit))
    in
      List.app def p
    end
end
