(* The cache of compiled units (docs/units.md, *The cache*; the incremental
   roadmap's D14 and M6): what a compile in units made of each unit -- its
   basis (UnitBasis) and its code (UnitFile) -- kept in a directory by the
   configuration that made it, by what the unit is, and by what it used of
   the units before it, so that a compile after it takes the unit from
   there rather than compiling it again.

   The configuration is the compiler's identity (Config.identity, a hash of
   its sources), the versions of the files, the instruction set, and every
   option that changes what it makes. A unit is keyed by its logical name
   (Workspace), the hash of its source, whether it may use _prim, and the settings that hold for
   the input files and not the libraries (--default-type, --or-patterns),
   where it is an input file's; under the key are its
   entries, one for each set of *usages* it was compiled with: every name
   its compile looked up (Usage), and the unit that bound the name then
   (UnitBasis.binders; "" the initial basis). An entry serves a compile
   where every one of its usages holds: each name is bound by the same unit
   -- whose identity is its basis, so that the name means the same -- and
   so the unit's compile would be the same.

   An entry is one file, written whole under another name and renamed, so
   that a compile at the same time never sees half of one; it carries the
   hash of what it holds, and one that does not hold what its hash says, or
   that cannot be read, is not there. Nothing in a key is a time. *)
structure UnitCache =
struct
  structure P = Pickle
  structure S = UnitStore

  val magic = "RCE"
  (* 10: an entry's mark, the lint it was checked by, and the schemes of
     the globals of other units its code names (the linting roadmap's M9);
     11: its warnings as spans and messages, not as lines *)
  val version = 11

  (* what a unit's entry holds: its usages, the warnings its compile gave,
     which a compile that takes it from the cache gives again as its own
     (giveWarnings), the name its source had in the compile, which its code's files name it by, the other
     files its code names with the unit each is the source of
     (UnitBasis.sourcesOf), its basis and the identity the basis gives,
     which loading need not work out from the bytes again (functors-units,
     F2), its code's file, and its Mid (UnitMid), for a whole program made
     of the units'; and what checked it: its mark, the level of the lint its
     compile ran (level), and the schemes of the globals of other units its
     code names, as its compile had them (UnitBasis.importedSchemes), which a
     compile that takes it holds the units it names now to *)
  type entry = {usages : (string * string) list, warnings : (Source.span * string) list, file : string,
                others : (string * string) list, pickle : string, identity : string, code : string, mid : string,
                level : int, schemes : (string * (int * string) list) list}

  (* The mark of what a compile checks of a unit: the level of its lint
     (Pass.lintLevel; the linting roadmap's D12 and D13), off ~1 to 2 --
     level 3's round trips of Mid's text are not asked of an entry -- and
     no more than 0 where RUNE_REGVERIFY=0 leaves the register code
     unchecked at the levels that check it. An entry serves a compile whose
     level is at most its own: one made at a lower level is, for a compile
     at a higher, an entry not there, and the unit is compiled again at
     that level and the entry stored marked, where the cache can be
     written. The frozen libraries are made at level 2 (make basis-cache),
     so that a compile at any level takes their entries. *)
  fun level () : int =
    let val l = Int.min (Pass.lintLevel (), 2)
    in if l >= 1 andalso not (isSome (RegVerify.level ())) then 0 else l end

  (* an entry found, or why there is none *)
  datatype found = Found of entry | Missed of string

  (* an entry's warnings, its compile having named its source was, given
     again as a compile of its source, now named name, gives them, in every
     form it may be asked for (Error.show) *)
  fun giveWarnings (warnings : (Source.span * string) list, was : string, name : string) : unit =
    (List.app (fn ({file, start, stop}, message) =>
                 Error.warn ({file = if file = was then name else file, start = start, stop = stop}, message)) warnings;
     Error.flushWarnings ())

  fun warningBytes (({file, start, stop}, message) : Source.span * string) : string =
    let val w = P.writer ()
    in P.string (w, file); P.int (w, start); P.int (w, stop); P.string (w, message); P.contents w end
  fun warningOf (s : string) : Source.span * string =
    let
      val r = P.reader s
      val file = P.rstring r
      val start = P.rint r
      val stop = P.rint r
    in ({file = file, start = start, stop = stop}, P.rstring r) end

  (* --verify-cache, or RUNE_VERIFY_CACHE set and not empty (for a compile
     that takes no flags, the REPL's use): each unit found is compiled all
     the same, and must be what its entry holds *)
  fun verifying () : bool =
    !CompilerSettings.verifyCache orelse (case OS.Process.getEnv "RUNE_VERIFY_CACHE" of SOME s => s <> "" | NONE => false)

  (* whether an entry found for the unit now named name holds the basis and
     the code that compiling it gave: the code by the bytes, where none of
     its files moved, and else with its files named where they are now,
     both written again from what they read as, which is not always the
     bytes read *)
  (* RUNE_VERIFY_DUMP=DIR: an entry that does not verify, and what compiling
     it gave, written to DIR, NAME.cached.{pickle,code,mid} and
     NAME.fresh.{pickle,code,mid}, to compare *)
  val dumped = ref 0
  val () = CompilerState.cellRoot ("UnitCache.dumped", dumped)
  fun dump (name, (pickle, code, mid), (pickle', code', mid')) =
    case OS.Process.getEnv "RUNE_VERIFY_DUMP" of
      NONE => ()
    | SOME dir =>
        let
          val () = dumped := !dumped + 1
          val base = OS.Path.joinDirFile {dir = dir, file = Int.toString (!dumped) ^ "-"
                                                            ^ String.translate (fn #"/" => "_" | c => String.str c) name}
          fun put (suffix, text) =
            let val out = BinIO.openOut (base ^ suffix)
            in BinIO.output (out, Byte.stringToBytes text); BinIO.closeOut out end
        in
          ((OS.FileSys.mkDir dir handle OS.SysErr _ => ());
           put (".cached.pickle", pickle); put (".cached.code", code); put (".cached.mid", mid);
           put (".fresh.pickle", pickle'); put (".fresh.code", code'); put (".fresh.mid", mid'))
          handle IO.Io _ => ()
        end

  fun verifies ({pickle, code, file, others, mid, ...} : entry, name : string, pickle' : string, bytes : string,
                mid' : string) : bool =
    let
      val same =
        pickle = pickle'
        andalso (mid = mid'
                 orelse ((UnitMid.relocate (mid, UnitBasis.movedTo (file, name, others)) = mid') handle UnitMid.Bad _ => false))
        andalso ((let
                    val (fp, u) = UnitFile.read code
                    fun again s = let val (fp, u) = UnitFile.read s in String.concat (UnitFile.chunks (fp, u)) end
                  in
                    if not (UnitBasis.moves (u, file, name, others)) then code = bytes
                    else String.concat (UnitFile.chunks (fp, UnitBasis.relocate (u, file, name, others))) = again bytes
                  end)
                 handle UnitFile.Bad _ => false)
    in
      if same then () else dump (name, (pickle, code, mid), (pickle', bytes, mid'));
      same
    end

  (* What the configuration of this compile is made of, by name. The
     probe of the hash (Pickle.probe) says which values the compiler's hash
     gives, which depend on the width of its host's Word: compilers whose
     hash differs never take each other's entries *)
  fun settings () : (string * string) list =
    [("identity", Config.identity), ("cache", Int.toString version), ("basis", Int.toString UnitBasis.version),
     ("unitfile", Int.toString UnitFile.version), ("isa", Int.toString (Pipeline.fingerprint ())),
     ("level", Int.toString (!Pass.level)), ("passes", case !Pass.only of NONE => "-" | SOME ps => String.concatWith "," ps),
     ("intbits", Int.toString (!Target.intBits)), ("flex", Elaborate.flexModeName (!Elaborate.flexRecords)),
     ("overloading", Elaborate.overloadModeName (!Elaborate.overloading)),
     ("freetyvars", Elaborate.freeModeName (!Elaborate.freeTyvars)),
     ("fuel", case !Pass.fuel of NONE => "-" | SOME n => Int.toString n), ("hash", P.probe ()),
     (* what a limit gives is what the compile gives: --functor-budget
        changes the code, --type-work and --match-work whether there is any *)
     ("functor-budget", Int.toString (!Expand.budget)), ("type-work", Int.toString (!Types.workLimit)),
     ("match-work", Int.toString (!Exhaust.workLimit))]
    (* the functors inlined across units: what a unit's basis keeps *)
    @ (if not (StringMap.isEmpty (!Elaborate.inlineFunctors))
       then [("inline", String.concatWith "," (StringMap.listKeys (!Elaborate.inlineFunctors)))] else [])
    (* and the functions (functors-units M10) *)
    @ (if not (StringMap.isEmpty (!Elaborate.inlineValues))
       then [("inline-val", String.concatWith "," (StringMap.listKeys (!Elaborate.inlineValues)))] else [])

  (* The hash of the configuration of this compile *)
  fun configuration () : string = S.configuration (UnitBasis.hashAt, settings ())

  (* The probe of another configuration of dir that is this one but for the
     hash, where dir has none of this one's: entries made by a compiler
     whose hash differs (--explain-rebuild) *)
  fun otherHash (dir : string, config : string) : string option = S.otherBut "hash" (settings (), dir, config)

  (* The directory of the cache: --cache-dir, else RUNE_CACHE, else .rune in
     the directory of the first input; NONE with --no-cache *)
  fun directory () : string option =
    if !CompilerSettings.noCache then NONE
    else
      case !CompilerSettings.cacheDir of
        SOME d => SOME d
      | NONE =>
          case OS.Process.getEnv "RUNE_CACHE" of
            SOME d => if d = "" then NONE else SOME d
          | NONE =>
              case !CompilerSettings.inputs of
                first :: _ => SOME (OS.Path.joinDirFile {dir = OS.Path.dir first, file = ".rune"})
              | [] => SOME ".rune"

  (* The frozen Basis Library (the incremental roadmap's D8): a cache that
     every unit of the library was compiled into once, `cache` beside the
     library's files (make basis-cache; installed with them), which a
     compile reads after its own cache and never writes; NONE with
     --no-cache or where there is none *)
  fun frozen () : string option =
    if !CompilerSettings.noCache then NONE
    else
      case !CompilerSettings.libDir of
        NONE => NONE
      | SOME lib =>
          let val d = OS.Path.joinDirFile {dir = lib, file = "cache"}
          in if (OS.FileSys.isDir d handle OS.SysErr _ => false) then SOME d else NONE end

  (* every hash of the cache's files, counted under "cache" *)
  fun hash (site : string, text : string) : string = UnitBasis.during "cache" (fn () => UnitBasis.hashAt (site, text))

  (* the key of a unit *)
  (* settings: what the unit was compiled under that the configuration does
     not say, because it holds for the input files and not the libraries
     (--default-type, --or-patterns); "" for none, which keeps the key it
     had before there were such settings *)
  fun key {name : string, text : string, allow : bool, settings : string} : string =
    UnitBasis.during "cache" (fn () =>
      S.key (UnitBasis.hashAt, [name, UnitBasis.hashAt ("source", text), if allow then "1" else "0"]
                               @ (if settings = "" then [] else [settings])))

  fun readFile (p : string) : string = S.readFile p

  (* ---- an entry in the store (UnitStore): its head, the usages, which
     name it among its key's; its sections, the rest ---- *)

  type sections = {warnings : (Source.span * string) list, file : string, others : (string * string) list, pickle : string,
                   identity : string, code : string, mid : string, level : int, schemes : (string * (int * string) list) list}

  fun whole ({head = usages, sections = {warnings, file, others, pickle, identity, code, mid, level, schemes}}
             : ((string * string) list, sections) S.entry) : entry =
    {usages = usages, warnings = warnings, file = file, others = others, pickle = pickle, identity = identity, code = code,
     mid = mid, level = level, schemes = schemes}

  fun usages (w : P.writer, us : (string * string) list) =
    P.list (fn (w, (k, i)) => (P.string (w, k); P.string (w, i))) (w, us)

  val format : ((string * string) list, sections) S.format =
    {magic = magic, version = version, hash = hash,
     writeHead = usages, readHead = P.rlist (fn r => let val k = P.rstring r in (k, P.rstring r) end),
     writeSections = fn (body, {warnings, file, others, pickle, identity, code, mid, level = lvl, schemes}) =>
       (P.list P.string (body, List.map warningBytes warnings); P.string (body, file);
        usages (body, others); P.string (body, pickle); P.string (body, identity); P.string (body, code);
        P.string (body, mid); P.int (body, lvl);
        P.list (fn (w, (u, ns)) => (P.string (w, u); P.list (fn (w, (n, t)) => (P.nat (w, n); P.string (w, t))) (w, ns)))
               (body, schemes)),
     readSections = fn r =>
       let
         val warnings = List.map warningOf (P.rlist P.rstring r)
         val file = P.rstring r
         val others = P.rlist (fn r => let val f = P.rstring r in (f, P.rstring r) end) r
         val pickle = P.rstring r
         val identity = P.rstring r
         val code = P.rstring r
         val mid = P.rstring r
         val lvl = P.rint r
         val schemes = P.rlist (fn r => let val u = P.rstring r
                                        in (u, P.rlist (fn r => let val n = P.rnat r in (n, P.rstring r) end) r) end) r
       in
         {warnings = warnings, file = file, others = others, pickle = pickle, identity = identity, code = code, mid = mid,
          level = lvl, schemes = schemes}
       end}

  (* an entry's file read: the entry, or why it is none *)
  fun read (p : string) : found =
    case S.read format p of
      S.Read e => Found (whole e)
    | S.Unread why => Missed why

  (* whether find has given an entry that holds across a unit that changed *)
  val across = ref false
  val () = CompilerState.cellRoot ("UnitCache.across", across)

  (* Whether an entry stands for this compile: one checked at a lower level
     of the lint than the compile's does not (level); one whose usages hold
     by their binders stands before one whose hold only by fingerprint, which
     needs units remapped to load. This format keeps the level and the basis
     its exactness reads among the sections (D24: the build-system roadmap's
     M7 moves what a lookup judges into the head) *)
  fun holds ({head = usages, sections = {level = l, pickle, ...}} : ((string * string) list, sections) S.entry) : S.verdict =
    if l < level () then S.Refused ("its entry was checked at a lower level of the lint (" ^ Int.toString l ^ ")")
    else
      case UnitBasis.broken usages of
        NONE => if UnitBasis.exactEntry (usages, pickle) then S.Stands else S.StandsBehind
      | SOME u => S.Refused ("its entries used " ^ u ^ ", which is another now")

  (* The entries of a key whose usages hold: the first found, or why there
     is none. One that holds by fingerprint alone, never for a program that
     keeps its units' identities (UnitBasis.remapAllowed): the entry names
     the units it was compiled against, which are others now
     (docs/plans/build-cache-issues.md, issue 15) *)
  fun find (dir : string, config : string, k : string) : found =
    case S.find (format, holds) (dir, config, k) of
      S.Found e => Found (whole e)
    | S.FoundBehind e =>
        if !UnitBasis.remapAllowed then (across := true; Found (whole e))
        else Missed "its entries hold across a unit that changed, which a program that keeps its units' identities takes none across"
    | S.Missed why => Missed why

  (* whether a key has an entry, whatever its usages: a unit likely found,
     which a parallel build leaves to the parent (Parallel) *)
  val hasEntry = S.hasEntry

  (* ---- what the cache keeps of a unit by its identity ---- *)

  (* The paths to a unit's names (UnitBasis.pathsOf), kept by its identity
     beside the entries, in units/ of the configuration's directory: what an
     entry compiled against the unit needs to be loaded against another
     unit of its name (UnitBasis.remapping) *)
  val paths : (int * int * string) list S.side =
    {magic = "RCP", version = version, hash = fn (_, text) => hash ("paths", text),
     write = P.list (fn (w, (k, n, path)) => (P.nat (w, k); P.nat (w, n); P.string (w, path))),
     read = P.rlist (fn r => let val k = P.rnat r val n = P.rnat r in (k, n, P.rstring r) end)}

  (* in the cache, else in the frozen Basis, else none *)
  fun pathsIn (dirs : string list, config : string) (identity : string) : (int * int * string) list option =
    S.sideIn paths (dirs, config) identity

  (* storePaths: a unit's paths kept by its identity, whole or not at all *)
  fun storePaths (dir : string, config : string, identity : string, ps : (int * int * string) list) : unit =
    S.storeSide paths (dir, config, identity, ps)

  (* store: the entry of a key written, whole or not at all, by the hash of
     its usages, beside the key's others; a cache that cannot be written is
     a cache that is not there *)
  fun store (dir : string, config : string, k : string,
             {usages = us, warnings, file, others, pickle, identity, code, mid, level = lvl, schemes} : entry) : unit =
    (* code a test switch corrupted (RUNE_REGVERIFY_INJECT) is not kept *)
    if RegVerify.injecting () then () else
    UnitBasis.during "cache" (fn () =>
      S.store (format, settings ())
              (dir, config, k,
               {head = us, sections = {warnings = warnings, file = file, others = others, pickle = pickle, identity = identity,
                                       code = code, mid = mid, level = lvl, schemes = schemes}}))
end
