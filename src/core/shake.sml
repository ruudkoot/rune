(* Tree shaking (docs/ir.md; docs/plans/middle-end.md, M7): the globals of
   Mid that nothing the program does reaches go, before anything else is
   done to them -- the Basis Library is compiled whole into every program,
   and most of it is never used (89% of tak's code was never called).

   What is done for its effect is kept (Do), and so is a global whose value
   is made with one: a call, a primitive that is not removable, a raise, a
   global set. From those, every global they use is reached, and every one
   the definitions of those use. A function of a group that nothing
   reaches goes alone. *)
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
        | Decon (_, a) => (atom (a, acc), eff)
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

  fun program (p : program) : program =
    let
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
