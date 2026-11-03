(* The memos of a warm build (docs/units.md, A warm build; the build-system
   roadmap's D25, l and u): what a compile kept of its own last run that
   lets it skip work whose inputs are what they were. None of it is a key
   of the cache: a memo says that an output is what this work would make
   again, and is believed only where every file it rests on has the stat it
   had, racily clean (UnitStore.clean), or the bytes it had.

   The link memo: the program a link made, by a hash of what was linked --
   each unit's code by the hash of its entry or of its bytes, and where its
   files are now -- and the output's stat and the hash of its bytes. A link
   of the same units to an output that is what it wrote is not made again.

   Up to date: of a compile in units, everything it read after its plan was
   made -- every source, every MANIFEST -- with the stat each had when it was
   read, the output with its stat and its bytes' hash, and the warnings it
   gave; under a key of all the plan rests on: the command line, the
   directory, the RUNE_ variables, the compiler, the build files' text, the
   inputs, the libraries and the workspace. A compile with the same key
   whose files all have the stats they had, and whose output is what it
   wrote, gives the warnings again and does nothing else. *)
structure UnitMemo =
struct
  structure S = UnitStore
  structure P = Pickle

  (* ---- an output, by its stat and the hash of its bytes ---- *)

  type output = {path : string, stamp : S.stamp, at : LargeInt.int, hash : string}

  fun bytesOf (path : string) : string option = SOME (S.readFile path) handle IO.Io _ => NONE

  (* an output just written: its stat, taken after at, and the hash of its
     bytes, read back *)
  fun written (path : string, at : LargeInt.int) : output option =
    case (S.statOf path, bytesOf path) of
      (SOME st, SOME b) => SOME {path = path, stamp = st, at = at, hash = P.hash b}
    | _ => NONE

  (* Whether an output holds what o says: its stat the same, racily clean;
     or else, the stat the same, its bytes, which then make the stat clean
     from now (SOME of the output as it is now known); NONE where it does
     not hold *)
  fun holds ({path, stamp, at, hash} : output) : output option =
    let val now = S.nowSeconds ()
    in
      case S.statOf path of
        NONE => NONE
      | SOME st =>
          if #key st <> #key stamp then NONE
          else if S.clean (stamp, at) then SOME {path = path, stamp = stamp, at = at, hash = hash}
          else (case bytesOf path of
                  SOME b => if P.hash b = hash then SOME {path = path, stamp = st, at = now, hash = hash} else NONE
                | NONE => NONE)
    end

  fun wstamp (w : P.writer, {key, latest} : S.stamp) = (P.string (w, key); P.string (w, LargeInt.toString latest))
  fun rlarge r = case LargeInt.fromString (P.rstring r) of SOME n => n | NONE => raise P.Bad "not a number"
  fun rstamp r : S.stamp = let val key = P.rstring r in {key = key, latest = rlarge r} end
  fun woutput (w : P.writer, {path, stamp, at, hash} : output) =
    (P.string (w, path); wstamp (w, stamp); P.string (w, LargeInt.toString at); P.string (w, hash))
  fun routput r : output =
    let val path = P.rstring r val stamp = rstamp r val at = rlarge r
    in {path = path, stamp = stamp, at = at, hash = P.rstring r} end

  (* ---- the link memo ---- *)

  (* What a link of units is: the instruction set, whether the program keeps
     its units' exports, the compiler and configuration, the output, and of
     each unit in order what its code is (a hit's entry's hash and where its
     files are now, a compiled unit's bytes' hash) *)
  fun linkDigest {fingerprint : int, exports : bool, config : string, output : string, units : string list} : string =
    P.hash (String.concatWith "\000"
              (["link 1", Int.toString fingerprint, if exports then "exports" else "-", Config.identity, config, output] @ units))

  (* what a link of units was: the hash of what was linked, and the output *)
  val links : (string * output) S.side =
    {magic = "RML", version = 1, hash = fn (_, text) => P.hash text,
     write = fn (w, (digest, out)) => (P.string (w, digest); woutput (w, out)),
     read = fn r => let val d = P.rstring r in (d, routput r) end}
  fun linkName (path : string) : string = "link " ^ path

  (* the output at path, where it is what a link of digest made, which a
     link need not make again *)
  fun linked (dir : string, config : string, path : string, digest : string) : output option =
    case S.readSide links (dir, config, linkName path) of
      SOME (d, out) =>
        if d <> digest then NONE
        else
          (case holds out of
             NONE => NONE
           | SOME out' => (if out' = out then () else S.storeSide links (dir, config, linkName path, (d, out')); SOME out'))
    | NONE => NONE

  (* a link of digest has written path, the time at taken before: the
     output as it is now known *)
  fun noteLink (dir : string, config : string, path : string, digest : string, at : LargeInt.int) : output option =
    case written (path, at) of
      SOME out => (S.storeSide links (dir, config, linkName path, (digest, out)); SOME out)
    | NONE => NONE

  (* ---- up to date ---- *)

  (* What a compile read, as it read it: each file once, with its stat
     before it was read, or none where it could not be statted; the time
     taken before the first. Kept while a compile runs (Source.reading) *)
  val reads : S.stamp option StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitMemo.reads", reads)
  val readsFrom : LargeInt.int ref = ref 0
  val () = CompilerState.cellRoot ("UnitMemo.readsFrom", readsFrom)
  (* and each file whose being there it asked, with the answer *)
  val probes : bool StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitMemo.probes", probes)
  fun keepReads () : unit =
    (reads := StringMap.empty; probes := StringMap.empty; readsFrom := S.nowSeconds ();
     Source.reading := (fn p => if StringMap.member (!reads, p) then () else reads := StringMap.insert (!reads, p, S.statOf p));
     Source.probing := (fn (p, there) => probes := StringMap.insert (!probes, p, there)))
  fun stopReads () : unit = (Source.reading := (fn _ => ()); Source.probing := (fn _ => ()))

  type record = {files : (string * S.stamp) list, probes : (string * bool) list, at : LargeInt.int, output : output,
                 warnings : (Source.span * string) list}
  val records : record S.side =
    {magic = "RMU", version = 1, hash = fn (_, text) => P.hash text,
     write = fn (w, {files, probes, at, output, warnings}) =>
       (P.list (fn (w, (p, st)) => (P.string (w, p); wstamp (w, st))) (w, files);
        P.list (fn (w, (p, there)) => (P.string (w, p); P.bool (w, there))) (w, probes);
        P.string (w, LargeInt.toString at); woutput (w, output);
        P.list (fn (w, ({file, start, stop}, msg)) => (P.string (w, file); P.int (w, start); P.int (w, stop); P.string (w, msg)))
               (w, warnings)),
     read = fn r =>
       let
         val files = P.rlist (fn r => let val p = P.rstring r in (p, rstamp r) end) r
         val probes = P.rlist (fn r => let val p = P.rstring r in (p, P.rbool r) end) r
         val at = rlarge r
         val output = routput r
         val warnings = P.rlist (fn r => let val file = P.rstring r val start = P.rint r val stop = P.rint r
                                         in ({file = file, start = start, stop = stop}, P.rstring r) end) r
       in {files = files, probes = probes, at = at, output = output, warnings = warnings} end}
  (* kept beside the configurations, which a compile knows only once its
     plan is made *)
  val place = "memo"

  (* The key of a compile's record: all its plan rests on. Every RUNE_
     variable, whatever it is, and the build files by the hashes of their
     text *)
  fun key {args : string list, directory : string, lib : string, inputs : string list,
           builds : (string * string) list, workspace : string list, roots : string list} : string =
    let
      val env = List.filter (fn v => String.isPrefix "RUNE_" v) (Posix.ProcEnv.environ () handle OS.SysErr _ => [])
      fun sorted l = List.foldl (fn (x, acc) => let fun ins [] = [x] | ins (y :: r) = if x < y then x :: y :: r else y :: ins r
                                                in ins acc end) [] l
    in
      P.hash (String.concatWith "\000"
                (["up to date 1", Config.identity, P.probe (), directory, lib] @ ["|"] @ args @ ["|"] @ sorted env
                 @ ["|"] @ inputs @ ["|"] @ List.map (fn (p, r) => p ^ " " ^ r) builds @ ["|"] @ workspace @ ["|"] @ roots))
    end

  (* the warnings to give again where nothing a compile of key rests on has
     changed since it was made, and its output is what it wrote; NONE where
     something has *)
  fun upToDate (dir : string, key : string) : (Source.span * string) list option =
    case S.readSide records (dir, place, key) of
      NONE => NONE
    | SOME {files, probes, at, output, warnings} =>
        let
          fun same (p, st) = case S.statOf p of SOME st' => #key st' = #key st andalso S.clean (st, at) | NONE => false
          fun answered (p, there) = (OS.FileSys.access (p, []) handle OS.SysErr _ => false) = there
        in
          if not (List.all same files andalso List.all answered probes) then NONE
          else
            case holds output of
              NONE => NONE
            | SOME out =>
                ((if out = output then ()
                  else S.storeSide records (dir, place, key, {files = files, probes = probes, at = at, output = out,
                                                              warnings = warnings}));
                 SOME warnings)
        end

  (* a compile of key made the output out, with these warnings, from what
     it read since keepReads; every file read could be statted *)
  fun noteUpToDate (dir : string, key : string, out : output, warnings : (Source.span * string) list) : unit =
    let
      val files = StringMap.listItemsi (!reads)
    in
      if List.exists (fn (_, st) => not (isSome st)) files then ()
      else
        S.storeSide records (dir, place, key, {files = List.map (fn (p, st) => (p, valOf st)) files,
                                               probes = StringMap.listItemsi (!probes), at = !readsFrom,
                                               output = out, warnings = warnings})
    end
end
