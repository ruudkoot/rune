(* rhc's driver (the haskell98 roadmap, M8): it reads its command line and
   runs what it asks for. As yet that is Core: read from text, checked by
   CoreLint and run on the Core interpreter, each stage through Pass.stage
   so that --dump-after prints it and --lint=3 reads its text back.

   A fault of the input is a line on standard error and status 1; a bug of
   rhc's, Error.Bug, says so. A run that ends in a bottom -- an exception no
   handler took, a stack too deep, the steps run out -- says which on
   standard error, after what the program printed, and ends with status 1;
   `exit` gives its own status. *)
structure RhcMain =
struct
  fun eprint s = TextIO.output (TextIO.stdErr, s)

  (* a fault of the input, said already *)
  exception Failed

  (* the stages there are, for --dump-after: rhc's, then those from Mid on *)
  val stages = ["read", "coretomid"] @ MidPipeline.stageNames MidPipeline.standardPasses

  fun version () = print ("rhc " ^ Config.version ^ " (identity " ^ Config.identity ^ ")\n")

  fun readFile path =
    let val ins = TextIO.openIn path
    in TextIO.inputAll ins before TextIO.closeIn ins end

  (* Core's text read back, at level 3: print, read, print is the identity *)
  fun roundTrip (p : Core.program) =
    let
      val text = CoreText.show p
      val again = CoreText.parse text
                  handle CoreText.Error (line, msg) =>
                    raise Error.Bug ("Core's text does not read back, at line " ^ Int.toString line ^ ": " ^ msg)
    in
      if again <> p then raise Error.Bug "Core's text reads back as another program"
      else if CoreText.show again <> text then raise Error.Bug "Core's text printed again is other text"
      else ()
    end

  (* the program of the files, read in order *)
  fun readCore (files : string list) : Core.program =
    let
      fun one file =
        CoreText.parse (readFile file)
        handle CoreText.Error (line, msg) => (eprint (file ^ ":" ^ Int.toString line ^ ": error: " ^ msg ^ "\n"); raise Failed)
      val read = fn () => List.concat (List.map one files)
    in
      Pass.stage {name = "read", showIn = NONE, show = CoreText.show,
                  check = Pass.checkAt ("read", 3) roundTrip, size = List.length} read ()
    end

  (* CoreLint on what was read, a check of the input's, unless --lint=off *)
  fun lint (files : string list, p : Core.program) =
    if not (Pass.linting' 0) then ()
    else CoreLint.check p
         handle CoreLint.Error msg => (eprint (String.concatWith ", " files ^ ": error: " ^ msg ^ "\n"); raise Failed)

  fun flush () = (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr)

  (* the status of a run of p *)
  fun interpret (opts : RhcOptions.options, p : Core.program) : int =
    let
      val out = fn s => TextIO.output (TextIO.stdOut, s)
      val err = fn s => (TextIO.flushOut TextIO.stdOut; TextIO.output (TextIO.stdErr, s))
      val {outcome, ...} =
        Pass.stage {name = "interpret", showIn = NONE, show = fn _ => "", check = fn _ => (), size = fn _ => 0}
                   CoreInterp.run {program = p, steps = #steps opts, depth = #depth opts, out = out, err = err}
      fun bottom why = (flush (); eprint ("rhc: bottom: " ^ why ^ "\n"); 1)
    in
      case outcome of
        CoreInterp.Exit n => (flush (); n)
      | CoreInterp.Raised (kind, msg) => bottom (kind ^ ": " ^ msg)
      | CoreInterp.TooDeep => bottom ("the stack went deeper than " ^ Int.toString (#depth opts))
      | CoreInterp.OutOfSteps => bottom ("the steps ran out, " ^ Int.toString (getOpt (#steps opts, 0)) ^ " of them")
    end
    handle CoreInterp.Stuck msg => (flush (); eprint ("rhc: the Core interpreter is stuck: " ^ msg ^ "\n"); 1)

  (* the bytecode of p, written to out: Core to Mid's text, read as Mid,
     the passes any front end may run (MidPipeline.standardPasses: Rune's,
     with no expand, which is SML's), Lower and the target *)
  fun compile (opts : RhcOptions.options, p : Core.program, out : string) : int =
    let
      val text =
        Pass.stage {name = "coretomid", showIn = NONE, show = fn s => s, check = fn _ => (), size = String.size}
                   (fn p => CoreToMid.program ({form = #thunks opts, fault = #fault opts}, p)) p
      (* Mid's text that Mid's reader refuses is a bug of Core to Mid, or, for
         --thunks=c, a tree without form C's suspensions *)
      fun parse text =
        MidText.parse text
        handle MidText.Syntax msg => raise Error.Bug ("Mid's reader refuses what Core to Mid wrote: " ^ msg)
      val mid = MidPipeline.midStage NONE parse text
      val low = MidPipeline.lowOfMid MidPipeline.standardPasses mid
      val code = MidPipeline.targetStage low
    in Emit.writeFileAs (MidPipeline.fingerprint (), out, code); 0 end
    handle CoreToMid.Unsupported msg =>
      (eprint (String.concatWith ", " (#readCore opts) ^ ": error: rhc cannot compile this yet: " ^ msg ^ "\n"); 1)

  (* --share DIR, where rhc's library is, which the wrapper bin/rhc gives *)
  fun share args =
    case args of
      "--share" :: d :: rest => (RhcLibrary.share := SOME d; share rest)
    | ["--share"] => raise RhcOptions.Usage "--share takes a directory"
    | a :: rest => a :: share rest
    | [] => []

  fun run (args : string list) : int =
    let val args = share args in
    case RhcSyntax.command args of
      SOME syntax => if OS.Process.isSuccess (syntax ()) then 0 else 1
    | NONE =>
    let
      val opts = RhcOptions.parse args
      val () = List.app (fn s => if s = "all" orelse List.exists (fn t => t = s) stages then ()
                                 else raise RhcOptions.Usage ("--dump-after: no stage " ^ s ^ " (the stages: "
                                                              ^ String.concatWith ", " stages ^ ")"))
                        (!Pass.dumpAfter)
    in
      if #help opts then (print RhcOptions.usage; 0)
      else if #version opts then (version (); 0)
      else if #lintRules opts then (List.app (fn (r, _) => print (r ^ "\n")) CoreLint.rules; 0)
      else
        case #generate opts of
          SOME seed => (print (CoreText.show (CoreGen.program seed)); 0)
        | NONE =>
            if null (#readCore opts) then raise RhcOptions.Usage "nothing to do: give --read-core FILE"
            else
              let
                val () = Pass.startup ()
                val p = readCore (#readCore opts)
                val () = lint (#readCore opts, p)
                val () =
                  if #typecheckOnly opts orelse isSome (#output opts)
                     orelse List.exists (fn Core.Val ("main", _, _) => true | _ => false) p then ()
                  else (eprint (String.concatWith ", " (#readCore opts)
                                ^ ": error: the program has no main to run (--typecheck-only checks one that has none)\n");
                        raise Failed)
                val status =
                  if #typecheckOnly opts then 0
                  else case #output opts of SOME out => compile (opts, p, out) | NONE => interpret (opts, p)
              in Pass.finish (); status end
    end
    end

  fun main (_ : string, args : string list) : int =
    run args
    handle RhcOptions.Usage msg => (eprint ("rhc: " ^ msg ^ "\n" ^ "rhc --help says what rhc takes\n"); 1)
         | Failed => 1
         | Error.Bug msg => (eprint ("rhc: " ^ msg ^ "\n"); 1)
         | IO.Io {name, function, cause} =>
             (eprint ("rhc: " ^ name ^ ": " ^ function ^ ": "
                      ^ (case cause of OS.SysErr (msg, _) => msg | _ => exnMessage cause) ^ "\n"); 1)
end
