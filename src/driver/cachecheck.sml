(* The independent checks of the cache that need a compile to fork
   (docs/testing.md, The checks of the cache). Neither runs in a build
   that does not ask for it.

   Root blanking: RUNE_BLANK_ROOTS=FILE. Before each unit it is asked of,
   every root of the compiler (CompilerState.names) is put back at the
   sealed baseline, one at a time, in a child, which then compiles the
   unit; a line of FILE gives the digest of what that made, and the
   parent's own compile gives the line it is held to. A root whose digest
   differs is one the compile reads: the test (bin/rune-incremental blank)
   wants it covered by a key, a usage or a basis.

   Verifying an entry taken across a unit that changed (--verify-cache): it
   names the old unit, so its bytes are not what compiling the unit gives
   (build-cache issue 15). What can be compared is the same thing made
   from each side: the entry loaded with its names remapped, and the unit
   as compiled, each loaded and its basis written again, and each one's
   code read and written, its identity left out. It is done in a child,
   since it leaves the session's tables as no compile would. M4's step 2
   makes a basis written again the same bytes, and the rest of this goes. *)
structure CacheCheck =
struct
  structure P = Posix.Process

  fun flush () = (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr)

  (* ---- root blanking ---- *)

  val log = OS.Process.getEnv "RUNE_BLANK_ROOTS"
  fun blanking () : bool = isSome log
  (* at the start of a compile: the baseline is what the modules left *)
  fun seal () = if blanking () then CompilerState.seal () else ()
  (* in a child, the root it blanked *)
  val blanked : (int * string) option ref = ref NONE

  fun note (unit', index, root, digest) =
    let val out = TextIO.openAppend (valOf log)
    in
      TextIO.output (out, String.concatWith "\t" [unit', Int.toString index, root, digest] ^ "\n");
      TextIO.closeOut out
    end

  (* RUNE_BLANK_UNITS=A,B: those units; else the input files *)
  fun asked (name : string) : bool =
    case OS.Process.getEnv "RUNE_BLANK_UNITS" of
      SOME names => List.exists (fn n => n = name) (String.fields (fn c => c = #",") names)
    | NONE => List.exists (fn n => n = name) (!CompilerSettings.inputs)

  (* before a unit is compiled: a child for each root, which comes back from
     here, the root blanked, and compiles the unit *)
  fun blankEach (name : string) : unit =
    if not (blanking ()) orelse not (asked name) then ()
    else
      let
        fun quiet () =
          let val null = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_WRONLY, Posix.FileSys.O.flags [])
          in Posix.IO.dup2 {old = null, new = Posix.FileSys.stdout}; Posix.IO.dup2 {old = null, new = Posix.FileSys.stderr} end
        fun go (_, []) = ()
          | go (i, root :: rest) =
              (flush ();
               case P.fork () of
                 NONE =>
                   (quiet ();
                    (* a root that sends the compile round for ever is one
                       it reads, as one that stops it is *)
                    ignore (P.alarm (Time.fromSeconds 300));
                    CompilerState.blank i;
                    blanked := SOME (i, root))
               | SOME pid =>
                   (case #2 (P.waitpid (P.W_CHILD pid, [])) of
                      P.W_EXITED => ()
                    | _ => note (name, i, root, "crash");
                    go (i + 1, rest)))
      in go (0, CompilerState.names ()) end

  (* what a compile of the unit came to. In a child that ends it *)
  fun blankResult (name : string, digest : unit -> string) : unit =
    case !blanked of
      SOME (i, root) => (note (name, i, root, digest ()); P.exit 0w0)
    | NONE => if blanking () andalso asked name then note (name, ~1, "-", digest ()) else ()

  (* ---- an entry taken across a unit that changed ---- *)

  type unitForm = {basis : string, code : string}
  datatype 'a outcome = Done of 'a | Refused of string

  fun formBytes ({basis, code} : unitForm) : string =
    let val w = Pickle.writer ()
    in Pickle.string (w, basis); Pickle.string (w, code); Pickle.contents w end
  fun formOf (bytes : string) : unitForm =
    let
      val r = Pickle.reader bytes
      val basis = Pickle.rstring r
    in {basis = basis, code = Pickle.rstring r} end

  (* f's result, from a child, or what it raised *)
  fun inChild (f : unit -> string) : string outcome =
    let
      val tmp = OS.FileSys.tmpName ()
      fun put text =
        let val out = BinIO.openOut tmp
        in BinIO.output (out, Byte.stringToBytes text); BinIO.closeOut out end
      fun got () =
        let
          val inp = BinIO.openIn tmp
          val text = Byte.bytesToString (BinIO.inputAll inp) before BinIO.closeIn inp
        in (OS.FileSys.remove tmp handle OS.SysErr _ => ()); text end
    in
      flush ();
      (* no child on Windows: such an entry is compiled, and not compared *)
      case (SOME (P.fork ()) handle OS.SysErr _ => NONE) of
        NONE => ((OS.FileSys.remove tmp handle OS.SysErr _ => ()); Refused "this system makes no child to load it in")
      | SOME NONE =>
          ((put ("=" ^ f ())
            handle UnitBasis.Missing i => put ("!it names " ^ i)
                 | e => put ("!" ^ General.exnMessage e));
           P.exit 0w0)
      | SOME (SOME pid) =>
          let
            val _ = P.waitpid (P.W_CHILD pid, [])
            val text = got () handle IO.Io _ => "!its child left nothing"
          in
            if String.isPrefix "=" text then Done (String.extract (text, 1, NONE))
            else Refused (String.extract (text, 1, NONE))
          end
    end
  fun forms (Done bytes) = Done (formOf bytes)
    | forms (Refused why) = Refused why

  (* the name both sides' code is given, which is not a unit's: the code of
     a unit names its identity, and that is what cannot be the same *)
  val noIdentity = "verified"

  fun written (fingerprint : int, x : UnitBasis.exported, u : Link.unitCode) : unitForm =
    {basis = UnitBasis.basisOf (#pickle x),
     code = String.concat (UnitFile.chunks (fingerprint, UnitBasis.renamed (u, noIdentity)))}

  type place = {start : unit -> UnitBasis.start, name : string, ident : string, text : unit -> string, mode : Source.mode}

  (* the entry, loaded here with its names remapped; Refused where it cannot
     be, which a normal build takes for a miss *)
  fun ofEntry ({pickle, identity, code, file, others, ...} : UnitCache.entry, {start, name, ident, text, mode} : place,
               paths : string -> (int * int * string) list option) : unitForm outcome =
    forms (inChild (fn () =>
      let
        val (fp, u) = UnitFile.read code
        val remap = UnitBasis.remapping (pickle, u, paths)
        val u = UnitBasis.remapKeys (u, remap)
        val () = Option.app (fn i => raise UnitBasis.Missing i) (UnitBasis.absent u)
        val s = start ()
        val l = UnitBasis.loadKnown ({pickle = pickle, sidecar = "", file = name, at = #counters s}, SOME identity, remap)
        val x = UnitBasis.exportAgain ({start = s, name = ident, file = name, mode = mode}, l)
      in formBytes (written (fp, x, UnitBasis.relocate (u, file, name, others))) end))

  (* the unit just compiled, which code is and loaded its basis *)
  fun ofCompile (fingerprint : int, bytes : string, l : UnitBasis.result, {start, name, ident, text, mode} : place)
      : unitForm outcome =
    forms (inChild (fn () =>
      let
        val (_, u) = UnitFile.read bytes
        val x = UnitBasis.exportAgain ({start = start (), name = ident, file = name, mode = mode}, l)
      in formBytes (written (fingerprint, x, u)) end))

  (* what differs, by the first byte; NONE: nothing *)
  fun difference (a : unitForm, b : unitForm) : string option =
    let
      fun first (x, y) =
        let
          val n = Int.min (size x, size y)
          fun go i = if i >= n then i else if String.sub (x, i) = String.sub (y, i) then go (i + 1) else i
        in go 0 end
      fun at (what, x, y) =
        if x = y then NONE else SOME (what ^ ", at byte " ^ Int.toString (first (x, y)) ^ " of " ^ Int.toString (size x))
    in
      case at ("its basis", #basis a, #basis b) of
        SOME d => SOME d
      | NONE => at ("its code", #code a, #code b)
    end
end
