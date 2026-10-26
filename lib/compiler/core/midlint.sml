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
   * constants, primitives, exceptions' payloads and the casts the
     compiler makes, by IrRules (linting roadmap, M4); a Do sets each
     global it lists on every way that returns;
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

  (* the functor bodies a unit's basis decoded (UnitBasis), the last first,
     to be linted at the next unit's passes (Pipeline.functorBodies) *)
  val pendingBodies : fundef list ref = ref []
  val () = CompilerState.cellRoot ("MidLint.pendingBodies", pendingBodies)

  (* The check, with imperative tables (linting roadmap, M2; E2): the
     binders, the globals and the functions of other than one parameter in
     hash tables, and the variables in scope in one table, entered and left
     as the walk goes -- which stamps' being unique, checked as each is
     bound, makes the same as a map per scope. A message is made only for a
     breach. *)
  (* What a program, or a part of one, is checked in: the scheme of a
     global it names and does not define, the parameters' types of a
     function of several parameters it names and does not define, and
     whether it may set such a global. *)
  type surround = {global : int -> scheme option, nary : int -> Ty.ty list option, sets : bool, setter : int -> bool}

  fun checkWith ({global = outer, nary = outerNary, sets, setter} : surround) (p : program) : unit =
    let
      fun bug msg = Error.bug msg
      val mayOuter = sets
      (* the globals a function sets (a Do's rule), and the depth of
         functions the walk is in *)
      val setInFun : unit IntTable.table = IntTable.table 16
      val inFun = ref 0
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
      fun naryParams x = case IntTable.find (nary, x) of SOME ps => SOME ps | NONE => outerNary x
      fun isNary x = isSome (naryParams x)

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
                 case outer g of
                   SOME s => instance (fn () => "g" ^ Int.toString g, s, args)
                 | NONE => bug ("global g" ^ Int.toString g ^ " is not defined"))
        | Const (c, t) => (Option.app bug (IrRules.const (c, t)); t)
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
              val n = case Option.mapPartial naryParams name of SOME ps => List.length ps | NONE => 1
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
            ((case (p, args) of ("functor_cast", [a]) => castBack (t, a) | _ => ());
             (* its description's, and a cast's origin's rule (IrRules.use):
                a record's slot is unit, a functor_cast to it or from it *)
             Option.app bug (IrRules.use (p, t));
             (* open_layout's descriptor is a CInt given its datatype *)
             let
               val layout = p = "open_layout"
               fun arg a = case a of Const (_, t) => if layout then t else atom a | _ => atom a
             in
             case Ty.view t of
               Ty.Arrow (d, res) =>
                 (case (args, Ty.view d) of
                    ([a], _) => expect (fn () => "the argument of " ^ p, arg a, d)
                  | (xs, Ty.Tuple ds) =>
                      if List.length xs = List.length ds then
                        ListPair.app (fn (x, d) => expect (fn () => "an argument of " ^ p, arg x, d)) (xs, ds)
                      else bug ("primitive " ^ p ^ " of type " ^ Ty.toString t ^ " given "
                                ^ Int.toString (List.length xs) ^ " arguments")
                  | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t);
                  res)
             | _ => bug ("primitive " ^ p ^ " of type " ^ Ty.toString t)
             end)
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
        | MkExn (c, p) =>
            (expect (the "an exception constructor", atom c, Ty.exnCon);
             let val t = atom p
             in case c of
                  Var (x, _) => Option.app bug (IrRules.payload (x, t))
                | Global (g, _) => Option.app bug (IrRules.payload (g, t))
                | _ => ()
             end;
             Ty.exn)
        | ExnCon a => (expect (the "an exception", atom a, Ty.exn); Ty.exnCon)
        | ExnArg (t, a) => (expect (the "an exception", atom a, Ty.exn); t)
        | SetGlobal (g, a) =>
            (if !inFun > 0 then IntTable.insert (setInFun, g, ()) else ();
             case (IntTable.find (globals, g), if mayOuter then outer g else NONE) of
               (SOME (_, t), _) => (expect (fn () => "the value of global g" ^ Int.toString g, atom a, t); Ty.unit)
             | (NONE, SOME (_, t)) => (expect (fn () => "the value of global g" ^ Int.toString g, atom a, t); Ty.unit)
             | (NONE, NONE) => bug ("global g" ^ Int.toString g ^ " is not defined"))

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
           inFun := !inFun + 1;
           exp (IntMap.empty, body, result);
           inFun := !inFun - 1;
           List.app (fn (x, _) => leave x) params)

      (* The globals set on every way through e that returns, NONE where
         none returns (a raise): a Do sets each it lists on every way that
         returns (linting roadmap, M4) -- after simplify, one that always
         raises still lists what it no longer sets. A handler's way may
         leave its body anywhere, so it is the handler's alone. A global a
         function sets is the exception: a dynamic module's slots are set
         by the function the runtime is given, at the load and at each
         reload (Translate, RuneDynamic.take), which Lift may move out of
         the Do *)
      fun meet (NONE, b) = b
        | meet (a, NONE) = a
        | meet (SOME a, SOME b) = SOME (IntMap.filteri (fn (g, _) => IntMap.member (b, g)) a)
      fun sets (joins : unit IntMap.map option IntMap.map, e : exp) : unit IntMap.map option =
        let
          fun step (SetGlobal (g, _), k) = Option.map (fn m => IntMap.insert (m, g, ())) k
            | step (_, k) = k
        in
          case e of
            Let (_, _, r, b) => step (r, sets (joins, b))
          | Fun (_, b) => sets (joins, b)
          | Join (j, _, body, sc) => sets (IntMap.insert (joins, j, sets (joins, body)), sc)
          | Jump (j, _) => (case IntMap.find (joins, j) of SOME k => k | NONE => SOME IntMap.empty)
          | If (_, t, f) => meet (sets (joins, t), sets (joins, f))
          | Handle (a, _, h) => meet (sets (joins, a), sets (joins, h))
          | Raise _ => NONE
          | Return r => step (r, SOME IntMap.empty)
          | Mark (_, a) => sets (joins, a)
        end

      fun valueOf e = case e of Mark (_, e) => valueOf e | Return r => SOME r | _ => NONE
      (* each Do's globals and what it sets on every way, checked once
         every function is seen *)
      val dos : ((var * scheme) list * unit IntMap.map) list ref = ref []
      fun def d =
        case d of
          Val (g, (_, t), e) => (bind g; exp (IntMap.empty, e, t); Option.app (fn r => noteCast (g, r)) (valueOf e))
        | Funs fs => List.app (fn f => (bind (#name f); fundef f)) fs
        | Do (gs, e) =>
            (List.app (fn (g, _) => bind g) gs;
             exp (IntMap.empty, e, Ty.unit);
             case sets (IntMap.empty, e) of
               NONE => ()
             | SOME set => dos := (gs, set) :: !dos)
      fun unset (gs, set) =
        case List.find (fn (g, _) => not (IntMap.member (set, g) orelse isSome (IntTable.find (setInFun, g)) orelse setter g)) gs of
          SOME (g, _) => bug ("a Do lists g" ^ Int.toString g ^ ", which a way of it that returns does not set")
        | NONE => ()
    in
      List.app def p;
      List.app unset (List.rev (!dos))
    end

  (* A whole program, or a unit's, whose globals of units before it are
     ToMid's to say (importedScheme) *)
  fun check (p : program) : unit =
    checkWith {global = fn g => if !Pass.whole then NONE else !importedScheme g, nary = fn _ => NONE, sets = false,
               setter = fn _ => false} p

  (* A part of a program checked in what is around it (Simplify's
     definitions, each as it is made: the linting roadmap, E9): the schemes
     of the globals and the functions of several parameters of the program
     it was taken from, and of the parts checked before it, which `extend`
     adds; a part may set a global of those. *)
  type context = {schemes : scheme IntTable.table, nary : Ty.ty list IntTable.table, setters : unit IntTable.table}
  fun extend ({schemes, nary, setters} : context) (p : program) : unit =
    let
      (* the globals a function sets, for a Do's rule *)
      fun exp (inFun, e) =
        case e of
          Let (_, _, r, b) => (rhs (inFun, r); exp (inFun, b))
        | Fun (fs, b) => (List.app (fn f => exp (true, #body f)) fs; exp (inFun, b))
        | Join (_, _, b, sc) => (exp (inFun, b); exp (inFun, sc))
        | If (_, t, f) => (exp (inFun, t); exp (inFun, f))
        | Handle (a, _, h) => (exp (inFun, a); exp (inFun, h))
        | Return r => rhs (inFun, r)
        | Mark (_, a) => exp (inFun, a)
        | _ => ()
      and rhs (true, SetGlobal (g, _)) = IntTable.insert (setters, g, ())
        | rhs _ = ()
      fun fundef (f : fundef) =
        (IntTable.insert (schemes, #name f, (#tyvars f, funTy f));
         case #params f of [_] => () | ps => IntTable.insert (nary, #name f, List.map #2 ps);
         exp (true, #body f))
    in
      List.app (fn Val (g, s, e) => (IntTable.insert (schemes, g, s); exp (false, e))
                 | Funs fs => List.app fundef fs
                 | Do (gs, e) => (List.app (fn (g, s) => IntTable.insert (schemes, g, s)) gs; exp (false, e))) p
    end
  fun context (p : program) : context =
    let val c = {schemes = IntTable.table 1024, nary = IntTable.table 64, setters = IntTable.table 16}
    in extend c p; c end
  fun checkIn ({schemes, nary, setters} : context) (part : program) : unit =
    checkWith {global = fn g => case IntTable.find (schemes, g) of
                                  SOME s => SOME s
                                | NONE => if !Pass.whole then NONE else !importedScheme g,
               nary = fn x => IntTable.find (nary, x), sets = true, setter = fn g => isSome (IntTable.find (setters, g))} part
end
