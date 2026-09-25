(* Tree shaking (docs/ir.md; docs/plans/middle-end.md, M7): the globals of
   Mid that nothing the program does reaches go, before anything else is
   done to them -- the Basis Library is compiled whole into every program,
   and most of it is never used (89% of tak's code was never called).

   What is done for its effect is kept (Do), and so is a global whose value
   is made with one: a call, a primitive that is not removable, a raise, a
   global set. From those, every global they use is reached, and every one
   the definitions of those use. A function of a group that nothing
   reaches goes alone. Before that, a global that is another's alias is
   the other wherever it is used (aliases). *)
structure Shake =
struct
  open Mid

  (* The globals an expression uses, added to acc, and whether it may do
     more than make its value. *)
  fun scan (e : exp, acc : unit IntMap.map, effect : bool) : unit IntMap.map * bool =
    let
      fun atom (a, acc) = case a of Global (g, _) => IntMap.insert (acc, g, ()) | _ => acc
      fun atoms (xs, acc) = List.foldl atom acc xs
      fun rhs (r, (acc, eff)) =
        case r of
          Atom a => (atom (a, acc), eff)
        | App (f, xs) => (atoms (f :: xs, acc), true)
        | Prim (p, _, xs) => (atoms (xs, acc), eff orelse not (Prims.removable p))
        | Tuple xs => (atoms (xs, acc), eff)
        | Select (_, a) => (atom (a, acc), eff)
        | Con (_, _, a) => (atom (a, acc), eff)
        | Decon (_, _, a) => (atom (a, acc), eff)
        | ConTag a => (atom (a, acc), eff)
        | MkExn (c, a) => (atoms ([c, a], acc), eff)
        | ExnCon a => (atom (a, acc), eff)
        | ExnArg (_, a) => (atom (a, acc), eff)
        | SetGlobal (_, a) => (atom (a, acc), true)
        | NewExn _ => (acc, eff)
        | BuiltinExn _ => (acc, eff)
      fun exp (e, st) =
        case e of
          Let (_, _, r, b) => exp (b, rhs (r, st))
        | Fun (fs, b) =>
            (* making a function does nothing; what it uses is used *)
            exp (b, List.foldl (fn (f, (acc, eff)) => (#1 (scan (#body f, acc, false)), eff)) st fs)
        | Join (_, _, body, s) => exp (s, exp (body, st))
        | Jump (_, xs) => (atoms (xs, #1 st), #2 st)
        | If (c, t, f) => exp (f, exp (t, (atom (c, #1 st), #2 st)))
        | Handle (a, _, h) => exp (h, exp (a, st))
        | Raise a => (atom (a, #1 st), true)
        | Return r => rhs (r, st)
        | Mark (_, a) => exp (a, st)
    in exp (e, (acc, effect)) end

  (* A global bound to another -- `val foldl = foldl` in structure List -- is
     the other at every use, at the types the use gives it, so that what
     knows a function of the top level knows it through the alias too: the
     workers, known calls, inlining (M12). The alias itself then goes, where
     nothing else uses it. *)
  fun aliases (p : program) : program =
    let
      fun global (Return (Atom (Global (h, ts)))) = SOME (h, ts)
        | global (Mark (_, e)) = global e
        | global _ = NONE
      val direct =
        List.foldl (fn (Val (g, (tvs, _), e), m) =>
                         (case global e of SOME (h, ts) => IntMap.insert (m, g, (tvs, h, ts)) | NONE => m)
                     | (_, m) => m) IntMap.empty p
      (* followed through aliases of aliases; a cycle, which no program
         makes, is left where it is found *)
      fun resolve (g, us, n) =
        case IntMap.find (direct, g) of
          SOME (tvs, h, ts) =>
            if n > 64 orelse List.length tvs <> List.length us then (g, us)
            else
              let val s = ListPair.foldl (fn (tv, u, s) => IntMap.insert (s, tv, u)) IntMap.empty (tvs, us)
              in resolve (h, List.map (Ty.subst s) ts, n + 1) end
        | NONE => (g, us)
      fun atom a = case a of Global (g, us) => Global (resolve (g, us, 0)) | _ => a
      fun rhs r =
        case r of
          Atom a => Atom (atom a)
        | App (f, xs) => App (atom f, List.map atom xs)
        | Prim (q, t, xs) => Prim (q, t, List.map atom xs)
        | Tuple xs => Tuple (List.map atom xs)
        | Select (i, a) => Select (i, atom a)
        | Con (tag, t, a) => Con (tag, t, atom a)
        | Decon (tag, t, a) => Decon (tag, t, atom a)
        | ConTag a => ConTag (atom a)
        | MkExn (c, a) => MkExn (atom c, atom a)
        | ExnCon a => ExnCon (atom a)
        | ExnArg (t, a) => ExnArg (t, atom a)
        | SetGlobal (g, a) => SetGlobal (g, atom a)
        | _ => r
      fun exp e =
        case e of
          Let (x, sc, r, b) => Let (x, sc, rhs r, exp b)
        | Fun (fs, b) => Fun (List.map fundef fs, exp b)
        | Join (j, ps, jb, sc) => Join (j, ps, exp jb, exp sc)
        | Jump (j, xs) => Jump (j, List.map atom xs)
        | If (a, t, f) => If (atom a, exp t, exp f)
        | Handle (a, x, h) => Handle (exp a, x, exp h)
        | Raise a => Raise (atom a)
        | Return r => Return (rhs r)
        | Mark (sp, a) => Mark (sp, exp a)
      and fundef {name, tyvars, params, result, body} =
        {name = name, tyvars = tyvars, params = params, result = result, body = exp body}
    in
      if IntMap.isEmpty direct orelse not (Pass.spend ()) then p
      else
        List.map (fn Val (g, s, e) => Val (g, s, if IntMap.member (direct, g) then e else exp e)
                   | Funs fs => Funs (List.map fundef fs)
                   | Do (gs, e) => Do (gs, exp e)) p
    end

  fun program (p : program) : program =
    let
      val p = aliases p
      (* what each global's definition uses *)
      val defs : unit IntMap.map IntMap.map ref = ref IntMap.empty
      fun define (g, used) = defs := IntMap.insert (!defs, g, used)
      val roots =
        List.foldl
          (fn (d, roots) =>
             case d of
               Val (g, _, e) =>
                 let val (used, eff) = scan (e, IntMap.empty, false)
                 in define (g, used); if eff then IntMap.unionWith #1 (used, IntMap.insert (roots, g, ())) else roots end
             | Funs fs =>
                 (List.app (fn f => define (#name f, #1 (scan (#body f, IntMap.empty, false)))) fs; roots)
             | Do (_, e) => IntMap.unionWith #1 (#1 (scan (e, IntMap.empty, true)), roots))
          IntMap.empty p
      (* everything the roots reach *)
      fun reach ([], seen) = seen
        | reach (g :: rest, seen) =
            if IntMap.member (seen, g) then reach (rest, seen)
            else
              let val used = case IntMap.find (!defs, g) of SOME u => IntMap.listKeys u | NONE => []
              in reach (used @ rest, IntMap.insert (seen, g, ())) end
      val live = reach (IntMap.listKeys roots, IntMap.empty)
      fun keep g = IntMap.member (live, g)
      fun def d =
        case d of
          Val (g, _, e) => if keep g orelse #2 (scan (e, IntMap.empty, false)) then SOME d else NONE
        | Funs fs =>
            (case List.filter (fn f => keep (#name f)) fs of
               [] => NONE
             | fs' => SOME (Funs fs'))
        | Do _ => SOME d
    in
      (* one rewrite, all of it or none: what is kept of a part would use
         what goes of it *)
      if Pass.spend () then List.mapPartial def p else p
    end
end
