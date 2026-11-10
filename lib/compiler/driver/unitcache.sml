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

   An entry is one file of the store (UnitStore), written whole under
   another name and renamed, so that a compile at the same time never sees
   half of one: its head, what a lookup judges it by, and its sections,
   each with the hash of its bytes. One that does not hold what its hashes
   say, or that cannot be read, is not there. Nothing in a key is a time.

   The store is the workspace's (the build-system roadmap's D24): .rune in
   the directory of its rune.workspace, which every build, the REPL and
   the memos of a warm build of the workspace share, else beside the build
   file or the first input; RUNE_CACHE names another, and --cache-dir
   another still. It is written there, its overlay, and read after it are
   its read-only layers: the frozen libraries (frozen), which a compile
   never writes. *)
structure UnitCache =
struct
  structure P = Pickle
  structure S = UnitStore

  val magic = "RCE"
  (* 10: an entry's mark, the lint it was checked by, and the schemes of
     the globals of other units its code names (the linting roadmap's M9);
     11: its warnings as spans and messages, not as lines; 12: a head of
     its usages, its mark and the units its basis names, and four sections
     hashed apart (the build-system roadmap's M7) *)
  val version = 12

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
     form it may be asked for (Error.show): each file a warning names read,
     for its line and column, where the build did not read it (Source.fault;
     docs/units.md, A warm build) *)
  fun giveWarnings (warnings : (Source.span * string) list, was : string, name : string) : unit =
    (List.app (fn ({file, start, stop}, message) =>
                 let val file = if file = was then name else file
                 in ignore (Source.findFile file); Error.warn ({file = file, start = start, stop = stop}, message) end) warnings;
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
                 orelse ((UnitMid.relocate (mid, UnitBasis.movedTo (file, name, others)) = mid')
                         handle UnitMid.Bad _ => false | P.Bad _ => false))
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
    (* the checks of casts, which change the code where a program casts *)
    @ (if !Lower.checkCasts then [("check-casts", "1")] else [])
    (* the functors inlined across units: what a unit's basis keeps *)
    @ (if not (StringMap.isEmpty (!Elaborate.inlineFunctors))
       then [("inline", String.concatWith "," (StringMap.listKeys (!Elaborate.inlineFunctors)))] else [])
    (* and the functions (functors-units M10) *)
    @ (if not (StringMap.isEmpty (!Elaborate.inlineValues))
       then [("inline-val", String.concatWith "," (StringMap.listKeys (!Elaborate.inlineValues)))] else [])

  (* The hash of the configuration of this compile *)
  fun configuration () : string = S.configuration (UnitBasis.hashAt, settings ())

  (* The configuration split in two (the build-system roadmap's D27): what
     moves a unit's static layer, which elaboration reads -- the compiler,
     which is its front end's version, the formats, the hash, and the
     language's settings -- and the rest, which says what the back end makes:
     the instruction set, the level, the passes, the fuel, the integers'
     width, the limits and what is inlined, none of which moves a static hash
     (E24). An analysis reads a static layer, so it takes an entry of any
     configuration whose static settings are its own *)
  val staticNames = ["identity", "cache", "basis", "hash", "flex", "overloading", "freetyvars"]
  fun staticSettings () : (string * string) list =
    List.filter (fn (n, _) => List.exists (fn m => m = n) staticNames) (settings ())

  (* The configurations in dir whose static settings are these, by what
     each says it is made of (UnitStore's about), the one written to last
     first: a store a compile keeps under one configuration and an analysis
     reads under any of them *)
  fun configurationsFor (dir : string) : string list =
    let
      val mine = staticSettings ()
      fun lines t = List.mapPartial (fn l => case String.fields (fn c => c = #" ") l of
                                               n :: rest => SOME (n, String.concatWith " " rest)
                                             | [] => NONE)
                                    (String.tokens (fn c => c = #"\n") t)
      fun theirs c =
        let
          val about = S.aboutFile (dir, c)
          val ls = lines (S.readFile about)
        in
          if List.filter (fn (n, _) => List.exists (fn m => m = n) staticNames) ls = mine
          then SOME (c, OS.FileSys.modTime (S.join (dir, c))) else NONE
        end
        handle IO.Io _ => NONE | OS.SysErr _ => NONE
      val found = List.mapPartial theirs (S.listDir dir)
    in List.map #1 (S.sortBy (fn ((_, a), (_, b)) => Time.> (a, b)) found) end

  (* The probe of another configuration of dir that is this one but for the
     hash, where dir has none of this one's: entries made by a compiler
     whose hash differs (--explain-rebuild) *)
  fun otherHash (dir : string, config : string) : string option = S.otherBut "hash" (settings (), dir, config)

  (* The store in a directory: its .rune *)
  fun storeIn (home : string) : string = OS.Path.joinDirFile {dir = home, file = ".rune"}

  (* The store's overlay, which a compile writes: --cache-dir, else
     RUNE_CACHE, else .rune in the workspace's directory (storeHome, which
     the driver sets: the directory of the nearest rune.workspace above the
     build file or the first input, else of that file), so that every build
     of a workspace, whatever file it begins with, has the one; NONE with
     --no-cache *)
  fun directory () : string option =
    if !CompilerSettings.noCache then NONE
    else
      case !CompilerSettings.cacheDir of
        SOME d => SOME d
      | NONE =>
          case OS.Process.getEnv "RUNE_CACHE" of
            SOME d => if d = "" then NONE else SOME d
          | NONE =>
              case (!CompilerSettings.storeHome, !CompilerSettings.inputs) of
                (SOME home, _) => SOME (storeIn home)
              | (NONE, first :: _) => SOME (storeIn (OS.Path.dir first))
              | (NONE, []) => SOME ".rune"

  (* The frozen libraries (the incremental roadmap's D8): a store that
     every unit of the Basis Library and of the libraries the compiler needs
     was compiled into once, `cache` beside the library's files (make
     basis-cache; installed and shipped with them), which a compile reads
     after its own store and never writes; NONE with --no-cache or where
     there is none *)
  fun frozen () : string option =
    if !CompilerSettings.noCache then NONE
    else
      case !CompilerSettings.libDir of
        NONE => NONE
      | SOME lib =>
          let val d = OS.Path.joinDirFile {dir = lib, file = "cache"}
          in if (OS.FileSys.isDir d handle OS.SysErr _ => false) then SOME d else NONE end

  (* The store's read-only layers, in the order they are read, after its
     overlay: the frozen libraries *)
  fun layers () : string list = case frozen () of SOME f => [f] | NONE => []

  (* whether a directory is where a layer is, there yet or not, however a
     path spells it: lib/cache, which make basis-cache writes as a store of
     its own *)
  fun isLayer (dir : string) : bool =
    let
      fun full d = OS.Path.mkCanonical (OS.Path.mkAbsolute {path = d, relativeTo = OS.FileSys.getDir ()})
                   handle OS.SysErr _ => d | OS.Path.Path => d
    in
      case (!CompilerSettings.noCache, !CompilerSettings.libDir) of
        (false, SOME lib) => full (OS.Path.joinDirFile {dir = lib, file = "cache"}) = full dir
      | _ => false
    end

  (* every hash of the cache's files, counted under "cache" *)
  fun hash (site : string, text : string) : string = UnitBasis.during "cache" (fn () => UnitBasis.hashAt (site, text))

  (* the key of a unit *)
  (* settings: what the unit was compiled under that the configuration does
     not say, because it holds for the input files and not the libraries
     (--default-type, --or-patterns); "" for none, which keeps the key it
     had before there were such settings *)
  (* source: the hash of its text (sourceHash), which the stat memo may
     give (UnitStore.hashBy) *)
  fun sourceHash (text : string) : string = UnitBasis.during "cache" (fn () => UnitBasis.hashAt ("source", text))
  fun keyOf {name : string, source : string, allow : bool, settings : string} : string =
    UnitBasis.during "cache" (fn () =>
      S.key (UnitBasis.hashAt, [name, source, if allow then "1" else "0"]
                               @ (if settings = "" then [] else [settings])))
  fun key {name : string, text : string, allow : bool, settings : string} : string =
    keyOf {name = name, source = sourceHash text, allow = allow, settings = settings}

  fun readFile (p : string) : string = S.readFile p

  (* ---- an entry in the store (UnitStore) ---- *)

  (* Its head: what a lookup judges it by, and all the store reads of an
     entry it does not take -- its usages, which name it among its key's,
     the level of the lint that checked it, and the units its basis names
     (UnitBasis.namedBy), which say whether it needs anything remapped *)
  type head = {usages : (string * string) list, level : int, named : string list}

  (* Its sections, each hashed apart: what else its compile gave, its
     basis, its code and its Mid. Its Mid is read only where a compile
     asks for it (needMid): a build of the units' code takes none *)
  type sections = {warnings : (Source.span * string) list, file : string, others : (string * string) list, pickle : string,
                   identity : string, code : string, mid : string, schemes : (string * (int * string) list) list}

  (* whether an entry's Mid is read, and held to its hash, where it is
     taken: --whole, --verify-cache and the compiler library's units ask
     for it; a build of the units' code does not (the driver says) *)
  val needMid = ref true
  val () = CompilerState.cellRoot ("UnitCache.needMid", needMid)

  fun whole ({head = {usages, level = lvl, ...}, sections = {warnings, file, others, pickle, identity, code, mid, schemes}}
             : (head, sections) S.entry) : entry =
    {usages = usages, warnings = warnings, file = file, others = others, pickle = pickle, identity = identity, code = code,
     mid = mid, level = lvl, schemes = schemes}

  fun usages (w : P.writer, us : (string * string) list) =
    P.list (fn (w, (k, i)) => (P.string (w, k); P.string (w, i))) (w, us)
  fun rusages (r : P.reader) : (string * string) list = P.rlist (fn r => let val k = P.rstring r in (k, P.rstring r) end) r

  val format : (head, sections) S.format =
    {magic = magic, version = version, hash = hash,
     writeHead = fn (w, {usages = us, level = lvl, named}) => (usages (w, us); P.int (w, lvl); P.list P.string (w, named)),
     readHead = fn r => let val us = rusages r val lvl = P.rint r in {usages = us, level = lvl, named = P.rlist P.rstring r} end,
     sections = fn {warnings, file, others, pickle, identity, code, mid, schemes} =>
       let val w = P.writer ()
       in
         P.list P.string (w, List.map warningBytes warnings); P.string (w, file); usages (w, others); P.string (w, identity);
         P.list (fn (w, (u, ns)) => (P.string (w, u); P.list (fn (w, (n, t)) => (P.nat (w, n); P.string (w, t))) (w, ns)))
                (w, schemes);
         [P.contents w, pickle, code, mid]
       end,
     ofSections = fn section =>
       let
         val r = P.reader (section 0)
         val warnings = List.map warningOf (P.rlist P.rstring r)
         val file = P.rstring r
         val others = rusages r
         val identity = P.rstring r
         val schemes = P.rlist (fn r => let val u = P.rstring r
                                        in (u, P.rlist (fn r => let val n = P.rnat r in (n, P.rstring r) end) r) end) r
         val () = if P.atEnd r then () else raise P.Bad "more than its section"
       in
         {warnings = warnings, file = file, others = others, pickle = section 1, identity = identity, code = section 2,
          mid = if !needMid then section 3 else "", schemes = schemes}
       end}

  (* the same, of an entry whose static layer is all that is read (an
     analysis's): its code and its Mid are neither read nor held to their
     hashes *)
  val staticFormat : (head, sections) S.format =
    {magic = #magic format, version = #version format, hash = #hash format, writeHead = #writeHead format,
     readHead = #readHead format, sections = #sections format,
     ofSections = fn section =>
       let val {warnings, file, others, pickle, identity, schemes, ...} =
             #ofSections format (fn i => if i >= 2 then "" else section i) handle P.Bad _ => raise P.Bad "not a section"
       in {warnings = warnings, file = file, others = others, pickle = pickle, identity = identity, code = "", mid = "",
           schemes = schemes} end}

  (* an entry's file read: the entry, or why it is none *)
  fun read (p : string) : found =
    case S.read format p of
      S.Read (e, _) => Found (whole e)
    | S.Unread why => Missed why

  (* whether find has given an entry that holds across a unit that changed *)
  val across = ref false
  val () = CompilerState.cellRoot ("UnitCache.across", across)
  (* the hash of what the entry find gave last holds (UnitStore.read) *)
  val lastSum = ref ""
  val () = CompilerState.cellRoot ("UnitCache.lastSum", lastSum)

  (* Whether an entry stands for this compile, by its head: one checked at
     a lower level of the lint than the compile's does not (level); one
     whose usages hold by their binders, and whose basis names only units
     of the session, stands before one that holds only by fingerprint, or
     names a unit the session has not, which needs units remapped to load *)
  fun lowerLevel (l : int) : S.verdict option =
    if l < level () then SOME (S.Refused ("its entry was checked at a lower level of the lint (" ^ Int.toString l ^ ")"))
    else NONE
  fun exactHead (usages : (string * string) list, named : string list) : bool =
    UnitBasis.exact usages andalso List.all (isSome o UnitBasis.loadedAs) named
  fun holds ({usages, level = l, named} : head) : S.verdict =
    case lowerLevel l of SOME refused => refused | NONE =>
      case UnitBasis.broken usages of
        NONE => if exactHead (usages, named) then S.Stands else S.StandsBehind
      | SOME u => S.Refused ("its entries used " ^ u ^ ", which is another now")

  (* The entries of a key whose usages hold: the first found, or why there
     is none. One that holds by fingerprint alone, never for a program that
     keeps its units' identities (UnitBasis.remapAllowed): the entry names
     the units it was compiled against, which are others now
     (docs/plans/build-cache-issues.md, issue 15). find, in a layer or a
     store that is only read; take, in the store's overlay, whose entries'
     times are kept (UnitStore.touch) *)
  fun findAt (overlay : bool) (dir : string, config : string, k : string) : found =
    case S.findAt (format, holds) {overlay = overlay} (dir, config, k) of
      S.Found (e, h) => (lastSum := h; Found (whole e))
    | S.FoundBehind (e, h) =>
        if !UnitBasis.remapAllowed then (across := true; lastSum := h; Found (whole e))
        else Missed "its entries hold across a unit that changed, which a program that keeps its units' identities takes none across"
    | S.Missed why => Missed why
  val find = findAt false
  val take = findAt true

  (* The first entry of a key that serves by its binders alone: its usages
     hold by them and its basis names only units of the session, so that
     taking it reads nothing of any unit (the warm path's light hit,
     UnitBasis.lightLoad); none where every one would need a fingerprint *)
  fun exactHolds ({usages, level = l, named} : head) : S.verdict =
    case lowerLevel l of SOME refused => refused | NONE =>
    if exactHead (usages, named) then S.Stands
    else S.Refused "no entry that holds by its binders alone"
  fun findExactAt (overlay : bool) (dir : string, config : string, k : string) : (entry * string) option =
    case S.findAt (format, exactHolds) {overlay = overlay} (dir, config, k) of
      S.Found (e, h) => SOME (whole e, h)
    | _ => NONE
  val findExact = findExactAt false
  val takeExact = findExactAt true

  (* An entry for an analysis, which reads its static layer alone: one whose
     usages hold by their binders and whose basis names only units of the
     session, of whatever lint level, in the first of configs that has one;
     its time kept, as a compile's take keeps it (the editor's shared layer,
     docs/language-server.md) *)
  fun forAnalysis ({usages, named, ...} : head) : S.verdict =
    if exactHead (usages, named) then S.Stands else S.Refused "not by its binders"
  (* an entry's file read as far as its basis, its head and those two
     sections held to their hashes: an analysis reads neither its code nor
     its Mid, most of its bytes *)
  fun readFirst (p : string, stands : head -> bool) : entry option =
    (let
       val opened as {ins, head = bytes, headSum, rest} = S.openEntry staticFormat p
       val h = S.headOf staticFormat bytes handle e => (BinIO.closeIn ins; raise e)
     in
       if not (stands h) orelse hash ("read", bytes) <> headSum then (BinIO.closeIn ins; NONE)
       else
         let
           val buffer = ref rest
           fun parse () =
             let val r = P.reader (!buffer)
                 val n = P.rnat r
                 val sums = List.tabulate (n, fn _ => P.rstring r)
             in if n < 2 then raise S.Damaged else SOME (sums, List.tabulate (2, fn _ => P.rstring r)) end
             handle P.Bad "cut short" => NONE
           fun more () =
             let val got = Byte.bytesToString (BinIO.inputN (ins, Int.max (65536, String.size (!buffer))))
             in if got = "" then raise P.Bad "cut short" else buffer := !buffer ^ got end
           fun loop () = case parse () of SOME found => found | NONE => (more (); loop ())
           val (sums, parts) = (loop () before BinIO.closeIn ins) handle e => (BinIO.closeIn ins; raise e)
           fun section i =
             if i >= 2 then ""
             else let val b = List.nth (parts, i)
                  in if hash ("read", b) = List.nth (sums, i) then b else raise S.Damaged end
         in SOME (whole {head = h, sections = #ofSections staticFormat section}) end
     end)
    handle IO.Io _ => NONE | S.Damaged => NONE | P.Bad _ => NONE | Overflow => NONE | Subscript => NONE | Size => NONE
         | OS.SysErr _ => NONE
  (* the first entry of a key that stands for an analysis, in the order of
     the names, its time kept where dir is an overlay (UnitStore.touch) *)
  fun findStatic {overlay : bool} (dir : string, configs : string list, k : string) : entry option =
    case configs of
      [] => NONE
    | config :: rest =>
        let
          val d = S.keyDir (dir, config, k)
          fun first [] = findStatic {overlay = overlay} (dir, rest, k)
            | first (n :: names) =
                if String.isSubstring ".tmp-" n then first names
                else case readFirst (S.join (d, n), fn h => forAnalysis h = S.Stands) of
                       SOME e => ((if overlay then S.touch (S.join (d, n)) else ()); SOME e)
                     | NONE => first names
        in first (S.sorted (S.listDir d)) end

  (* Every entry of a key, whatever its usages, in a store or a layer, which
     is only read: what an analysis knows a unit it elaborated by too, where
     an entry's static layer is the same (UnitBasis.alias) *)
  fun entriesAt (dir : string, config : string, k : string) : entry list =
    let val d = S.keyDir (dir, config, k)
    in
      List.mapPartial (fn n => if String.isSubstring ".tmp-" n then NONE else readFirst (S.join (d, n), fn _ => true))
                      (S.sorted (S.listDir d))
    end

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

  (* in the first of dirs that has them -- the store's overlay, then its
     layers -- else none *)
  fun pathsIn (dirs : string list, config : string) (identity : string) : (int * int * string) list option =
    S.sideIn paths (dirs, config) identity

  (* a unit's paths, kept in the overlay dir with its entry where the unit
     is taken: a unit compiled against it reads them only once it changes,
     which may be after a store trimmed by age has kept its entry and not
     them (UnitStore.touch) *)
  fun keepPaths (dir : string, config : string, identity : string) : unit = S.touchSide paths (dir, config, identity)

  (* storePaths: a unit's paths kept by its identity, whole or not at all *)
  fun storePaths (dir : string, config : string, identity : string, ps : (int * int * string) list) : unit =
    S.storeSide paths (dir, config, identity, ps)

  (* The keys a unit binds (UnitBasis.bindKeys), kept by its identity: what
     a light hit binds the unit's names by without its basis *)
  val binds : string list S.side =
    {magic = "RCB", version = version, hash = fn (_, text) => hash ("binds", text),
     write = P.list P.string, read = P.rlist P.rstring}
  fun bindsIn (dirs : string list, config : string) (identity : string) : string list option =
    S.sideIn binds (dirs, config) ("binds " ^ identity)
  fun storeBinds (dir : string, config : string, identity : string, keys : string list) : unit =
    S.storeSide binds (dir, config, "binds " ^ identity, keys)

  (* The editor's sidecars (docs/language-server.md, The store): what an
     analysis keeps of a unit's source beside a compile's entries -- the
     names it mentions, its facts, uses and types, and the origins a
     compile's basis has none of -- by their format, their part and the hash
     of the source, in editor/ of the store and under no configuration, so
     that a compiler upgrade leaves them, as hints that the analysis that
     reads one checks (CompilerAnalysisEngine). Two parts: what a unit is
     loaded with ("head"), and its notes, read only where a question asks
     for them ("notes"). Trimmed with the rest (trim) *)
  val sidecars : string S.side =
    {magic = "RES", version = 1, hash = fn (_, text) => hash ("sidecar", text), write = P.string, read = P.rstring}
  fun sidecarName (format : int, part : string, source : string) : string =
    String.concatWith "\000" [Int.toString format, part, source]
  fun readSidecar (dir : string, format : int, part : string, source : string) : string option =
    S.readSide sidecars (dir, "editor", sidecarName (format, part, source))
  fun storeSidecar (dir : string, format : int, part : string, source : string, bytes : string) : unit =
    S.storeSide sidecars (dir, "editor", sidecarName (format, part, source), bytes)

  (* store: the entry of a key written, whole or not at all, by the hash of
     its usages, beside the key's others; a cache that cannot be written is
     a cache that is not there *)
  (* the hash of what it holds, as a read of it gives it; NONE where it is
     not kept *)
  fun storeSum (dir : string, config : string, k : string,
                {usages = us, warnings, file, others, pickle, identity, code, mid, level = lvl, schemes} : entry) : string option =
    (* code a test switch corrupted (RUNE_REGVERIFY_INJECT) is not kept *)
    if RegVerify.injecting () then NONE else
    UnitBasis.during "cache" (fn () =>
      SOME (S.store (format, settings ())
                    (dir, config, k,
                     {head = {usages = us, level = lvl, named = UnitBasis.namedBy pickle handle P.Bad _ => []},
                      sections = {warnings = warnings, file = file, others = others, pickle = pickle, identity = identity,
                                  code = code, mid = mid, schemes = schemes}})))
  fun store (dir : string, config : string, k : string, e : entry) : unit = ignore (storeSum (dir, config, k, e))

  (* ---- keeping the store small (UnitStore.trim) ---- *)

  (* the limits of trim: --cache-max-age DAYS, a week unless given, and
     --cache-max-size SIZE, 4 GiB unless given; NONE, none *)
  val week = Time.fromSeconds 604800
  val maxAge : Time.time option ref = ref (SOME week)
  val () = CompilerState.cellRoot ("UnitCache.maxAge", maxAge)
  val maxSize : LargeInt.int option ref = ref (SOME (LargeInt.* (LargeInt.fromInt 4096, LargeInt.fromInt 1048576)))
  val () = CompilerState.cellRoot ("UnitCache.maxSize", maxSize)
  fun limits () : S.limits = {age = !maxAge, size = !maxSize}

  (* The overlay dir trimmed after a compile's work is done, where it was
     last trimmed a day ago or more: one stat where it was not. A store
     that is also a layer -- lib/cache, which make basis-cache writes -- is
     never trimmed *)
  fun trimAfter (dir : string) : unit =
    if not (S.trimDue (Time.fromSeconds 86400) dir) orelse isLayer dir then ()
    else (S.markTrimmed dir; ignore (S.trim (limits ()) dir))
end
