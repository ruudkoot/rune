(* The passes of the compiler and what can be asked of each
   (docs/plans/middle-end.md, M2; docs/ir.md): every stage from one
   intermediate representation to the next is run by `stage`, which prints
   it before or after when asked (--dump-before, --dump-after), checks what
   it made (--lint), and says what it cost (--pass-stats). A pass that
   rewrites asks `spend` before each rewrite, so that --fuel can stop the
   rewriting after N of them: halving N finds the one rewrite that breaks a
   program (bin/rune-measure bisect-fuel). *)
structure Pass =
struct
  (* The optimisation level, -O0 to -O2, and the options of the passes. *)
  val level = ref 1
  val () = CompilerState.cellRoot ("Pass.level", level)
  val only : string list option ref = ref NONE     (* --passes: the optional passes to run *)
  val () = CompilerState.cellRoot ("Pass.only", only)
  val dumpBefore : string list ref = ref []
  val () = CompilerState.cellRoot ("Pass.dumpBefore", dumpBefore)
  val dumpAfter : string list ref = ref []
  val () = CompilerState.cellRoot ("Pass.dumpAfter", dumpAfter)
  val lint = ref false
  val () = CompilerState.cellRoot ("Pass.lint", lint)
  (* --lint, or RUNE_LINT set and not empty: what the tests compile with
     (bin/rune-test sets it), the REPL's and the compiler library's compiles
     too, which take no flags *)
  fun linting () = !lint orelse (case OS.Process.getEnv "RUNE_LINT" of SOME s => s <> "" | NONE => false)
  val stats = ref false
  val () = CompilerState.cellRoot ("Pass.stats", stats)
  (* the live heap's bytes after a full collection, where the program can
     ask its runtime (Rune's own main sets it; the hosts' builds cannot):
     --pass-stats with RUNE_MEM set prints it after each unit *)
  val liveBytes : (unit -> int) ref = ref (fn () => ~1)
  val () = CompilerState.cellRoot ("Pass.liveBytes", liveBytes)
  val fuel : int option ref = ref NONE
  val () = CompilerState.cellRoot ("Pass.fuel", fuel)

  (* Whether the passes see the whole program (docs/plans/incremental-
     compilation.md, M2). With --units they see one unit at a time, after
     the units before it, and every top-level binding may be named by a unit
     after it: Shake does not run, and neither Workers nor Simplify drops a
     function of the top level it no longer names. *)
  val whole = ref true
  val () = CompilerState.cellRoot ("Pass.whole", whole)

  (* Whether an optional pass runs at the level given: --passes names the
     ones to run, whatever the level; otherwise a pass runs from its level
     up. *)
  fun enabled (name : string, fromLevel : int) : bool =
    case !only of
      SOME names => List.exists (fn n => n = name) names
    | NONE => !level >= fromLevel

  (* Whether a rewrite may be made: always, unless --fuel has run out. *)
  fun spend () : bool =
    case !fuel of
      NONE => true
    | SOME 0 => false
    | SOME n => (fuel := SOME (n - 1); true)

  fun asked (names : string list ref, name : string) =
    List.exists (fn n => n = name orelse n = "all") (!names)

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  (* --pass-stats accounts for the whole compile: how deep the stages are
     nested where the compile is (a unit's stages run inside the stage that
     makes its code, with --units), and the processor time of the outermost
     ones, which `finish` shows beside the process's total *)
  val depth = ref 0
  val () = CompilerState.cellRoot ("Pass.depth", depth)
  val outer = ref Time.zeroTime
  val () = CompilerState.cellRoot ("Pass.outer", outer)
  (* what the outermost stages spent apart from their own time: counting
     the size of what they made (--pass-stats), and printing (--dump-before,
     --dump-after) and checking it (--lint) *)
  val sizes = ref Time.zeroTime
  val () = CompilerState.cellRoot ("Pass.sizes", sizes)
  val checks = ref Time.zeroTime
  val () = CompilerState.cellRoot ("Pass.checks", checks)

  (* the processor time the process has taken: from its start, with the
     collector's. Every stage is timed by it, so that the stages and the time
     between them add up to the total *)
  fun used () : Time.time =
    let val {usr, sys} = Timer.checkCPUTimer (Timer.totalCPUTimer ())
    in Time.+ (usr, sys) end

  fun line (name : string, size : int, t : Time.time) : unit =
    eprint ("pass " ^ name ^ ": " ^ Int.toString size ^ " nodes, " ^ Time.toString t ^ " s\n")

  (* Run a stage of the pipeline: `name` for the options, `show` to print
     what it made, `check` its lint (raising Error.Bug), `size` a count of
     what it made for --pass-stats. The input is printed with --dump-before
     by the stage before's `show`, which the caller passes as `showIn`. *)
  fun stage {name : string, showIn : ('a -> string) option, show : 'b -> string, check : 'b -> unit,
             size : 'b -> int}
            (f : 'a -> 'b) (x : 'a) : 'b =
    let
      (* The ordinary compile never samples a clock or accumulates timing
         values. Measuring a pass is work requested by --pass-stats. *)
      val measuring = !stats
      fun now () = if measuring then used () else Time.zeroTime
      fun since t0 = if measuring then Time.- (used (), t0) else Time.zeroTime
      val start = now ()
      val () =
        case showIn of
          SOME s => if asked (dumpBefore, name) then print ("(* before " ^ name ^ " *)\n" ^ s x ^ "\n") else ()
        | NONE => ()
      val dumped = since start
      val t0 = now ()
      val () = if measuring then depth := !depth + 1 else ()
      fun leave () = if measuring then depth := !depth - 1 else ()
      val y = f x handle e => (leave (); raise e)
      val () = leave ()
      val t = since t0
      val counted = now ()
      val () = if measuring then line (name, size y, t) else ()
      val after = now ()
      val () = if asked (dumpAfter, name) then print ("(* after " ^ name ^ " *)\n" ^ show y ^ "\n") else ()
      val () =
        if linting () then (check y handle Error.Bug msg => raise Error.Bug ("lint after " ^ name ^ ": " ^ msg))
        else ()
      val () =
        if measuring andalso !depth = 0
        then (outer := Time.+ (!outer, t);
              sizes := Time.+ (!sizes, Time.- (after, counted));
              checks := Time.+ (!checks, Time.+ (dumped, since after)))
        else ()
    in
      y
    end

  (* A stage that makes nothing to print or check: its size is 0. *)
  fun timed (name : string) (f : unit -> 'a) : 'a =
    stage {name = name, showIn = NONE, show = fn _ => "", check = fn _ => (), size = fn _ => 0} f ()

  (* --pass-stats, first and last: the processor time the process took before
     the compiler's own code (loading it, and its top-level declarations),
     shown as the stage `startup`; and at the end the time of the sizes it
     counted as the stage `stats`, that of --lint and the dumps as `checks`,
     then the total beside the sum of the outermost stages, which
     tests/compiler holds to it *)
  (* where the process's processor time starts: 0, or below it where a host
     counts from before the process (SML/NJ's exported heap may), so that no
     stage is negative *)
  val origin = ref Time.zeroTime
  val () = CompilerState.cellRoot ("Pass.origin", origin)

  fun startup () : unit =
    if !stats then
      let
        val t = used ()
        val () = if Time.< (t, Time.zeroTime) then origin := t else ()
        val t = Time.- (t, !origin)
      in outer := Time.+ (!outer, t); line ("startup", 0, t) end
    else ()

  fun finish () : unit =
    if !stats then
      let
        val () = (outer := Time.+ (!outer, !sizes); line ("stats", 0, !sizes))
        val () = if linting () orelse not (List.null (!dumpBefore)) orelse not (List.null (!dumpAfter))
                 then (outer := Time.+ (!outer, !checks); line ("checks", 0, !checks))
                 else ()
        val total = Time.- (used (), !origin)
        val share = if Time.toReal total > 0.0 then 100.0 * Time.toReal (!outer) / Time.toReal total else 100.0
      in
        eprint ("total: " ^ Time.toString total ^ " s processor time, " ^ Time.toString (!outer)
                ^ " s in the stages (" ^ Real.fmt (StringCvt.FIX (SOME 1)) share ^ "%)\n")
      end
    else ()
end
