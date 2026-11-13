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
  val version = 1

  (* what a compile read, by a name of rhc's (H1, H2, H7, H9), and what it
     gave then *)
  type usage = string * string
  (* An entry's head: its usages; the digest of what the unit exports, which
     its clients' usages name; and the level of the lint that checked it *)
  type head = {usages : usage list, exports : string, level : int}
  (* its sections, each hashed apart: the unit's interface (HsIface's
     bytes) and its code (a unit file's) *)
  (* the code's parts, each a section of its own, read and held to its hash
     only where it is asked for: a unit taken whose code no link needs
     never reads it, and a link reads only the parts it reaches (a unit's
     Core by its declarations, CoreUnits.index). `count` is the parts a
     writer gives; a reader asks for those it knows are there *)
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

  (* Whether an entry stands. One checked at a lower level of the lint than
     this compile checks at does not, nor one any of whose usages gives now
     other than it gave its compile; current says what a usage gives now,
     from the graph of this compile *)
  fun holds {level = want : int, current : string -> string} ({usages, level = l, ...} : head) : S.verdict =
    if l < want then S.Refused ("it was checked at a lower level of the lint (" ^ Int.toString l ^ ")")
    else
      case List.find (fn (k, v) => current k <> v) usages of
        NONE => S.Stands
      | SOME (k, v) => S.Refused ("its compile read " ^ k ^ " as " ^ v ^ ", which is " ^ current k ^ " now")

  (* A unit's entry: in the overlay first, which keeps the times of what it
     gives, then in each layer, read only (the Prelude's snapshot, D45);
     where none stands, why the overlay's did not *)
  fun find ({overlay, layers, config, key = k, holds = h}
            : {overlay : string, layers : string list, config : string, key : string, holds : head -> S.verdict})
           : (head, sections) S.found =
    let
      fun inLayers ([], why) = S.Missed why
        | inLayers (d :: ds, why) =
            case S.find (format, h) (d, config, k) of
              S.Missed _ => inLayers (ds, why)
            | found => found
    in
      case S.findAt (format, h) {overlay = true} (overlay, config, k) of
        S.Missed why => inLayers (layers, why)
      | found => found
    end

  (* A unit's entry kept in dir, the overlay or a layer being made: the sum
     of what it holds, which names its bytes (UnitMemo's link memo) *)
  fun store ({dir, settings, config, key = k, entry}
             : {dir : string, settings : (string * string) list, config : string, key : string, entry : entry}) : string =
    S.store (format, settings) (dir, config, k, entry)
end
