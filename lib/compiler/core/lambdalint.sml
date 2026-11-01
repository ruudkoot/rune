(* What every Lambda the compiler makes keeps (docs/ir.md), checked after
   the stage that made it when --lint is given (Pass.stage):
   * every variable is used where a binder of it is in scope: a function's
     parameter, a let, a letrec, a handler;
   * every binder's stamp is bound once in the whole program, which the code
     generator relies on (its slots are by stamp);
   * every Fail is in tail position of the body of a Try of the same
     function, where it jumps to the Try's fallback with the stack as the
     Try found it; every Jump in tail position of the scope of its join
     point, in the same function, with an argument of each parameter's type;
   * every right-hand side of a letrec is a function;
   * it is well typed (Ty): every node has the type its parts give it, a use
     of a variable at an instance (Inst) is one of its scheme, which gives
     each type variable fixed where the variable is bound (one of a
     variable a Fn or a Join binds around it, monomorphic) as itself, a
     constructor is one of the datatype it builds, and an argument, a
     binding and a branch have the type they must;
   * a constant is of its type's kind and range, a primitive's type is an
     instance of its description, an exception's payload has its
     argument's type, and a cast the compiler makes is of its origin's
     kind (IrRules; linting roadmap, M4).
   A breach is a bug of the compiler, raised as Error.Bug. *)
structure LambdaLint =
struct
  open Lambda

  (* What checking an expression finds: its type, or that it never
     returns (a Fail, a raise), which fits wherever a type is wanted. *)
  datatype found = T of Ty.ty | Never

  fun check (e : lexp) : unit =
    let
      val bound : unit IntMap.map ref = ref IntMap.empty
      fun bind x =
        if IntMap.member (!bound, x) then Error.bug ("variable v" ^ Int.toString x ^ " is bound twice")
        else bound := IntMap.insert (!bound, x, ())
      fun isFn e = case unmark e of Fn _ => true | _ => false
      fun wrong (what, t, want) =
        Error.bug (what ^ " has type " ^ Ty.toString t ^ " where " ^ Ty.toString want ^ " is wanted")
      fun expect (what, T t, want) = if Ty.equal (t, want) then () else wrong (what, t, want)
        | expect (_, Never, _) = ()
      fun join (what, T a, T b) = (if Ty.equal (a, b) then () else wrong (what, b, a); T a)
        | join (_, Never, b) = b
        | join (_, a, Never) = a
      (* the type of a global: its scheme, or an exception constructor's *)
      fun globalTy g =
        case IntTable.find (Ty.binders, g) of
          SOME t => Ty.fromTypes t
        | NONE =>
            if isSome (IntTable.find (Ty.exnArgs, g)) then Ty.exnCon
            else Error.bug ("global g" ^ Int.toString g ^ " has no type")
      (* the argument of a constructor of the datatype t: SOME NONE for a
         nullary one *)
      fun conArg (what, t, tag) =
        case Ty.view t of
          Ty.Con (stamp, _, args) =>
            (case Ty.conArg (stamp, args, tag) of
               SOME a => a
             | NONE => Error.bug (what ^ ": " ^ Ty.toString t ^ " has no constructor " ^ Int.toString tag))
        | _ => Error.bug (what ^ ": " ^ Ty.toString t ^ " is no datatype")
      (* scope: the type of each variable in scope; tail: whether a Fail here
         is in tail position of a Try's body, and the join points a Jump here
         is in tail position of the scope of, with their parameters' types *)
      val no : bool * Ty.ty list IntMap.map = (false, IntMap.empty)
      (* the generic variables fixed here -- those of the types of the
         variables a Fn or a Join binds around it, which are monomorphic --
         and where each variable was bound, with its own where a Fn binds it
         and, in its own right-hand side, a LetRec's: a use of a variable at
         an instance gives each of those as itself (the linting roadmap's
         E10, M5) *)
      val fixed : unit IntMap.map ref = ref IntMap.empty
      val fixedAt : unit IntMap.map IntTable.table = IntTable.table 256
      fun addGens (m, t) = List.foldl (fn (g, m) => IntMap.insert (m, g, ())) m (Ty.gens t)
      fun fixedIn (m, f) = let val saved = !fixed in fixed := m; f () before fixed := saved end
      fun unfixed (x, s, t, sigma) =
        case IntTable.find (fixedAt, x) of
          NONE => ()
        | SOME fx =>
            case List.find (fn (g, u) => IntMap.member (fx, g) andalso not (Ty.equal (u, Ty.gen g))) (IntMap.listItemsi sigma) of
              NONE => ()
            | SOME (g, u) =>
                Error.bug ("v" ^ Int.toString x ^ " of type " ^ Ty.toString s ^ " used at " ^ Ty.toString t ^ ", which makes 'a"
                           ^ Int.toString g ^ ", fixed where v" ^ Int.toString x ^ " is bound, " ^ Ty.toString u)
      fun go (e, scope : Ty.ty IntMap.map, tail : bool * Ty.ty list IntMap.map) : found =
        case e of
          Var x =>
            (case IntMap.find (scope, x) of
               SOME t => T t
             | NONE => Error.bug ("variable v" ^ Int.toString x ^ " is not in scope"))
        | Global g => T (globalTy g)
        | Inst (a, t) =>
            (case go (a, scope, no) of
               T s =>
                 (case Ty.match (s, t) of
                    SOME sigma => ((case unmark a of Var x => unfixed (x, s, t, sigma) | _ => ()); T t)
                  | NONE => Error.bug ("a use at " ^ Ty.toString t ^ " of what has type " ^ Ty.toString s))
             | Never => T t)
        | Const (c, t) => (Option.app Error.bug (IrRules.const (c, t)); T t)
        | Unit => T Ty.unit
        | Fn (x, t, b) =>
            (case Ty.view t of
               Ty.Arrow (d, r) =>
                 let val fx = addGens (!fixed, d)
                 in
                   bind x; IntTable.insert (fixedAt, x, fx);
                   fixedIn (fx, fn () => expect ("the body of a function", go (b, IntMap.insert (scope, x, d), no), r));
                   T t
                 end
             | _ => Error.bug ("a function of type " ^ Ty.toString t))
        | App (f, a) =>
            (case go (f, scope, no) of
               T t =>
                 (case Ty.view t of
                    Ty.Arrow (d, r) => (expect ("an argument", go (a, scope, no), d); T r)
                  | _ => Error.bug ("an application of what has type " ^ Ty.toString t))
             | Never => (ignore (go (a, scope, no)); Never))
        | Let (x, a, b) =>
            (case go (a, scope, no) of
               T t => (bind x; IntTable.insert (fixedAt, x, !fixed); go (b, IntMap.insert (scope, x, t), tail))
             | Never =>
                 (* nothing after it runs, but it is checked with the type the
                    variable was declared with, where it was *)
                 (bind x;
                  case IntTable.find (Ty.binders, x) of
                    SOME t => (ignore (go (b, IntMap.insert (scope, x, Ty.fromTypes t), tail)); Never)
                  | NONE => Never))
        | LetRec (bs, b) =>
            let
              val () = List.app (fn (x, _, _) => bind x) bs
              val scope' = List.foldl (fn ((x, t, _), m) => IntMap.insert (m, x, t)) scope bs
              (* monomorphic in their own right-hand sides *)
              val () = List.app (fn (x, t, _) => IntTable.insert (fixedAt, x, addGens (!fixed, t))) bs
              val () =
                List.app (fn (x, t, r) =>
                            if isFn r then expect ("the letrec of v" ^ Int.toString x, go (r, scope', no), t)
                            else Error.bug ("the letrec of v" ^ Int.toString x ^ " binds what is no function"))
                         bs
              val () = List.app (fn (x, _, _) => IntTable.insert (fixedAt, x, !fixed)) bs
            in
              go (b, scope', tail)
            end
        | Seq (a, b) => (ignore (go (a, scope, no)); go (b, scope, tail))
        | SetGlobal (g, a) => (expect ("the value of global g" ^ Int.toString g, go (a, scope, no), globalTy g); T Ty.unit)
        | Tuple es =>
            let val found = List.map (fn e => go (e, scope, no)) es
            in
              if List.exists (fn Never => true | _ => false) found then Never
              else T (Ty.tuple (List.map (fn T t => t | Never => Ty.unit) found))
            end
        | Select (i, a) =>
            (case go (a, scope, no) of
               T t =>
                 (case Ty.view t of
                    Ty.Tuple ts =>
                      if i < List.length ts then T (List.nth (ts, i))
                      else Error.bug ("field " ^ Int.toString i ^ " of a tuple of " ^ Int.toString (List.length ts))
                  | _ => Error.bug ("a field of what has type " ^ Ty.toString t))
             | Never => Never)
        | Con0 (tag, t) =>
            (case conArg ("a nullary constructor", t, tag) of
               NONE => T t
             | SOME _ => Error.bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " is not nullary"))
        | Con (tag, t, a) =>
            (case conArg ("a constructor", t, tag) of
               SOME arg => (expect ("the argument of a constructor", go (a, scope, no), arg); T t)
             | NONE => Error.bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " takes no argument"))
        | Decon (tag, a) =>
            (case go (a, scope, no) of
               T t =>
                 (case conArg ("a deconstruction", t, tag) of
                    SOME arg => T arg
                  | NONE => Error.bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t ^ " has no argument"))
             | Never => Never)
        | ConTag a =>
            (case go (a, scope, no) of
               T t =>
                 (case Ty.view t of
                    Ty.Con _ => T Ty.int
                  | _ => Error.bug ("the tag of what has type " ^ Ty.toString t))
             | Never => Never)
        | If (c, t, f) =>
            (expect ("a condition", go (c, scope, no), Ty.bool);
             join ("the branches of an if", go (t, scope, tail), go (f, scope, tail)))
        | Try (a, b) => join ("a try and its fallback", go (a, scope, (true, #2 tail)), go (b, scope, tail))
        | Fail => if #1 tail then Never else Error.bug "a Fail is not in tail position of a Try"
        | Join (j, ps, b, sc) =>
            (bind j;
             List.app (fn (x, _) => bind x) ps;
             let
               val fx = List.foldl (fn ((_, t), m) => addGens (m, t)) (!fixed) ps
               val () = List.app (fn (x, _) => IntTable.insert (fixedAt, x, fx)) ps
               val found = fixedIn (fx, fn () => go (b, List.foldl (fn ((x, t), m) => IntMap.insert (m, x, t)) scope ps, tail))
               val inScope = go (sc, scope, (#1 tail, IntMap.insert (#2 tail, j, List.map #2 ps)))
             in join ("a join point and its scope", found, inScope) end)
        | Jump (j, args) =>
            (case IntMap.find (#2 tail, j) of
               SOME ts =>
                 if List.length ts = List.length args then
                   (ListPair.app (fn (a, t) => expect ("an argument of join point j" ^ Int.toString j, go (a, scope, no), t))
                                 (args, ts);
                    Never)
                 else Error.bug ("join point j" ^ Int.toString j ^ " given " ^ Int.toString (List.length args) ^ " arguments")
             | NONE => Error.bug ("a jump to j" ^ Int.toString j ^ " that is not in tail position of its scope"))
        | Raise a => (expect ("what is raised", go (a, scope, no), Ty.exn); Never)
        | Handle (a, x, h) =>
            let val ta = go (a, scope, no)
            in bind x; join ("a handled expression and its handler", ta, go (h, IntMap.insert (scope, x, Ty.exn), tail)) end
        | NewExn _ => T Ty.exnCon
        | BuiltinExn _ => T Ty.exnCon
        | MkExn (c, p) =>
            (expect ("an exception constructor", go (c, scope, no), Ty.exnCon);
             case (unmark c, go (p, scope, no)) of
               (Var x, T t) => Option.app Error.bug (IrRules.payload (x, t))
             | (Global g, T t) => Option.app Error.bug (IrRules.payload (g, t))
             | _ => ();
             T Ty.exn)
        | ExnCon a => (expect ("an exception", go (a, scope, no), Ty.exn); T Ty.exnCon)
        | ExnArg (t, a) => (expect ("an exception", go (a, scope, no), Ty.exn); T t)
        | Prim (p, SOME t, args) =>
            let
              (* open_layout's descriptor is a CInt given its datatype *)
              val layout = p = "open_layout"
              val found = List.map (fn e => case (layout, unmark e) of
                                              (true, Const (_, t)) => T t
                                            | _ => go (e, scope, no)) args
              val () = Option.app Error.bug (IrRules.use (p, t))
            in
              case Ty.view t of
                Ty.Arrow (d, r) =>
                  (case (found, Ty.view d) of
                     ([x], _) => expect ("the argument of " ^ p, x, d)
                   | (xs, Ty.Tuple ds) =>
                       if List.length xs = List.length ds then ListPair.app (fn (x, d) => expect ("an argument of " ^ p, x, d)) (xs, ds)
                       else Error.bug ("primitive " ^ p ^ " of type " ^ Ty.toString t ^ " given " ^ Int.toString (List.length xs) ^ " arguments")
                   | _ => Error.bug ("primitive " ^ p ^ " of type " ^ Ty.toString t);
                   if List.exists (fn Never => true | _ => false) found then Never else T r)
              | _ => Error.bug ("primitive " ^ p ^ " of type " ^ Ty.toString t)
            end
        | Prim (p, NONE, args) =>
            (case (p, List.map (fn e => go (e, scope, no)) args) of
               ("ref_get", [T r]) =>
                 (case Ty.view r of
                    Ty.Con (s, _, [t]) => if s = #stamp Types.refTycon then T t else Error.bug ("ref_get of what has type " ^ Ty.toString r)
                  | _ => Error.bug ("ref_get of what has type " ^ Ty.toString r))
             | ("poly_eq", [a, b]) => (ignore (join ("the arguments of =", a, b)); T Ty.bool)
             | ("ptr_eq", [a, b]) => (ignore (join ("the arguments of ptr_eq", a, b)); T Ty.bool)
             | (_, found) =>
                 if List.exists (fn Never => true | _ => false) found then Never
                 else Error.bug ("primitive " ^ p ^ " without a type"))
        | Mark (_, a) => go (a, scope, tail)
        | Rest a => go (a, scope, tail)
    in
      ignore (go (e, IntMap.empty, no))
    end
end
