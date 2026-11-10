(* Eta-expansion for the Core simplifier (coresimplify_sig.sml; the
   haskell98 roadmap's M23, D48).

   A binding of a function type whose expression binds fewer values than
   its type takes is given more lambdas where the expression can take more
   arguments at no cost: where it is, under the lambdas it has, a lambda, a
   function applied to fewer values than it binds, or either under lets of
   values. Under the pedantic rule (D48's C, decided) that is all: the
   expression is a value already, so no evaluation is moved under a
   lambda and `seq` sees what it saw (6.2). `f = \x -> case x of _ -> \y ->
   e` keeps its arity, since `f undefined `seq` ()` is bottom, and so does
   an action of `IO` behind a let, which GHC's state hack would expand.

   GHC's default (D48's D, built to be measured and not conforming) goes
   through a case on an atom, its alternatives' least arity, and expands
   a function of an `IO` result through anything, the state hack. Under
   the pedantic rule the passes count what D would expand and C does not
   (`eta-refused`), and under D what it does (`eta-ghc`). *)
structure CoreSimplifyEta =
struct
  open Core
  structure B = CoreSimplifyBase

  datatype mode = Pedantic | Ghc

  (* the type t of a binding, its leading foralls given the type binders
     of its lambda, without the value parameters the lambda binds: the
     parameters left and the result *)
  fun remaining (t : ty, bs : binder list) : (ty list * ty) option =
    let
      fun go (t, [], acc) = SOME (List.rev acc, t)
        | go (t, TyBinder (a, _) :: rest, acc) =
            (case stripEval t of
               TForall (b, _, body) => go (substTy ([(b, TVar a)], body), rest, acc)
             | _ => NONE)
        | go (t, ValBinder _ :: rest, acc) =
            (case stripEval t of
               TFun (_, r) => go (r, rest, acc)
             | _ => NONE)
      fun params (t, acc) = case stripEval t of TFun (p, r) => params (r, p :: acc) | r => (List.rev acc, r)
    in
      case go (t, bs, []) of
        SOME (_, t') => SOME (params (t', []))
      | NONE => NONE
    end

  fun program (mode : mode, p : program) : program =
    let
      val dt = B.datatypes p
      val globalArity =
        List.foldl (fn (Val (x, _, Lam (bs, _)), m) => CoreMap.insert (m, x, B.valueArity bs) | (_, m) => m) CoreMap.empty p
      fun arityIn (locals : int CoreMap.map) (x : string) : int =
        case CoreMap.find (locals, x) of
          SOME n => n
        | NONE => getOpt (CoreMap.find (globalArity, x), 0)
      fun valueArgs args = List.length (List.filter (fn ValArg _ => true | TyArg _ => false) args)
      fun cheap (ar, e) =
        B.isValue e
        orelse (case e of
                  App (Atom (Var f), args) => valueArgs args < ar f
                | Cast (e, _) => cheap (ar, e)
                | _ => false)
      (* how many more arguments e takes at no cost, under the mode *)
      fun etaArity (mode, locals) (e : exp) : int =
        let
          val ar = arityIn locals
          fun go e =
            case e of
              Lam (bs, b) =>
                if List.exists (fn TyBinder _ => true | _ => false) bs then 0 else B.valueArity bs + go b
            | App (Atom (Var f), args) => Int.max (0, ar f - valueArgs args)
            | Atom (Var f) => ar f
            | Let (x, _, r, b) =>
                if cheap (ar, r) then
                  etaArity (mode, case r of Lam (bs, _) => CoreMap.insert (locals, x, B.valueArity bs) | _ => locals) b
                else 0
            | LetRec (bs, b) =>
                if List.all (fn (_, _, r) => case r of Lam _ => true | _ => false) bs then
                  etaArity (mode, List.foldl (fn ((x, _, Lam (lbs, _)), m) => CoreMap.insert (m, x, B.valueArity lbs) | (_, m) => m)
                                              locals bs) b
                else 0
            | Case (Atom _, _, alts) =>
                (case mode of
                   Pedantic => 0
                 | Ghc =>
                     let val live = List.filter (fn a => not (B.isBottom (B.altRhs a))) alts
                     in case live of
                          [] => 0
                        | _ => List.foldl (fn (a, n) => Int.min (n, go (B.altRhs a))) 1000000 live
                     end)
            | _ => 0
        in go e end
      (* whether t, a function's result, is an action of IO: a newtype
         over a function of the state token *)
      fun isAction t =
        case B.unfold dt t of
          SOME (TFun (w, _)) => (case stripEval w of TCon "World" => true | _ => false)
        | _ => false
      fun isManifestAction e =
        case e of
          Cast (Lam _, _) => true
        | _ => false
      (* the binding x : t = e, expanded where it may be *)
      fun binding (locals, t : ty, e : exp) : exp =
        let
          val (bs, body) = case e of Lam (bs, b) => (bs, b) | _ => ([], e)
          val canBind = case (bs, stripEval t) of ([], TForall _) => false | _ => true
        in
          if not canBind then e
          else
            case remaining (t, bs) of
              NONE => e
            | SOME (params, result) =>
                let
                  val kC = Int.min (length params, etaArity (Pedantic, locals) body)
                  val kD = Int.min (length params, etaArity (Ghc, locals) body)
                  (* the state hack: a function of an IO result, all its
                     parameters bound, through whatever stands before the
                     action *)
                  val hack = length params = 0 andalso not (null bs) andalso B.valueArity bs > 0 andalso isAction result
                             andalso not (isManifestAction body) andalso not (cheap (arityIn locals, body))
                  val refused = kD > kC orelse hack
                  val () = if refused then B.count (case mode of Pedantic => "eta-refused" | Ghc => "eta-ghc-candidate") else ()
                  val k = case mode of Pedantic => kC | Ghc => kD
                  fun expand () =
                    let
                      val ys = List.map (fn p => (B.fresh "%eta", p)) (List.take (params, k))
                      val body' = App (body, List.map (fn (y, _) => ValArg (Var y)) ys)
                    in Lam (bs @ List.map ValBinder ys, body') end
                  fun stateHack e =
                    case (e, B.unfold dt result) of
                      (Lam (bs, body), SOME fnTy) =>
                        let val w = B.fresh "%eta"
                        in Lam (bs, Cast (Lam ([ValBinder (w, TCon "World")], App (Cast (body, fnTy), [ValArg (Var w)])), result)) end
                    | _ => e
                in
                  if k > 0 andalso B.tick (if kD > kC then "eta-ghc" else "eta") then expand ()
                  else if mode = Ghc andalso hack andalso B.tick "eta-ghc" then stateHack e
                  else e
                end
        end
      fun walk (locals : int CoreMap.map) (e : exp) : exp =
        case e of
          Lam (bs, b) => Lam (bs, walk locals b)
        | App (f, args) => App (walk locals f, args)
        | Let (x, t, r, b) =>
            let
              val r' = binding (locals, t, walk locals r)
              val locals' = case r' of Lam (bs, _) => CoreMap.insert (locals, x, B.valueArity bs) | _ => locals
            in Let (x, t, r', walk locals' b) end
        | LetRec (bs, b) =>
            let
              val locals' = List.foldl (fn ((x, _, Lam (lbs, _)), m) => CoreMap.insert (m, x, B.valueArity lbs) | (_, m) => m) locals bs
              val bs' = List.map (fn (x, t, r) => (x, t, binding (locals', t, walk locals' r))) bs
              val locals'' = List.foldl (fn ((x, _, Lam (lbs, _)), m) => CoreMap.insert (m, x, B.valueArity lbs) | (_, m) => m) locals bs'
            in LetRec (bs', walk locals'' b) end
        | Case (s, b, alts) =>
            Case (walk locals s, b, List.map (fn AltCon (c, xs, r) => AltCon (c, xs, walk locals r)
                                              | AltLit (l, r) => AltLit (l, walk locals r)
                                              | AltUTuple (xs, r) => AltUTuple (xs, walk locals r)
                                              | AltDefault r => AltDefault (walk locals r)) alts)
        | Cast (e, t) => Cast (walk locals e, t)
        | _ => e
      fun decl d =
        case d of
          Val (x, t, e) => if x = "main" then Val (x, t, walk CoreMap.empty e) else Val (x, t, binding (CoreMap.empty, t, walk CoreMap.empty e))
        | _ => d
    in List.map decl p end
end
