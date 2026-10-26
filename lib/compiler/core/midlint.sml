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
   * casts (functors-units.md, D3) of a
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

  (* The check, with imperative tables (linting roadmap, M2; E2): the
     binders, the globals and the functions of other than one parameter in
     hash tables, and the variables in scope in one table, entered and left
     as the walk goes -- which stamps' being unique, checked as each is
     bound, makes the same as a map per scope. A message is made only for a
     breach. *)
  fun check (p : program) : unit =
    let
      fun bug msg = Error.bug msg
      val bound : unit IntTable.table = IntTable.table 256
      fun bind x =
        case IntTable.find (bound, x) of
          SOME () => bug ("variable v" ^ Int.toString x ^ " is bound twice")
        | NONE => IntTable.insert (bound, x, ())
      fun expect (what : unit -> string, t, want) =
        if Ty.equal (t, want) then ()
        else bug (what () ^ " has type " ^ Ty.toString t ^ " where " ^ Ty.toString want ^ " is wanted")
      fun the what () = what

      (* the functions, global and local, of other than one parameter: the
         types of their parameters *)
      val nary : Ty.ty list IntTable.table = IntTable.table 256
      fun naryOf (f : fundef) =
        case #params f of
          [_] => ()
        | ps => IntTable.insert (nary, #name f, List.map #2 ps)
      fun isNary x = isSome (IntTable.find (nary, x))

      (* the globals, from their definitions *)
      val globals : scheme IntTable.table = IntTable.table 256
      fun define (g, s) =
        case IntTable.find (globals, g) of
          SOME _ => bug ("global g" ^ Int.toString g ^ " is defined twice")
        | NONE => IntTable.insert (globals, g, s)
      fun schemeOf (f : fundef) : scheme = (#tyvars f, funTy f)
      val () =
        List.app (fn Val (g, s, _) => define (g, s)
                   | Funs fs => List.app (fn f => (define (#name f, schemeOf f); naryOf f)) fs
                   | Do (gs, _) => List.app define gs) p

      fun instance (what : unit -> string, (tyvars, t) : scheme, args) =
        if List.length tyvars <> List.length args then
          bug (what () ^ " abstracts over " ^ Int.toString (List.length tyvars) ^ " variables and is given "
               ^ Int.toString (List.length args) ^ " types")
        else if null tyvars then t
        else Ty.subst (ListPair.foldl (fn (a, u, s) => IntMap.insert (s, a, u)) IntMap.empty (tyvars, args)) t

      (* the variables in scope, each with its scheme: entered where it is
         bound and left where its scope ends *)
      val scope : scheme IntTable.table = IntTable.table 256
      fun enter (x, s) = IntTable.insert (scope, x, s)
      fun leave x = IntTable.removeRange (scope, x, x + 1)

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
      fun atom (a : atom) : Ty.ty =
        case a of
          Var (x, _) => if isNary x then bug ("v" ^ Int.toString x ^ ", a function of other than one parameter, used as a value") else callee a
        | Global (g, _) => if isNary g then bug ("g" ^ Int.toString g ^ ", a function of other than one parameter, used as a value") else callee a
        | _ => callee a

      and callee (a : atom) : Ty.ty =
        case a of
          Var (x, args) =>
            (case IntTable.find (scope, x) of
               SOME s => instance (fn () => "v" ^ Int.toString x, s, args)
             | NONE => bug ("variable v" ^ Int.toString x ^ " is not in scope"))
        | Global (g, args) =>
            (case IntTable.find (globals, g) of
               SOME s => instance (fn () => "g" ^ Int.toString g, s, args)
             | NONE =>
                 case if !Pass.whole then NONE else !importedScheme g of
                   SOME s => instance (fn () => "g" ^ Int.toString g, s, args)
                 | NONE => bug ("global g" ^ Int.toString g ^ " is not defined"))
        | Const (_, t) => t
        | Con0 (tag, t) =>
            (case conArg ("a nullary constructor", t, tag) of
               NONE => t
             | SOME _ => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " is not nullary"))
        | Unit => Ty.unit

      fun rhs (r : rhs) : Ty.ty =
        case r of
          Atom a => atom a
        | App (f, args) =>
            let
              val name = case f of Var (x, _) => SOME x | Global (g, _) => SOME g | _ => NONE
              val n = case Option.mapPartial (fn x => IntTable.find (nary, x)) name of SOME ps => List.length ps | NONE => 1
              val ft = callee f
              fun wrong () = bug ("an application of what has type " ^ Ty.toString ft)
            in
              case (Ty.view ft, args) of
                (Ty.Arrow (d, res), [a]) =>
                  if n = 1 then (expect (the "an argument", atom a, d); res)
                  else bug ("a function of " ^ Int.toString n ^ " parameters given 1 argument")
              | (Ty.Arrow (d, res), _) =>
                  (case Ty.view d of
                     Ty.Tuple ds =>
                       if n = List.length args andalso n = List.length ds then
                         (ListPair.app (fn (a, d) => expect (the "an argument", atom a, d)) (args, ds); res)
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
                    ([a], _) => expect (fn () => "the argument of " ^ p, atom a, d)
                  | (xs, Ty.Tuple ds) =>
                      if List.length xs = List.length ds then
                        ListPair.app (fn (x, d) => expect (fn () => "an argument of " ^ p, atom x, d)) (xs, ds)
                      else bug ("primitive " ^ p ^ " of type " ^ Ty.toString t ^ " given "
                                ^ Int.toString (List.length xs) ^ " arguments")
                  | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t);
                  res)
             | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t))
        | Tuple xs => Ty.tuple (List.map atom xs)
        | Select (i, a) =>
            let val t = atom a
            in
              case Ty.view t of
                Ty.Tuple ts =>
                  if i < List.length ts then List.nth (ts, i)
                  else bug ("field " ^ Int.toString i ^ " of a tuple of " ^ Int.toString (List.length ts))
              | _ => bug ("a field of what has type " ^ Ty.toString t)
            end
        | Con (tag, t, a) =>
            (case conArg ("a constructor", t, tag) of
               SOME arg => (expect (the "the argument of a constructor", atom a, arg); t)
             | NONE => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " takes no argument"))
        | Decon (tag, t, a) =>
            (expect (the "what a deconstruction takes apart", atom a, t);
             case conArg ("a deconstruction", t, tag) of
               SOME arg => arg
             | NONE => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " has no argument"))
        | ConTag a =>
            let val t = atom a
            in case Ty.view t of Ty.Con _ => Ty.int | _ => bug ("the tag of what has type " ^ Ty.toString t) end
        | NewExn _ => Ty.exnCon
        | BuiltinExn _ => Ty.exnCon
        | MkExn (c, p) => (expect (the "an exception constructor", atom c, Ty.exnCon); ignore (atom p); Ty.exn)
        | ExnCon a => (expect (the "an exception", atom a, Ty.exn); Ty.exnCon)
        | ExnArg (t, a) => (expect (the "an exception", atom a, Ty.exn); t)
        | SetGlobal (g, a) =>
            (case IntTable.find (globals, g) of
               SOME (_, t) => (expect (fn () => "the value of global g" ^ Int.toString g, atom a, t); Ty.unit)
             | NONE => bug ("global g" ^ Int.toString g ^ " is not defined"))

      (* e, where the join points in labels are in scope, wanted to have
         type want *)
      fun exp (labels : Ty.ty list IntMap.map, e : exp, want : Ty.ty) : unit =
        case e of
          Let (x, s as (_, t), r, b) =>
            (expect (fn () => "the value of v" ^ Int.toString x, rhs r, t);
             bind x;
             noteCast (x, r);
             enter (x, s); exp (labels, b, want); leave x)
        | Fun (fs, b) =>
            (List.app (fn f => (bind (#name f); naryOf f; enter (#name f, schemeOf f))) fs;
             List.app fundef fs;
             exp (labels, b, want);
             List.app (fn f => leave (#name f)) fs)
        | Join (j, params, body, sc) =>
            (bind j;
             List.app (fn (x, _) => bind x) params;
             List.app (fn (x, t) => enter (x, ([], t))) params;
             exp (labels, body, want);
             List.app (fn (x, _) => leave x) params;
             exp (IntMap.insert (labels, j, List.map #2 params), sc, want))
        | Jump (j, args) =>
            (case IntMap.find (labels, j) of
               SOME ts =>
                 if List.length ts = List.length args then
                   ListPair.app (fn (a, t) => expect (fn () => "an argument of join point j" ^ Int.toString j, atom a, t)) (args, ts)
                 else bug ("join point j" ^ Int.toString j ^ " given " ^ Int.toString (List.length args) ^ " arguments")
             | NONE => bug ("join point j" ^ Int.toString j ^ " is not in scope"))
        | If (c, t, f) => (expect (the "a condition", atom c, Ty.bool); exp (labels, t, want); exp (labels, f, want))
        | Handle (a, x, h) =>
            (exp (labels, a, want); bind x; enter (x, ([], Ty.exn)); exp (labels, h, want); leave x)
        | Raise a => expect (the "what is raised", atom a, Ty.exn)
        | Return r => expect (the "a result", rhs r, want)
        | Mark (_, a) => exp (labels, a, want)

      and fundef (f as {params, result, body, ...} : fundef) =
        if null params then bug ("function v" ^ Int.toString (#name f) ^ " has no parameter")
        else
          (List.app (fn (x, _) => bind x) params;
           List.app (fn (x, t) => enter (x, ([], t))) params;
           exp (IntMap.empty, body, result);
           List.app (fn (x, _) => leave x) params)

      fun valueOf e = case e of Mark (_, e) => valueOf e | Return r => SOME r | _ => NONE
      fun def d =
        case d of
          Val (g, (_, t), e) => (bind g; exp (IntMap.empty, e, t); Option.app (fn r => noteCast (g, r)) (valueOf e))
        | Funs fs => List.app (fn f => (bind (#name f); fundef f)) fs
        | Do (gs, e) => (List.app (fn (g, _) => bind g) gs; exp (IntMap.empty, e, Ty.unit))
    in
      List.app def p
    end
end
