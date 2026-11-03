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

  (* What of current crosses a boundary: through a filter, what it exports;
     with none, a library with no boundary or what a friend sees, all that
     current has over before', what the library declares (provides) and the
     values and whatever else its files bring in that are not as they were *)
  fun crossing (before' : basis, current : basis, provides : string list, filter : exports option) : basis =
    case filter of
      SOME exports =>
        let
          fun visible key = List.exists (fn exported => exported = key) exports
          val Env.Env {tys, strs, ...} = #env current
        in
          {env = Env.make {origins = Env.origins (#env current), vals = StringMap.empty,
                           tys = StringMap.filteri (fn (n, _) => visible ("type", n)) tys,
                           strs = StringMap.filteri (fn (n, _) => visible ("structure", n)) strs},
           sigs = StringMap.filteri (fn (n, _) => visible ("signature", n)) (#sigs current),
           funs = StringMap.filteri (fn (n, _) => visible ("functor", n)) (#funs current)}
        end
    | NONE =>
        let
          fun declared n = List.exists (fn p => p = n) provides
          fun fresh same (old, new) =
            StringMap.filteri (fn (n, v) => declared n orelse
                                            (case StringMap.find (old, n) of SOME o' => not (same (o', v)) | NONE => true)) new
          val b = #env before'
          val c = #env current
        in
          {env = Env.make {origins = Env.origins c, vals = fresh Env.sameBinding (Env.vals b, Env.vals c),
                           tys = fresh Env.sameTyStr (Env.tys b, Env.tys c),
                           strs = fresh Env.sameStr (Env.strs b, Env.strs c)},
           sigs = StringMap.filteri (fn (n, _) => declared n) (#sigs current),
           funs = StringMap.filteri (fn (n, _) => declared n) (#funs current)}
        end

  (* A map with the renames of a kind made, all at once, so that two names
     may change places (D9; docs/build.md, Clashes); key gives a name's key *)
  fun renameKeys (renames : BasisManifest.rename list, kind : string, key : string -> string) (m : 'a StringMap.map) =
    let
      val mine = List.filter (fn {kind = k, ...} => k = kind) renames
      val taken = List.mapPartial (fn {from, to, ...} => Option.map (fn v => (key to, v)) (StringMap.find (m, key from))) mine
      val m = List.foldl (fn ({from, ...}, m) => StringMap.remove (m, key from)) m mine
    in List.foldl (fn ((k, v), m) => StringMap.insert (m, k, v)) m taken end
  (* a rename of a binding the import does not have of that kind: a
     library with no header says its names, not their kinds *)
  exception NotRenamed of BasisManifest.rename
  fun renameBasis (renames : BasisManifest.rename list, b as {env, sigs, funs} : basis) : basis =
    if List.null renames then b
    else
      let
        fun has ({kind, from, ...} : BasisManifest.rename) =
          case kind of
            "structure" => StringMap.member (Env.strs env, from)
          | "type" => StringMap.member (Env.tys env, from)
          | "signature" => StringMap.member (sigs, from)
          | _ => StringMap.member (funs, from)
        (* what only parses has nothing to rename *)
        val elaborated = not (StringMap.isEmpty (Env.strs env) andalso StringMap.isEmpty (Env.tys env)
                              andalso StringMap.isEmpty sigs andalso StringMap.isEmpty funs)
        val () = if elaborated then List.app (fn r => if has r then () else raise NotRenamed r) renames else ()
        fun same n = n
        val origins = renameKeys (renames, "structure", fn n => "s " ^ n)
                        (renameKeys (renames, "type", fn n => "t " ^ n) (Env.origins env))
      in
        {env = Env.make {origins = origins, vals = Env.vals env,
                         tys = renameKeys (renames, "type", same) (Env.tys env),
                         strs = renameKeys (renames, "structure", same) (Env.strs env)},
         sigs = renameKeys (renames, "signature", same) sigs,
         funs = renameKeys (renames, "functor", same) funs}
      end

  (* what a library leaves a basis with: prior, and through a filter what it
     added to before' to make current, renamed as the import says *)
  fun addBasis (prior : basis, (before', current, provides) : basis * basis * string list, filter : exports option,
                renames : BasisManifest.rename list) : basis =
    let val c = renameBasis (renames, crossing (before', current, provides, filter))
    in
      {env = Env.plus (#env prior, #env c), sigs = StringMap.unionWith #2 (#sigs prior, #sigs c),
       funs = StringMap.unionWith #2 (#funs prior, #funs c)}
    end

  (* the same of the fixity: only what is exported crosses a filter *)
  fun addFixity (prior : Fixity.env, (before', current) : Fixity.env * Fixity.env, filter : exports option) : Fixity.env =
    let
      val added = List.take (#list current, List.length (#list current) - List.length (#list before'))
    in
      Fixity.extend (prior, case filter of
                              NONE => added
                            | SOME exports => List.filter (fn (n, _) => List.exists (fn e => e = ("fixity", n)) exports) added)
    end

  (* and of what bound each name (UnitBasis.binders), whose key is its kind's
     and its name *)
  fun addBinders (prior : string StringMap.map, (before', current) : string StringMap.map * string StringMap.map,
                  filter : exports option, renames : BasisManifest.rename list) : string StringMap.map =
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
      fun renamed m =
        List.foldl (fn ((kind, prefix), m) => renameKeys (renames, kind, fn n => prefix ^ n) m) m
                   [("structure", "s "), ("type", "t "), ("signature", "sig "), ("functor", "fun ")]
    in StringMap.unionWith #2 (prior, renamed (StringMap.filteri (fn (key, _) => exported key) current)) end

  (* ---- the walk ---- *)

  (* What a file is compiled in, which a boundary changes: the environment and
     the signatures and functors, the fixity, and what bound each name. What
     keeps no units has binders that nobody reads, and what only parses has an
     environment that does not change. *)
  type state = {basis : basis, fixity : Fixity.env, binders : string StringMap.map}
  type change = state * state * string list
  type finished = {dir : string, raw : state, change : change}
  (* view: what the seals of the program's view of the Basis Library bound,
     which only the program sees (D12) *)
  type walk = {env : Env.env ref, fixity : Fixity.env ref, binders : string StringMap.map ref, scopes : BasisManifest.scopes,
               base : state option ref, finished : finished list ref, view : change option ref}

  fun walk (env : Env.env ref, fixity : Fixity.env ref, binders : string StringMap.map ref, scopes : BasisManifest.scopes) : walk =
    {env = env, fixity = fixity, binders = binders, scopes = scopes, base = ref NONE, finished = ref [], view = ref NONE}

  fun get ({env, fixity, binders, ...} : walk) : state =
    {basis = {env = !env, sigs = !Elaborate.sigs, funs = !Elaborate.funs}, fixity = !fixity, binders = !binders}
  fun set ({env, fixity, binders, ...} : walk, {basis, fixity = f, binders = b} : state) : unit =
    (env := #env basis; Elaborate.sigs := #sigs basis; Elaborate.funs := #funs basis; fixity := f; binders := b)

  (* onto, with what a library changed through a filter, renamed as its
     import says *)
  fun add (onto : state, (before', raw, provides) : change, filter : exports option, renames : BasisManifest.rename list) : state =
    {basis = addBasis (#basis onto, (#basis before', #basis raw, provides), filter, renames),
     fixity = addFixity (#fixity onto, (#fixity before', #fixity raw), filter),
     binders = addBinders (#binders onto, (#binders before', #binders raw), filter, renames)}

  (* the state to set for a scope: the Basis Library, and what it imports in
     the order they were compiled *)
  fun assemble (w as {base, finished, ...} : walk, imports : BasisManifest.import list) : unit =
    let
      fun step ({dir, change, ...} : finished, state) =
        case List.find (fn {dir = d, ...} => d = dir) imports of
          NONE => state
        | SOME {names, renames, ...} =>
            add (state, change, names, renames)
            handle NotRenamed {kind, from, ...} =>
              raise BasisManifest.Usage ("the import of the library " ^ dir ^ " renames " ^ kind ^ " " ^ from
                                         ^ ", which it does not declare as a " ^ kind ^ " (docs/build.md, Clashes)")
    in set (w, List.foldr step (case !base of SOME b => b | NONE => get w) (!finished)) end

  (* One library: its files, compile (), in its scope, and what is left is
     what the libraries with no header after it see, which is what its
     boundary lets out. A library with no header and no boundary leaves all
     it declared, and where nothing is scoped that is all there is to it.
     This is the one place a library is loaded and its boundary applied. *)
  fun group (w as {scopes, base, finished, view, ...} : walk, entries : BasisManifest.entry list, compile : unit -> 'a) : 'a =
    let
      val dir = #dir (hd entries)
    in
      if dir = #basis scopes andalso isSome (#view (hd entries)) andalso isSome (!base) then
        (* The seals of the program's view, after the libraries (D12): in the
           Basis Library alone, so that what a library declared is not sealed
           again, and given to the program's scope, which a library's is not *)
        let
          val chain = get w
          val () = set (w, valOf (!base))
          val start = get w
          val result = compile ()
          val c = (start, get w, List.concat (List.map #provides entries))
        in view := SOME c; set (w, add (chain, c, NONE, [])); result end
      else if dir = #basis scopes then
        let val result = compile () in base := SOME (get w); result end
      else
        let
          val () = if isSome (!base) then () else base := SOME (get w)
          val chain = get w
          val filter = BasisManifest.scopeOf entries
          val () = Option.app (fn imports => assemble (w, imports)) (BasisManifest.importsOf (scopes, dir))
          val start = get w
          val result = compile ()
          val raw = get w
        in
          if not (#scoped scopes orelse isSome filter) then ()
          else
            let val c = (start, raw, List.concat (List.map #provides entries))
            in
              finished := {dir = dir, raw = raw, change = c} :: !finished;
              if isSome filter then set (w, add (chain, c, filter, [])) else ()
            end;
          result
        end
    end

  (* The libraries before a program, in order, each given to f in its scope *)
  fun libraries (w : walk, groups : BasisManifest.entry list list, f : BasisManifest.entry list * 'a -> 'a, start : 'a) : 'a =
    List.foldl (fn (entries, acc) => group (w, entries, fn () => f (entries, acc))) start groups

  (* The program's scope, before its first file, with its view of the Basis
     Library last *)
  fun program (w as {scopes, view, ...} : walk) : unit =
    if #scoped scopes
    then (assemble (w, #program scopes); Option.app (fn c => set (w, add (get w, c, NONE, []))) (!view))
    else ()

  (* A library's final files, after the program: in its private context,
     where it has a boundary or the program does not see it, and else in what
     the program left, as it always has been. *)
  fun final (w as {scopes, finished, ...} : walk, entries : BasisManifest.entry list, compile : unit -> 'a) : 'a =
    let
      val dir = #dir (hd entries)
      val apart = isSome (BasisManifest.scopeOf entries)
                  orelse not (List.exists (fn {dir = d, ...} => d = dir) (#program scopes))
    in
      case (apart, List.find (fn {dir = d, ...} => d = dir) (!finished)) of
        (true, SOME {raw, ...}) =>
          let
            val prior = get w
            val () = set (w, raw)
            val result = compile ()
          in set (w, prior); result end
      | _ => compile ()
    end
  fun finals (w : walk, groups : BasisManifest.entry list list, f : BasisManifest.entry list * 'a -> 'a, start : 'a) : 'a =
    List.foldl (fn (entries, acc) => final (w, entries, fn () => f (entries, acc))) start groups
end
