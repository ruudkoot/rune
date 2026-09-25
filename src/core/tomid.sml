(* From Lambda to Mid (docs/ir.md). The translation names every value that
   is not an atom, in the order Lambda evaluates it; makes a Try a join
   point without parameters and its Fail a jump to it, and a join point of
   Lambda (a match's rule) one of Mid; gives what follows an
   expression that branches a join point with the value as its parameter,
   so that it is not copied into every branch; and splits the top level at
   each `Rest` into a list of definitions.

   Types: every binder abstracts over the generic variables of its type that
   no binder around it abstracts over, where the elaborator could have
   generalised them there -- a variable it bound, or a function; a variable
   the translation made is never polymorphic. A use of a variable gives its
   instance (Lambda's Inst) as the types of the variables it abstracts over;
   a use without one, at the variables themselves. *)
structure ToMid =
struct
  structure L = Lambda
  structure M = Mid

  fun bug msg = Error.bug ("ToMid: " ^ msg)
  fun fresh () = Elaborate.freshStamp ()

  (* The generic variables of a type, each once, in the order they appear. *)
  fun gens (t : Ty.ty) : int list =
    let
      fun go (t, acc) =
        case t of
          Ty.Gen x => if List.exists (fn y => y = x) acc then acc else x :: acc
        | Ty.Con (_, _, ts) => List.foldl go acc ts
        | Ty.Tuple ts => List.foldl go acc ts
        | Ty.Arrow (a, b) => go (b, go (a, acc))
        | _ => acc
    in List.rev (go (t, [])) end

  fun codomain (Ty.Arrow (_, r)) = r
    | codomain t = bug ("a function of type " ^ Ty.toString t)
  fun domain (Ty.Arrow (d, _)) = d
    | domain t = bug ("a function of type " ^ Ty.toString t)

  (* The schemes of the globals, from the elaborator's tables: at the top
     level every generic variable of a type is the global's own. *)
  val globalSchemes : M.scheme IntMap.map ref = ref IntMap.empty
  fun globalScheme (g : int) : M.scheme =
    case IntMap.find (!globalSchemes, g) of
      SOME s => s
    | NONE =>
        let
          val s =
            case IntMap.find (!Ty.binders, g) of
              SOME t => let val t = Ty.fromTypes t in (gens t, t) end
            | NONE =>
                if IntMap.member (!Ty.exnArgs, g) then ([], Ty.ExnCon)
                else bug ("global g" ^ Int.toString g ^ " has no type")
        in globalSchemes := IntMap.insert (!globalSchemes, g, s); s end

  (* What the translation of an expression is in:
     * scope: the generic variables the binders around it abstract over;
     * fail: the join point a Fail jumps to, that of the innermost Try whose
       body it is in tail position of;
     * env: the scheme of each local variable. *)
  type state = {scope : unit IntMap.map, fail : M.label option, env : M.scheme IntMap.map}

  fun bindLocal ({scope, fail, env} : state, x, s) : state = {scope = scope, fail = fail, env = IntMap.insert (env, x, s)}
  fun withFail ({scope, env, ...} : state, fail) : state = {scope = scope, fail = fail, env = env}
  fun inFunction ({scope, env, ...} : state, tyvars) : state =
    {scope = List.foldl (fn (a, m) => IntMap.insert (m, a, ())) scope tyvars, fail = NONE, env = env}

  (* The variables a binder of type t abstracts over. *)
  fun own ({scope, ...} : state, t : Ty.ty) : int list =
    List.filter (fn a => not (IntMap.member (scope, a))) (gens t)

  (* A value: an atom, or one step that makes it. *)
  datatype value = A of M.atom * Ty.ty | R of M.rhs * Ty.ty

  (* Where a value goes:
     * Ret: it is the value of the enclosing expression;
     * To: a jump to a join point with it, whose parameter's type the first
       jump says;
     * Bind: a variable is bound to it, and the rest is made from its type;
     * Then: the rest is made from it. The rest of a Bind or a Then is made
       at most once. *)
  datatype ctx =
      Ret
    | To of M.label * Ty.ty option ref
    | Bind of int * (Ty.ty -> M.exp)
    | Then of value -> M.exp

  fun typeOf (A (_, t)) = t
    | typeOf (R (_, t)) = t

  (* The value as an atom: a step is named first. *)
  fun atomize (v : value, k : M.atom * Ty.ty -> M.exp) : M.exp =
    case v of
      A (a, t) => k (a, t)
    | R (r, t) => let val x = fresh () in M.Let (x, ([], t), r, k (M.Var (x, []), t)) end

  fun mark (sp, e as M.Mark _) = e
    | mark (sp, e) = M.Mark ((sp, []), e)

  fun program (e : L.lexp) : M.program =
    let
      (* the scheme a local variable is bound with, of the value's type *)
      fun scheme (st, x, t) =
        if IntMap.member (!Ty.binders, x) then (own (st, t), t) else ([], t)

      fun deliver (ctx : ctx, st : state, v : value) : M.exp =
        case ctx of
          Ret => M.Return (case v of A (a, _) => M.Atom a | R (r, _) => r)
        | To (j, r) =>
            atomize (v, fn (a, t) => (case !r of NONE => r := SOME t | SOME _ => (); M.Jump (j, [a])))
        | Bind (x, k) =>
            let val t = typeOf v
            in M.Let (x, scheme (st, x, t), case v of A (a, _) => M.Atom a | R (r, _) => r, k t) end
        | Then k => k v

      (* An expression that branches: each branch goes to the same place,
         which is a join point where it is the rest of a Bind or a Then; no
         join point where no branch returns. *)
      fun branch (ctx : ctx, f : ctx -> M.exp) : M.exp =
        case ctx of
          Bind (x, k) =>
            let val j = fresh () val r = ref NONE val body = f (To (j, r))
            in case !r of NONE => body | SOME t => M.Join (j, [(x, t)], k t, body) end
        | Then k =>
            let val j = fresh () val x = fresh () val r = ref NONE val body = f (To (j, r))
            in case !r of NONE => body | SOME t => M.Join (j, [(x, t)], k (A (M.Var (x, []), t)), body) end
        | _ => f ctx

      fun varAtom (st : state, x : int, inst : Ty.ty option) : value =
        case IntMap.find (#env st, x) of
          SOME s => use (M.Var, x, s, inst)
        | NONE => bug ("v" ^ Int.toString x ^ " is not in scope")
      and use (make, x, (tyvars, t) : M.scheme, inst) : value =
        case (tyvars, inst) of
          ([], _) => A (make (x, []), t)
        | (_, NONE) => A (make (x, List.map Ty.Gen tyvars), t)
        | (_, SOME i) =>
            (case Ty.match (t, i) of
               SOME s => A (make (x, List.map (fn a => case IntMap.find (s, a) of SOME u => u | NONE => Ty.Gen a) tyvars), i)
             | NONE => bug ("v" ^ Int.toString x ^ " of type " ^ Ty.toString t ^ " used at " ^ Ty.toString i))

      fun exp (e : L.lexp, st : state, ctx : ctx) : M.exp =
        case e of
          L.Var x => deliver (ctx, st, varAtom (st, x, NONE))
        | L.Global g => deliver (ctx, st, use (M.Global, g, globalScheme g, NONE))
        | L.Inst (L.Var x, t) => deliver (ctx, st, varAtom (st, x, SOME t))
        | L.Inst (L.Global g, t) => deliver (ctx, st, use (M.Global, g, globalScheme g, SOME t))
        | L.Inst _ => bug "an instance of what is no variable"
        | L.Const (c, t) => deliver (ctx, st, A (M.Const (c, t), t))
        | L.Unit => deliver (ctx, st, A (M.Unit, Ty.unit))
        | L.Con0 (tag, t) => deliver (ctx, st, A (M.Con0 (tag, t), t))
        | L.Fn (x, t, b) =>
            let val f = fresh ()
            in M.Fun ([fundef (st, f, [], x, t, b)], deliver (ctx, bindLocal (st, f, ([], t)), A (M.Var (f, []), t))) end
        | L.App (f, a) =>
            atom (f, st, fn (fa, ft) => atom (a, st, fn (aa, _) => deliver (ctx, st, R (M.App (fa, [aa]), codomain ft))))
        | L.Let (x, a, b) =>
            (case fnOf a of
               SOME (sp, p, t, body) =>
                 let
                   val s = scheme (st, x, t)
                   val st' = bindLocal (st, x, s)
                 in M.Fun ([markDef (sp, fundef (st, x, #1 s, p, t, body))], exp (b, st', ctx)) end
             | NONE => exp (a, st, Bind (x, fn t => exp (b, bindLocal (st, x, scheme (st, x, t)), ctx))))
        | L.LetRec (bs, b) =>
            let
              val defs = List.map (fn (x, t, r) => (x, t, own (st, t), r)) bs
              val st' = List.foldl (fn ((x, t, tvs, _), st) => bindLocal (st, x, (tvs, t))) st defs
              fun one (x, t, tvs, r) =
                case fnOf r of
                  SOME (sp, p, _, body) => markDef (sp, fundef (st', x, tvs, p, t, body))
                | NONE => bug "a letrec of what is no function"
            in M.Fun (List.map one defs, exp (b, st', ctx)) end
        | L.Seq (a, b) =>
            exp (a, st, Then (fn v =>
                                case v of
                                  A _ => exp (b, st, ctx)
                                | R (r, t) => M.Let (fresh (), ([], t), r, exp (b, st, ctx))))
        | L.SetGlobal (g, a) => atom (a, st, fn (aa, _) => deliver (ctx, st, R (M.SetGlobal (g, aa), Ty.unit)))
        | L.Tuple es => atoms (es, st, fn (xs, ts) => deliver (ctx, st, R (M.Tuple xs, Ty.Tuple ts)))
        | L.Select (i, a) =>
            atom (a, st, fn (aa, t) =>
                            case t of
                              Ty.Tuple ts => deliver (ctx, st, R (M.Select (i, aa), List.nth (ts, i)))
                            | _ => bug ("a field of what has type " ^ Ty.toString t))
        | L.Con (tag, t, a) => atom (a, st, fn (aa, _) => deliver (ctx, st, R (M.Con (tag, t, aa), t)))
        | L.Decon (tag, a) =>
            atom (a, st, fn (aa, t) =>
                            case t of
                              Ty.Con (stamp, _, args) =>
                                (case Ty.conArg (stamp, args, tag) of
                                   SOME (SOME arg) => deliver (ctx, st, R (M.Decon (tag, t, aa), arg))
                                 | _ => bug ("constructor " ^ Int.toString tag ^ " of " ^ Ty.toString t))
                            | _ => bug ("a deconstruction of what has type " ^ Ty.toString t))
        | L.ConTag a => atom (a, st, fn (aa, _) => deliver (ctx, st, R (M.ConTag aa, Ty.int)))
        | L.If (c, t, f) =>
            atom (c, st, fn (ca, _) => branch (ctx, fn ctx => M.If (ca, exp (t, st, ctx), exp (f, st, ctx))))
        | L.Try (a, b) =>
            branch (ctx, fn ctx =>
                           let val j = fresh ()
                           in M.Join (j, [], exp (b, st, ctx), exp (a, withFail (st, SOME j), ctx)) end)
        | L.Fail =>
            (case #fail st of
               SOME j => M.Jump (j, [])
             | NONE => bug "a Fail outside a Try")
        | L.Join (j, ps, b, sc) =>
            branch (ctx, fn ctx =>
                           M.Join (j, ps, exp (b, List.foldl (fn ((x, t), st) => bindLocal (st, x, ([], t))) st ps, ctx),
                                   exp (sc, st, ctx)))
        | L.Jump (j, args) => atoms (args, st, fn (xs, _) => M.Jump (j, xs))
        | L.Raise a => atom (a, st, fn (aa, _) => M.Raise aa)
        | L.Handle (a, x, h) =>
            branch (ctx, fn ctx =>
                           M.Handle (exp (a, withFail (st, NONE), ctx), x, exp (h, bindLocal (st, x, ([], Ty.exn)), ctx)))
        | L.NewExn n => deliver (ctx, st, R (M.NewExn n, Ty.ExnCon))
        | L.BuiltinExn k => deliver (ctx, st, R (M.BuiltinExn k, Ty.ExnCon))
        | L.MkExn (c, p) =>
            atom (c, st, fn (ca, _) => atom (p, st, fn (pa, _) => deliver (ctx, st, R (M.MkExn (ca, pa), Ty.exn))))
        | L.ExnCon a => atom (a, st, fn (aa, _) => deliver (ctx, st, R (M.ExnCon aa, Ty.ExnCon)))
        | L.ExnArg (t, a) => atom (a, st, fn (aa, _) => deliver (ctx, st, R (M.ExnArg (t, aa), t)))
        | L.Prim (p, SOME t, args) => atoms (args, st, fn (xs, _) => deliver (ctx, st, R (M.Prim (p, t, xs), codomain t)))
        | L.Prim (p, NONE, args) =>
            atoms (args, st, fn (xs, ts) =>
                               let
                                 val t =
                                   case (p, ts) of
                                     ("ref_get", [r as Ty.Con (_, _, [a])]) => Ty.Arrow (r, a)
                                   | ("poly_eq", [a, _]) => Ty.Arrow (Ty.Tuple [a, a], Ty.bool)
                                   | ("ptr_eq", [a, _]) => Ty.Arrow (Ty.Tuple [a, a], Ty.bool)
                                   | _ => bug ("primitive " ^ p ^ " without a type")
                               in deliver (ctx, st, R (M.Prim (p, t, xs), codomain t)) end)
        | L.Mark (sp, a) => mark (sp, exp (a, st, ctx))
        | L.Rest _ => bug "the rest of the program inside an expression"

      and atom (e, st, k) = exp (e, st, Then (fn v => atomize (v, k)))

      and atoms (es, st, k) =
        case es of
          [] => k ([], [])
        | e :: rest => atom (e, st, fn (a, t) => atoms (rest, st, fn (xs, ts) => k (a :: xs, t :: ts)))

      (* A function of Lambda, under its marks. *)
      and fnOf e =
        let
          fun go (e, sp) =
            case e of
              L.Mark (sp, a) => go (a, SOME sp)
            | L.Fn (p, t, body) => SOME (sp, p, t, body)
            | _ => NONE
        in go (e, NONE) end

      and markDef (NONE, f : M.fundef) = f
        | markDef (SOME sp, {name, tyvars, params, result, body}) =
            {name = name, tyvars = tyvars, params = params, result = result, body = mark (sp, body)}

      (* The function named f, abstracting over tyvars, of parameter x and
         type t; st has f in it where f is recursive. *)
      and fundef (st, f, tyvars, x, t, body) : M.fundef =
        let val st' = bindLocal (inFunction (st, tyvars), x, ([], domain t))
        in {name = f, tyvars = tyvars, params = [(x, domain t)], result = codomain t, body = exp (body, st', Ret)} end

      val top : state = {scope = IntMap.empty, fail = NONE, env = IntMap.empty}

      (* ---- the top level ---- *)

      (* A declaration, with the rest of the program in it replaced by (), and
         that rest: the Rest is in tail position of the declaration, which
         every other way out of never returns from. *)
      fun split (e : L.lexp) : L.lexp * L.lexp option =
        case e of
          L.Rest r => (L.Unit, SOME r)
        | L.Seq (a, b) => let val (b', r) = split b in (L.Seq (a, b'), r) end
        | L.Let (x, a, b) => let val (b', r) = split b in (L.Let (x, a, b'), r) end
        | L.LetRec (bs, b) => let val (b', r) = split b in (L.LetRec (bs, b'), r) end
        | L.Mark (sp, a) => let val (a', r) = split a in (L.Mark (sp, a'), r) end
        | L.Try (a, b) =>
            (case split a of
               (a', SOME r) => (L.Try (a', b), SOME r)
             | (_, NONE) => let val (b', r) = split b in (L.Try (a, b'), r) end)
        | L.If (c, t, f) =>
            (case split t of
               (t', SOME r) => (L.If (c, t', f), SOME r)
             | (_, NONE) => let val (f', r) = split f in (L.If (c, t, f'), r) end)
        | L.Join (j, ps, b, sc) =>
            (case split sc of
               (sc', SOME r) => (L.Join (j, ps, b, sc'), SOME r)
             | (_, NONE) => let val (b', r) = split b in (L.Join (j, ps, b', sc), r) end)
        | _ => (e, NONE)

      (* The globals a declaration sets. *)
      fun sets (e : L.lexp, acc : int list) : int list =
        case e of
          L.SetGlobal (g, a) => sets (a, g :: acc)
        | L.Seq (a, b) => sets (b, sets (a, acc))
        | L.Let (_, a, b) => sets (b, sets (a, acc))
        | L.LetRec (bs, b) => sets (b, List.foldl (fn ((_, _, r), acc) => sets (r, acc)) acc bs)
        | L.Mark (_, a) => sets (a, acc)
        | L.Try (a, b) => sets (b, sets (a, acc))
        | L.If (c, t, f) => sets (f, sets (t, sets (c, acc)))
        | L.Handle (a, _, h) => sets (h, sets (a, acc))
        | L.Join (_, _, b, sc) => sets (sc, sets (b, acc))
        | _ => acc

      (* The definitions of a declaration: a run of globals set in sequence
         is a function or a value each, consecutive functions one group;
         anything else is done for its effect. *)
      fun defs (d : L.lexp) : M.def list =
        let
          fun run (e, acc) =
            case e of
              L.Seq (L.SetGlobal (g, v), rest) => run (rest, (g, v) :: acc)
            | L.Unit => SOME (List.rev acc)
            | _ => NONE
          fun global (g, v) =
            let val s as (tyvars, t) = globalScheme g
            in
              case fnOf v of
                SOME (sp, p, _, body) => (true, M.Funs [markDef (sp, fundef (inFunction (top, tyvars), g, tyvars, p, t, body))])
              | NONE => (false, M.Val (g, s, exp (v, inFunction (top, tyvars), Ret)))
            end
          fun group ([], acc) = List.rev acc
            | group ((true, M.Funs [f]) :: rest, M.Funs fs :: acc) = group (rest, M.Funs (fs @ [f]) :: acc)
            | group ((_, d) :: rest, acc) = group (rest, d :: acc)
        in
          case run (d, []) of
            SOME gs => group (List.map global gs, [])
          | NONE =>
              [M.Do (List.map (fn g => (g, globalScheme g)) (List.rev (sets (d, []))), exp (d, top, Ret))]
        end

      fun spine (e : L.lexp, acc : M.def list) : M.def list =
        case e of
          L.Unit => List.rev acc
        | L.Rest r => spine (r, acc)
        | _ =>
            (case split e of
               (d, SOME r) => spine (r, List.revAppend (defs d, acc))
             | (d, NONE) => List.rev (List.revAppend (defs d, acc)))
    in
      globalSchemes := IntMap.empty;
      spine (e, [])
    end
end
