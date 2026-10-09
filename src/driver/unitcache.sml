(* The cache of compiled units (docs/units.md, *The cache*; the incremental
   roadmap's D14 and M6): what a compile in units made of each unit -- its
   basis (UnitBasis) and its code (UnitFile) -- kept in a directory by the
   configuration that made it, by what the unit is, and by what it used of
   the units before it, so that a compile after it takes the unit from
   there rather than compiling it again.

   The configuration is the compiler's identity (Config.identity, a hash of
   its sources), the versions of the files, the instruction set, and every
   option that changes what it makes. A unit is keyed by its name, the hash
   of its source and whether it may use _prim; under the key are its
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
  val version = 3

  (* what a unit's entry holds: its usages, the warnings its compile gave,
     which a compile that takes it from the cache gives again, the name its
     source had in the compile, which its code's files name it by, its
     basis, and its code's file *)
  type entry = {usages : (string * string) list, warnings : string list, file : string, pickle : string, code : string}

  (* an entry found, or why there is none *)
  datatype found = Found of entry | Missed of string

  (* The hash of the configuration of this compile *)
  fun configuration () : string =
    P.hash (String.concatWith "\000"
              [Config.identity, Int.toString version, Int.toString UnitBasis.version, Int.toString UnitFile.version,
               Int.toString (Pipeline.fingerprint ()), Int.toString (!Pass.level),
               (case !Pass.only of NONE => "-" | SOME ps => String.concatWith "," ps),
               Int.toString (!Target.intBits),
               (case !Pass.fuel of NONE => "-" | SOME n => Int.toString n)])

  (* The directory of the cache: --cache-dir, else RUNE_CACHE, else .rune in
     the directory of the first input; NONE with --no-cache *)
  fun directory () : string option =
    if !Options.noCache then NONE
    else
      case !Options.cacheDir of
        SOME d => SOME d
      | NONE =>
          case OS.Process.getEnv "RUNE_CACHE" of
            SOME d => if d = "" then NONE else SOME d
          | NONE =>
              case !Options.inputs of
                first :: _ => SOME (OS.Path.joinDirFile {dir = OS.Path.dir first, file = ".rune"})
              | [] => SOME ".rune"

  (* The frozen Basis Library (the incremental roadmap's D8): a cache that
     every unit of the library was compiled into once, `cache` beside the
     library's files (make basis-cache; installed with them), which a
     compile reads after its own cache and never writes; NONE with
     --no-cache or where there is none *)
  fun frozen () : string option =
    if !Options.noCache then NONE
    else
      case !Options.libDir of
        NONE => NONE
      | SOME lib =>
          let val d = OS.Path.joinDirFile {dir = lib, file = "cache"}
          in if (OS.FileSys.isDir d handle OS.SysErr _ => false) then SOME d else NONE end

  (* the key of a unit *)
  fun key {name : string, text : string, allow : bool} : string =
    P.hash (String.concatWith "\000" [name, P.hash text, if allow then "1" else "0"])

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
           val pickle = P.rstring r
           val code = P.rstring r
         in
           if not (P.atEnd r) orelse P.hash (String.extract (s, at, NONE)) <> h then Missed "a damaged entry"
           else Found {usages = us, warnings = warnings, file = file, pickle = pickle, code = code}
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
      fun try ([], why) = Missed why
        | try (n :: rest, why) =
            case read (OS.Path.joinDirFile {dir = d, file = n}) of
              Found (e as {usages, ...}) =>
                (case UnitBasis.broken usages of
                   NONE => Found e
                 | SOME u => try (rest, if why = "no entry" then "its entries used " ^ u ^ ", which is another now" else why))
            | Missed w => try (rest, if why = "no entry" then w else why)
      (* in an order of their own, whatever the directory's: any whose usages
         hold is the same *)
      fun insert (n, []) = [n]
        | insert (n, m :: rest) = if n < m then n :: m :: rest else m :: insert (n, rest)
    in
      try (List.foldl insert [] names, "no entry")
    end

  (* every directory of a path, made where it is not there *)
  fun mkdirs (d : string) : unit =
    if d = "" orelse d = "." orelse d = "/" orelse (OS.FileSys.isDir d handle OS.SysErr _ => false) then ()
    else (mkdirs (OS.Path.dir d); OS.FileSys.mkDir d handle OS.SysErr _ => ())

  (* a name of its own for what is being written *)
  val written = ref 0
  fun unique () =
    (written := !written + 1;
     LargeInt.toString (Time.toMicroseconds (Time.now ()) mod 1000000000000) ^ "-" ^ Int.toString (!written))

  (* store: the entry of a key written, whole or not at all, by the hash of
     its usages, beside the key's others; a cache that cannot be written is
     a cache that is not there *)
  fun store (dir : string, config : string, k : string, {usages = us, warnings, file, pickle, code} : entry) : unit =
    let
      val d = keyDir (dir, config, k)
      val u = P.writer ()
      val () = usages (u, us)
      val p = OS.Path.joinDirFile {dir = d, file = P.hash (P.contents u)}
      val tmp = p ^ ".tmp-" ^ unique ()
      val body = P.writer ()
      val () = (usages (body, us); P.list P.string (body, warnings); P.string (body, file); P.string (body, pickle);
                P.string (body, code))
      val b = P.contents body
      val w = P.writer ()
      val () = (P.bytes (w, magic); P.nat (w, version); P.string (w, P.hash b); P.bytes (w, b))
    in
      (mkdirs d;
       let val out = BinIO.openOut tmp
       in BinIO.output (out, Byte.stringToBytes (P.contents w)); BinIO.closeOut out end;
       OS.FileSys.rename {old = tmp, new = p})
      handle IO.Io _ => ((OS.FileSys.remove tmp) handle OS.SysErr _ => ())
           | OS.SysErr _ => ((OS.FileSys.remove tmp) handle OS.SysErr _ => ())
    end
end
