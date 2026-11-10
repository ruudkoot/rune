(* The Core simplifier's rewrites (coresimplify_sig.sml; the haskell98
   roadmap's M23, D48): one round over a program, which inlines, reduces
   and floats, each rewrite asked for first (CoreSimplifyBase.tick).

   It works on Core whose binders are distinct (CoreSimplifyBase.distinct),
   in one walk of each declaration with an environment: what each variable
   of the input is in the output (an atom, or an expression put where it is
   used once), the type variables' types, and, by the output's names, what
   is known of a variable: bound to a constructor applied, a lambda or a
   cast value, evaluated to a constructor or a literal by a case around it,
   or evaluated. A copy of an expression, a body inlined, is walked with
   every binder given a fresh name.

   The rewrites, each kept to what is shared and what is forced:
   - a let of an atom is the atom; one whose variable is not used goes; one
     used once, not as an argument and not in a lambda it is outside of, is
     put where it is used, and so is a value used once in a lambda;
   - a let around a value in a let's expression is floated out of it, and a
     let out of a case's scrutinee, an application's function or a cast;
   - a lambda applied is its body with its binders the arguments (beta),
     and a function that is small and not recursive, or a lambda bound once,
     is inlined where it is applied to all its value binders take;
   - a case of a constructor, a literal, a variable bound to a constructor
     or one that a case around it has taken apart, chooses its alternative;
     a case of an evaluated variable with a default alone is that default;
     a case of a case whose alternatives are mostly known, or small, is
     pushed into it; an application of a case is pushed into its branches;
   - a primitive of literals, and fromInteger and fromRational of literals
     at the Prelude's instances, are folded (CoreSimplifyFold);
   - a cast of a cast that undoes it is its expression; lambdas of lambdas
     are merged, type binders kept first;
   - a letrec is split into its strongly connected groups, the dead ones
     dropped;
   - a value of the top level made of lets around a value is floated out
     into values of the top level, so that a dictionary is a constructor;
     a value of the top level that is an atom is that atom where it is used;
     and with the whole program, a value main does not reach goes. *)
structure CoreSimplifySimp =
struct
  open Core
  structure B = CoreSimplifyBase
  structure F = CoreSimplifyFold

  (* ---- What is known ---- *)

  datatype known =
      KCon of string * ty list * atom list      (* bound to a constructor applied: a value *)
    | KIs of string * atom list * string         (* evaluated to the constructor, its fields, by a case whose binder holds it *)
    | KEval of string                            (* evaluated, the variable that holds its value *)
    | KLit of lit                                (* evaluated to the literal by a case *)
    | KUTuple of atom list                       (* the unboxed tuple's components *)
    | KLam of binder list * exp                  (* bound to the lambda, in the output *)
    | KCast of exp                               (* bound to a value cast, in the output *)

  type env = {sub : atom CoreMap.map,            (* a variable of the input: the atom it is *)
              tys : (string * ty) list,           (* a type variable of the input: its type *)
              inl : (exp * bool ref) CoreMap.map, (* a variable of the input: the expression put where it is used *)
              known : known CoreMap.map,          (* a variable of the output: what it is *)
              types : ty CoreMap.map,             (* a variable of the output: its type, where it is known *)
              rename : bool,                      (* whether every binder is given a fresh name *)
              stack : string list}                (* the functions of the top level being inlined *)

  (* ---- The round's tables ---- *)

  (* a value of the top level: its type, its expression in the round's
     input, its size (to the limit), and whether inlining it may not end,
     a loop breaker *)
  type global = {ty : ty, body : exp, size : int, breaker : bool}

  (* the size of a body inlined wherever it is applied *)
  val inlineSize = 30
  (* the size of a case's alternatives copied into a case it scrutinises *)
  val caseSize = 12
  val caseKnownSize = 200
  (* how deep inlining goes inside what was inlined, and how many bodies
     are inlined into one declaration in a round *)
  val maxDepth = 8
  val maxInlines = 400
  val inlines = ref 0

  (* whether a body may be inlined, the declaration's budget spent *)
  fun inlining () = !inlines > 0 andalso (inlines := !inlines - 1; true)

  val globals = ref (CoreMap.empty : global CoreMap.map)
  val aliases = ref (CoreMap.empty : atom CoreMap.map)
  val occs = ref (CoreMap.empty : B.occ CoreMap.map)
  val dt = ref (B.datatypes [])
  val whole = ref true

  fun occ x = B.occOf (!occs, x)

  (* the globals each expression mentions *)
  fun mentions (isGlobal : string -> bool) (e : exp) : string list =
    let
      val acc = ref (CoreMap.empty : bool CoreMap.map)
      val order = ref []
      fun note x = if isGlobal x andalso not (CoreMap.member (!acc, x)) then (acc := CoreMap.insert (!acc, x, true); order := x :: !order) else ()
      fun atom (Var x) = note x
        | atom (Lit _) = ()
      fun go e =
        case e of
          Atom a => atom a
        | App (f, args) => (go f; List.app (fn ValArg a => atom a | TyArg _ => ()) args)
        | Lam (_, b) => go b
        | Let (_, _, r, b) => (go r; go b)
        | LetRec (bs, b) => (List.app (fn (_, _, r) => go r) bs; go b)
        | Case (s, _, alts) => (go s; List.app (fn a => go (B.altRhs a)) alts)
        | Con (_, _, xs) => List.app atom xs
        | Prim (_, _, xs) => List.app atom xs
        | UTuple xs => List.app atom xs
        | Cast (e, _) => go e
    in go e; List.rev (!order) end

  (* the strongly connected groups of nodes, by Tarjan: each group after
     every group it reaches *)
  fun sccs (nodes : string list, edges : string -> string list) : string list list =
    let
      val index = ref (CoreMap.empty : int CoreMap.map)
      val low = ref (CoreMap.empty : int CoreMap.map)
      val onStack = ref (CoreMap.empty : bool CoreMap.map)
      val stack = ref []
      val next = ref 0
      val out = ref []
      fun get (m, x) = valOf (CoreMap.find (!m, x))
      fun visit v =
        let
          val () = index := CoreMap.insert (!index, v, !next)
          val () = low := CoreMap.insert (!low, v, !next)
          val () = next := !next + 1
          val () = stack := v :: !stack
          val () = onStack := CoreMap.insert (!onStack, v, true)
          fun edge w =
            if not (CoreMap.member (!index, w)) then (visit w; low := CoreMap.insert (!low, v, Int.min (get (low, v), get (low, w))))
            else if getOpt (CoreMap.find (!onStack, w), false) then low := CoreMap.insert (!low, v, Int.min (get (low, v), get (index, w)))
            else ()
          val () = List.app edge (edges v)
        in
          if get (low, v) = get (index, v) then
            let
              fun pop acc =
                case !stack of
                  w :: rest => (stack := rest; onStack := CoreMap.insert (!onStack, w, false);
                                if w = v then w :: acc else pop (w :: acc))
                | [] => acc
            in out := pop [] :: !out end
          else ()
        end
    in
      List.app (fn v => if CoreMap.member (!index, v) then () else visit v) nodes;
      List.rev (!out)
    end

  (* the round's tables of p: its globals, with a loop breaker wherever a
     group of values of the top level reach each other, a dictionary
     (a constructor) standing for none *)
  fun prepare (p : program) : unit =
    let
      val () = dt := B.datatypes p
      val () = occs := B.occurrences p
      val vals = List.mapPartial (fn Val (x, t, e) => SOME (x, t, e) | _ => NONE) p
      val bodies = List.foldl (fn ((x, t, e), m) => CoreMap.insert (m, x, e)) CoreMap.empty vals
      fun isCon x = case CoreMap.find (bodies, x) of SOME (Con _) => true | _ => false
      fun isFun x = case CoreMap.find (bodies, x) of SOME (Lam _) => true | SOME (Cast (Lam _, _)) => true | _ => false
      (* edges between functions, through what a constructor's fields name *)
      val edges0 = List.foldl (fn ((x, _, e), m) => CoreMap.insert (m, x, mentions (fn y => CoreMap.member (bodies, y)) e))
                              CoreMap.empty vals
      fun edges x = if isCon x then [] else getOpt (CoreMap.find (edges0, x), [])
      val groups = sccs (List.map #1 vals, edges)
      val breakers =
        List.foldl (fn (g, m) =>
                      case g of
                        [x] => if List.exists (fn y => y = x) (edges x) then CoreMap.insert (m, x, true) else m
                      | _ => List.foldl (fn (x, m) => if isFun x then CoreMap.insert (m, x, true) else m) m g)
                   CoreMap.empty groups
      val () =
        globals := List.foldl (fn ((x, t, e), m) =>
                                 CoreMap.insert (m, x, {ty = t, body = e, size = B.sizeUpTo inlineSize e,
                                                        breaker = CoreMap.member (breakers, x)}))
                              CoreMap.empty vals
      (* a value that is an atom stands for it where it is used *)
      val () =
        aliases := List.foldl (fn ((x, _, Atom (Var y)), m) => if x <> "main" andalso x <> y then CoreMap.insert (m, x, Var y) else m
                                | ((x, _, Atom (Lit l)), m) =>
                                    if x <> "main" andalso not (#tup (occ x)) then CoreMap.insert (m, x, Lit l) else m
                                | (_, m) => m)
                              CoreMap.empty vals
    in () end

  (* ---- The environment ---- *)

  fun setSub (env : env, x, a) : env =
    {sub = CoreMap.insert (#sub env, x, a), tys = #tys env, inl = #inl env, known = #known env, types = #types env,
     rename = #rename env, stack = #stack env}
  fun setTy (env : env, a, t) : env =
    {sub = #sub env, tys = (a, t) :: #tys env, inl = #inl env, known = #known env, types = #types env,
     rename = #rename env, stack = #stack env}
  fun setInl (env : env, x, e) : env =
    {sub = #sub env, tys = #tys env, inl = CoreMap.insert (#inl env, x, (e, ref false)), known = #known env,
     types = #types env, rename = #rename env, stack = #stack env}
  fun setKnown (env : env, x, k) : env =
    if x = "_" then env
    else {sub = #sub env, tys = #tys env, inl = #inl env, known = CoreMap.insert (#known env, x, k), types = #types env,
          rename = #rename env, stack = #stack env}
  fun setType (env : env, x, t) : env =
    if x = "_" then env
    else {sub = #sub env, tys = #tys env, inl = #inl env, known = #known env, types = CoreMap.insert (#types env, x, t),
          rename = #rename env, stack = #stack env}
  (* the environment of a copy of output, or of a global's body: nothing of
     the input in scope, every binder renamed *)
  fun copyEnv (env : env, stack) : env =
    {sub = CoreMap.empty, tys = [], inl = CoreMap.empty, known = #known env, types = #types env, rename = true, stack = stack}

  val topEnv : env = {sub = CoreMap.empty, tys = [], inl = CoreMap.empty, known = CoreMap.empty, types = CoreMap.empty,
                      rename = false, stack = []}

  fun ty (env : env) (t : ty) : ty = case #tys env of [] => t | s => substTy (s, t)

  fun knownOf (env : env, x : string) : known option =
    case CoreMap.find (#known env, x) of
      SOME k => SOME k
    | NONE =>
        case CoreMap.find (!globals, x) of
          SOME {body = Con (c, tys, xs), ...} => SOME (KCon (c, tys, xs))
        | _ => NONE

  fun typeOfVar (env : env, x : string) : ty option =
    case CoreMap.find (#types env, x) of
      SOME t => SOME t
    | NONE => Option.map #ty (CoreMap.find (!globals, x))

  (* whether the variable x of the input, of type t, may be the atom a
     where it is used: anywhere but as a component of an unboxed tuple,
     where it may be only what is as evaluated as it is; elsewhere an
     evaluated value stands for a lazy one, as Core to Mid makes it *)
  fun canSubst (env : env, x : string, t : ty, a : atom) : bool =
    not (#tup (occ x)) orelse isEval t orelse B.isUnliftedTy t
    orelse (case a of
              Var v => (case typeOfVar (env, v) of SOME tv => not (isEval tv) | NONE => false)
            | Lit _ => false)

  fun atom (env : env) (a : atom) : atom =
    case a of
      Lit _ => a
    | Var x =>
        let
          val a' =
            case CoreMap.find (#sub env, x) of
              SOME a' => a'
            | NONE =>
                if CoreMap.member (#inl env, x) then raise Fail ("CoreSimplify: " ^ x ^ ", to be put where it is used, is an argument")
                else case CoreMap.find (!aliases, x) of SOME a' => a' | NONE => a
        in
          case a' of
            Var y => (case CoreMap.find (#known env, y) of
                        SOME (KLit l) => if #tup (occ x) then a' else Lit l
                      | _ => a')
          | _ => a'
        end

  fun arg (env : env) (a : arg) : arg =
    case a of
      TyArg t => TyArg (ty env t)
    | ValArg x => ValArg (atom env x)

  (* a binder of the input: its name in the output and the environment
     under it *)
  fun bindVar (env : env, x : string) : string * env =
    if x = "_" orelse not (#rename env) then (x, env)
    else let val y = B.fresh x in (y, setSub (env, x, Var y)) end

  fun bindVars (env : env, xs : string list) : string list * env =
    let val (ys, env) = List.foldl (fn (x, (acc, env)) => let val (y, env) = bindVar (env, x) in (y :: acc, env) end) ([], env) xs
    in (List.rev ys, env) end

  fun binders (env : env, bs : binder list) : binder list * env =
    let
      fun go ([], env, acc) = (List.rev acc, env)
        | go (TyBinder (a, k) :: rest, env, acc) =
            if #rename env then let val b = B.fresh a in go (rest, setTy (env, a, TVar b), TyBinder (b, k) :: acc) end
            else go (rest, env, TyBinder (a, k) :: acc)
        | go (ValBinder (x, t) :: rest, env, acc) =
            let
              val t' = ty env t
              val (y, env) = bindVar (env, x)
              val env = setType (env, y, t')
              val env = if isEval t' then setKnown (env, y, KEval y) else env
            in go (rest, env, ValBinder (y, t') :: acc) end
    in go (bs, env, []) end

  (* ---- Helpers ---- *)

  fun mkLam (bs : binder list, body : exp) : exp =
    case body of
      Lam (bs2, b) =>
        if (not (List.exists (fn TyBinder _ => true | _ => false) bs2) orelse not (List.exists (fn ValBinder _ => true | _ => false) bs))
           andalso B.tick "lambda-merge"
        then Lam (bs @ bs2, b)
        else Lam (bs, body)
    | _ => Lam (bs, body)

  fun countArgs args =
    List.foldl (fn (TyArg _, (t, v)) => (t + 1, v) | (ValArg _, (t, v)) => (t, v + 1)) (0, 0) args
  fun countBinders bs =
    List.foldl (fn (TyBinder _, (t, v)) => (t + 1, v) | (ValBinder _, (t, v)) => (t, v + 1)) (0, 0) bs

  (* whether args give a lambda of binders bs all it binds *)
  fun saturates (bs, args) =
    let val (bt, bv) = countBinders bs
        val (at, av) = countArgs args
    in at >= bt andalso av >= bv end

  (* the number of value binders of what x is bound to, a function *)
  fun arityOf (env : env, x : string) : int =
    case CoreMap.find (#known env, x) of
      SOME (KLam (bs, _)) => B.valueArity bs
    | _ =>
        case CoreMap.find (!globals, x) of
          SOME {body = Lam (bs, _), ...} => B.valueArity bs
        | _ => 0

  (* whether e is a function applied to fewer values than it binds: a
     value, whose making does no work *)
  fun isPartial (env : env, e : exp) : bool =
    case e of
      App (Atom (Var f), args) => #2 (countArgs args) < arityOf (env, f)
    | Atom (Var f) => arityOf (env, f) > 0
    | _ => false

  (* whether a lambda's copy where it is applied costs no work: one that
     binds a value, or a type lambda of a value *)
  fun inlinableLam (env : env, bs, body) =
    List.exists (fn ValBinder _ => true | _ => false) bs orelse B.isValue body orelse isPartial (env, body)

  fun knownOfExp (env : env, e : exp) : known option =
    case e of
      Con (c, tys, xs) => SOME (KCon (c, tys, xs))
    | Lam (bs, b) => if inlinableLam (env, bs, b) then SOME (KLam (bs, b)) else NONE
    | Cast (c, _) => if B.isValue c then SOME (KCast e) else NONE
    | _ => NONE

  (* the environment with what the lets floated out of an expression bind *)
  fun knownOfLets (env : env, ls : B.binding list) : env =
    List.foldl (fn (B.NonRec (x, t, r), env) =>
                     let val env = setType (env, x, t)
                     in case knownOfExp (env, r) of SOME k => setKnown (env, x, k) | NONE => env end
                 | (B.Rec bs, env) => List.foldl (fn ((x, t, _), env) => setType (env, x, t)) env bs)
               env ls

  fun used (b : string) = b <> "_" andalso #n (occ b) > 0

  fun mapRhs f alt =
    case alt of
      AltCon (c, xs, r) => AltCon (c, xs, f r)
    | AltLit (l, r) => AltLit (l, f r)
    | AltUTuple (xs, r) => AltUTuple (xs, f r)
    | AltDefault r => AltDefault (f r)

  (* the alternative of a case on constructor c, or its default *)
  fun pickCon (c : string, alts : alt list) : alt option =
    case List.find (fn AltCon (k, _, _) => k = c | _ => false) alts of
      SOME a => SOME a
    | NONE => List.find (fn AltDefault _ => true | _ => false) alts

  fun pickLit (l : lit, alts : alt list) : alt option =
    case List.find (fn AltLit (m, _) => m = l | _ => false) alts of
      SOME a => SOME a
    | NONE => List.find (fn AltDefault _ => true | _ => false) alts

  (* the numerator and denominator of a ratio of Integer literals x is
     bound to *)
  fun ratioOf (env : env) (x : string) : (IntInf.int * IntInf.int) option =
    case knownOf (env, x) of
      SOME (KCon (c, _, [Lit (LInteger n), Lit (LInteger d)])) => if c = "haskell98:Ratio.:%" then SOME (n, d) else NONE
    | _ => NONE

  (* ---- Expressions ---- *)

  fun exp (env : env) (e : exp) : exp =
    case e of
      Atom (Var x) => var (env, x)
    | Atom (Lit _) => e
    | App (f, args) => app (env, f, List.map (arg env) args)
    | Lam (bs, b) => let val (bs', env') = binders (env, bs) in mkLam (bs', exp env' b) end
    | Let (x, t, r, b) => letE (env, x, t, r, b)
    | LetRec (bs, b) => letRec (env, bs, b)
    | Case (s, b, alts) =>
        let
          val s' = exp env s
          (* the scrutinee's type, where it is known: a polymorphic case
             given a newtype, by an inlining or a specialisation, is a case
             on that newtype, which Core has as a case on what it wraps *)
          val st =
            case (s, s') of
              (_, Cast (_, t)) => SOME t
            | (Atom (Var _), Atom (Var v)) => typeOfVar (env, v)
            | (Atom (Var x), _) => if CoreMap.member (#inl env, x) then typeOfVar (env, x) else NONE
            | _ => NONE
        in
          case Option.mapPartial (fn t => B.unfold (!dt) (stripEval t)) st of
            SOME u =>
              if List.all (fn AltDefault _ => true | _ => false) alts then newtypeCase (env, s', b, alts, stripEval (valOf st), u)
              else caseE (env, s', b, alts)
          | NONE => caseE (env, s', b, alts)
        end
    | Con (c, tys, xs) => Con (c, List.map (ty env) tys, List.map (atom env) xs)
    | Prim (p, tys, xs) =>
        let val xs' = List.map (atom env) xs
            val e' = Prim (p, List.map (ty env) tys, xs')
        in case F.prim (p, xs') of SOME v => if B.tick "fold" then v else e' | NONE => e' end
    | UTuple xs => UTuple (List.map (atom env) xs)
    | Cast (e, t) => cast (env, exp env e, ty env t)

  (* a variable where an expression may stand *)
  and var (env : env, x : string) : exp =
    case CoreMap.find (#inl env, x) of
      SOME (rhs, placed) => if !placed then copy (env, rhs) else (placed := true; rhs)
    | NONE => Atom (atom env (Var x))

  (* a copy of the output e, its binders renamed *)
  and copy (env : env, e : exp) : exp = exp (copyEnv (env, #stack env)) e

  (* f, of the input, applied to args, of the output *)
  and app (env : env, f : exp, args : arg list) : exp =
    case f of
      Lam (bs, body) =>
        if B.tick "beta" then beta (env, bs, body, args) else App (exp env f, args)
    | Atom (Var x) =>
        if CoreMap.member (#inl env, x) then rebuild (env, var (env, x), args)
        else (case atom env (Var x) of
                Var y => headVar (env, y, args)
              | Lit _ => raise Fail "CoreSimplify: a literal applied")
    | _ => rebuild (env, exp env f, args)

  (* the body of a lambda of binders bs, of env's input, given args *)
  and beta (env : env, bs : binder list, body : exp, args : arg list) : exp =
    let
      (* each binder its argument, or a let of it where the argument may not
         stand for it (canSubst) *)
      fun go (TyBinder (a, _) :: bs, TyArg t :: args, env, lets) = go (bs, args, setTy (env, a, t), lets)
        | go (ValBinder (x, t) :: bs, ValArg v :: args, env, lets) =
            if x = "_" then go (bs, args, env, lets)
            else
              let val t' = ty env t
              in
                if canSubst (env, x, t', v) then go (bs, args, setSub (env, x, v), lets)
                else
                  let val (x', env') = bindVar (env, x)
                  in go (bs, args, setType (env', x', t'), (x', t', v) :: lets) end
              end
        | go ([], args, env, lets) = (env, [], args, lets)
        | go (bs, [], env, lets) = (env, bs, [], lets)
        | go (_, _, _, _) = raise Fail "CoreSimplify: a lambda given what it does not bind"
      val (env', rest, extra, lets) = go (bs, args, env, [])
      val e = case rest of
                [] => exp env' body
              | _ => let val (bs', env'') = binders (env', rest) in mkLam (bs', exp env'' body) end
      val e = List.foldl (fn ((x, t, v), e) => Let (x, t, Atom v, e)) e lets
    in
      case extra of [] => e | _ => rebuild (env, e, extra)
    end

  (* the variable y of the output applied to args: a literal folded, a
     function inlined, or the application *)
  and headVar (env : env, y : string, args : arg list) : exp =
    let
      val plain = App (Atom (Var y), args)
      val folded =
        case args of
          [TyArg _, ValArg (Var d), ValArg a] =>
            if String.isSuffix "fromInteger" y orelse String.isSuffix "fromRational" y then F.literal (y, d, a, ratioOf env)
            else NONE
        | _ => NONE
    in
      case folded of
        SOME v => if B.tick "fold-literal" then v else plain
      | NONE =>
          case CoreMap.find (#known env, y) of
            SOME (KLam (bs, body)) =>
              if length (#stack env) < maxDepth andalso saturates (bs, args)
                 andalso (B.sizeUpTo inlineSize body <= inlineSize orelse #n (occ y) = 1)
                 andalso inlining () andalso B.tick "inline-local"
              then beta (copyEnv (env, "" :: #stack env), bs, body, args)
              else plain
          | SOME (KCast c) =>
              if B.sizeUpTo inlineSize c <= inlineSize andalso inlining () andalso B.tick "inline-cast" then rebuild (env, copy (env, c), args)
              else plain
          | _ =>
              case CoreMap.find (!globals, y) of
                SOME {body = Lam (bs, body), size, breaker = false, ...} =>
                  if size <= inlineSize andalso length (#stack env) < maxDepth andalso saturates (bs, args)
                     andalso inlinableLam (env, bs, body)
                     andalso not (List.exists (fn s => s = y) (#stack env)) andalso inlining () andalso B.tick "inline"
                  then beta (copyEnv (env, y :: #stack env), bs, body, args)
                  else plain
              | _ => plain
    end

  (* f, of the output, applied to args *)
  and rebuild (env : env, f : exp, args : arg list) : exp =
    case args of
      [] => f
    | _ =>
        case f of
          App (g, xs) => if B.tick "app-flatten" then rebuild (env, g, xs @ args) else App (f, args)
        | Atom (Var y) => headVar (env, y, args)
        | Lam (bs, body) =>
            if B.tick "beta" then beta ({sub = CoreMap.empty, tys = [], inl = CoreMap.empty, known = #known env,
                                         types = #types env, rename = false, stack = #stack env}, bs, body, args)
            else App (f, args)
        | Let (x, t, r, b) => if B.tick "app-let" then Let (x, t, r, rebuild (env, b, args)) else App (f, args)
        | LetRec (bs, b) => if B.tick "app-let" then LetRec (bs, rebuild (env, b, args)) else App (f, args)
        | Case (s, b, alts) =>
            if B.tick "app-case" then Case (s, b, List.map (mapRhs (fn r => rebuild (env, r, args))) alts) else App (f, args)
        | _ => App (f, args)

  (* e, of the output, cast to t *)
  and cast (env : env, e : exp, t : ty) : exp =
    let
      (* whether (cast (cast e0 t0) t) is e0 *)
      fun cancels (e0, t0) =
        case e0 of
          Atom (Var x) => (case typeOfVar (env, x) of SOME tx => equalTy (stripEval tx, t) | NONE => false)
        | Cast (_, t00) => equalTy (t00, t)
        | Lam _ => (case B.unfold (!dt) t0 of SOME u => equalTy (u, t) | NONE => false)
        | Con _ => (case B.unfold (!dt) t0 of SOME u => equalTy (u, t) | NONE => false)
        | _ => false
    in
      case e of
        Cast (e0, t0) => if cancels (e0, t0) andalso B.tick "cast-cast" then e0 else Cast (e, t)
      | Atom (Var v) =>
          (case knownOf (env, v) of
             SOME (KCast (c as Cast (e0, t0))) =>
               if cancels (e0, t0) andalso B.sizeUpTo inlineSize e0 <= inlineSize andalso B.tick "cast-cast"
               then copy (env, e0)
               else Cast (e, t)
           | _ => Cast (e, t))
      | Let (x, tx, r, b) => if B.tick "cast-let" then Let (x, tx, r, cast (env, b, t)) else Cast (e, t)
      | LetRec (bs, b) => if B.tick "cast-let" then LetRec (bs, cast (env, b, t)) else Cast (e, t)
      | _ => Cast (e, t)
    end

  (* let x : t = r in body, of the input *)
  and letE (env : env, x, t, r, body) : exp =
    let val oc = occ x
    in
      if #n oc = 0 andalso B.tick "dead" then exp env body
      else
        let
          val t' = ty env t
          val r' = exp env r
        in
          case B.peelLets r' of
            (ls as _ :: _, c) =>
              if B.isValue c andalso B.tick "let-let" then B.wrapLets (ls, letCore (knownOfLets (env, ls), x, t', c, body, oc))
              else letCore (env, x, t', r', body, oc)
          | _ => letCore (env, x, t', r', body, oc)
        end
    end

  and letCore (env : env, x, t', r', body, oc : B.occ) : exp =
    let
      fun keep () =
        let
          val (x', env1) = bindVar (env, x)
          val env2 = setType (env1, x', t')
          val env3 = case knownOfExp (env2, r') of SOME k => setKnown (env2, x', k) | NONE => env2
        in Let (x', t', r', exp env3 body) end
    in
      case r' of
        Atom a => if canSubst (env, x, t', a) andalso B.tick "let-atom" then exp (setSub (env, x, a)) body else keep ()
      | _ =>
          if #n oc = 1 andalso not (#arg oc) andalso (not (#lam oc) orelse B.isValue r') andalso B.tick "inline-once"
          then exp (setType (setInl (env, x, r'), x, t')) body
          else keep ()
    end

  and letRec (env : env, bs, body) : exp =
    let
      val (names, env1) = bindVars (env, List.map #1 bs)
      val tys = List.map (fn (_, t, _) => ty env t) bs
      val env1 = ListPair.foldl (fn (y, t, env) => setType (env, y, t)) env1 (names, tys)
      val rs = List.map (fn (_, _, r) => exp env1 r) bs
      val body' = exp env1 body
      val group = ListPair.zip (names, ListPair.zip (tys, rs))
      val isMember = fn y => List.exists (fn n => n = y) names
      val edges0 = List.foldl (fn ((y, (_, r)), m) => CoreMap.insert (m, y, mentions isMember r)) CoreMap.empty group
      fun edges y = getOpt (CoreMap.find (edges0, y), [])
      (* what the body reaches *)
      val reached = ref (CoreMap.empty : bool CoreMap.map)
      fun reach y = if CoreMap.member (!reached, y) then () else (reached := CoreMap.insert (!reached, y, true); List.app reach (edges y))
      val () = List.app reach (mentions isMember body')
      val live = List.filter (fn (y, _) => CoreMap.member (!reached, y)) group
      val groups = sccs (List.map #1 live, edges)
      fun bindingOf y = case List.find (fn (z, _) => z = y) live of SOME (_, (t, r)) => (y, t, r) | NONE => raise Fail "CoreSimplify: letrec"
      fun one (g, e) =
        case g of
          [y] => if List.exists (fn z => z = y) (edges y) then LetRec ([bindingOf y], e)
                 else let val (_, t, r) = bindingOf y in Let (y, t, r, e) end
        | _ => LetRec (List.map bindingOf g, e)
      val split = length groups > 1 orelse length live < length group
                  orelse (case groups of [[y]] => not (List.exists (fn z => z = y) (edges y)) | _ => false)
    in
      if null live andalso B.tick "dead" then body'
      else if split andalso B.tick "letrec-split" then List.foldr one body' groups
      else LetRec (List.map (fn (y, (t, r)) => (y, t, r)) group, body')
    end

  (* ---- Cases ---- *)

  (* a case of s, of the newtype t that unfolds to u, whose alternatives
     are a default: a case of s cast to u, its binder, where it is used, t's
     value. The rewrite is what keeps the Core valid after a substitution,
     and asks for no fuel *)
  and newtypeCase (env : env, s : exp, b : string, alts : alt list, t : ty, u : ty) : exp =
    let
      val () = B.count "case-newtype"
      val s'' = cast (env, s, u)
    in
      if not (used b) then caseE (env, s'', b, alts)
      else
        case s of
          Atom (Var v) => caseE (setSub (env, b, Var v), s'', "_", alts)
        | _ =>
            let val b2 = B.fresh b
            in caseE (env, s'', b2, List.map (fn AltDefault r => AltDefault (Let (b, t, Cast (Atom (Var b2), t), r)) | a => a) alts) end
    end

  (* case s of alts, binding b, s of the output and the rest of the input *)
  and caseE (env : env, s : exp, b : string, alts : alt list) : exp =
    case B.peelLets s of
      (ls as _ :: _, c) =>
        if B.tick "case-let" then B.wrapLets (ls, caseCore (knownOfLets (env, ls), c, b, alts)) else caseCore (env, s, b, alts)
    | _ => caseCore (env, s, b, alts)

  and caseCore (env : env, s : exp, b : string, alts : alt list) : exp =
    let
      (* the alternative chosen, its fields the atoms xs; the binder, where
         it is used, bound by a case of s's value alone, or held by holder *)
      fun chosen (alt, xs, holder : string option, fact : string -> known, fields : ty list option) =
        let
          (* each field's binder its atom, or a let of it where the atom may
             not stand for it (canSubst); a field of a constructor whose
             types are unknown is its atom as the scrutinee's binders were *)
          fun bindField ((y, x, fty), (env, lets)) =
            if y = "_" then (env, lets)
            else
              case fty of
                NONE => (setSub (env, y, x), lets)
              | SOME t =>
                  if canSubst (env, y, t, x) then (setSub (env, y, x), lets)
                  else let val (y', env') = bindVar (env, y) in (setType (env', y', t), (y', t, x) :: lets) end
          fun fieldsOf ys =
            case fields of
              SOME ts => if length ts = length ys then List.map SOME ts else List.map (fn _ => NONE) ys
            | NONE => List.map (fn _ => NONE) ys
          fun rhsOf alt =
            case alt of
              AltCon (_, ys, r) =>
                let val (env', lets) = List.foldl bindField (env, [])
                                                  (ListPair.map (fn (y, (x, f)) => (y, x, f)) (ys, ListPair.zip (xs, fieldsOf ys)))
                in (env', r, lets) end
            | AltDefault r => (env, r, [])
            | AltLit (_, r) => (env, r, [])
            | AltUTuple (ys, r) => (ListPair.foldl (fn (y, x, env) => if y = "_" then env else setSub (env, y, x)) env (ys, xs), r, [])
          val (env', r, lets) = rhsOf alt
          fun wrap e = List.foldl (fn ((y, t, x), e) => Let (y, t, Atom x, e)) e lets
        in
          if not (used b) then wrap (exp env' r)
          else
            case holder of
              SOME h => if h <> "_" then wrap (exp (setSub (env', b, Var h)) r)
                        else
                          let val (b', env'') = bindVar (env', b)
                          in Case (s, b', [AltDefault (wrap (exp (setKnown (env'', b', fact b')) r))]) end
            | NONE =>
                let val (b', env'') = bindVar (env', b)
                in Case (s, b', [AltDefault (wrap (exp (setKnown (env'', b', fact b')) r))]) end
        end
      fun gen () = general (env, s, b, alts)
    in
      case s of
        Con (c, tys, xs) =>
          (case pickCon (c, alts) of
             SOME alt => if B.tick "case-known" then chosen (alt, xs, NONE, fn _ => KCon (c, tys, xs), B.fieldTys (!dt) (c, tys))
                         else gen ()
           | NONE => gen ())
      | Atom (Lit l) =>
          (case pickLit (l, alts) of
             SOME alt => if B.tick "case-known" then exp (setSub (env, b, Lit l)) (B.altRhs alt) else gen ()
           | NONE => gen ())
      | Atom (Var x) =>
          (case knownOf (env, x) of
             SOME (KCon (c, tys, xs)) =>
               (case pickCon (c, alts) of
                  SOME alt => if B.tick "case-known" then chosen (alt, xs, NONE, fn _ => KCon (c, tys, xs), B.fieldTys (!dt) (c, tys))
                              else gen ()
                | NONE => gen ())
           | SOME (KIs (c, xs, h)) =>
               (case pickCon (c, alts) of
                  SOME alt => if B.tick "case-known" then chosen (alt, xs, SOME h, fn _ => KIs (c, xs, h), NONE) else gen ()
                | NONE => gen ())
           | SOME (KEval h) =>
               (case alts of
                  [AltDefault r] =>
                    if (h <> "_" orelse not (used b)) andalso B.tick "case-evaluated"
                    then exp (if used b then setSub (env, b, Var h) else env) r
                    else gen ()
                | _ => gen ())
           | SOME (KUTuple xs) =>
               (case alts of
                  [alt as AltUTuple _] => if B.tick "case-known" then chosen (alt, xs, NONE, fn _ => KUTuple xs, NONE) else gen ()
                | _ => gen ())
           | _ => gen ())
      | UTuple xs =>
          (case alts of
             [alt as AltUTuple _] => if B.tick "case-known" then chosen (alt, xs, NONE, fn _ => KUTuple xs, NONE) else gen ()
           | _ => gen ())
      | Case (s2, b2, alts2) =>
          if caseOfCase (env, alts2, alts) andalso B.tick "case-case" then
            let
              val first = ref true
              fun inner (env2, r2) =
                let val env' = if !first then (first := false; env2)
                               else {sub = #sub env2, tys = #tys env2, inl = #inl env2, known = #known env2,
                                     types = #types env2, rename = true, stack = #stack env2}
                in caseE (env', r2, b, alts) end
              val sv = case s2 of Atom (Var v) => SOME v | _ => NONE
              fun know (env, fact) =
                let val env = setKnown (env, b2, fact)
                in case sv of SOME v => setKnown (env, v, fact) | NONE => env end
              (* what an alternative of the output tells: its fields, where
                 each has a name *)
              fun whole xs = not (List.exists (fn x => x = "_") xs)
              fun alt2 a =
                case a of
                  AltCon (c, xs, r) =>
                    AltCon (c, xs, inner (if whole xs then know (env, KIs (c, List.map Var xs, b2)) else know (env, KEval b2), r))
                | AltLit (l, r) => AltLit (l, inner (know (env, KLit l), r))
                | AltUTuple (xs, r) =>
                    AltUTuple (xs, inner (if whole xs then setKnown (env, b2, KUTuple (List.map Var xs)) else env, r))
                | AltDefault r => AltDefault (inner (know (env, KEval b2), r))
            in Case (s2, b2, List.map alt2 alts2) end
          else gen ()
      | _ => gen ()
    end

  (* whether a case of alternatives alts, of the input, may be copied into
     those of a case it scrutinises, alts2 of the output: where they are
     small, or where all but one of those alternatives give what the case
     then knows *)
  and caseOfCase (env : env, alts2 : alt list, alts : alt list) : bool =
    let
      val size = List.foldl (fn (a, n) => n + B.sizeUpTo caseKnownSize (B.altRhs a) + 1) 0 alts
      fun isKnown r =
        case r of
          Con _ => true
        | Atom (Lit _) => true
        | Atom (Var x) => (case knownOf (env, x) of SOME (KCon _) => true | SOME (KIs _) => true | _ => false)
        | _ => false
      val unknown = List.length (List.filter (fn a => not (isKnown (B.altRhs a))) alts2)
    in
      length alts2 <= 8 andalso (size <= caseSize orelse unknown <= 1 andalso size <= caseKnownSize)
    end

  (* a case kept: its alternatives with what each tells of the scrutinee *)
  and general (env : env, s : exp, b : string, alts : alt list) : exp =
    let
      val (b', env1) = bindVar (env, b)
      val sv = case s of Atom (Var v) => SOME v | _ => NONE
      fun know (env, fact) =
        let val env = setKnown (env, b', fact)
        in case sv of SOME v => setKnown (env, v, fact) | NONE => env end
      (* a field that binds nothing is given a name, so that what the case
         tells of the scrutinee holds each field *)
      fun named xs = List.map (fn "_" => B.fresh "%u" | y => y) xs
      fun alt a =
        case a of
          AltCon (c, xs, r) =>
            let val (xs', env2) = bindVars (env1, xs)
                val xs' = named xs'
            in AltCon (c, xs', exp (know (env2, KIs (c, List.map Var xs', b'))) r) end
        | AltLit (l, r) => AltLit (l, exp (know (env1, KLit l)) r)
        | AltUTuple (xs, r) =>
            let val (xs', env2) = bindVars (env1, xs)
                val xs' = named xs'
            in AltUTuple (xs', exp (setKnown (env2, b', KUTuple (List.map Var xs'))) r) end
        | AltDefault r => AltDefault (exp (know (env1, KEval b')) r)
      val alts' = List.map alt alts
      (* a case on the same variable in the default joins this one: its
         alternatives this one has are not reached there (case merging; the
         repeated tests a match in the Report's order leaves, D34) *)
      fun heads alts = List.mapPartial (fn AltCon (c, _, _) => SOME (SOME c, NONE) | AltLit (l, _) => SOME (NONE, SOME l) | _ => NONE) alts
      fun covered (hs, AltCon (c, _, _)) = List.exists (fn (SOME k, _) => k = c | _ => false) hs
        | covered (hs, AltLit (l, _)) = List.exists (fn (_, SOME m) => m = l | _ => false) hs
        | covered _ = false
      val merged =
        case (sv, List.rev alts') of
          (SOME x, AltDefault (Case (Atom (Var y), b2, alts2)) :: restRev) =>
            if (y = x orelse y = b') andalso (b2 = "_" orelse null (mentions (fn z => z = b2) (Case (Atom (Var y), "_", alts2))))
               andalso B.tick "case-merge"
            then
              let val hs = heads restRev
              in List.rev restRev @ List.filter (fn a => not (covered (hs, a))) alts2 end
            else alts'
        | _ => alts'
      (* a default no constructor reaches goes *)
      val final =
        case List.partition (fn AltDefault _ => true | _ => false) merged of
          ([_], cons as AltCon (c, _, _) :: _) =>
            (case CoreMap.find (#cons (!dt), c) of
               SOME t =>
                 (case CoreMap.find (#datas (!dt), t) of
                    SOME (_, cs) =>
                      if List.all (fn (k, _) => List.exists (fn AltCon (k', _, _) => k' = k | _ => false) cons) cs
                         andalso B.tick "dead-default"
                      then cons
                      else merged
                  | NONE => merged)
             | NONE => merged)
        | _ => merged
    in Case (s, b', final) end

  (* ---- A round ---- *)

  (* the values of the top level main reaches, where the program is whole *)
  fun reachable (p : program) : program =
    let
      val vals = List.foldl (fn (Val (x, _, e), m) => CoreMap.insert (m, x, e) | (_, m) => m) CoreMap.empty p
      val reached = ref (CoreMap.empty : bool CoreMap.map)
      fun reach x =
        if CoreMap.member (!reached, x) then ()
        else (reached := CoreMap.insert (!reached, x, true);
              case CoreMap.find (vals, x) of
                SOME e => List.app reach (mentions (fn y => CoreMap.member (vals, y)) e)
              | NONE => ())
      val () = reach "main"
      val dead = List.exists (fn Val (x, _, _) => not (CoreMap.member (!reached, x)) | _ => false) p
    in
      if not (CoreMap.member (vals, "main")) orelse not dead then p
      else if B.tick "dead-global" then List.filter (fn Val (x, _, _) => CoreMap.member (!reached, x) | _ => true) p
      else p
    end

  (* a value of the top level: its expression simplified, and the lets
     around a value floated out into values of their own *)
  fun decl (d : decl) : decl list =
    case d of
      Val (x, t, e) =>
        let
          val env = {sub = CoreMap.empty, tys = [], inl = CoreMap.empty, known = CoreMap.empty, types = CoreMap.empty,
                     rename = false, stack = [x]}
          val () = inlines := maxInlines
          val e' = exp env e
        in
          case (t, B.peelLets e') of
            (TForall _, _) => [Val (x, t, e')]
          | (_, (ls as _ :: _, c)) =>
              if (B.isValue c orelse isPartial (env, c)) andalso B.tick "float-top" then
                List.concat (List.map (fn B.NonRec (y, ty, r) => [Val (y, ty, r)]
                                         | B.Rec bs => List.map (fn (y, ty, r) => Val (y, ty, r)) bs) ls)
                @ [Val (x, t, c)]
              else [Val (x, t, e')]
          | _ => [Val (x, t, e')]
        end
    | _ => [d]

  (* `round p` is p simplified once: every value's expression, then, with
     the whole program, what main does not reach dropped *)
  fun round (p : program) : program =
    let
      val () = prepare p
      val p' = List.concat (List.map decl p)
    in if !whole then reachable p' else p' end

  (* `instantiate (env, lam, args)` is the lambda `lam` of the output, or
     the body of a value of the top level, given args, its binders
     renamed: a copy, simplified, as an inlining makes one *)
  fun instantiate (stack : string list, bs : binder list, body : exp, args : arg list) : exp =
    (inlines := maxInlines;
     beta ({sub = CoreMap.empty, tys = [], inl = CoreMap.empty, known = CoreMap.empty, types = CoreMap.empty,
           rename = true, stack = stack}, bs, body, args))
end
