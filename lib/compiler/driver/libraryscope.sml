(* Visibility at a library export boundary. Keep the compiler's internal
   basis available while elaborating its files, then publish this view. *)
structure LibraryScope =
struct
  type basis = {env : Env.env, sigs : SigMatch.sigma StringMap.map,
                funs : Elaborate.funinfo StringMap.map}

  fun restrict (prior : basis, current : basis, exports : (string * string) list) : basis =
    let
      fun visible key = List.exists (fn exported => exported = key) exports
      val Env.Env {tys, strs, ...} = #env current
      val exported = Env.make
        {origins=Env.origins (#env current),vals = StringMap.empty,
         tys = StringMap.filteri (fn (n, _) => visible ("type", n)) tys,
         strs = StringMap.filteri (fn (n, _) => visible ("structure", n)) strs}
    in
      {env = Env.plus (#env prior, exported),
       sigs = StringMap.unionWith #2 (#sigs prior,
         StringMap.filteri (fn (n, _) => visible ("signature", n)) (#sigs current)),
       funs = StringMap.unionWith #2 (#funs prior,
         StringMap.filteri (fn (n, _) => visible ("functor", n)) (#funs current))}
    end
end
