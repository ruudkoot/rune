(* The cache of compiled units (docs/units.md, *The cache*; the incremental
   roadmap's D14 and M6): what a compile in units made of each unit -- its
   basis (UnitBasis) and its code (UnitFile) -- kept in a directory by the
   configuration that made it, by what the unit is, and by what it used of
   the units before it, so that a compile after it takes the unit from
   there rather than compiling it again.

   The configuration is the compiler's identity (Config.identity, a hash of
   its sources), the versions of the files, the instruction set, and every
   option that changes what it makes. A unit is keyed by its name, the hash
   of its source, whether it may use _prim, and the settings that hold for
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

  val magic = "RCE"
  (* 10: an entry's mark, the lint it was checked by, and the schemes of
     the globals of other units its code names (the linting roadmap's M9) *)
  val version = 10

  (* what a unit's entry holds: its usages, the warnings its compile gave,
     which a compile that takes it from the cache gives again, the name its
     source had in the compile, which its code's files name it by, the other
     files its code names with the unit each is the source of
     (UnitBasis.sourcesOf), its basis and the identity the basis gives,
     which loading need not work out from the bytes again (functors-units,
     F2), its code's file, and its Mid (UnitMid), for a whole program made
     of the units'; and what checked it: its mark, the level of the lint its
     compile ran (level), and the schemes of the globals of other units its
     code names, as its compile had them (UnitBasis.importedSchemes), which a
     compile that takes it holds the units it names now to *)
  type entry = {usages : (string * string) list, warnings : string list, file : string,
                others : (string * string) list, pickle : string, identity : string, code : string, mid : string,
                level : int, schemes : (string * (int * string) list) list}

  (* The mark of what a compile checks of a unit: the level of its lint --
     every pass's, today's --lint, is 2 (the linting roadmap's D13), none 0,
     nor where RUNE_REGVERIFY=0 leaves the register code unchecked.
     An entry serves a compile whose level is at most its own: one made
     without the lint is, for a compile with it, an entry not there, and the
     unit is compiled again under the lint and the entry stored marked, where
     the cache can be written. The frozen Basis is made with the lint
     (make basis-cache), so that a compile with it takes its entries. *)
  fun level () : int = if Pass.linting () andalso RegVerify.on () then 2 else 0

  (* an entry found, or why there is none *)
  datatype found = Found of entry | Missed of string

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
     ("fuel", case !Pass.fuel of NONE => "-" | SOME n => Int.toString n), ("hash", P.probe ())]
    (* the functors inlined across units: what a unit's basis keeps *)
    @ (if not (StringMap.isEmpty (!Elaborate.inlineFunctors))
       then [("inline", String.concatWith "," (StringMap.listKeys (!Elaborate.inlineFunctors)))] else [])

  (* The hash of the configuration of this compile *)
  fun configuration () : string =
    UnitBasis.hashAt ("configuration", String.concatWith "\000" (List.map #2 (settings ())))

  (* A configuration's directory says what it is made of, in units/about (a
     line "NAME VALUE" a setting), written with its first entry, so that a
     compile that finds none of its own but one that differs from it in the
     hash alone can say so (--explain-rebuild) *)
  fun aboutText () : string = String.concat (List.map (fn (n, v) => n ^ " " ^ v ^ "\n") (settings ()))
  fun aboutFile (dir : string, config : string) : string =
    OS.Path.joinDirFile {dir = OS.Path.joinDirFile {dir = OS.Path.joinDirFile {dir = dir, file = config}, file = "units"},
                         file = "about"}

  (* The probe of another configuration of dir that is this one but for the
     hash, where dir has none of this one's *)
  fun otherHash (dir : string, config : string) : string option =
    if (OS.FileSys.isDir (OS.Path.joinDirFile {dir = dir, file = config}) handle OS.SysErr _ => false) then NONE
    else
      let
        val mine = List.filter (fn (n, _) => n <> "hash") (settings ())
        fun lines t = List.mapPartial (fn l => case String.fields (fn c => c = #" ") l of
                                                 n :: rest => SOME (n, String.concatWith " " rest)
                                               | [] => NONE)
                                      (String.tokens (fn c => c = #"\n") t)
        fun theirs c =
          let
            val ins = TextIO.openIn (aboutFile (dir, c))
            val ls = lines (TextIO.inputAll ins) before TextIO.closeIn ins
          in
            if List.filter (fn (n, _) => n <> "hash") ls = mine
            then Option.map #2 (List.find (fn (n, _) => n = "hash") ls) else NONE
          end
          handle IO.Io _ => NONE
        val ds = (let
                    val s = OS.FileSys.openDir dir
                    fun go acc = case OS.FileSys.readDir s of NONE => acc | SOME n => go (n :: acc)
                  in go [] before OS.FileSys.closeDir s end)
                 handle OS.SysErr _ => []
        fun insert (n, []) = [n]
          | insert (n, m :: rest) = if n < m then n :: m :: rest else m :: insert (n, rest)
      in List.foldl (fn (c, found) => case found of SOME _ => found | NONE => theirs c) NONE (List.foldl insert [] ds) end

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

  (* the key of a unit *)
  (* settings: what the unit was compiled under that the configuration does
     not say, because it holds for the input files and not the libraries
     (--default-type, --or-patterns); "" for none, which keeps the key it
     had before there were such settings *)
  fun key {name : string, text : string, allow : bool, settings : string} : string =
    UnitBasis.during "cache" (fn () =>
      UnitBasis.hashAt ("key", String.concatWith "\000" ([name, UnitBasis.hashAt ("source", text), if allow then "1" else "0"]
                                                           @ (if settings = "" then [] else [settings]))))

  fun keyDir (dir : string, config : string, k : string) : string =
    OS.Path.joinDirFile {dir = OS.Path.joinDirFile {dir = dir, file = config}, file = k}

  fun readFile (p : string) : string =
    let val ins = BinIO.openIn p
    in Byte.bytesToString (BinIO.inputAll ins) before BinIO.closeIn ins end

  fun usages (w : P.writer, us : (string * string) list) =
    P.list (fn (w, (k, i)) => (P.string (w, k); P.string (w, i))) (w, us)

  (* an entry's file read: the entry, or why it is none *)
  fun read (p : string) : found =
    case (SOME (readFile p) handle IO.Io _ => NONE) of
      NONE => Missed "an entry that cannot be read"
    | SOME s =>
        (let
           val r = P.reader s
           val () = if P.rbytes (r, 3) = magic then () else raise P.Bad "not an entry"
           val () = if P.rnat r = version then () else raise P.Bad "an entry of another version"
           val h = P.rstring r
           val at = !(#pos r)
           val us = P.rlist (fn r => let val k = P.rstring r in (k, P.rstring r) end) r
           val warnings = P.rlist P.rstring r
           val file = P.rstring r
           val others = P.rlist (fn r => let val f = P.rstring r in (f, P.rstring r) end) r
           val pickle = P.rstring r
           val identity = P.rstring r
           val code = P.rstring r
           val mid = P.rstring r
           val lvl = P.rnat r
           val schemes = P.rlist (fn r => let val u = P.rstring r
                                          in (u, P.rlist (fn r => let val n = P.rnat r in (n, P.rstring r) end) r) end) r
         in
           if not (P.atEnd r) orelse UnitBasis.during "cache" (fn () => UnitBasis.hashAt ("read", String.extract (s, at, NONE))) <> h
           then Missed "a damaged entry"
           else Found {usages = us, warnings = warnings, file = file, others = others, pickle = pickle, identity = identity,
                       code = code, mid = mid, level = lvl, schemes = schemes}
         end
         handle P.Bad why => Missed ("a damaged entry: " ^ why)
              | Overflow => Missed "a damaged entry"
              | Subscript => Missed "a damaged entry")

  (* The entries of a key whose usages hold: the first found, or why there
     is none *)
  fun find (dir : string, config : string, k : string) : found =
    let
      val d = keyDir (dir, config, k)
      val names =
        (let
           val s = OS.FileSys.openDir d
           fun go acc = case OS.FileSys.readDir s of
                          NONE => acc
                        | SOME n => go (if String.isSubstring ".tmp-" n then acc else n :: acc)
         in (go [] before OS.FileSys.closeDir s) end)
        handle OS.SysErr _ => []
      (* an entry whose usages hold by their binders before one whose hold
         only by fingerprint, which needs units remapped to load *)
      (* one that holds by fingerprint alone, never for a program that keeps
         its units' identities (UnitBasis.remapAllowed): the entry names
         the units it was compiled against, which are others now
         (docs/plans/build-cache-issues.md, issue 15) *)
      fun try ([], why, byFingerprint) =
            (case byFingerprint of
               SOME e => if !UnitBasis.remapAllowed then Found e
                         else Missed "its entries hold across a unit that changed, which a program that keeps its units' identities takes none across"
             | NONE => Missed why)
        | try (n :: rest, why, byFingerprint) =
            case read (OS.Path.joinDirFile {dir = d, file = n}) of
              Found (e as {usages, level = l, ...}) =>
                (* one made without the lint, for a compile with it: none
                   (level) *)
                if l < level ()
                then try (rest, if why = "no entry" then "its entry was not checked by the lint" else why, byFingerprint)
                else
                  (case UnitBasis.broken usages of
                     NONE => if UnitBasis.exact usages then Found e
                             else try (rest, why, case byFingerprint of NONE => SOME e | some => some)
                   | SOME u => try (rest, if why = "no entry" then "its entries used " ^ u ^ ", which is another now" else why,
                                    byFingerprint))
            | Missed w => try (rest, if why = "no entry" then w else why, byFingerprint)
      (* in an order of their own, whatever the directory's: any whose usages
         hold is the same *)
      fun insert (n, []) = [n]
        | insert (n, m :: rest) = if n < m then n :: m :: rest else m :: insert (n, rest)
    in
      try (List.foldl insert [] names, "no entry", NONE)
    end

  (* whether a key has an entry, whatever its usages: a unit likely found,
     which a parallel build leaves to the parent (Parallel) *)
  fun hasEntry (dir : string, config : string, k : string) : bool =
    (let
       val s = OS.FileSys.openDir (keyDir (dir, config, k))
       fun go () = case OS.FileSys.readDir s of
                     NONE => false
                   | SOME n => not (String.isSubstring ".tmp-" n) orelse go ()
     in go () before OS.FileSys.closeDir s end)
    handle OS.SysErr _ => false

  (* ---- what the cache keeps of a unit by its identity ---- *)

  (* The paths to a unit's names (UnitBasis.pathsOf), kept by its identity
     beside the entries, in units/ of the configuration's directory: what an
     entry compiled against the unit needs to be loaded against another
     unit of its name (UnitBasis.remapping) *)
  val pathsMagic = "RCP"
  fun pathsFile (dir : string, config : string, identity : string) : string =
    OS.Path.joinDirFile {dir = OS.Path.joinDirFile {dir = OS.Path.joinDirFile {dir = dir, file = config}, file = "units"},
                         file = UnitBasis.during "cache" (fn () => UnitBasis.hashAt ("paths", identity))}

  fun readPaths (dir : string, config : string, identity : string) : (int * int * string) list option =
    (let
       val s = readFile (pathsFile (dir, config, identity))
       val r = P.reader s
       val () = if P.rbytes (r, 3) = pathsMagic andalso P.rnat r = version then () else raise P.Bad "not paths"
       val h = P.rstring r
       val at = !(#pos r)
       val i = P.rstring r
       val ps = P.rlist (fn r => let val k = P.rnat r val n = P.rnat r in (k, n, P.rstring r) end) r
     in
       if i = identity andalso P.atEnd r
          andalso UnitBasis.during "cache" (fn () => UnitBasis.hashAt ("paths", String.extract (s, at, NONE))) = h
       then SOME ps else NONE
     end)
    handle IO.Io _ => NONE | P.Bad _ => NONE | Overflow => NONE | Subscript => NONE

  (* in the cache, else in the frozen Basis, else none *)
  fun pathsIn (dirs : string list, config : string) (identity : string) : (int * int * string) list option =
    List.foldl (fn (d, found) => case found of SOME _ => found | NONE => readPaths (d, config, identity)) NONE dirs

  (* every directory of a path, made where it is not there *)
  fun mkdirs (d : string) : unit =
    if d = "" orelse d = "." orelse d = "/" orelse (OS.FileSys.isDir d handle OS.SysErr _ => false) then ()
    else (mkdirs (OS.Path.dir d); OS.FileSys.mkDir d handle OS.SysErr _ => ())

  (* a name of its own for what is being written *)
  val written = ref 0
  val () = CompilerState.cellRoot ("UnitCache.written", written)
  fun unique () =
    (written := !written + 1;
     LargeInt.toString (Time.toMicroseconds (Time.now ()) mod 1000000000000) ^ "-"
     ^ SysWord.fmt StringCvt.DEC (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())) ^ "-" ^ Int.toString (!written))

  (* storePaths: a unit's paths kept by its identity, whole or not at all *)
  fun storePaths (dir : string, config : string, identity : string, ps : (int * int * string) list) : unit =
    let
      val p = pathsFile (dir, config, identity)
      val tmp = p ^ ".tmp-" ^ unique ()
      val body = P.writer ()
      val () = (P.string (body, identity);
                P.list (fn (w, (k, n, path)) => (P.nat (w, k); P.nat (w, n); P.string (w, path))) (body, ps))
      val b = P.contents body
      val w = P.writer ()
      val () = (P.bytes (w, pathsMagic); P.nat (w, version);
                P.string (w, UnitBasis.during "cache" (fn () => UnitBasis.hashAt ("paths", b))); P.bytes (w, b))
    in
      (mkdirs (OS.Path.dir p);
       let val out = BinIO.openOut tmp
       in BinIO.output (out, Byte.stringToBytes (P.contents w)); BinIO.closeOut out end;
       OS.FileSys.rename {old = tmp, new = p})
      handle IO.Io _ => ((OS.FileSys.remove tmp) handle OS.SysErr _ => ())
           | OS.SysErr _ => ((OS.FileSys.remove tmp) handle OS.SysErr _ => ())
    end

  (* store: the entry of a key written, whole or not at all, by the hash of
     its usages, beside the key's others; a cache that cannot be written is
     a cache that is not there *)
  fun store (dir : string, config : string, k : string,
             {usages = us, warnings, file, others, pickle, identity, code, mid, level = lvl, schemes} : entry) : unit =
    (* code a test switch corrupted (RUNE_REGVERIFY_INJECT) is not kept *)
    if RegVerify.injecting () then () else
    UnitBasis.during "cache" (fn () =>
    let
      val d = keyDir (dir, config, k)
      val u = P.writer ()
      val () = usages (u, us)
      val p = OS.Path.joinDirFile {dir = d, file = UnitBasis.hashAt ("store", P.contents u)}
      val tmp = p ^ ".tmp-" ^ unique ()
      val body = P.writer ()
      val () = (usages (body, us); P.list P.string (body, warnings); P.string (body, file);
                usages (body, others); P.string (body, pickle); P.string (body, identity); P.string (body, code);
                P.string (body, mid); P.nat (body, lvl);
                P.list (fn (w, (u, ns)) => (P.string (w, u); P.list (fn (w, (n, t)) => (P.nat (w, n); P.string (w, t))) (w, ns)))
                       (body, schemes))
      val b = P.contents body
      val w = P.writer ()
      val () = (P.bytes (w, magic); P.nat (w, version); P.string (w, UnitBasis.hashAt ("store", b)); P.bytes (w, b))
      val about = aboutFile (dir, config)
    in
      (mkdirs d;
       if (OS.FileSys.access (about, []) handle OS.SysErr _ => false) then ()
       else (let val () = mkdirs (OS.Path.dir about)
                 val t = about ^ ".tmp-" ^ unique ()
                 val out = TextIO.openOut t
             in TextIO.output (out, aboutText ()); TextIO.closeOut out; OS.FileSys.rename {old = t, new = about} end
             handle IO.Io _ => () | OS.SysErr _ => ());
       let val out = BinIO.openOut tmp
       in BinIO.output (out, Byte.stringToBytes (P.contents w)); BinIO.closeOut out end;
       OS.FileSys.rename {old = tmp, new = p})
      handle IO.Io _ => ((OS.FileSys.remove tmp) handle OS.SysErr _ => ())
           | OS.SysErr _ => ((OS.FileSys.remove tmp) handle OS.SysErr _ => ())
    end)
end
