(* Strictness: the analysis and its workers and wrappers (corestrict_sig.sml). *)
structure CoreStrict : CORE_STRICT =
struct
  open Core
  structure B = CoreSimplifyBase

  type strictness = {params : bool list, bottom : bool}

  val enabled = ref true

  (* ---- Sets of names, sorted ---- *)

  fun union ([], ys) = ys
    | union (xs, []) = xs
    | union (xs as x :: xs', ys as y :: ys') =
        case String.compare (x, y) of
          LESS => x :: union (xs', ys)
        | GREATER => y :: union (xs, ys')
        | EQUAL => x :: union (xs', ys')

  fun inter ([], _) = []
    | inter (_, []) = []
    | inter (xs as x :: xs', ys as y :: ys') =
        case String.compare (x, y) of
          LESS => inter (xs', ys)
        | GREATER => inter (xs, ys')
        | EQUAL => x :: inter (xs', ys')

  fun mem (x, xs) = List.exists (fn y => y = x) xs
  fun without (xs, gone) = List.filter (fn x => not (mem (x, gone))) xs

  (* ---- Demands ---- *)

  (* what evaluating an expression to its head does: the variables it
     surely evaluates, and whether it surely diverges *)
  type demand = {strict : string list, div : bool}

  val none : demand = {strict = [], div = false}
  fun just x : demand = {strict = [x], div = false}
  val diverges : demand = {strict = [], div = true}

  (* one after the other *)
  fun both (a : demand, b : demand) : demand = {strict = union (#strict a, #strict b), div = #div a orelse #div b}

  (* one or the other: a way that diverges says nothing of the others *)
  fun either (a : demand, b : demand) : demand =
    if #div a then b else if #div b then a else {strict = inter (#strict a, #strict b), div = false}

  fun bound (d : demand, xs) : demand = {strict = without (#strict d, xs), div = #div d}

  (* ---- Expressions ---- *)

  (* a lambda's binders, through the lambdas directly inside it, and its body *)
  fun peel (Lam (bs, e)) = let val (bs', body) = peel e in (bs @ bs', body) end
    | peel e = ([], e)

  fun valueParams bs = List.mapPartial (fn ValBinder (x, t) => SOME (x, t) | TyBinder _ => NONE) bs

  (* whether e is a function: a lambda of a value binder *)
  fun isFunction e = not (null (valueParams (#1 (peel e))))

  (* the strict fields of each constructor *)
  fun fieldsOf (p : program) : bool list CoreMap.map =
    List.foldl (fn (Data (_, _, cs), m) => List.foldl (fn ((c, fs), m) => CoreMap.insert (m, c, List.map isEval fs)) m cs
                 | (_, m) => m)
      CoreMap.empty (builtinData @ p)

  fun primParams p =
    case CorePrim.find p of
      SOME {ty, ...} =>
        let
          fun strip (TForall (_, _, b)) = strip b
            | strip t = t
          fun go (TFun (q, r)) = isEval q :: go r
            | go _ = []
        in go (strip ty) end
    | NONE => []

  (* a primitive whose result holds the state token: an I/O action's *)
  fun primIsIO p =
    case CorePrim.find p of
      SOME {ty, ...} =>
        let
          fun strip (TForall (_, _, b)) = strip b
            | strip t = t
          fun result (TFun (_, r)) = result r
            | result t = t
          fun hasWorld t = case stripEval t of TCon "World" => true | TUTuple ts => List.exists hasWorld ts | _ => false
        in hasWorld (result (strip ty)) end
    | NONE => false

  (* the demand of evaluating e, given the signatures `sigs` of the
     functions in scope *)
  fun demand (fields : bool list CoreMap.map, sigs : strictness CoreMap.map) (e : exp) : demand =
    case e of
      Atom (Var x) => just x
    | Atom (Lit _) => none
    | App (f, args) =>
        let
          val atoms = List.mapPartial (fn ValArg a => SOME a | TyArg _ => NONE) args
          fun arg (Var y) = just y
            | arg (Lit _) = none
        in
          case f of
            Atom (Var g) =>
              (case CoreMap.find (sigs, g) of
                 SOME {params, bottom} =>
                   if length atoms >= length params then
                     let
                       val given = List.foldl both (just g)
                                     (ListPair.mapEq (fn (s, a) => if s then arg a else none)
                                        (params, List.take (atoms, length params)))
                     in if bottom then {strict = #strict given, div = true} else given end
                   else just g
               | NONE => just g)
          | _ => demand (fields, sigs) f
        end
    | Lam _ => none
    | Let (x, t, rhs, body) =>
        let
          val sigs' = if isFunction rhs then CoreMap.insert (sigs, x, signatureOf (fields, sigs) rhs) else sigs
          val d = demand (fields, sigs') body
        in
          if mem (x, #strict d) then both (bound (d, [x]), demand (fields, sigs) rhs) else bound (d, [x])
        end
    | LetRec (bs, body) =>
        let
          val sigs' = recursive (fields, sigs) bs
        in bound (demand (fields, sigs') body, List.map #1 bs) end
    | Case (scrut, b, alts) =>
        let
          val ds = demand (fields, sigs) scrut
          fun alt a =
            case a of
              AltCon (c, xs, rhs) =>
                let
                  val d = demand (fields, sigs) rhs
                  (* a strict field is evaluated already: nothing to say of it *)
                in bound (d, b :: xs) end
            | AltLit (_, rhs) => bound (demand (fields, sigs) rhs, [b])
            | AltUTuple (xs, rhs) => bound (demand (fields, sigs) rhs, b :: xs)
            | AltDefault rhs => bound (demand (fields, sigs) rhs, [b])
          val da = case List.map alt alts of
                     [] => diverges
                   | d :: ds' => List.foldl either d ds'
          (* after an I/O action, nothing it might not reach is evaluated
             before it, and nothing is known to diverge (precise exceptions) *)
          val io = List.exists (fn AltUTuple _ => true | _ => false) alts
                   orelse (case scrut of Prim (p, _, _) => primIsIO p | _ => false)
          val da = if io then none else da
        in both (ds, da) end
    | Con (c, _, atoms) =>
        (case CoreMap.find (fields, c) of
           SOME fs => List.foldl both none (ListPair.map (fn (s, Var y) => if s then just y else none | (_, Lit _) => none) (fs, atoms))
         | NONE => none)
    | Prim (p, _, atoms) =>
        let
          val d = List.foldl both none (ListPair.map (fn (s, Var y) => if s then just y else none | (_, Lit _) => none)
                                          (primParams p, atoms))
        in if p = "raise" then {strict = #strict d, div = true} else d end
    | UTuple _ => none
    | Cast (e, _) => demand (fields, sigs) e

  (* a function's signature: what its body does to its value parameters *)
  and signatureOf (fields, sigs) (e : exp) : strictness =
    let
      val (bs, body) = peel e
      val ps = valueParams bs
      val d = demand (fields, sigs) body
    in {params = List.map (fn (x, t) => isEval t orelse mem (x, #strict d)) ps, bottom = #div d} end

  (* the signatures of a recursive group's functions, from the most strict
     down to what holds *)
  and recursive (fields, sigs) (bs : (string * ty * exp) list) : strictness CoreMap.map =
    let
      val funs = List.filter (fn (_, _, e) => isFunction e) bs
      val top = List.foldl (fn ((x, _, e), m) =>
                              CoreMap.insert (m, x, {params = List.map (fn _ => true) (valueParams (#1 (peel e))), bottom = true}))
                  sigs funs
      fun iterate (m, n) =
        let
          val next = List.map (fn (x, _, e) => (x, signatureOf (fields, m) e)) funs
          val changed = List.exists (fn (x, s) => CoreMap.find (m, x) <> SOME s) next
          val m' = List.foldl (fn ((x, s), m) => CoreMap.insert (m, x, s)) m next
        in
          if not changed then m'
          else if n = 0 then List.foldl (fn ((x, _, e), m) => CoreMap.insert (m, x, lazy e)) sigs funs
          else iterate (m', n - 1)
        end
    in iterate (top, 60) end

  (* what is known of a function no fixed point was found for *)
  and lazy e : strictness = {params = List.map (fn (_, t) => isEval t) (valueParams (#1 (peel e))), bottom = false}

  fun signatures (p : program) : strictness CoreMap.map =
    let
      val fields = fieldsOf p
      val vals = List.mapPartial (fn Val v => SOME v | _ => NONE) p
    in recursive (fields, CoreMap.empty) vals end

  (* ---- Workers and wrappers ---- *)

  fun isLifted (dt : B.datatypes) (t : ty) =
    not (isEval t) andalso not (B.isUnliftedTy t) andalso not (isSome (B.unfold dt t))
    andalso (case t of TForall _ => false | TFun _ => false | _ => true)

  (* f's type without its first foralls, given the binders' type variables *)
  fun instantiateTo (t : ty, tvs : string list) : ty =
    let
      fun go (TForall (a, _, b), v :: vs, s) = go (b, vs, (a, TVar v) :: s)
        | go (t, _, s) = substTy (s, t)
    in go (t, tvs, []) end

  fun resultAfter (t : ty, n : int) : ty =
    if n = 0 then t else case t of TFun (_, r) => resultAfter (r, n - 1) | _ => t

  fun workerName f = "%w:" ^ f

  (* whether t holds an unboxed tuple: a case that joins one of a strict
     parameter with one of a lazy value relaxes the components' `!`
     (CoreLint's join), which a worker's declared result would not keep *)
  fun hasUTuple t =
    case t of
      TUTuple _ => true
    | TEval u => hasUTuple u
    | TFun (a, b) => hasUTuple a orelse hasUTuple b
    | TForall (_, _, b) => hasUTuple b
    | TApp (a, b) => hasUTuple a orelse hasUTuple b
    | _ => false

  (* f, strict in some of its parameters: its worker's type and lambda, of
     them evaluated, and a wrapper that evaluates them, of f's type, and
     which of its value parameters the worker takes evaluated; NONE where
     none is worth it *)
  fun splitOf (dt : B.datatypes, sig_ : strictness) (f : string, t : ty, e : exp)
      : (ty * exp * exp * int * bool list) option =
    let
      val {params, ...} = sig_
      val (bs, body) = peel e
      val tyBinders = List.mapPartial (fn TyBinder b => SOME b | ValBinder _ => NONE) bs
      val vps = valueParams bs
    in
      if length params <> length vps
         orelse List.exists (fn TyBinder _ => true | _ => false) (List.drop (bs, length tyBinders))
      then NONE
      else
        let
          val marked = ListPair.map (fn ((x, pt), s) => (x, pt, s andalso isLifted dt pt)) (vps, params)
        in
          if not (List.exists #3 marked) orelse hasUTuple (resultAfter (instantiateTo (t, List.map #1 tyBinders), length vps))
          then NONE
          else
            let
              val tvs = List.map #1 tyBinders
              val inner = instantiateTo (t, tvs)
              val res = resultAfter (inner, length vps)
              val wty = List.foldr (fn ((a, k), r) => TForall (a, k, r))
                          (List.foldr (fn ((_, pt, s), r) => TFun (if s then TEval pt else pt, r)) res marked) tyBinders
              val worker = Lam (List.map TyBinder tyBinders @ List.map (fn (x, pt, s) => ValBinder (x, if s then TEval pt else pt)) marked,
                                body)
              (* the wrapper's own names *)
              val ys = List.map (fn (x, pt, s) => (B.fresh x, pt, s)) marked
              val zs = List.map (fn (y, _, s) => if s then B.fresh y else y) ys
              val call = App (Atom (Var (workerName f)), List.map (TyArg o TVar) tvs @ List.map (ValArg o Var) zs)
              val forced = ListPair.foldr (fn ((y, _, s), z, rest) => if s then Case (Atom (Var y), z, [AltDefault rest]) else rest)
                             call (ys, zs)
              val wrapper = Lam (List.map TyBinder tyBinders @ List.map (fn (y, pt, _) => ValBinder (y, pt)) ys, forced)
            in
              SOME (wty, worker, wrapper, length vps, List.map #3 marked)
            end
        end
    end

  (* e with each call of a function of `split` (its value parameters and
     those its worker takes evaluated) that gives them all made a call of
     the worker, the arguments evaluated first: the wrapper inlined, in a
     group whose functions call each other, where the simplifier inlines
     no wrapper *)
  fun callWorkers (split : (int * bool list) CoreMap.map) (e : exp) : exp =
    let
      fun go e =
        case e of
          App (Atom (Var f), args) =>
            let val args = List.map (fn a => a) args
            in
              case CoreMap.find (split, f) of
                SOME (n, ss) =>
                  let
                    val vals = List.length (List.filter (fn ValArg _ => true | TyArg _ => false) args)
                  in
                    if vals < n then App (Atom (Var f), args)
                    else
                      let
                        (* the arguments in order, each value one forced where the worker takes it evaluated *)
                        fun walk ([], _, acc, wrap) = wrap (App (Atom (Var (workerName f)), List.rev acc))
                          | walk (TyArg t :: rest, ss, acc, wrap) = walk (rest, ss, TyArg t :: acc, wrap)
                          | walk (ValArg a :: rest, s :: ss, acc, wrap) =
                              (case (s, a) of
                                 (true, Var y) =>
                                   let val z = B.fresh y
                                   in walk (rest, ss, ValArg (Var z) :: acc, fn inner => wrap (Case (Atom (Var y), z, [AltDefault inner]))) end
                               | _ => walk (rest, ss, ValArg a :: acc, wrap))
                          | walk (ValArg a :: rest, [], acc, wrap) = walk (rest, [], ValArg a :: acc, wrap)
                      in walk (args, ss, [], fn x => x) end
                  end
              | NONE => App (Atom (Var f), args)
            end
        | App (f, args) => App (go f, args)
        | Lam (bs, b) => Lam (bs, go b)
        | Let (x, t, r, b) => Let (x, t, go r, go b)
        | LetRec (bs, b) => LetRec (List.map (fn (x, t, r) => (x, t, go r)) bs, go b)
        | Case (s, b, alts) =>
            Case (go s, b, List.map (fn AltCon (c, xs, r) => AltCon (c, xs, go r)
                                      | AltLit (l, r) => AltLit (l, go r)
                                      | AltUTuple (xs, r) => AltUTuple (xs, go r)
                                      | AltDefault r => AltDefault (go r)) alts)
        | Cast (b, t) => Cast (go b, t)
        | _ => e
    in go e end

  (* e with each local function strict in a parameter split: a let of one
     the worker's let and the wrapper's, a letrec's its workers and wrappers
     in the group, every call inside the group of a function split made of
     its worker *)
  fun locals (dt : B.datatypes, fields, sigs : strictness CoreMap.map) (e : exp) : exp =
    let
      fun go e =
        case e of
          Let (x, t, r, b) =>
            let
              val r' = go r
              val b' = go b
            in
              if isFunction r' then
                case splitOf (dt, signatureOf (fields, sigs) r') (x, t, r') of
                  SOME (wty, worker, wrapper, _, _) =>
                    if B.tick "strict-worker-local" then Let (workerName x, wty, worker, Let (x, t, wrapper, b'))
                    else Let (x, t, r', b')
                | NONE => Let (x, t, r', b')
              else Let (x, t, r', b')
            end
        | LetRec (bs, b) =>
            let
              val bs' = List.map (fn (x, t, r) => (x, t, go r)) bs
              val b' = go b
              val gsigs = recursive (fields, sigs) bs'
              val made =
                List.map (fn (x, t, r) =>
                            case (if isFunction r then CoreMap.find (gsigs, x) else NONE) of
                              SOME s => (case splitOf (dt, s) (x, t, r) of
                                           SOME sp => if B.tick "strict-worker-local" then (x, t, r, SOME sp) else (x, t, r, NONE)
                                         | NONE => (x, t, r, NONE))
                            | NONE => (x, t, r, NONE))
                  bs'
              val split = List.foldl (fn ((x, _, _, SOME (_, _, _, n, ss)), m) => CoreMap.insert (m, x, (n, ss)) | (_, m) => m)
                            CoreMap.empty made
              val group =
                List.concat
                  (List.map (fn (x, t, r, SOME (wty, worker, wrapper, _, _)) =>
                                  [(workerName x, wty, callWorkers split worker), (x, t, wrapper)]
                              | (x, t, r, NONE) => [(x, t, callWorkers split r)]) made)
            in LetRec (group, b') end
        | App (f, args) => App (go f, args)
        | Lam (bs, b) => Lam (bs, go b)
        | Case (s, b, alts) =>
            Case (go s, b, List.map (fn AltCon (c, xs, r) => AltCon (c, xs, go r)
                                      | AltLit (l, r) => AltLit (l, go r)
                                      | AltUTuple (xs, r) => AltUTuple (xs, go r)
                                      | AltDefault r => AltDefault (go r)) alts)
        | Cast (b, t) => Cast (go b, t)
        | _ => e
    in go e end

  fun program (spend : unit -> bool, p : program) : program =
    if not (!enabled) then p
    else
      let
        val () = B.spendRef := spend
        val sigs = signatures p
        val dt = B.datatypes p
        val fields = fieldsOf p
        fun one (d as Val (f, t, e)) =
              let val e = locals (dt, fields, sigs) e
              in
                if String.isPrefix "%w:" f orelse f = "main" then [Val (f, t, e)]
                else
                  case (case CoreMap.find (sigs, f) of SOME s => splitOf (dt, s) (f, t, e) | NONE => NONE) of
                    SOME (wty, worker, wrapper, _, _) =>
                      if B.tick "strict-worker" then [Val (workerName f, wty, worker), Val (f, t, wrapper)] else [Val (f, t, e)]
                  | NONE => [Val (f, t, e)]
              end
          | one d = [d]
      in List.concat (List.map one p) end

  (* ---- Signatures as text ---- *)

  fun show ({params, bottom} : strictness) =
    String.implode (List.map (fn true => #"S" | false => #"L") params) ^ (if bottom then "b" else "")

  fun read s =
    let
      val cs = String.explode s
      val (body, bottom) = case List.rev cs of #"b" :: rest => (List.rev rest, true) | _ => (cs, false)
    in
      if List.all (fn c => c = #"S" orelse c = #"L") body
      then SOME {params = List.map (fn c => c = #"S") body, bottom = bottom}
      else NONE
    end
end
