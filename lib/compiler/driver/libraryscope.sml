(* Visibility at a library export boundary. Keep the compiler's internal
   basis available while elaborating its files, then publish this view. And
   the walk of a compile's libraries, which puts each file in the scope it is
   compiled in (BasisManifest, what each scope sees; docs/build.md), the same
   for each of the compiler's ways through them. *)
structure LibraryScope =
struct
  type basis = {env : Env.env, sigs : SigMatch.sigma StringMap.map,
                funs : Elaborate.funinfo StringMap.map}
  type exports = (string * string) list

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

  (* prior, with all that current has over before, a library with no boundary
     or what a friend sees: what the library declares (provides), and the
     values and whatever else its files bring in that are not as they were *)
  fun extended (prior : basis, before' : basis, current : basis, provides : string list) : basis =
    let
      fun declared n = List.exists (fn p => p = n) provides
      fun fresh same (old, new) =
        StringMap.filteri (fn (n, v) => declared n orelse
                                        (case StringMap.find (old, n) of SOME o' => not (same (o', v)) | NONE => true)) new
      val b = #env before'
      val c = #env current
      val added = Env.make {origins = Env.origins c, vals = fresh Env.sameBinding (Env.vals b, Env.vals c),
                            tys = fresh Env.sameTyStr (Env.tys b, Env.tys c),
                            strs = fresh Env.sameStr (Env.strs b, Env.strs c)}
      fun named (old, new) = StringMap.unionWith #2 (old, StringMap.filteri (fn (n, _) => declared n) new)
    in
      {env = Env.plus (#env prior, added), sigs = named (#sigs prior, #sigs current), funs = named (#funs prior, #funs current)}
    end

  (* what a library leaves a basis with: prior, and through a filter what it
     added to before' to make current *)
  fun addBasis (prior : basis, (before', current, provides) : basis * basis * string list, filter : exports option) : basis =
    case filter of
      SOME exports => restrict (prior, current, exports)
    | NONE => extended (prior, before', current, provides)

  (* the same of the fixity: only what is exported crosses a filter *)
  fun addFixity (prior : Fixity.env, (before', current) : Fixity.env * Fixity.env, filter : exports option) : Fixity.env =
    let
      val added = List.take (#list current, List.length (#list current) - List.length (#list before'))
    in
      Fixity.extend (prior, case filter of
                              NONE => added
                            | SOME exports => List.filter (fn (n, _) => List.exists (fn e => e = ("fixity", n)) exports) added)
    end

  (* and of what bound each name (UnitBasis.binders) *)
  fun addBinders (prior : string StringMap.map, (before', current) : string StringMap.map * string StringMap.map,
                  filter : exports option) : string StringMap.map =
    let
      fun exported key =
        case (filter, String.fields (fn c => c = #" ") key) of
          (NONE, _) => (case StringMap.find (before', key) of
                          NONE => true
                        | SOME id => StringMap.find (current, key) <> SOME id)
        | (SOME exports, [kind, name]) =>
            let val k = case kind of "s" => "structure" | "t" => "type" | "sig" => "signature" | "fun" => "functor"
                                   | "fix" => "fixity" | _ => ""
            in List.exists (fn e => e = (k, name)) exports end
        | _ => false
    in StringMap.unionWith #2 (prior, StringMap.filteri (fn (key, _) => exported key) current) end

  (* ---- the walk ---- *)

  (* What a way through the libraries works on: its state, which is what a
     file is compiled in; what a library changed of it; and the state with
     what a change adds through a filter. *)
  type ('s, 'c) site = {get : unit -> 's, set : 's -> unit, change : 's * 's * string list -> 'c,
                        add : 's * 'c * exports option -> 's}
  type ('s, 'c) done = {dir : string, raw : 's, change : 'c}
  type ('s, 'c) walk = {site : ('s, 'c) site, scopes : BasisManifest.scopes, base : 's option ref,
                        finished : ('s, 'c) done list ref}

  fun walk (site : ('s, 'c) site, scopes : BasisManifest.scopes) : ('s, 'c) walk =
    {site = site, scopes = scopes, base = ref NONE, finished = ref []}

  (* the sites of the ways through that keep no binders *)
  fun fixitySite (fixity : Fixity.env ref) : (Fixity.env, Fixity.env * Fixity.env) site =
    {get = fn () => !fixity, set = fn f => fixity := f, change = fn (b, a, _) => (b, a), add = addFixity}
  fun basisSite (env : Env.env ref) : (basis, basis * basis * string list) site =
    {get = fn () => {env = !env, sigs = !Elaborate.sigs, funs = !Elaborate.funs},
     set = fn (b : basis) => (env := #env b; Elaborate.sigs := #sigs b; Elaborate.funs := #funs b),
     change = fn x => x, add = addBasis}
  fun bothSite (env : Env.env ref, fixity : Fixity.env ref)
      : (basis * Fixity.env, (basis * basis * string list) * (Fixity.env * Fixity.env)) site =
    let
      val {get = getB, set = setB, ...} = basisSite env
      val {get = getF, set = setF, ...} = fixitySite fixity
    in
      {get = fn () => (getB (), getF ()), set = fn (b, f) => (setB b; setF f),
       change = fn ((b, f), (b', f'), provides) => ((b, b', provides), (f, f')),
       add = fn ((b, f), (cb, cf), filter) => (addBasis (b, cb, filter), addFixity (f, cf, filter))}
    end

  (* the state to set for a scope: the Basis Library, and what it imports in
     the order they were compiled *)
  fun assemble ({site = {add, set, get, ...}, base, finished, ...} : ('s, 'c) walk, imports : BasisManifest.import list) : unit =
    let
      fun step ({dir, change, ...} : ('s, 'c) done, state) =
        case List.find (fn {dir = d, ...} => d = dir) imports of
          NONE => state
        | SOME {names, ...} => add (state, change, names)
    in set (List.foldr step (case !base of SOME b => b | NONE => get ()) (!finished)) end

  (* One library: its files, compile (), in its scope, and what is left is
     what the libraries with no header after it see, which is what its
     boundary lets out. A library with no header and no boundary leaves all
     it declared, and where nothing is scoped that is all there is to it. *)
  fun group (w as {site = {get, set, change, add}, scopes, base, finished} : ('s, 'c) walk,
             entries : BasisManifest.entry list, compile : unit -> 'a) : 'a =
    let
      val dir = #dir (hd entries)
    in
      if dir = #basis scopes then
        let val result = compile () in base := SOME (get ()); result end
      else
        let
          val () = if isSome (!base) then () else base := SOME (get ())
          val chain = get ()
          val filter = BasisManifest.scopeOf entries
          val () = Option.app (fn imports => assemble (w, imports)) (BasisManifest.importsOf (scopes, dir))
          val start = get ()
          val result = compile ()
          val raw = get ()
        in
          if not (#scoped scopes orelse isSome filter) then ()
          else
            let val c = change (start, raw, List.concat (List.map #provides entries))
            in
              finished := {dir = dir, raw = raw, change = c} :: !finished;
              if isSome filter then set (add (chain, c, filter)) else ()
            end;
          result
        end
    end

  (* The program's scope, before its first file. *)
  fun program (w as {scopes, ...} : ('s, 'c) walk) : unit =
    if #scoped scopes then assemble (w, #program scopes) else ()

  (* A library's final files, after the program: in its private context,
     where it has a boundary or the program does not see it, and else in what
     the program left, as it always has been. *)
  fun final ({site = {get, set, ...}, scopes, finished, ...} : ('s, 'c) walk,
             entries : BasisManifest.entry list, compile : unit -> 'a) : 'a =
    let
      val dir = #dir (hd entries)
      val apart = isSome (BasisManifest.scopeOf entries)
                  orelse not (List.exists (fn {dir = d, ...} => d = dir) (#program scopes))
    in
      case (apart, List.find (fn {dir = d, ...} => d = dir) (!finished)) of
        (true, SOME {raw, ...}) =>
          let
            val prior = get ()
            val () = set raw
            val result = compile ()
          in set prior; result end
      | _ => compile ()
    end
end
