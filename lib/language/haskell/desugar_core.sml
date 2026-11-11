(* Implements: HS_DS_CORE *)
structure HsDsCore :> HS_DS_CORE =
struct
  structure M = HsStringMap

  type texp = Core.exp * Core.ty

  datatype shape = DataS of (string * Core.ty list) list | NewS of string * Core.ty | PrimS

  type tyconInfo = {params : (string * Core.kind) list, shape : shape, kind : Core.kind}
  type conInfo_ = {tycon : string, params : (string * Core.kind) list, fields : Core.ty list}

  val counter = ref 0
  val tycons : tyconInfo M.map ref = ref M.empty
  val cons : conInfo_ M.map ref = ref M.empty
  val values : Core.ty M.map ref = ref M.empty
  (* the fields a constructor forces where it is applied, where they are
     not its fields' `!`: a strict field of a newtype's type, lazy in Core *)
  val forcedMap : bool list M.map ref = ref M.empty

  fun fresh base = (counter := !counter + 1; "%" ^ base ^ Int.toString (!counter))

  type saved = {counter : int, tycons : tyconInfo M.map, cons : conInfo_ M.map, values : Core.ty M.map,
                forced : bool list M.map}

  fun save () = {counter = !counter, tycons = !tycons, cons = !cons, values = !values, forced = !forcedMap}

  fun restore (s : saved) =
    (counter := #counter s; tycons := #tycons s; cons := #cons s; values := #values s; forcedMap := #forced s)

  (* a name made here, `%`, a base and a number, and its base *)
  fun made x =
    String.size x > 1 andalso String.sub (x, 0) = #"%" andalso Char.isDigit (String.sub (x, String.size x - 1))

  fun baseOf x =
    let fun go i = if i > 1 andalso Char.isDigit (String.sub (x, i - 1)) then go (i - 1) else i
    in String.substring (x, 0, go (String.size x)) end

  (* the names a value binds, numbered again; one it does not bind (of the
     top level, whose made names hold a `:`, or of the runtime) is kept *)
  fun canonical e =
    let
      val n = ref 0
      fun bind (m, x) =
        if made x then (n := !n + 1; let val y = baseOf x ^ Int.toString (!n) in (M.insert (m, x, y), y) end)
        else (m, x)
      fun binds (m, xs) =
        let val (m', ys) = List.foldl (fn (x, (m, acc)) => let val (m', y) = bind (m, x) in (m', y :: acc) end) (m, []) xs
        in (m', List.rev ys) end
      fun name m x = getOpt (M.find (m, x), x)
      fun atom m a = case a of Core.Var x => Core.Var (name m x) | Core.Lit _ => a
      fun arg m a = case a of Core.ValArg x => Core.ValArg (atom m x) | Core.TyArg _ => a
      fun binder (b, (m, acc)) =
        case b of
          Core.ValBinder (x, t) => let val (m', y) = bind (m, x) in (m', Core.ValBinder (y, t) :: acc) end
        | Core.TyBinder _ => (m, b :: acc)
      fun exp m e =
        case e of
          Core.Atom a => Core.Atom (atom m a)
        | Core.App (f, args) => Core.App (exp m f, List.map (arg m) args)
        | Core.Lam (bs, b) => let val (m', bs') = List.foldl binder (m, []) bs in Core.Lam (List.rev bs', exp m' b) end
        | Core.Let (x, t, e1, e2) => let val e1' = exp m e1 val (m', y) = bind (m, x) in Core.Let (y, t, e1', exp m' e2) end
        | Core.LetRec (bs, b) =>
            let val (m', ys) = binds (m, List.map #1 bs)
            in Core.LetRec (ListPair.map (fn ((_, t, e), y) => (y, t, exp m' e)) (bs, ys), exp m' b) end
        | Core.Case (s, x, alts) => let val s' = exp m s val (m', y) = bind (m, x) in Core.Case (s', y, List.map (alt m') alts) end
        | Core.Con (c, ts, xs) => Core.Con (c, ts, List.map (atom m) xs)
        | Core.Prim (p, ts, xs) => Core.Prim (p, ts, List.map (atom m) xs)
        | Core.UTuple xs => Core.UTuple (List.map (atom m) xs)
        | Core.Cast (b, t) => Core.Cast (exp m b, t)
      and alt m a =
        case a of
          Core.AltCon (c, xs, b) => let val (m', ys) = binds (m, xs) in Core.AltCon (c, ys, exp m' b) end
        | Core.AltLit (l, b) => Core.AltLit (l, exp m b)
        | Core.AltUTuple (xs, b) => let val (m', ys) = binds (m, xs) in Core.AltUTuple (ys, exp m' b) end
        | Core.AltDefault b => Core.AltDefault (exp m b)
    in
      exp M.empty e
    end

  fun kindOfParams ps = List.foldr (fn ((_, k), r) => Core.Arrow (k, r)) Core.Star ps

  fun declare d =
    case d of
      Core.Data (t, ps, cs) =>
        (tycons := M.insert (!tycons, t, {params = ps, shape = DataS cs, kind = kindOfParams ps});
         List.app (fn (c, fs) => cons := M.insert (!cons, c, {tycon = t, params = ps, fields = fs})) cs)
    | Core.Newtype (t, ps, c, f) =>
        (tycons := M.insert (!tycons, t, {params = ps, shape = NewS (c, f), kind = kindOfParams ps});
         cons := M.insert (!cons, c, {tycon = t, params = ps, fields = [f]}))
    | Core.Val (x, t, _) => values := M.insert (!values, x, t)
    | Core.Import (x, t) => values := M.insert (!values, x, t)

  (* a tuple of n components, its type and its constructor `(,...,)`, of
     arbitrary length (3.8): each declared where it is first wanted *)
  fun tupleArity c =
    let val n = String.size c
    in
      if n >= 3 andalso String.sub (c, 0) = #"(" andalso String.sub (c, n - 1) = #")"
         andalso CharVector.all (fn ch => ch = #",") (String.substring (c, 1, n - 2))
      then SOME (n - 1)
      else NONE
    end

  fun tupleData n =
    let
      val name = "(" ^ CharVector.tabulate (n - 1, fn _ => #",") ^ ")"
      val ps = List.tabulate (n, fn i => ("a" ^ Int.toString (i + 1), Core.Star))
    in
      Core.Data (name, ps, [(name, List.map (Core.TVar o #1) ps)])
    end

  fun findTycon c =
    case M.find (!tycons, c) of
      SOME i => SOME i
    | NONE => (case tupleArity c of SOME n => (declare (tupleData n); M.find (!tycons, c)) | NONE => NONE)

  (* a function that raises the exception a primitive makes of a message,
     at every type: so raise's own result is never a function, which Core
     to Mid takes a primitive's never to be *)
  fun raiser kind = "%raise:" ^ kind

  val raiserTy = Core.TForall ("a", Core.Star, Core.TFun (Core.TEval (Core.TCon "Str"), Core.TVar "a"))

  val raisers =
    List.map (fn kind =>
                Core.Val (raiser kind, raiserTy,
                          Core.Lam ([Core.TyBinder ("a", Core.Star), Core.ValBinder ("s", Core.TEval (Core.TCon "Str"))],
                                    Core.Case (Core.Prim (kind, [], [Core.Var "s"]), "e",
                                               [Core.AltDefault (Core.Prim ("raise", [Core.TVar "a"], [Core.Var "e"]))]))))
      ["exn_pattern", "exn_error"]

  fun reset () =
    (counter := 0;
     tycons := M.empty;
     cons := M.empty;
     values := M.empty;
     forcedMap := M.empty;
     List.app (fn (c, k) =>
                 let
                   (* Core's built-in types: Ref's parameter, the others none *)
                   val ps = case k of Core.Arrow (Core.Star, Core.Star) => [("a", Core.Star)] | _ => []
                 in
                   tycons := M.insert (!tycons, c, {params = ps, shape = PrimS, kind = k})
                 end)
       Core.builtinTypes;
     List.app declare Core.builtinData;
     List.app declare raisers)

  fun tycon c = Option.map (fn {params, shape, ...} => (params, shape)) (findTycon c)

  fun conInfo k = (ignore (findTycon k); M.find (!cons, k))

  fun fieldsAt (k, args) =
    case conInfo k of
      SOME {params, fields, ...} =>
        if length params <> length args then raise Fail ("HsDsCore: " ^ k ^ " at " ^ Int.toString (length args) ^ " types")
        else List.map (fn f => Core.substTy (ListPair.map (fn ((a, _), t) => (a, t)) (params, args), f)) fields
    | NONE => raise Fail ("HsDsCore: the constructor " ^ k ^ " is not declared")

  (* a tuple's constructor as a function is of the type a declared one
     would be, made where it is reached (HsDesugar) *)
  fun valueType x =
    case M.find (!values, x) of
      SOME t => SOME t
    | NONE =>
        case tupleArity x of
          SOME n =>
            let val ps = List.tabulate (n, fn i => "a" ^ Int.toString (i + 1))
            in
              SOME (List.foldr (fn (a, t) => Core.TForall (a, Core.Star, t))
                      (List.foldr Core.TFun (Core.apply (Core.TCon x, List.map Core.TVar ps)) (List.map Core.TVar ps)) ps)
            end
        | NONE => NONE

  fun dataArgs t =
    case Core.spine (Core.stripEval t) of
      (Core.TCon c, args) =>
        (case findTycon c of
           SOME {params, ...} => if length params = length args then SOME (c, args) else NONE
         | NONE => NONE)
    | _ => NONE

  fun unfold t =
    case dataArgs t of
      SOME (c, args) =>
        (case findTycon c of
           SOME {shape = NewS (k, _), ...} => SOME (hd (fieldsAt (k, args)))
         | _ => NONE)
    | NONE => NONE

  (* ---- Kinds ---- *)

  (* a kind with variables, for inference *)
  datatype ikind = IStar | IUnl | IArr of ikind * ikind | IVar of ikind option ref

  fun repr k = case k of IVar (r as ref (SOME k')) => let val k'' = repr k' in r := SOME k''; k'' end | _ => k

  fun fromKind k =
    case k of
      Core.Star => IStar
    | Core.Unlifted => IUnl
    | Core.Arrow (a, b) => IArr (fromKind a, fromKind b)

  fun toKind k =
    case repr k of
      IStar => Core.Star
    | IUnl => Core.Unlifted
    | IArr (a, b) => Core.Arrow (toKind a, toKind b)
    | IVar r => (r := SOME IStar; Core.Star)

  fun occurs (r, k) =
    case repr k of
      IVar r' => r = r'
    | IArr (a, b) => occurs (r, a) orelse occurs (r, b)
    | _ => false

  (* kinds made one where they can be; where they cannot, the program is
     ill kinded, which the checker refused already, so nothing is said *)
  fun unifyK (a, b) =
    case (repr a, repr b) of
      (IVar r, IVar r') => if r = r' then () else r := SOME (IVar r')
    | (IVar r, k) => if occurs (r, k) then () else r := SOME k
    | (k, IVar r) => if occurs (r, k) then () else r := SOME k
    | (IArr (a1, b1), IArr (a2, b2)) => (unifyK (a1, a2); unifyK (b1, b2))
    | _ => ()

  fun newK () = IVar (ref NONE)

  (* the kind of t, its variables' kinds by vars *)
  fun ikindOf (vars : ikind M.map) t =
    case t of
      Core.TVar a => (case M.find (vars, a) of SOME k => k | NONE => IStar)
    | Core.TCon c => (case findTycon c of SOME {kind, ...} => fromKind kind | NONE => IStar)
    | Core.TApp (f, a) =>
        let
          val kf = ikindOf vars f
          val ka = ikindOf vars a
          val r = newK ()
        in
          unifyK (kf, IArr (ka, r)); r
        end
    | Core.TFun (a, b) => (unifyK (ikindOf vars a, IStar) handle _ => (); ignore (ikindOf vars b); IStar)
    | Core.TForall (a, k, b) => ikindOf (M.insert (vars, a, fromKind k)) b
    | Core.TEval u => ikindOf vars u
    | Core.TUTuple ts => (List.app (ignore o ikindOf vars) ts; IUnl)

  fun kindOf (vars, t) = toKind (ikindOf (List.foldl (fn ((a, k), m) => M.insert (m, a, fromKind k)) M.empty vars) t)

  fun inferKinds (names, known, tys) =
    let
      fun freeVars t = Core.freeTyVars t
      val others = List.foldl (fn (t, acc) => acc @ List.filter (fn a => not (List.exists (fn b => b = a) (names @ acc)))
                                                         (freeVars t)) [] tys
      val ks = List.map (fn n => (n, newK ())) names
      val vars =
        List.foldl (fn (a, m) => M.insert (m, a, case known a of SOME k => fromKind k | NONE => IStar))
          (List.foldl (fn ((n, k), m) => M.insert (m, n, k)) M.empty ks) others
      val () = List.app (fn t => let val k = ikindOf vars t in (case repr k of IUnl => () | _ => unifyK (k, IStar)) end) tys
    in
      List.map (fn (n, k) => (n, toKind k)) ks
    end

  (* ---- Types ---- *)

  fun instantiate (t, []) = t
    | instantiate (t, ty :: rest) =
        case Core.stripEval t of
          Core.TForall (a, _, b) => instantiate (Core.substTy ([(a, ty)], b), rest)
        | t' => raise Fail ("HsDsCore: " ^ CoreText.showTy t' ^ " is given a type")

  fun applyType (t, args) =
    List.foldl
      (fn (Core.TyArg ty, t) => instantiate (t, [ty])
        | (Core.ValArg _, t) =>
            (case Core.stripEval t of
               Core.TFun (_, r) => r
             | t' => raise Fail ("HsDsCore: " ^ CoreText.showTy t' ^ " is given a value")))
      t args

  fun params (t, 0) = ([], t)
    | params (t, n) =
        case Core.stripEval t of
          Core.TFun (p, r) => let val (ps, res) = params (r, n - 1) in (p :: ps, res) end
        | t' => raise Fail ("HsDsCore: " ^ CoreText.showTy t' ^ " takes no parameter")

  fun lazyTy t = Core.stripEval t

  (* ---- Expressions ---- *)

  fun atom ((Core.Atom a, t), k) = k (a, t)
    | atom ((e, t), k) =
        let
          val v = fresh "x"
          val t' = lazyTy t
          val (body, tb) = k (Core.Var v, t')
        in
          (Core.Let (v, t', e, body), lazyTy tb)
        end

  fun atoms (xs, k) =
    let
      fun go ([], acc) = k (List.rev acc)
        | go (x :: rest, acc) = atom (x, fn a => go (rest, a :: acc))
    in
      go (xs, [])
    end

  fun var (x, t) = (Core.Atom (Core.Var x), t)

  (* e with the type variables of ts and the variables of xs replaced *)
  fun subst (ts, xs) e =
    let
      fun ty t = if null ts then t else Core.substTy (ts, t)
      fun atom (a as Core.Var x) = (case List.find (fn (y, _) => y = x) xs of SOME (_, b) => b | NONE => a)
        | atom a = a
      fun arg (Core.TyArg t) = Core.TyArg (ty t)
        | arg (Core.ValArg a) = Core.ValArg (atom a)
      fun binder (Core.ValBinder (x, t)) = Core.ValBinder (x, ty t)
        | binder b = b
      fun go e =
        case e of
          Core.Atom a => Core.Atom (atom a)
        | Core.App (f, args) => Core.App (go f, List.map arg args)
        | Core.Lam (bs, b) => Core.Lam (List.map binder bs, go b)
        | Core.Let (x, t, r, b) => Core.Let (x, ty t, go r, go b)
        | Core.LetRec (bs, b) => Core.LetRec (List.map (fn (x, t, r) => (x, ty t, go r)) bs, go b)
        | Core.Case (sc, b, alts) =>
            Core.Case (go sc, b, List.map (fn Core.AltCon (k, xs, r) => Core.AltCon (k, xs, go r)
                                            | Core.AltLit (l, r) => Core.AltLit (l, go r)
                                            | Core.AltUTuple (xs, r) => Core.AltUTuple (xs, go r)
                                            | Core.AltDefault r => Core.AltDefault (go r)) alts)
        | Core.Con (k, tys, atoms) => Core.Con (k, List.map ty tys, List.map atom atoms)
        | Core.Prim (p, tys, atoms) => Core.Prim (p, List.map ty tys, List.map atom atoms)
        | Core.UTuple atoms => Core.UTuple (List.map atom atoms)
        | Core.Cast (b, t) => Core.Cast (go b, ty t)
    in
      go e
    end

  fun app ((f, t), []) = (f, t)
    | app ((f, t), args) =
        let val r = applyType (t, args)
        in
          case f of
            Core.App (g, args0) => (Core.App (g, args0 @ args), r)
          | Core.Lam (bs, body) =>
              (* a lambda applied where it is made: its body with what it is
                 given, every argument an atom, so nothing is copied *)
              let
                fun go (b :: bs, a :: args, ts, xs) =
                      (case (b, a) of
                         (Core.TyBinder (x, _), Core.TyArg u) => go (bs, args, (x, u) :: ts, xs)
                       | (Core.ValBinder (x, _), Core.ValArg v) => go (bs, args, ts, (x, v) :: xs)
                       | _ => NONE)
                  | go (bs, args, ts, xs) = SOME (bs, args, ts, xs)
              in
                case go (bs, args, [], []) of
                  SOME (left, more, ts, xs) =>
                    let
                      val body' = subst (ts, xs) body
                      val e = case left of
                                [] => body'
                              | _ => (case subst (ts, []) (Core.Lam (left, Core.Atom (Core.Var "_"))) of
                                        Core.Lam (left', _) => Core.Lam (left', body')
                                      | _ => raise Fail "HsDsCore: a lambda")
                    in
                      (case more of [] => e | _ => Core.App (e, more), r)
                    end
                | NONE => (Core.App (f, args), r)
              end
          | _ => (Core.App (f, args), r)
        end

  fun appAtoms (f, xs) = atoms (xs, fn avs => app (f, List.map (fn (a, _) => Core.ValArg a) avs))

  fun hasType bs = List.exists (fn Core.TyBinder _ => true | _ => false) bs
  fun hasValue bs = List.exists (fn Core.ValBinder _ => true | _ => false) bs

  fun lam ([], body) = body
    | lam (bs, (body, tb)) =
        case body of
          (* \a -> \b -> e is \a b -> e, unless that puts a type after a value *)
          Core.Lam (bs', inner) =>
            if hasType bs' andalso hasValue bs then (Core.Lam (bs, body), Core.lamTy (bs, lazyTy tb))
            else (Core.Lam (bs @ bs', inner), Core.lamTy (bs, lazyTy tb))
        | _ => (Core.Lam (bs, body), Core.lamTy (bs, lazyTy tb))

  fun let_ (x, t, (rhs, _), (body, tb)) = (Core.Let (x, lazyTy t, rhs, body), lazyTy tb)

  fun letrec ([], body) = body
    | letrec (bs, (body, tb)) = (Core.LetRec (List.map (fn (x, t, (e, _)) => (x, lazyTy t, e)) bs, body), lazyTy tb)

  fun force ((e, t), k) =
    case (e, t) of
      (Core.Atom (Core.Var v), Core.TEval _) => k (v, t)
    | _ =>
        let
          val b = fresh "v"
          val (body, tb) = k (b, Core.TEval (lazyTy t))
        in
          (Core.Case (e, b, [Core.AltDefault body]), lazyTy tb)
        end

  (* x's representation evaluated, through every newtype at its head,
     before k: what a strict field of a newtype's type forces *)
  fun forceRep ((e, t), k) =
    let
      fun rep (e, t, seen) =
        case dataArgs (lazyTy t) of
          SOME (c, _) =>
            if List.exists (fn s => s = c) seen then (e, t)
            else (case unfold (lazyTy t) of SOME r => rep (Core.Cast (e, r), r, c :: seen) | NONE => (e, t))
        | NONE => (e, t)
    in
      force (rep (e, t, []), fn _ => k ())
    end

  fun forced k =
    case M.find (!forcedMap, k) of
      SOME fl => fl
    | NONE => (case conInfo k of SOME {fields, ...} => List.map Core.isEval fields | NONE => [])

  fun setForced (k, fl) = forcedMap := M.insert (!forcedMap, k, fl)

  fun forcedOverrides () = M.listItems (!forcedMap)

  fun caseCon (x, ty, alts, default) =
    case dataArgs ty of
      NONE => raise Fail ("HsDsCore: a case on " ^ CoreText.showTy ty ^ ", which is no data type")
    | SOME (c, args) =>
        let
          val all = case tycon c of SOME (_, DataS cs) => List.map #1 cs | _ => raise Fail ("HsDsCore: " ^ c ^ " is no data type")
          val made =
            List.map (fn (k, mk) =>
                        let
                          val fs = fieldsAt (k, args)
                          val names = List.map (fn _ => fresh "f") fs
                          val (body, t) = mk (ListPair.zip (names, fs))
                        in
                          (Core.AltCon (k, names, body), t)
                        end)
              alts
          val covered = List.all (fn k => List.exists (fn (k', _) => k' = k) alts) all
          val dflt =
            case (covered, default) of
              (true, _) => []
            | (false, SOME (d, t)) => [(Core.AltDefault d, t)]
            | (false, NONE) => raise Fail ("HsDsCore: a case on " ^ c ^ " that does not cover it")
          val alts' = made @ dflt
          val t = case alts' of (_, t) :: _ => lazyTy t | [] => raise Fail "HsDsCore: a case with no alternative"
        in
          (Core.Case (Core.Atom x, fresh "c", List.map #1 alts'), t)
        end

  fun ifBool ((c, _), (t, tt), (e, _)) =
    (Core.Case (c, fresh "b", [Core.AltCon ("True", [], t), Core.AltCon ("False", [], e)]), lazyTy tt)

  fun con (k, tys, xs) =
    case conInfo k of
      NONE => raise Fail ("HsDsCore: the constructor " ^ k ^ " is not declared")
    | SOME {tycon, ...} =>
        let
          val fs = fieldsAt (k, tys)
          val result = Core.apply (Core.TCon tycon, tys)
        in
          atoms (xs, fn avs =>
                       let
                         (* a strict field is given its value evaluated; one of a
                            newtype's type, lazy in Core, its representation *)
                         fun go ([], [], _, acc) = (Core.Con (k, tys, List.rev acc), result)
                           | go ((a, t) :: rest, f :: fs, b :: bs, acc) =
                               if Core.isEval f andalso not (Core.isEval t) then
                                 force ((Core.Atom a, t), fn (v, _) => go (rest, fs, bs, Core.Var v :: acc))
                               else if b andalso not (Core.isEval f) andalso not (Core.isEval t) then
                                 forceRep ((Core.Atom a, t), fn () => go (rest, fs, bs, a :: acc))
                               else go (rest, fs, bs, a :: acc)
                           | go _ = raise Fail ("HsDsCore: " ^ k ^ " given another number of fields")
                       in
                         go (avs, fs, forced k, [])
                       end)
        end

  fun cast ((e, _), t) = (Core.Cast (e, t), t)

  fun fail (kind, message, t) =
    let val t' = lazyTy t
    in (Core.App (Core.Atom (Core.Var (raiser kind)), [Core.TyArg t', Core.ValArg (Core.Lit (Core.LStr message))]), t') end

  (* every atom and name of an expression, to f *)
  fun walk f e =
    let
      fun atom (Core.Var x) = f x
        | atom (Core.Lit _) = ()
      fun go e =
        case e of
          Core.Atom a => atom a
        | Core.App (g, args) => (go g; List.app (fn Core.ValArg a => atom a | Core.TyArg _ => ()) args)
        | Core.Lam (_, b) => go b
        | Core.Let (_, _, r, b) => (go r; go b)
        | Core.LetRec (bs, b) => (List.app (fn (_, _, r) => go r) bs; go b)
        | Core.Case (s, _, alts) =>
            (go s;
             List.app (fn Core.AltCon (k, _, b) => (f k; go b)
                        | Core.AltLit (_, b) => go b
                        | Core.AltUTuple (_, b) => go b
                        | Core.AltDefault b => go b) alts)
        | Core.Con (k, _, xs) => (f k; List.app atom xs)
        | Core.Prim (_, _, xs) => List.app atom xs
        | Core.UTuple xs => List.app atom xs
        | Core.Cast (b, _) => go b
    in
      go e
    end

  exception Found

  fun mentions (x, e) = (walk (fn y => if y = x then raise Found else ()) e; false) handle Found => true

  fun names e =
    let
      val seen = ref M.empty
      val out = ref []
    in
      walk (fn y => if M.member (!seen, y) then () else (seen := M.insert (!seen, y, ()); out := y :: !out)) e;
      List.rev (!out)
    end

  val unitTy = Core.TCon "()"

  fun unitVal () = (Core.Con ("()", [], []), unitTy)
end
