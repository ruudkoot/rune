(* Local refs as values (docs/ir.md; plans/performance.md, M8, D8 A, step
   4): a parameter of a function of the top level that is a ref the
   function only reads and sets, and gives on as it is to its own calls of
   itself in tail position -- a loop's counter -- is its value instead, in
   a copy of the function: a read is the value the ref holds there, a set
   the value it holds from there on, a join point is given it as a
   parameter, and a call of itself gives the value it holds then. A call
   of the function that gives refs made for it alone -- made in the same
   function, not in a function inside it, and used by that call only --
   calls the copy with the values they were made of, and the refs are not
   made. A ref under a handler is left as it is, since a raise would leave
   its value where the handler cannot see it.

   The function is kept for its other uses; Shake takes it out where
   nothing names it any more. *)
structure Refs =
struct
  open Mid

  fun freshStamp () = Elaborate.freshStamp ()

  fun refArg (t : Ty.ty) : Ty.ty option =
    case t of
      Ty.Con (s, _, [a]) => if s = #stamp Types.refTycon then SOME a else NONE
    | _ => NONE

  fun atomsOf (r : rhs) : atom list =
    case r of
      Atom a => [a]
    | App (f, xs) => f :: xs
    | Prim (_, _, xs) => xs
    | Tuple xs => xs
    | Select (_, a) => [a]
    | Con (_, _, a) => [a]
    | Decon (_, _, a) => [a]
    | ConTag a => [a]
    | MkExn (c, a) => [c, a]
    | ExnCon a => [a]
    | ExnArg (_, a) => [a]
    | SetGlobal (_, a) => [a]
    | _ => []

  (* The places of f's parameters that are refs it only reads and sets and
     gives on to its calls of itself in tail position. *)
  fun refParams (f : fundef) : int list =
    let
      val ps = Vector.fromList (#params f)
      val n = Vector.length ps
      val cand = Array.tabulate (n, fn i => isSome (refArg (#2 (Vector.sub (ps, i)))))
      fun index x =
        let fun go i = if i = n then NONE else if #1 (Vector.sub (ps, i)) = x then SOME i else go (i + 1)
        in go 0 end
      fun kill a = case a of Var (x, _) => (case index x of SOME i => Array.update (cand, i, false) | NONE => ()) | _ => ()
      fun killAll r = List.app kill (atomsOf r)
      fun killExp e =
        case e of
          Let (_, _, r, b) => (killAll r; killExp b)
        | Fun (fs, b) => (List.app (fn g => killExp (#body g)) fs; killExp b)
        | Join (_, _, jb, sc) => (killExp jb; killExp sc)
        | Jump (_, xs) => List.app kill xs
        | If (a, t, e) => (kill a; killExp t; killExp e)
        | Handle (a, _, h) => (killExp a; killExp h)
        | Raise a => kill a
        | Return r => killAll r
        | Mark (_, a) => killExp a
      fun rhs (r, tail) =
        case r of
          Prim ("ref_get", _, [Var _]) => ()
        | Prim ("ref_set", _, [Var _, v]) => kill v
        | App (Global (g, _), args) =>
            if g = #name f andalso tail andalso List.length args = n then
              ListPair.app (fn (i, a) =>
                              case a of
                                Var (x, _) => if x = #1 (Vector.sub (ps, i)) then () else kill a
                              | _ => kill a)
                           (List.tabulate (n, fn i => i), args)
            else List.app kill args
        | _ => killAll r
      fun exp e =
        case e of
          Let (_, _, r, b) => (rhs (r, false); exp b)
        | Fun (fs, b) => (List.app (fn g => killExp (#body g)) fs; exp b)
        | Join (_, _, jb, sc) => (exp jb; exp sc)
        | Jump (_, xs) => List.app kill xs
        | If (a, t, e) => (kill a; exp t; exp e)
        | Handle (a, _, h) => (killExp a; killExp h)
        | Raise a => kill a
        | Return r => rhs (r, true)
        | Mark (_, a) => exp a
    in
      if not (Array.exists (fn c => c) cand) then []
      else (exp (#body f); List.filter (fn i => Array.sub (cand, i)) (List.tabulate (n, fn i => i)))
    end

  (* f's copy named f', its refs at the places ks their values. *)
  fun copyOf (f as {name, tyvars, params, result, body} : fundef, f' : var, ks : int list) : fundef =
    let
      val ps' = List.map (fn (x, t) => (x, freshStamp (), t)) params
      val renamed = List.foldl (fn ((x, y, _), m) => IntMap.insert (m, x, y)) IntMap.empty ps'
      val body = Simplify.copyWith (renamed, body)
      val refs = List.map (fn k => #2 (List.nth (ps', k))) ks
      val elemTy = List.map (fn k => valOf (refArg (#3 (List.nth (ps', k))))) ks
      fun isRef r = List.exists (fn y => y = r) refs
      (* the join points given the values, by label *)
      val extended : unit IntTable.table = IntTable.table 16
      fun values cur = List.map (fn r => valOf (IntMap.find (cur, r))) refs
      (* whether a join point's body asks what the refs hold: reads one,
         sets one, calls the function, or jumps to a join point that does *)
      fun asks (e : exp) : bool =
        let
          fun rhs r =
            case r of
              Prim ("ref_get", _, [Var (r, _)]) => isRef r
            | Prim ("ref_set", _, [Var (r, _), _]) => isRef r
            | App (Global (g, _), _) => g = name
            | _ => false
          fun go e =
            case e of
              Let (_, _, r, b) => rhs r orelse go b
            | Fun (_, b) => go b
            | Join (_, _, jb, sc) => go jb orelse go sc
            | Jump (j, _) => isSome (IntTable.find (extended, j))
            | If (_, t, f) => go t orelse go f
            | Handle (a, _, h) => go a orelse go h
            | Return r => rhs r
            | Mark (_, a) => go a
            | _ => false
        in go e end
      fun go (e, cur : atom IntMap.map) : exp =
        case e of
          Let (x, s, g as Prim ("ref_get", _, [Var (r, _)]), b) =>
            if isRef r then Let (x, s, Atom (valOf (IntMap.find (cur, r))), go (b, cur))
            else Let (x, s, g, go (b, cur))
        | Let (x, s, Prim ("ref_set", t, [Var (r, ts), v]), b) =>
            if isRef r then Let (x, s, Atom Unit, go (b, IntMap.insert (cur, r, v)))
            else Let (x, s, Prim ("ref_set", t, [Var (r, ts), v]), go (b, cur))
        | Let (x, s, r, b) => Let (x, s, r, go (b, cur))
        | Fun (fs, b) => Fun (fs, go (b, cur))
        | Join (j, qs, jb, sc) =>
            if not (asks jb) then Join (j, qs, go (jb, cur), go (sc, cur))
            else
              let
                val cs = ListPair.map (fn (_, t) => (freshStamp (), t)) (refs, elemTy)
                val () = IntTable.insert (extended, j, ())
                val cur' = ListPair.foldl (fn (r, (c, _), m) => IntMap.insert (m, r, Var (c, []))) cur (refs, cs)
              in Join (j, qs @ cs, go (jb, cur'), go (sc, cur)) end
        | Jump (j, xs) => if isSome (IntTable.find (extended, j)) then Jump (j, xs @ values cur) else e
        | If (a, t, f) => If (a, go (t, cur), go (f, cur))
        | Handle (a, x, h) => Handle (go (a, cur), x, go (h, cur))
        | Return (App (Global (g, ts), args)) =>
            if g = name then
              Return (App (Global (f', ts),
                           ListPair.map (fn (i, a) =>
                                           case List.find (fn (k, _) => k = i) (ListPair.zip (ks, refs)) of
                                             SOME (_, r) => valOf (IntMap.find (cur, r))
                                           | NONE => a)
                                        (List.tabulate (List.length args, fn i => i), args)))
            else e
        | Mark (sp, a) => Mark (sp, go (a, cur))
        | _ => e
      val cur0 = List.foldl (fn (r, m) => IntMap.insert (m, r, Var (r, []))) IntMap.empty refs
      (* the parameters: a ref's is its value now, of the type it holds *)
      val params' = ListPair.map (fn ((_, y, t), i) => (y, if List.exists (fn k => k = i) ks then valOf (refArg t) else t))
                                 (ps', List.tabulate (List.length ps', fn i => i))
      val () =
        case (params, ps') of
          ((x, _) :: _, (_, y, _) :: _) =>
            (case IntMap.find (!Translate.funNames, x) of
               SOME n => Translate.funNames := IntMap.insert (!Translate.funNames, y, n)
             | NONE => ())
        | _ => ()
    in
      {name = f', tyvars = tyvars, params = params', result = result, body = go (body, cur0)}
    end

  fun program (p : program) : program =
    let
      (* the functions, their ref parameters, and their copies, made where
         a call first asks *)
      val cands : (fundef * int list) IntTable.table = IntTable.table 64
      val any = ref false
      val () =
        List.app (fn Funs fs =>
                       List.app (fn f => case refParams f of
                                           [] => ()
                                         | ks => (any := true; IntTable.insert (cands, #name f, (f, ks)))) fs
                   | _ => ()) p
      (* whether e calls one of them, where a ref may be given: only such an
         expression is walked again *)
      fun callsOne (e : exp) : bool =
        let
          fun rhs r = case r of App (Global (g, _), _) => isSome (IntTable.find (cands, g)) | _ => false
          fun go e =
            case e of
              Let (_, _, r, b) => rhs r orelse go b
            | Fun (fs, b) => List.exists (fn f => go (#body f)) fs orelse go b
            | Join (_, _, jb, sc) => go jb orelse go sc
            | If (_, t, f) => go t orelse go f
            | Handle (a, _, h) => go a orelse go h
            | Return r => rhs r
            | Mark (_, a) => go a
            | _ => false
        in go e end
      (* a copy for each function and set of its ref parameters given
         fresh refs *)
      val copies : var StringMap.map ref = ref StringMap.empty
      val made : fundef list ref = ref []
      fun copyFor (g : var, ks : int list) : var =
        let val key = String.concatWith "," (List.map Int.toString (g :: ks))
        in
          case StringMap.find (!copies, key) of
            SOME g' => g'
          | NONE =>
              let
                val (f, _) = valOf (IntTable.find (cands, g))
                val g' = freshStamp ()
              in
                copies := StringMap.insert (!copies, key, g');
                made := copyOf (f, g', ks) :: !made;
                g'
              end
        end
      (* how often each variable is used in a definition *)
      fun counts (e : exp) : int IntTable.table =
        let
          val t = IntTable.table 64
          fun atom a = case a of Var (x, _) => IntTable.bump (t, x) | _ => ()
          fun go e =
            case e of
              Let (_, _, r, b) => (List.app atom (atomsOf r); go b)
            | Fun (fs, b) => (List.app (fn f => go (#body f)) fs; go b)
            | Join (_, _, jb, sc) => (go jb; go sc)
            | Jump (_, xs) => List.app atom xs
            | If (a, t, f) => (atom a; go t; go f)
            | Handle (a, _, h) => (go a; go h)
            | Raise a => atom a
            | Return r => List.app atom (atomsOf r)
            | Mark (_, a) => go a
        in go e; t end
      (* a definition's expression, its calls rewritten: fresh holds the
         refs made in this function and used once, with what each was made
         of; used, those a call took *)
      fun rewrite (e : exp) : exp = if callsOne e then rewriteCalls e else e
      and rewriteCalls (e : exp) : exp =
        let
          val uses = counts e
          fun once x = IntTable.find (uses, x) = SOME 1
          val fresh : atom IntTable.table = IntTable.table 16
          val used : unit IntTable.table = IntTable.table 16
          fun call (r : rhs) : rhs =
            case r of
              App (Global (g, ts), args) =>
                (case IntTable.find (cands, g) of
                   SOME (_, ks) =>
                     let
                       (* the places given fresh refs, each with the ref and
                          what it was made of *)
                       val given = List.mapPartial (fn k => case List.nth (args, k) of
                                                              Var (x, []) => Option.map (fn v => (k, x, v)) (IntTable.find (fresh, x))
                                                            | _ => NONE) ks
                     in
                       if not (null given) andalso Pass.spend () then
                         let
                           val () = List.app (fn (_, x, _) => IntTable.insert (used, x, ())) given
                           val args' = ListPair.map (fn (i, a) =>
                                                       case List.find (fn (k, _, _) => k = i) given of
                                                         SOME (_, _, v) => v
                                                       | NONE => a)
                                                    (List.tabulate (List.length args, fn i => i), args)
                         in App (Global (copyFor (g, List.map #1 given), ts), args') end
                       else r
                     end
                 | NONE => r)
            | _ => r
          fun go (e : exp) : exp =
            case e of
              Let (x, s, r as Prim ("ref_new", _, [v]), b) =>
                (if once x then IntTable.insert (fresh, x, v) else ();
                 let val b' = go b
                 in if isSome (IntTable.find (used, x)) then b' else Let (x, s, r, b') end)
            | Let (x, s, r, b) => Let (x, s, call r, go b)
            | Fun (fs, b) =>
                (* a function inside: rewritten for itself, where a ref
                   made outside is not fresh *)
                Fun (List.map (fn {name, tyvars, params, result, body} =>
                                 {name = name, tyvars = tyvars, params = params, result = result, body = rewrite body}) fs,
                     go b)
            | Join (j, ps, jb, sc) => Join (j, ps, go jb, go sc)
            | If (a, t, f) => If (a, go t, go f)
            | Handle (a, x, h) => Handle (go a, x, go h)
            | Return r => Return (call r)
            | Mark (sp, a) => Mark (sp, go a)
            | _ => e
        in go e end
      val p' =
        if not (!any) then p else
        List.map (fn Val (g, s, e) => Val (g, s, rewrite e)
                   | Funs fs => Funs (List.map (fn {name, tyvars, params, result, body} =>
                                                   {name = name, tyvars = tyvars, params = params, result = result,
                                                    body = rewrite body}) fs)
                   | Do (gs, e) => Do (gs, rewrite e)) p
      (* the copies' own calls rewritten in turn, which may make more *)
      fun drain acc =
        case !made of
          [] => acc
        | fs =>
            (made := [];
             drain (acc @ List.map (fn {name, tyvars, params, result, body} =>
                                      {name = name, tyvars = tyvars, params = params, result = result, body = rewrite body})
                                   (List.rev fs)))
      val copied = drain []
    in
      if not (!any) then p else
      (* the copies after the last definition, as a group of their own:
         known calls find a function wherever it is *)
      case copied of
        [] => p'
      | fs => p' @ [Funs fs]
    end
end
