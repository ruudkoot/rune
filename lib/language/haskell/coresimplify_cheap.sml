(* Cheap eagerness (the haskell98 roadmap's D51, C; Faxén 2000; GHC's
   exprOkForSpeculation): a let whose expression is cheap and total -- it
   cannot raise, loop, or do more than bounded work -- is made a case, so
   that its value is made at once and no suspension is built for it, nor
   forced where it is used.

   Cheap and total, on values Core's types say are evaluated (a binder of
   `!T`, a case's binder, a field a constructor declares `!T`, a variable
   bound to a value):
   - a value: a constructor applied, a lambda, a literal, an evaluated
     variable, a function bound to a lambda of the top level or of a let
     given fewer arguments than its lambda's (a partial application: a
     closure made, Mid's functions being curried);
   - a primitive of `cheapPrims`: the comparisons of Int, Char, Double and
     Float, Char's `ord`, a Str's size, and the arithmetic, conversions and
     tests of Double and Float, which IEEE's rules make total; its operands
     are evaluated by Core's types, which ask `!T` of every primitive's;
   - a case of an evaluated variable, or of a cheap and total expression,
     whose alternatives are each cheap and total;
   - a cast of one.
   Not Int's arithmetic, whose checked primitives raise on overflow (D22),
   nor `div`; not Integer's, nor a comparison of Integers or Strs, whose
   work grows with their operands (D20's D, an add of two immediates
   behind a test of the immediate bit, is not built);
   not a call, which may do anything, a dictionary function's above all,
   which may be recursive (GHC's Note in CoreToStg.Prep); not a variable
   that may be a suspension, whose force may loop.

   The case binds a name of its own, and the let's variable is that name at
   the let's type, so that every type it is held to stays as it was.

   A let of a newtype's type stays a let: a case does not take a newtype's
   value but cast to what it wraps.

   A let whose expression is lets around a cheap and total expression has
   those lets floated out of it first: their suspensions are made at once,
   bounded work, and its own expression is then made a case (moving bounded
   work out of a thunk to expose a head normal form). A let of a
   polymorphic or unlifted type, a letrec, and a value of the top level
   stay as they are.

   The pass core-cheap runs at -O2, after eta and before the last
   simplification, as the owner took D51's C (2026-11-14); rhc
   --no-cheap-eagerness leaves the program as it is. *)
structure CoreSimplifyCheap =
struct
  open Core
  structure B = CoreSimplifyBase

  (* the primitives that cannot raise and do bounded work *)
  val cheapPrims =
    List.concat (List.map (fn p => List.map (fn c => p ^ "_" ^ c) ["eq", "ne", "lt", "le", "gt", "ge"])
                          ["int", "char", "double", "float"])
    @ ["char_ord", "str_size"]
    @ List.concat (List.map (fn p => List.map (fn c => p ^ "_" ^ c)
                                              ["add", "sub", "mul", "div", "neg", "is_nan", "is_infinite",
                                               "is_negative_zero", "is_denormalized"])
                            ["double", "float"])
    @ ["double_from_int", "float_from_int", "float_from_double", "float_to_double"]
  val cheapSet = List.foldl (fn (p, m) => CoreMap.insert (m, p, true)) CoreMap.empty cheapPrims
  fun cheapPrim p = CoreMap.member (cheapSet, p)

  (* what is evaluated: the variables known to hold a value, not a
     suspension *)
  type env = {evaluated : bool CoreMap.map, dt : B.datatypes, arity : int CoreMap.map}

  fun evaluate (env : env, x : string) : env =
    if x = "_" then env else {evaluated = CoreMap.insert (#evaluated env, x, true), dt = #dt env, arity = #arity env}
  fun isEvaluated (env : env, x : string) = CoreMap.member (#evaluated env, x)
  (* a function bound to a lambda: how many values the lambda binds *)
  fun withArity (env : env, x : string, e : exp) : env =
    case e of
      Lam (bs, _) => let val n = B.valueArity bs
                     in if n > 0 then {evaluated = #evaluated env, dt = #dt env, arity = CoreMap.insert (#arity env, x, n)} else env end
    | _ => env
  fun arityOf (env : env, f : string) = getOpt (CoreMap.find (#arity env, f), 0)
  fun valueArgs args = List.length (List.filter (fn ValArg _ => true | TyArg _ => false) args)

  fun atomOk (env : env) (a : atom) =
    case a of
      Lit _ => true
    | Var x => isEvaluated (env, x)

  (* whether a field of constructor c is declared `!T`, by its place *)
  fun strictFields (env : env, c : string) : bool list =
    case CoreMap.find (#cons (#dt env), c) of
      SOME t =>
        (case CoreMap.find (#datas (#dt env), t) of
           SOME (_, cs) => (case List.find (fn (k, _) => k = c) cs of SOME (_, fs) => List.map isEval fs | NONE => [])
         | NONE => [])
    | NONE => []

  (* the environment of an alternative of a case whose binder is b *)
  fun altEnv (env : env, b : string, alt : alt) : env =
    let val env' = evaluate (env, b)
    in
      case alt of
        AltCon (c, xs, _) =>
          let
            val strict = strictFields (env, c)
            fun go (x :: xs, s :: ss, env) = go (xs, ss, if s then evaluate (env, x) else env)
              | go (_, _, env) = env
          in go (xs, strict, env') end
      | _ => env'
    end

  (* whether e is cheap and total, and its value evaluated *)
  fun ok (env : env) (e : exp) : bool =
    case e of
      Atom a => atomOk env a
    | Con _ => true
    | Lam (bs, _) => List.exists (fn ValBinder _ => true | _ => false) bs
    | Prim (p, _, _) => cheapPrim p
    | App (Atom (Var f), args) => let val n = valueArgs args in n > 0 andalso n < arityOf (env, f) end
    | Case (s, b, alts) =>
        (case s of Atom (Var y) => isEvaluated (env, y) | _ => ok env s)
        andalso List.all (fn alt => ok (altEnv (env, b, alt)) (B.altRhs alt)) alts
    | Cast (e, _) => ok env e
    | _ => false

  (* the environment after the binding of x to r, lazily *)
  fun bindLazy (env0 : env, x : string, t : ty, r : exp) : env =
    let val env = withArity (env0, x, r)
    in
    if isEval t then evaluate (env, x)
    else
      case r of
        Atom a => if atomOk env a then evaluate (env, x) else env
      | _ => if B.isValue r then evaluate (env, x) else env
    end

  fun bindings (env : env, bs : B.binding list) : env =
    List.foldl (fn (B.NonRec (x, t, r), env) => bindLazy (env, x, t, r) | (B.Rec _, env) => env) env bs

  (* whether a let of type t may be made a case: not polymorphic, not
     unlifted, and not of a newtype, which a case takes only cast *)
  fun speculable (env : env) (t : ty) : bool =
    case stripEval t of
      TForall _ => false
    | t' =>
        not (B.isUnliftedTy t)
        andalso (case spine t' of (TCon c, _) => not (CoreMap.member (#newtypes (#dt env), c)) | _ => true)

  fun exp (env : env) (e : exp) : exp =
    case e of
      Atom _ => e
    | App (f, args) => App (exp env f, args)
    | Lam (bs, b) =>
        let val env' = List.foldl (fn (ValBinder (x, t), env) => if isEval t then evaluate (env, x) else env
                                    | (TyBinder _, env) => env) env bs
        in Lam (bs, exp env' b) end
    | Let (x, t, r, b) =>
        let
          val r' = exp env r
          val (ls, c) = B.peelLets r'
          val envc = bindings (env, ls)
        in
          if speculable env t andalso not (B.isValue c) andalso ok envc c
             andalso (null ls orelse B.tick "cheap-float") andalso B.tick "cheap"
          then
            (* the case binds a fresh name, of the evaluated type, and x is
               it at x's own type, a let of an atom: where x's type is
               held exactly (a component of an unboxed tuple, IO's in a
               cast), it is the type it was *)
            let val x' = B.fresh x
            in B.wrapLets (ls, Case (c, x', [AltDefault (Let (x, t, Atom (Var x'), exp (evaluate (evaluate (envc, x'), x)) b))])) end
          else Let (x, t, r', exp (bindLazy (env, x, t, r')) b)
        end
    | LetRec (bs, b) =>
        let val env' = List.foldl (fn ((x, _, r), env) => withArity (env, x, r)) env bs
        in LetRec (List.map (fn (x, t, r) => (x, t, exp env' r)) bs, exp env' b) end
    | Case (s, b, alts) =>
        Case (exp env s, b, List.map (fn alt => let val env' = altEnv (env, b, alt)
                                                in case alt of
                                                     AltCon (c, xs, r) => AltCon (c, xs, exp env' r)
                                                   | AltLit (l, r) => AltLit (l, exp env' r)
                                                   | AltUTuple (xs, r) => AltUTuple (xs, exp env' r)
                                                   | AltDefault r => AltDefault (exp env' r)
                                                end) alts)
    | Con _ => e
    | Prim _ => e
    | UTuple _ => e
    | Cast (e, t) => Cast (exp env e, t)

  (* the pass: each value of the top level's expression; what is evaluated
     at the top level, its values *)
  fun program (p : program) : program =
    let
      val p = B.distinct p
      val dt = B.datatypes p
      val top = List.foldl (fn (Val (x, t, e), env) => let val env = withArity (env, x, e)
                                                       in if isEval t orelse B.isValue e then evaluate (env, x) else env end
                             | (_, env) => env) {evaluated = CoreMap.empty, dt = dt, arity = CoreMap.empty} p
    in List.map (fn Val (x, t, e) => Val (x, t, exp top e) | d => d) p end
end
