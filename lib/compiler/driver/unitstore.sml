(* The store of what a compile in units made (docs/units.md, *The store*;
   the build-system roadmap's D24): a directory, in it a directory by each
   configuration, in that a directory by each key, and in that an entry by
   each head. It knows how an entry is kept, how one is found, what is kept
   beside the entries and how a store is kept small, and nothing of what a
   unit is: an entry's head and sections are of whatever types a client's
   format writes and reads, a client's holds says of a head whether its
   entry stands, and a configuration is a list of settings its client
   names. So it holds for any language compiled in units, and depends on
   Pickle alone, and the hash its client gives it.

   An entry is one file, written whole under another name and renamed, so
   that a compile at the same time never sees half of one. Its head comes
   first, with the hash of its bytes, then its sections, each with its own:
   a lookup reads the heads of a key's entries alone and judges them, and
   reads the rest of an entry only where its head stands. A head that a
   damage makes refuse is a miss, and one that stands is held to its hash
   before its entry is taken, and each section to its own as its client
   reads it. One that does not hold what its hashes say, or that cannot be
   read, is not there. Its name in its key's directory is the hash of its
   head's bytes, so that a compile that made the same head again writes
   over it. Nothing in a key is a time.

   A store is one writable directory, its overlay, read before read-only
   ones, its layers. What a compile takes from the overlay -- an entry, a
   file kept beside the entries -- has its time set to now where it is an
   hour old (Go's rule), and trim removes from the overlay what no compile
   has taken for longer than an age, and then, the least recently taken
   first, what makes it larger than a size. It runs after a build, never
   during one, and a file gone is a file that is not there: what a compile
   does not find, it compiles or does again.

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
     that asks (a client counts them); how its head is written and read;
     the bytes of its sections, each hashed apart; and what it makes of
     them, given a section's bytes by its place as it asks for one, held to
     its hash. A reader reads them all, and nothing else *)
  type ('h, 's) format =
    {magic : string, version : int, hash : string * string -> string,
     writeHead : P.writer * 'h -> unit, readHead : P.reader -> 'h,
     sections : 's -> string list, ofSections : (int -> string) -> 's}

  type ('h, 's) entry = {head : 'h, sections : 's}

  (* an entry's file read: the entry and the hash of what it holds, which
     names its bytes (a link of the units it holds is the same where these
     are: UnitMemo), or why it is none *)
  datatype ('h, 's) read = Read of ('h, 's) entry * string | Unread of string

  (* What a client's holds says of an entry's head: it stands; it stands,
     but behind any that simply stands; it does not, and why *)
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
  fun sortBy (less : 'a * 'a -> bool) (xs : 'a list) : 'a list =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if less (y, x) then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun pairs (a :: b :: rest) = merge (a, b) :: pairs rest
        | pairs l = l
      fun all [] = []
        | all [l] = l
        | all ls = all (pairs ls)
    in all (List.map (fn x => [x]) xs) end
  fun sorted (names : string list) : string list = sortBy (fn (a, b) => a < b) names

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

  (* ---- time ---- *)

  val hour = Time.fromSeconds 3600

  (* What a compile takes from an overlay, its time set to now where it is
     an hour old or more: so a file's time is when a compile last took it,
     within the hour, and trim keeps what is taken. A time decides here
     what stays in a store, and no compile's result *)
  fun touch (p : string) : unit =
    (if Time.< (Time.+ (OS.FileSys.modTime p, hour), Time.now ()) then OS.FileSys.setTime (p, NONE) else ())
    handle OS.SysErr _ => ()

  (* ---- reading ---- *)

  fun readFile (p : string) : string =
    let val ins = BinIO.openIn p
    in Byte.bytesToString (BinIO.inputAll ins) before BinIO.closeIn ins end

  (* An entry's file: its marks, the hash of its head's bytes, the head,
     the number of its sections, the hash of each, and each:

       magic version string(head's hash) string(head)
       nat(n) string(hash 1) ... string(hash n) string(section 1) ... string(section n)

     The hash of what it holds is that of its head's hash and its
     sections' *)
  fun sumOf (hash : string * string -> string, headSum : string, sums : string list) : string =
    hash ("sum", String.concatWith "\000" (headSum :: sums))

  exception Damaged

  (* an entry's file opened and its head read, not yet held to its hash:
     the head's bytes, its hash, and the stream past them with what was
     read of it beyond them *)
  type opened = {ins : BinIO.instream, head : string, headSum : string, rest : string}

  fun openEntry ({magic, version, ...} : ('h, 's) format) (p : string) : opened =
    let
      val ins = BinIO.openIn p
      fun more n = Byte.bytesToString (BinIO.inputN (ins, n))
    in
      (let
         val first = more 4096
         val r = P.reader first
         val () = if P.rbytes (r, 3) = magic then () else raise P.Bad "not an entry"
         val () = if P.rnat r = version then () else raise P.Bad "an entry of another version"
         val headSum = P.rstring r
         val n = P.rnat r
         val at = !(#pos r)
         val have = String.size first - at
       in
         if n <= have
         then {ins = ins, head = String.substring (first, at, n), headSum = headSum, rest = String.extract (first, at + n, NONE)}
         else
           let val tail = if Position.> (Position.fromInt (n - have), OS.FileSys.fileSize p) then raise P.Bad "cut short"
                          else more (n - have)
           in
             if String.size tail <> n - have then raise P.Bad "cut short"
             else {ins = ins, head = String.extract (first, at, NONE) ^ tail, headSum = headSum, rest = ""}
           end
       end)
      handle e => (BinIO.closeIn ins; raise e)
    end

  (* the client's head of the bytes of one; P.Bad where they are not one *)
  fun headOf ({readHead, ...} : ('h, 's) format) (bytes : string) : 'h =
    let
      val r = P.reader bytes
      val h = readHead r
    in if P.atEnd r then h else raise P.Bad "more than a head" end

  (* the rest of an opened entry, its head held to its hash and each
     section to its own as the client asks for it: the entry and the hash
     of what it holds; the stream closed *)
  fun whole (format as {hash, ofSections, ...} : ('h, 's) format) ({ins, head, headSum, rest} : opened, h : 'h)
      : ('h, 's) entry * string =
    let
      val () = if hash ("read", head) = headSum then () else (BinIO.closeIn ins; raise Damaged)
      val s = (rest ^ Byte.bytesToString (BinIO.inputAll ins) handle e => (BinIO.closeIn ins; raise e)) before BinIO.closeIn ins
      val r = P.reader s
      val n = P.rnat r
      fun strings (0, acc) = List.rev acc
        | strings (k, acc) = strings (k - 1, P.rstring r :: acc)
      val sums = Vector.fromList (strings (n, []))
      val parts = Vector.fromList (strings (n, []))
      val () = if P.atEnd r then () else raise P.Bad "more than an entry"
      val held = Array.array (n, false)
      fun section i =
        let val b = Vector.sub (parts, i)
        in
          if Array.sub (held, i) then b
          else if hash ("read", b) = Vector.sub (sums, i) then (Array.update (held, i, true); b)
          else raise Damaged
        end
        handle Subscript => raise P.Bad "no such section"
    in ({head = h, sections = ofSections section}, sumOf (hash, headSum, Vector.foldr (op ::) [] sums)) end

  (* why a file is no entry *)
  fun unread (e : exn) : string =
    case e of
      IO.Io _ => "an entry that cannot be read"
    | Damaged => "a damaged entry"
    | P.Bad why => "a damaged entry: " ^ why
    | Overflow => "a damaged entry"
    | Subscript => "a damaged entry"
    | Size => "a damaged entry"
    | OS.SysErr _ => "an entry that cannot be read"
    | e => raise e

  (* an entry's file read whole *)
  fun read (format : ('h, 's) format) (p : string) : ('h, 's) read =
    (let
       val opened = openEntry format p
       val h = headOf format (#head opened) handle e => (BinIO.closeIn (#ins opened); raise e)
     in Read (whole format (opened, h)) end)
    handle e => Unread (unread e)

  (* A name with .tmp- in it is a file being written, or one that a compile
     that died left there, which nothing takes (withTemporary). None is
     written for long: an hour old, it is the second, and it is removed where
     a compile comes across it. What a time decides here is whether a file
     that no compile reads stays, and no compile's result. *)
  fun sweep (path : string) : unit =
    if Time.< (Time.now (), Time.+ (OS.FileSys.modTime path, hour)) then ()
    else OS.FileSys.remove path handle OS.SysErr _ => ()

  (* the names of a key's entries, the files being written swept where old *)
  fun entryNames (d : string) : string list =
    List.filter (fn n => if String.isSubstring ".tmp-" n
                         then ((sweep (join (d, n)) handle OS.SysErr _ => ()); false)
                         else true)
                (listDir d)

  (* The entries of a key whose heads the client's holds lets stand, in an
     order of their own, whatever the directory's, since any that stands is
     the same: the first that stands, else the first that stands behind, or
     why there is none, the first reason given. Only the heads of those
     refused are read, and not held to their hashes: a damage that makes a
     head refuse is a miss. overlay: whether dir is a store's overlay, whose
     entries have their times kept (touch) *)
  fun findAt (format : ('h, 's) format, holds : 'h -> verdict) {overlay : bool} (dir : string, config : string, k : string)
      : ('h, 's) found =
    let
      val d = keyDir (dir, config, k)
      fun first (why, w) = if why = "no entry" then w else why
      fun taken (p, e) = (if overlay then touch p else (); e)
      (* the head of the entry at p, its stream open; or why it is none *)
      fun look p =
        (let
           val opened = openEntry format p
         in
           (SOME (opened, headOf format (#head opened)), "")
           handle e => (BinIO.closeIn (#ins opened); raise e)
         end)
        handle e => (NONE, unread e)
      fun again (p, why) =
        case look p of
          (SOME (opened, h), _) =>
            ((case holds h of
                Refused w => (BinIO.closeIn (#ins opened); Missed w)
              | _ => FoundBehind (taken (p, whole format (opened, h))))
             handle e => Missed (unread e))
        | (NONE, w) => Missed (first (why, w))
      fun try ([], why, behind) =
            (case behind of
               SOME p => again (p, why)
             | NONE => Missed why)
        | try (n :: rest, why, behind) =
            let val p = join (d, n)
            in
              case look p of
                (NONE, w) => try (rest, first (why, w), behind)
              | (SOME (opened, h), _) =>
                  case (holds h handle e => (BinIO.closeIn (#ins opened); raise e)) of
                    Stands =>
                      ((Found (taken (p, whole format (opened, h))))
                       handle e => try (rest, first (why, unread e), behind))
                  | StandsBehind => (BinIO.closeIn (#ins opened); try (rest, why, case behind of NONE => SOME p | some => some))
                  | Refused w => (BinIO.closeIn (#ins opened); try (rest, first (why, w), behind))
            end
    in
      try (sorted (entryNames d), "no entry", NONE)
    end

  (* in a directory that is no overlay, whose times are not kept *)
  fun find (format : ('h, 's) format, holds : 'h -> verdict) (dir : string, config : string, k : string) : ('h, 's) found =
    findAt (format, holds) {overlay = false} (dir, config, k)

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
  fun store ({magic, version, hash, writeHead, sections, ...} : ('h, 's) format, settings : (string * string) list)
            (dir : string, config : string, k : string, {head, sections = s} : ('h, 's) entry) : string =
    let
      val d = keyDir (dir, config, k)
      val u = P.writer ()
      val () = writeHead (u, head)
      val headBytes = P.contents u
      val headSum = hash ("store", headBytes)
      val p = join (d, headSum)
      val parts = sections s
      val sums = List.map (fn b => hash ("store", b)) parts
      val bytes =
        let val w = P.writer ()
        in
          P.bytes (w, magic); P.nat (w, version); P.string (w, headSum); P.string (w, headBytes);
          P.nat (w, List.length parts); List.app (fn h => P.string (w, h)) sums; List.app (fn b => P.string (w, b)) parts;
          P.contents w
        end
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
      sumOf (hash, headSum, sums)
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

  fun readSideAt ({magic, version, hash, read, ...} : 'a side) {overlay : bool} (dir : string, config : string, name : string)
      : 'a option =
    (let
       val p = sideFile (hash, dir, config, name)
       val s = readFile p
       val r = P.reader s
       val () = if P.rbytes (r, 3) = magic andalso P.rnat r = version then () else raise P.Bad "not a side file"
       val h = P.rstring r
       val at = !(#pos r)
       val i = P.rstring r
       val v = read r
     in
       if i = name andalso P.atEnd r andalso hash ("side", String.extract (s, at, NONE)) = h
       then ((if overlay then touch p else ()); SOME v) else NONE
     end)
    handle IO.Io _ => NONE | P.Bad _ => NONE | Overflow => NONE | Subscript => NONE

  (* in an overlay, whose files have their times kept (touch) *)
  fun readSide (side : 'a side) (dir : string, config : string, name : string) : 'a option =
    readSideAt side {overlay = true} (dir, config, name)

  (* in the first of dirs that has it: a store's overlay, then its layers,
     which are only read *)
  fun sideIn (side : 'a side) (dirs : string list, config : string) (name : string) : 'a option =
    case dirs of
      [] => NONE
    | overlay :: layers =>
        case readSide side (overlay, config, name) of
          SOME v => SOME v
        | NONE => List.foldl (fn (d, found) => case found of SOME _ => found
                                                            | NONE => readSideAt side {overlay = false} (d, config, name))
                             NONE layers

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

  (* The hash of what files held, by their stat: a file's path from the
     root of the machine's filesystem, since compiles in other directories
     share a store, and the mode its text was read in, to its stamp, when
     the stamp was taken, and the hash. Read once, from units/stat-memo of a configuration's directory,
     and written back where it changed; nothing in a key is read from it but
     a hash whose stat holds, and a memo that cannot be read or written is a
     memo that is empty *)
  type memo = {dir : string, config : string, cwd : string, entries : (stamp * LargeInt.int * string) StringMap.map ref,
               read : bool ref, dirty : bool ref}
  val memoSide : (string * stamp * LargeInt.int * string) list side =
    {magic = "RSM", version = 2, hash = fn (_, text) => P.hash text,
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
    {dir = dir, config = config, cwd = OS.FileSys.getDir () handle OS.SysErr _ => "", entries = ref StringMap.empty,
     read = ref false, dirty = ref false}
  fun memoRead ({dir, config, entries, read, ...} : memo) : unit =
    if !read then ()
    else
      (read := true;
       case readSide memoSide (dir, config, "stat-memo") of
         SOME es => entries := List.foldl (fn ((k, st, at, h), m) => StringMap.insert (m, k, (st, at, h))) StringMap.empty es
       | NONE => ())

  (* the hash of a file's text, read in mode (a name for the memo), by the
     memo where its stat holds, else of text (), which the memo then keeps *)
  fun hashBy (m as {entries, dirty, cwd, ...} : memo) (path : string, mode : string, text : unit -> string,
                                                        hash : string -> string) : string =
    let
      val () = memoRead m
      val k = (if OS.Path.isAbsolute path orelse cwd = "" then path else OS.Path.mkAbsolute {path = path, relativeTo = cwd})
              ^ "\000" ^ mode
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

  (* ---- keeping a store small ---- *)

  (* What trim removes from an overlay: what no compile has taken for
     longer than age, and then, the least recently taken first, what makes
     it larger than size, in bytes; NONE, no limit. Sizes are LargeInt's,
     which no host's file positions bound *)
  type limits = {age : Time.time option, size : LargeInt.int option}
  (* what it found there, and what it removed *)
  type trimmed = {files : int, bytes : LargeInt.int, removed : int, freed : LargeInt.int}

  (* every file under d, with its size and time, no link followed; a file
     being written left out, and swept where a compile that died left it *)
  fun filesUnder (d : string) : (string * LargeInt.int * Time.time) list =
    List.foldl (fn (n, acc) =>
                  let val p = join (d, n)
                  in
                    (if OS.FileSys.isLink p then acc
                     else if OS.FileSys.isDir p then filesUnder p @ acc
                     else if String.isSubstring ".tmp-" n then (sweep p; acc)
                     else (p, Position.toLarge (OS.FileSys.fileSize p), OS.FileSys.modTime p) :: acc)
                    handle OS.SysErr _ => acc
                  end)
               [] (listDir d)

  (* the directories under d that are empty, removed, deepest first; d
     stays. One a compile has just made is made again by it, or what it
     would have written there is not kept *)
  fun pruneUnder (d : string) : unit =
    List.app (fn n => let val p = join (d, n)
                      in
                        if (OS.FileSys.isDir p andalso not (OS.FileSys.isLink p)) handle OS.SysErr _ => false
                        then (pruneUnder p; OS.FileSys.rmDir p handle OS.SysErr _ => ())
                        else ()
                      end)
             (listDir d)

  (* The file whose time says when the overlay dir was last trimmed: in
     memo/units, beside the memos of builds, as nothing that is not an
     entry is anywhere but in a units directory *)
  fun trimmedFile (dir : string) : string = join (unitsDir (dir, "memo"), "trimmed")

  (* The overlay dir trimmed to limits: what it held, and what went. A file
     that cannot be removed stays, and one another compile took or wrote
     since it was looked at may go: a compile that does not find what it
     looks for compiles it again. Never during a build: a compile trims
     after its own work is done (UnitCache.trimAfter) *)
  fun trim ({age, size} : limits) (dir : string) : trimmed =
    let
      val now = Time.now ()
      val stamp = trimmedFile dir
      val files = List.filter (fn (p, _, _) => p <> stamp) (filesUnder dir)
      val zero = LargeInt.fromInt 0
      val total = List.foldl (fn ((_, n, _), t) => LargeInt.+ (t, n)) zero files
      fun gone p = (OS.FileSys.remove p; true) handle OS.SysErr _ => false
      val old = case age of
                  NONE => (fn _ => false)
                | SOME a => (fn (_, _, t) => Time.< (Time.+ (t, a), now))
      val (removed, freed) =
        List.foldl (fn (f as (p, n, _), (k, b)) => if old f andalso gone p then (k + 1, LargeInt.+ (b, n)) else (k, b))
                   (0, zero) files
      val young = sortBy (fn ((_, _, a), (_, _, b)) => Time.< (a, b)) (List.filter (not o old) files)
      fun shrink ([], k, b, _) = (k, b)
        | shrink ((p, n, _) :: rest, k, b, left) =
            case size of
              SOME limit => if LargeInt.<= (left, limit) then (k, b)
                            else if gone p then shrink (rest, k + 1, LargeInt.+ (b, n), LargeInt.- (left, n))
                            else shrink (rest, k, b, left)
            | NONE => (k, b)
      val (removed, freed) = shrink (young, removed, freed, LargeInt.- (total, freed))
    in
      pruneUnder dir;
      {files = List.length files, bytes = total, removed = removed, freed = freed}
    end

  (* whether the overlay dir was last trimmed longer ago than every, or
     never: one stat *)
  fun trimDue (every : Time.time) (dir : string) : bool =
    (OS.FileSys.isDir dir handle OS.SysErr _ => false)
    andalso ((Time.< (Time.+ (OS.FileSys.modTime (trimmedFile dir), every), Time.now ())) handle OS.SysErr _ => true)

  (* the overlay dir marked trimmed now, before it is, so that another
     compile does not trim it too *)
  fun markTrimmed (dir : string) : unit =
    let val p = trimmedFile dir
    in
      (if (OS.FileSys.access (p, []) handle OS.SysErr _ => false) then OS.FileSys.setTime (p, NONE)
       else (mkdirs (OS.Path.dir p);
             publish (p, "the time of this file is when this store was last trimmed (docs/units.md, The store)\n")))
      handle IO.Io _ => () | OS.SysErr _ => ()
    end

end
