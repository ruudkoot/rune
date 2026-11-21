(* rhc's entries in the store (the haskell98 roadmap's M21, D43): a client
   of UnitStore with a format, head, holds, key and settings of its own, so
   that a unit of a Haskell program, an SCC of its modules' graph, is kept
   as Rune keeps its own, in a configuration of rhc's that no compile of
   Rune's shares. The store knows nothing of a unit: rhc's head says what
   the unit's compile read (its usages, each a name and what it was), and
   holds judges an entry by them against what the graph gives now, never
   by what the entry says the graph was (H3). It depends on Pickle and
   UnitStore alone, so that it is tested with no compiler; what a
   configuration of rhc's is made of is RhcStoreConfig's. *)
structure RhcStore =
struct
  structure S = UnitStore
  structure P = Pickle

  val magic = "RHE"
  (* 2: a unit's interface in HsIface's bytes, and the driver's parts the
     desugaring's interface and the fingerprints before its Core *)
  (* 3: the driver's part of HsLint's findings of a unit's modules, made at
     level 2, before its Core (ruling 66) *)
  (* 4: the hash of a unit's Core, a part of its own, which the link's memo
     is keyed by (build-cache-issues.md, issue 35) *)
  val version = 4

  (* what a compile read, by a name of rhc's (H1, H2, H7, H9), and what it
     gave then *)
  type usage = string * string
  (* An entry's head: its usages; the digest of what the unit exports, which
     its clients' usages name; and the level of the lint that checked it *)
  type head = {usages : usage list, exports : string, level : int}
  (* its sections, each hashed apart: the unit's interface (HsIface's
     bytes) and its parts, which the client lays out (rhc's driver: the
     desugaring's interface, the fingerprints, HsLint's part, the Core's
     index and each of its declarations; a unit of Core: its unit file).
     Each part is a
     section of its own, read and held to its hash only where it is asked
     for: a unit taken that no later unit desugars against never reads its
     desugaring's, and a link reads only the declarations it reaches
     (CoreUnits.index). `count` is the parts a writer gives; a reader asks
     for those it knows are there *)
  type sections = {iface : string, parts : int -> string, count : int}
  type entry = (head, sections) S.entry

  fun hash (_ : string, text : string) : string = P.hash text

  fun wusages (w : P.writer, us : usage list) = P.list (fn (w, (k, v)) => (P.string (w, k); P.string (w, v))) (w, us)
  fun rusages (r : P.reader) : usage list = P.rlist (fn r => let val k = P.rstring r in (k, P.rstring r) end) r

  val format : (head, sections) S.format =
    {magic = magic, version = version, hash = hash,
     writeHead = fn (w, {usages, exports, level}) => (wusages (w, usages); P.string (w, exports); P.int (w, level)),
     readHead = fn r => let val us = rusages r val e = P.rstring r in {usages = us, exports = e, level = P.rint r} end,
     sections = fn {iface, parts, count} => iface :: List.tabulate (count, parts),
     ofSections = fn get => {iface = get 0, parts = fn i => get (i + 1), count = ~1}}

  (* A unit's key: its name, and each member with the hash of its text, in
     the graph's order: over every member of an SCC (H8), and a module's
     `default` with its text (H4) *)
  fun key (unit : string, members : (string * string) list) : string =
    S.key (hash, ["rhc", unit] @ List.map (fn (m, h) => m ^ " " ^ h) members)

  (* The first of `usages` that gives now other than it gave its compile,
     with what it gives now: `current (k, v)` is what the usage k, which
     gave v, gives now *)
  fun differing (current : string * string -> string) (usages : usage list) : (string * string * string) option =
    case List.find (fn (k, v) => current (k, v) <> v) usages of
      NONE => NONE
    | SOME (k, v) => SOME (k, v, current (k, v))

  (* Whether an entry stands. One checked at a lower level of the lint than
     this compile checks at does not, nor one of whose usages `judge` finds
     one that gives now other than it gave its compile (`differing`), from
     the graph of this compile *)
  fun holdsBy {level = want : int, judge : usage list -> (string * string * string) option} ({usages, level = l, ...} : head)
      : S.verdict =
    if l < want then S.Refused ("it was checked at a lower level of the lint (" ^ Int.toString l ^ ")")
    else
      case judge usages of
        NONE => S.Stands
      | SOME (k, v, now) => S.Refused ("its compile read " ^ k ^ " as " ^ v ^ ", which is " ^ now ^ " now")

  (* `holdsBy` asking each usage of `current` *)
  fun holds {level : int, current : string -> string} : head -> S.verdict =
    holdsBy {level = level, judge = differing (fn (k, _) => current k)}

  (* A part of an entry of the read-only store `dir` (a layer, bin/rhc's
     snapshot) that does not hold what its hash says, read after the entry
     was taken: an entry a compile cannot take back, nor remove, so it
     stops, saying which store to make again *)
  exception Damaged of string

  (* The store holds an entry's head to its hash before the entry is
     taken, and each section to its own only as the client reads it
     (UnitStore), and rhc reads a unit's parts long after it takes the
     unit: its desugaring's where a unit after it is made, its Core's
     declarations where the link reaches them. So an entry of the overlay
     is held whole before it is taken, every part read once, which a
     compile that goes on to read them reads again for nothing; one that
     does not hold is no entry, and is removed, so that the next compile
     does not read it again (build-cache-issues.md, issue 28) *)
  fun intact ({sections = {parts, ...}, ...} : entry) : bool =
    let fun go i = (ignore (parts i); go (i + 1))
    in go 0 handle P.Bad _ => true | S.Damaged => false end

  (* the file of an entry of the key k, named by the hash of its head's
     bytes (UnitStore.store) *)
  fun fileOf (dir : string, config : string, k : string, h : head) : string =
    let val w = P.writer ()
    in #writeHead format (w, h); S.join (S.keyDir (dir, config, k), hash ("store", P.contents w)) end

  (* an entry of a read-only store dir, each part read through a guard:
     one that does not hold stops the compile (Damaged dir) *)
  fun guarded (dir : string) (found : (head, sections) S.found) : (head, sections) S.found =
    let
      fun guard ({head, sections = {iface, parts, count}} : entry) : entry =
        {head = head, sections = {iface = iface, parts = fn i => parts i handle S.Damaged => raise Damaged dir, count = count}}
    in
      case found of
        S.Found (e, sum) => S.Found (guard e, sum)
      | S.FoundBehind (e, sum) => S.FoundBehind (guard e, sum)
      | missed => missed
    end

  (* A unit's entry: in the overlay first, which keeps the times of what it
     gives, held whole (intact), then in each layer, read only (the
     Prelude's snapshot, D45), each part held as it is read (guarded);
     where none stands, why the overlay's did not *)
  fun find ({overlay, layers, config, key = k, holds = h}
            : {overlay : string, layers : string list, config : string, key : string, holds : head -> S.verdict})
           : (head, sections) S.found =
    let
      fun inLayers ([], why) = S.Missed why
        | inLayers (d :: ds, why) =
            case S.find (format, h) (d, config, k) of
              S.Missed _ => inLayers (ds, why)
            | found => guarded d found
      fun held (e : entry, found) =
        if intact e then found
        else ((OS.FileSys.remove (fileOf (overlay, config, k, #head e)) handle OS.SysErr _ => ());
              inLayers (layers, "a damaged entry"))
    in
      case S.findAt (format, h) {overlay = true} (overlay, config, k) of
        S.Missed why => inLayers (layers, why)
      | found as S.Found (e, _) => held (e, found)
      | found as S.FoundBehind (e, _) => held (e, found)
    end

  (* A unit's entry in the layers alone, read only, where a compile keeps
     nothing (no overlay): bin/rhc's compile against its snapshot *)
  fun findIn ({layers, config, key = k, holds = h}
              : {layers : string list, config : string, key : string, holds : head -> S.verdict})
             : (head, sections) S.found =
    let
      fun inLayers ([], why) = S.Missed why
        | inLayers (d :: ds, why) =
            case S.find (format, h) (d, config, k) of
              S.Missed w => inLayers (ds, if why = "" then w else why)
            | found => guarded d found
    in
      inLayers (layers, "")
    end

  (* The configurations of the store dir that hold no entry of rhc's
     identity `identity`: each a directory of dir whose units/about names
     another identity, its files removed and the directories they leave
     empty, as the store's trim removes what it removes (UnitStore's
     filesUnder and prune), so that a layer made at each build of rhc keeps
     its own entries alone; how many went *)
  fun dropOthers (dir : string, identity : string) : int =
    let
      fun aboutOf d =
        let val f = S.aboutFile (dir, d)
        in (let val i = TextIO.openIn f in TextIO.inputAll i before TextIO.closeIn i end) handle IO.Io _ => "" end
      fun ofIdentity text = List.exists (fn l => l = "identity " ^ identity) (String.fields (fn c => c = #"\n") text)
      val configs = List.filter (fn d => (OS.FileSys.isDir (S.join (dir, d)) handle OS.SysErr _ => false)) (S.listDir dir)
      val others = List.filter (fn d => let val a = aboutOf d in a <> "" andalso not (ofIdentity a) end) configs
      fun drop d =
        let val files = List.map #1 (S.filesUnder (S.join (dir, d), []))
        in List.app (fn f => OS.FileSys.remove f handle OS.SysErr _ => ()) files; S.prune (dir, files) end
    in
      List.app drop others; length others
    end

  (* A unit's entry kept in dir, the overlay or a layer being made: the sum
     of what it holds, which names its bytes (UnitMemo's link memo) *)
  fun store ({dir, settings, config, key = k, entry}
             : {dir : string, settings : (string * string) list, config : string, key : string, entry : entry}) : string =
    S.store (format, settings) (dir, config, k, entry)
end
