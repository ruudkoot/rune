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
   * calls: a function of other than one parameter (a worker, M8) is only
     called, with an argument for each, and never used as a value.
   * casts, under --functors=functions (functors-units.md, D3), of a
     record's slots (functor_cast, which only Translate's records make: a
     program's own unsafe_cast is not checked): each is to unit or from
     unit, and none cast back from unit gives another ground type than the
     variable bound to the cast to unit was cast from -- what a slot is
     where its value is known, after the expansion (Expand). It sees a
     cast through a variable bound to it, not through an alias or a join
     point's parameter, and a type variable on either side passes.
   A breach is a bug of the compiler, raised as Error.Bug. *)
structure MidLint =
struct
  open Mid

  (* The scheme of a global of a unit before this one, which a unit names
     and does not define (not Pass.whole); set where a session of units
     begins (UnitBasis.startSession), since it is ToMid's to say. *)
  val importedScheme : (int -> scheme option) ref = ref (fn _ => NONE)
  val () = CompilerState.cellRoot ("MidLint.importedScheme", importedScheme)

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

      (* the functions, global and local, of other than one parameter: the
         types of their parameters *)
      val nary : Ty.ty list IntMap.map ref = ref IntMap.empty
      fun naryOf (f : fundef) =
        case #params f of
          [_] => ()
        | ps => nary := IntMap.insert (!nary, #name f, List.map #2 ps)

      (* the globals, from their definitions *)
      val globals : scheme IntMap.map ref = ref IntMap.empty
      fun define (g, s) =
        if IntMap.member (!globals, g) then bug ("global g" ^ Int.toString g ^ " is defined twice")
        else globals := IntMap.insert (!globals, g, s)
      fun schemeOf (f : fundef) : scheme = (#tyvars f, funTy f)
      val () =
        List.app (fn Val (g, s, _) => define (g, s)
                   | Funs fs => List.app (fn f => (define (#name f, schemeOf f); naryOf f)) fs
                   | Do (gs, _) => List.app define gs) p

      fun instance (what, (tyvars, t) : scheme, args) =
        if List.length tyvars <> List.length args then
          bug (what ^ " abstracts over " ^ Int.toString (List.length tyvars) ^ " variables and is given "
               ^ Int.toString (List.length args) ^ " types")
        else if null tyvars then t
        else Ty.subst (ListPair.foldl (fn (a, u, s) => IntMap.insert (s, a, u)) IntMap.empty (tyvars, args)) t

      (* the variables whose value is a cast to unit, of the type cast from *)
      val toUnit : Ty.ty IntTable.table = IntTable.table 64
      fun ground t =
        case Ty.view t of
          Ty.Gen _ => false
        | Ty.Var _ => false
        | Ty.Con (_, _, args) => List.all ground args
        | Ty.Tuple ts => List.all ground ts
        | Ty.Arrow (a, b) => ground a andalso ground b
        | Ty.ExnCon => true
      fun noteCast (x, r) =
        case r of
          Prim ("functor_cast", t, [_]) =>
            (case Ty.view t of
               Ty.Arrow (d, c) => if Ty.equal (c, Ty.unit) andalso not (Ty.equal (d, Ty.unit))
                                  then IntTable.insert (toUnit, x, d) else ()
             | _ => ())
        | _ => ()
      (* a record's slot is unit: a functor_cast is to it or from it *)
      fun toOrFromUnit t =
        case Ty.view t of
          Ty.Arrow (d, c) =>
            if Ty.equal (d, Ty.unit) orelse Ty.equal (c, Ty.unit) then ()
            else bug ("a functor_cast from " ^ Ty.toString d ^ " to " ^ Ty.toString c ^ ", neither unit")
        | _ => bug ("a functor_cast of type " ^ Ty.toString t)
      fun castBack (t, a) =
        case (Ty.view t, a) of
          (Ty.Arrow (d, c), Var (x, _)) => castFrom (d, c, x)
        | (Ty.Arrow (d, c), Global (x, _)) => castFrom (d, c, x)
        | _ => ()
      and castFrom (d, c, x) =
        if not (Ty.equal (d, Ty.unit)) then ()
        else
          case IntTable.find (toUnit, x) of
            SOME from =>
              if ground from andalso ground c andalso not (Ty.equal (from, c)) then
                bug ("v" ^ Int.toString x ^ ", cast to unit from " ^ Ty.toString from ^ ", is cast back to " ^ Ty.toString c)
              else ()
          | NONE => ()

      fun conArg (what, t, tag) =
        case Ty.view t of
          Ty.Con (stamp, _, args) =>
            (case Ty.conArg (stamp, args, tag) of
               SOME a => a
             | NONE => bug (what ^ ": " ^ Ty.toString t ^ " has no constructor " ^ Int.toString tag))
        | _ => bug (what ^ ": " ^ Ty.toString t ^ " is no datatype")

      (* an atom, which must not be a function of other than one parameter:
         such a one is only called (callee) *)
      fun atom (env : scheme IntMap.map, a : atom) : Ty.ty =
        case a of
          Var (x, _) => if IntMap.member (!nary, x) then bug ("v" ^ Int.toString x ^ ", a function of other than one parameter, used as a value") else callee (env, a)
        | Global (g, _) => if IntMap.member (!nary, g) then bug ("g" ^ Int.toString g ^ ", a function of other than one parameter, used as a value") else callee (env, a)
        | _ => callee (env, a)

      and callee (env : scheme IntMap.map, a : atom) : Ty.ty =
        case a of
          Var (x, args) =>
            (case IntMap.find (env, x) of
               SOME s => instance ("v" ^ Int.toString x, s, args)
             | NONE => bug ("variable v" ^ Int.toString x ^ " is not in scope"))
        | Global (g, args) =>
            (case IntMap.find (!globals, g) of
               SOME s => instance ("g" ^ Int.toString g, s, args)
             | NONE =>
                 case if !Pass.whole then NONE else !importedScheme g of
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
          | App (f, args) =>
              let
                val name = case f of Var (x, _) => SOME x | Global (g, _) => SOME g | _ => NONE
                val n = case Option.mapPartial (fn x => IntMap.find (!nary, x)) name of SOME ps => List.length ps | NONE => 1
                val ft = callee (env, f)
                fun wrong () = bug ("an application of what has type " ^ Ty.toString ft)
              in
                case (Ty.view ft, args) of
                  (Ty.Arrow (d, res), [a]) =>
                    if n = 1 then (expect ("an argument", at a, d); res)
                    else bug ("a function of " ^ Int.toString n ^ " parameters given 1 argument")
                | (Ty.Arrow (d, res), _) =>
                    (case Ty.view d of
                       Ty.Tuple ds =>
                         if n = List.length args andalso n = List.length ds then
                           (ListPair.app (fn (a, d) => expect ("an argument", at a, d)) (args, ds); res)
                         else bug ("a function of " ^ Int.toString n ^ " parameters given " ^ Int.toString (List.length args)
                                   ^ " arguments")
                     | _ => wrong ())
                | _ => wrong ()
              end
          | Prim (p, t, args) =>
              ((case (p, args) of ("functor_cast", [a]) => (castBack (t, a); toOrFromUnit t) | _ => ());
               case Ty.view t of
                 Ty.Arrow (d, res) =>
                   (case (args, Ty.view d) of
                      ([a], _) => expect ("the argument of " ^ p, at a, d)
                    | (xs, Ty.Tuple ds) =>
                        if List.length xs = List.length ds then
                          ListPair.app (fn (x, d) => expect ("an argument of " ^ p, at x, d)) (xs, ds)
                        else bug ("primitive " ^ p ^ " of type " ^ Ty.toString t ^ " given "
                                  ^ Int.toString (List.length xs) ^ " arguments")
                    | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t);
                    res)
               | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t))
          | Tuple xs => Ty.tuple (List.map at xs)
          | Select (i, a) =>
              let val t = at a
              in
                case Ty.view t of
                  Ty.Tuple ts =>
                    if i < List.length ts then List.nth (ts, i)
                    else bug ("field " ^ Int.toString i ^ " of a tuple of " ^ Int.toString (List.length ts))
                | _ => bug ("a field of what has type " ^ Ty.toString t)
              end
          | Con (tag, t, a) =>
              (case conArg ("a constructor", t, tag) of
                 SOME arg => (expect ("the argument of a constructor", at a, arg); t)
               | NONE => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " takes no argument"))
          | Decon (tag, t, a) =>
              (expect ("what a deconstruction takes apart", at a, t);
               case conArg ("a deconstruction", t, tag) of
                 SOME arg => arg
               | NONE => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " has no argument"))
          | ConTag a =>
              let val t = at a
              in case Ty.view t of Ty.Con _ => Ty.int | _ => bug ("the tag of what has type " ^ Ty.toString t) end
          | NewExn _ => Ty.exnCon
          | BuiltinExn _ => Ty.exnCon
          | MkExn (c, p) => (expect ("an exception constructor", at c, Ty.exnCon); ignore (at p); Ty.exn)
          | ExnCon a => (expect ("an exception", at a, Ty.exn); Ty.exnCon)
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
             noteCast (x, r);
             exp (IntMap.insert (env, x, s), labels, b, want))
        | Fun (fs, b) =>
            let val env' = List.foldl (fn (f, env) => (bind (#name f); naryOf f; IntMap.insert (env, #name f, schemeOf f)))
                                      env fs
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
        if null params then bug ("function v" ^ Int.toString (#name f) ^ " has no parameter")
        else
          (List.app (fn (x, _) => bind x) params;
           exp (List.foldl (fn ((x, t), env) => IntMap.insert (env, x, ([], t))) env params, IntMap.empty, body, result))

      fun valueOf e = case e of Mark (_, e) => valueOf e | Return r => SOME r | _ => NONE
      fun def d =
        case d of
          Val (g, (_, t), e) => (bind g; exp (IntMap.empty, IntMap.empty, e, t); Option.app (fn r => noteCast (g, r)) (valueOf e))
        | Funs fs => List.app (fn f => (bind (#name f); fundef (IntMap.empty, f))) fs
        | Do (gs, e) => (List.app (fn (g, _) => bind g) gs; exp (IntMap.empty, IntMap.empty, e, Ty.unit))
    in
      List.app def p
    end
end
