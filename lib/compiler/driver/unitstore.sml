(* The store of what a compile in units made (docs/units.md, *The cache*;
   the build-system roadmap's D24): a directory, in it a directory by each
   configuration, in that a directory by each key, and in that an entry by
   each head. It knows how an entry is kept, how one is found and what is
   kept beside the entries, and nothing of what a unit is: an entry's head
   and sections are of whatever types a client's format writes and reads, a
   client's holds says whether a candidate stands, and a configuration is
   a list of settings its client names. So it holds for any language
   compiled in units, and depends on Pickle alone, and the hash its client
   gives it.

   An entry is one file, written whole under another name and renamed, so
   that a compile at the same time never sees half of one; it carries the
   hash of what it holds, and one that does not hold what its hash says, or
   that cannot be read, is not there. Its name in its key's directory is the
   hash of its head's bytes, so that a compile that made the same head again
   writes over it. Nothing in a key is a time.

   The stat memo (memo) is not a key either: it says what a file's text
   hashed to when the file had its stat, and is believed only where the
   stat is the same and was taken at least two seconds after the file last
   changed, as git believes its index (racily clean). A file whose stat
   says nothing (an edit within the same second as the last, of the same
   size) is read and hashed again. *)
structure UnitStore =
struct
  structure P = Pickle

  (* What a client says of a kind of file: its marks; its hash, by the site
     that asks (a client counts them); and how its head and its sections
     are written and read. A reader reads them all, and nothing else *)
  type ('h, 's) format =
    {magic : string, version : int, hash : string * string -> string,
     writeHead : P.writer * 'h -> unit, readHead : P.reader -> 'h,
     writeSections : P.writer * 's -> unit, readSections : P.reader -> 's}

  type ('h, 's) entry = {head : 'h, sections : 's}

  (* an entry's file read: the entry and the hash of what it holds, which
     names its bytes (a link of the units it holds is the same where these
     are: UnitMemo), or why it is none *)
  datatype ('h, 's) read = Read of ('h, 's) entry * string | Unread of string

  (* What a client's holds says of an entry that a compile might take: it
     stands; it stands, but behind any that simply stands; it does not, and
     why *)
  datatype verdict = Stands | StandsBehind | Refused of string

  (* the entry found, or why there is none *)
  datatype ('h, 's) found = Found of ('h, 's) entry * string | FoundBehind of ('h, 's) entry * string | Missed of string

  (* ---- where things are ---- *)

  fun join (dir : string, file : string) : string = OS.Path.joinDirFile {dir = dir, file = file}

  fun keyDir (dir : string, config : string, k : string) : string = join (join (dir, config), k)
  fun unitsDir (dir : string, config : string) : string = join (join (dir, config), "units")

  (* A configuration's directory says what it is made of, in units/about (a
     line "NAME VALUE" a setting), written with its first entry, so that a
     compile that finds none of its own but one that differs from it in one
     setting alone can say so (otherBut) *)
  fun aboutFile (dir : string, config : string) : string = join (unitsDir (dir, config), "about")
  fun aboutText (settings : (string * string) list) : string =
    String.concat (List.map (fn (n, v) => n ^ " " ^ v ^ "\n") settings)

  (* the hash of a configuration, of a key *)
  fun configuration (hash : string * string -> string, settings : (string * string) list) : string =
    hash ("configuration", String.concatWith "\000" (List.map #2 settings))
  fun key (hash : string * string -> string, parts : string list) : string =
    hash ("key", String.concatWith "\000" parts)

  (* in an order of their own, whatever the directory's *)
  fun sorted (names : string list) : string list =
    let
      fun insert (n, []) = [n]
        | insert (n, m :: rest) = if n < m then n :: m :: rest else m :: insert (n, rest)
    in List.foldl insert [] names end

  (* the names in a directory, none where it cannot be read *)
  fun listDir (d : string) : string list =
    (let
       val s = OS.FileSys.openDir d
       fun go acc = case OS.FileSys.readDir s of NONE => acc | SOME n => go (n :: acc)
     in go [] before OS.FileSys.closeDir s end)
    handle OS.SysErr _ => []

  (* The value of the setting except of another configuration of dir that
     is this one but for it, where dir has none of this one's *)
  fun otherBut (except : string) (settings : (string * string) list, dir : string, config : string) : string option =
    if (OS.FileSys.isDir (join (dir, config)) handle OS.SysErr _ => false) then NONE
    else
      let
        val mine = List.filter (fn (n, _) => n <> except) settings
        fun lines t = List.mapPartial (fn l => case String.fields (fn c => c = #" ") l of
                                                 n :: rest => SOME (n, String.concatWith " " rest)
                                               | [] => NONE)
                                      (String.tokens (fn c => c = #"\n") t)
        fun theirs c =
          let
            val ins = TextIO.openIn (aboutFile (dir, c))
            val ls = lines (TextIO.inputAll ins) before TextIO.closeIn ins
          in
            if List.filter (fn (n, _) => n <> except) ls = mine
            then Option.map #2 (List.find (fn (n, _) => n = except) ls) else NONE
          end
          handle IO.Io _ => NONE
      in List.foldl (fn (c, found) => case found of SOME _ => found | NONE => theirs c) NONE (sorted (listDir dir)) end

  (* ---- reading ---- *)

  fun readFile (p : string) : string =
    let val ins = BinIO.openIn p
    in Byte.bytesToString (BinIO.inputAll ins) before BinIO.closeIn ins end

  fun read ({magic, version, hash, readHead, readSections, ...} : ('h, 's) format) (p : string) : ('h, 's) read =
    case (SOME (readFile p) handle IO.Io _ => NONE) of
      NONE => Unread "an entry that cannot be read"
    | SOME s =>
        (let
           val r = P.reader s
           val () = if P.rbytes (r, 3) = magic then () else raise P.Bad "not an entry"
           val () = if P.rnat r = version then () else raise P.Bad "an entry of another version"
           val h = P.rstring r
           val at = !(#pos r)
           val head = readHead r
           val sections = readSections r
         in
           if not (P.atEnd r) orelse hash ("read", String.extract (s, at, NONE)) <> h
           then Unread "a damaged entry"
           else Read ({head = head, sections = sections}, h)
         end
         handle P.Bad why => Unread ("a damaged entry: " ^ why)
              | Overflow => Unread "a damaged entry"
              | Subscript => Unread "a damaged entry")

  (* A name with .tmp- in it is a file being written, or one that a compile
     that died left there, which nothing takes (withTemporary). None is
     written for long: an hour old, it is the second, and it is removed where
     a compile comes across it. What a time decides here is whether a file
     that no compile reads stays, and no compile's result. *)
  fun sweep (path : string) : unit =
    if Time.< (Time.now (), Time.+ (OS.FileSys.modTime path, Time.fromSeconds 3600)) then ()
    else OS.FileSys.remove path handle OS.SysErr _ => ()

  (* the names of a key's entries, the files being written swept where old *)
  fun entryNames (d : string) : string list =
    List.filter (fn n => if String.isSubstring ".tmp-" n
                         then ((sweep (join (d, n)) handle OS.SysErr _ => ()); false)
                         else true)
                (listDir d)

  (* The entries of a key that the client's holds lets stand, in an order of
     their own, whatever the directory's, since any that stands is the
     same: the first that stands, else the first that stands behind, or why
     there is none, the first reason given *)
  fun find (format : ('h, 's) format, holds : ('h, 's) entry -> verdict) (dir : string, config : string, k : string)
      : ('h, 's) found =
    let
      val d = keyDir (dir, config, k)
      fun first (why, w) = if why = "no entry" then w else why
      fun try ([], why, behind) =
            (case behind of
               SOME e => FoundBehind e
             | NONE => Missed why)
        | try (n :: rest, why, behind) =
            case read format (join (d, n)) of
              Read (e, h) =>
                (case holds e of
                   Stands => Found (e, h)
                 | StandsBehind => try (rest, why, case behind of NONE => SOME (e, h) | some => some)
                 | Refused w => try (rest, first (why, w), behind))
            | Unread w => try (rest, first (why, w), behind)
    in
      try (sorted (entryNames d), "no entry", NONE)
    end

  (* whether a key has an entry, whatever it holds *)
  fun hasEntry (dir : string, config : string, k : string) : bool =
    (let
       val s = OS.FileSys.openDir (keyDir (dir, config, k))
       fun go () = case OS.FileSys.readDir s of
                     NONE => false
                   | SOME n => not (String.isSubstring ".tmp-" n) orelse go ()
     in go () before OS.FileSys.closeDir s end)
    handle OS.SysErr _ => false

  (* ---- writing ---- *)

  (* every directory of a path, made where it is not there *)
  fun mkdirs (d : string) : unit =
    if d = "" orelse d = "." orelse d = "/" orelse (OS.FileSys.isDir d handle OS.SysErr _ => false) then ()
    else (mkdirs (OS.Path.dir d); OS.FileSys.mkDir d handle OS.SysErr _ => ())

  (* The system reserves a name; the file to publish is beside its
     destination so that rename stays on one filesystem. Keep the
     reservation until publication finishes, as Emit does. Clock readings
     and process ids never enter the compiler's arithmetic or its cache. *)
  fun withTemporary (path : string) (write : string -> unit) : unit =
    let
      val reservation = OS.FileSys.tmpName ()
      val temporary = path ^ ".tmp-" ^ OS.Path.file reservation
      fun remove p = OS.FileSys.remove p handle OS.SysErr _ => ()
      fun clean () = (remove temporary; remove reservation)
    in
      (write temporary; clean ()) handle ex => (clean (); raise ex)
    end

  (* bytes published at p, whole or not at all *)
  fun publish (p : string, bytes : string) : unit =
    withTemporary p (fn tmp =>
      (let val out = BinIO.openOut tmp
       in
         (BinIO.output (out, Byte.stringToBytes bytes); BinIO.closeOut out)
         handle ex => (BinIO.closeOut out handle _ => (); raise ex)
       end;
       OS.FileSys.rename {old = tmp, new = p}))

  (* the file of what body holds: its marks, its hash, it *)
  fun framed (magic : string, version : int, hash : string * string -> string, site : string, b : string) : string =
    let val w = P.writer ()
    in (P.bytes (w, magic); P.nat (w, version); P.string (w, hash (site, b)); P.bytes (w, b); P.contents w) end

  (* An entry of a key written, whole or not at all, by the hash of its
     head, beside the key's others, and the configuration's about with the
     first; a store that cannot be written is a store that is not there. The
     hash of what it holds, which a read of it gives (read) *)
  fun store ({magic, version, hash, writeHead, writeSections, ...} : ('h, 's) format, settings : (string * string) list)
            (dir : string, config : string, k : string, {head, sections} : ('h, 's) entry) : string =
    let
      val d = keyDir (dir, config, k)
      val u = P.writer ()
      val () = writeHead (u, head)
      val p = join (d, hash ("store", P.contents u))
      val body = P.writer ()
      val () = (writeHead (body, head); writeSections (body, sections))
      val b = P.contents body
      val sum = hash ("store", b)
      val bytes = let val w = P.writer () in P.bytes (w, magic); P.nat (w, version); P.string (w, sum); P.bytes (w, b); P.contents w end
      val about = aboutFile (dir, config)
    in
      (mkdirs d;
       if (OS.FileSys.access (about, []) handle OS.SysErr _ => false) then ()
       else ((mkdirs (OS.Path.dir about);
              withTemporary about (fn t =>
                (let val out = TextIO.openOut t
                 in
                   (TextIO.output (out, aboutText settings); TextIO.closeOut out)
                   handle ex => (TextIO.closeOut out handle _ => (); raise ex)
                 end;
                 OS.FileSys.rename {old = t, new = about})))
             handle IO.Io _ => () | OS.SysErr _ => ());
       publish (p, bytes))
      handle IO.Io _ => () | OS.SysErr _ => ();
      sum
    end

  (* ---- what is kept beside the entries, by a name ---- *)

  (* A file kept by a name, in units/ of the configuration's directory: its
     marks, its hash, the name, and what the client's format writes; read
     back only where all of that holds. Such a file is a function of its
     name (a unit's identity), so whoever writes it writes the same *)
  type 'a side = {magic : string, version : int, hash : string * string -> string,
                  write : P.writer * 'a -> unit, read : P.reader -> 'a}

  fun sideFile (hash : string * string -> string, dir : string, config : string, name : string) : string =
    join (unitsDir (dir, config), hash ("side", name))

  fun readSide ({magic, version, hash, read, ...} : 'a side) (dir : string, config : string, name : string) : 'a option =
    (let
       val s = readFile (sideFile (hash, dir, config, name))
       val r = P.reader s
       val () = if P.rbytes (r, 3) = magic andalso P.rnat r = version then () else raise P.Bad "not a side file"
       val h = P.rstring r
       val at = !(#pos r)
       val i = P.rstring r
       val v = read r
     in
       if i = name andalso P.atEnd r andalso hash ("side", String.extract (s, at, NONE)) = h
       then SOME v else NONE
     end)
    handle IO.Io _ => NONE | P.Bad _ => NONE | Overflow => NONE | Subscript => NONE

  (* in the first of dirs that has it *)
  fun sideIn (side : 'a side) (dirs : string list, config : string) (name : string) : 'a option =
    List.foldl (fn (d, found) => case found of SOME _ => found | NONE => readSide side (d, config, name)) NONE dirs

  (* The directory of what is kept by name, swept of what a compile left
     (sweep), by the first compile to write there: no key leads a compile to
     it, as one leads to an entry's directory. Once a compile *)
  val swept = ref false
  val () = CompilerState.cellRoot ("UnitStore.swept", swept)
  fun sweepUnits (units : string) : unit =
    if !swept then ()
    else
      (swept := true;
       List.app (fn n => if String.isSubstring ".tmp-" n then (sweep (join (units, n)) handle OS.SysErr _ => ()) else ())
                (listDir units))

  (* kept by a name, whole or not at all *)
  fun storeSide ({magic, version, hash, write, ...} : 'a side) (dir : string, config : string, name : string, v : 'a) : unit =
    let
      val p = sideFile (hash, dir, config, name)
      val () = sweepUnits (OS.Path.dir p)
      val body = P.writer ()
      val () = (P.string (body, name); write (body, v))
    in
      (mkdirs (OS.Path.dir p); publish (p, framed (magic, version, hash, "side", P.contents body)))
      handle IO.Io _ => () | OS.SysErr _ => ()
    end

  (* ---- the stat memo ---- *)

  (* What a file's stat says of it: its device and inode, its size, and the
     times it was last written and last changed, as text of whole numbers
     however wide; and the later of those times in seconds. A file whose
     stat is the same is the same file, written no more since -- but within
     the second its times were taken, which `at` guards (clean) *)
  type stamp = {key : string, latest : LargeInt.int}
  fun stampOf {dev : SysWord.word, ino : SysWord.word, size : Position.int, mtime : Time.time, ctime : Time.time} : stamp =
    let fun word w = SysWord.fmt StringCvt.DEC w
    in
      {key = String.concatWith ":" [word dev, word ino, Position.toString size,
                                    LargeInt.toString (Time.toMicroseconds mtime), LargeInt.toString (Time.toMicroseconds ctime)],
       latest = LargeInt.max (Time.toSeconds mtime, Time.toSeconds ctime)}
    end

  (* How a file is statted, where the program can ask: Rune's own main sets
     it, from Posix.FileSys.ST, whose ctime not every host's Basis Library
     has (MLKit's has none). Where it cannot, a file has no stamp, and no memo
     is kept or believed: a compiler built by another host hashes every
     source and links every time *)
  val stat : (string -> stamp option) ref = ref (fn _ => NONE)
  val () = CompilerState.cellRoot ("UnitStore.stat", stat)
  fun statOf (p : string) : stamp option = !stat p

  fun nowSeconds () : LargeInt.int = Time.toSeconds (Time.now ())

  (* A stat taken at `at` (seconds, taken before the stat) says what the
     file held then if the file was last written at least two seconds
     before: a write after the stat would then have given it later times.
     One written in the second of the stat, or just before it, is racily
     clean, and read again (git's rule, with whole seconds and a second
     more for a clock that is not the filesystem's) *)
  fun clean ({latest, ...} : stamp, at : LargeInt.int) : bool = latest + 2 <= at

  (* The hash of what files held, by their stat: a file's path and the mode
     its text was read in, to its stamp, when the stamp was taken, and the
     hash. Read once, from units/stat-memo of a configuration's directory,
     and written back where it changed; nothing in a key is read from it but
     a hash whose stat holds, and a memo that cannot be read or written is a
     memo that is empty *)
  type memo = {dir : string, config : string, entries : (stamp * LargeInt.int * string) StringMap.map ref, read : bool ref,
               dirty : bool ref}
  val memoSide : (string * stamp * LargeInt.int * string) list side =
    {magic = "RSM", version = 1, hash = fn (_, text) => P.hash text,
     write = P.list (fn (w, (k, {key, latest}, at, h)) =>
                       (P.string (w, k); P.string (w, key); P.string (w, LargeInt.toString latest);
                        P.string (w, LargeInt.toString at); P.string (w, h))),
     read = P.rlist (fn r =>
                       let
                         val k = P.rstring r
                         val key = P.rstring r
                         fun large r = case LargeInt.fromString (P.rstring r) of SOME n => n | NONE => raise P.Bad "not a number"
                         val latest = large r
                         val at = large r
                       in (k, {key = key, latest = latest}, at, P.rstring r) end)}
  fun memoAt (dir : string, config : string) : memo =
    {dir = dir, config = config, entries = ref StringMap.empty, read = ref false, dirty = ref false}
  fun memoRead ({dir, config, entries, read, ...} : memo) : unit =
    if !read then ()
    else
      (read := true;
       case readSide memoSide (dir, config, "stat-memo") of
         SOME es => entries := List.foldl (fn ((k, st, at, h), m) => StringMap.insert (m, k, (st, at, h))) StringMap.empty es
       | NONE => ())

  (* the hash of a file's text, read in mode (a name for the memo), by the
     memo where its stat holds, else of text (), which the memo then keeps *)
  fun hashBy (m as {entries, dirty, ...} : memo) (path : string, mode : string, text : unit -> string,
                                                   hash : string -> string) : string =
    let
      val () = memoRead m
      val k = path ^ "\000" ^ mode
      val at = nowSeconds ()
    in
      case statOf path of
        NONE => hash (text ())
      | SOME st =>
          case StringMap.find (!entries, k) of
            SOME (st', at', h) =>
              if #key st = #key st' andalso clean (st', at') then h
              else let val h = hash (text ()) in entries := StringMap.insert (!entries, k, (st, at, h)); dirty := true; h end
          | NONE => let val h = hash (text ()) in entries := StringMap.insert (!entries, k, (st, at, h)); dirty := true; h end
    end

  (* the memo written back, where it changed *)
  fun memoWrite ({dir, config, entries, dirty, ...} : memo) : unit =
    if not (!dirty) then ()
    else
      (dirty := false;
       storeSide memoSide (dir, config, "stat-memo", List.map (fn (k, (st, at, h)) => (k, st, at, h)) (StringMap.listItemsi (!entries))))

end
