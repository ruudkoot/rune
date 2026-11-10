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
  val stages = ["read", "desugar", "coretomid"] @ MidPipeline.stageNames MidPipeline.standardPasses

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

  (* the program of the files, read in order, each a unit, after what it
     reaches of rhc's runtime (CoreRuntime): the units joined, an import
     given its definition and a type declared once (CoreUnits), and every
     import defined where the program is run or compiled (whole); a unit
     checked alone (--typecheck-only) may import what it does not define *)
  fun readCore (strings, files : string list, whole : bool) : Core.program =
    let
      fun one file =
        CoreText.parse (readFile file)
        handle CoreText.Error (line, msg) => (eprint (file ^ ":" ^ Int.toString line ^ ": error: " ^ msg ^ "\n"); raise Failed)
      fun runtime p =
        CoreRuntime.link strings p
        handle CoreText.Error (line, msg) => raise Error.Bug ("rhc's runtime does not read, at line " ^ Int.toString line ^ ": " ^ msg)
      fun failed msg = (eprint (String.concatWith ", " files ^ ": error: " ^ msg ^ "\n"); raise Failed)
      fun defined p =
        case (whole, CoreUnits.unresolved p) of
          (false, _) => p
        | (true, []) => p
        | (true, xs) => failed ("imported and defined by no unit: " ^ String.concatWith ", " xs)
      val read = fn () => defined (CoreUnits.join [runtime (List.concat (List.map one files))])
                          handle CoreUnits.Error msg => failed msg
    in
      Pass.stage {name = "read", showIn = NONE, show = CoreText.show,
                  check = Pass.checkAt ("read", 3) roundTrip, size = List.length} read ()
    end

  (* CoreLint on what was read, a check of the input's, unless --lint=off *)
  fun lint (files : string list, p : Core.program) =
    if not (Pass.linting' 0) then ()
    else CoreLint.check p
         handle CoreLint.Error msg => (eprint (String.concatWith ", " files ^ ": error: " ^ msg ^ "\n"); raise Failed)

  (* `-- ARG...`: what follows is the program's own, its arguments where rhc
     interprets it (getArgs: command_arg_count and command_arg), as runevm
     takes a program's after its file *)
  val programArgs : string list ref = ref []

  fun splitArgs args =
    let
      fun go (pre, "--" :: rest) = (List.rev pre, rest)
        | go (pre, a :: rest) = go (a :: pre, rest)
        | go (pre, []) = (List.rev pre, [])
    in
      go ([], args)
    end

  fun flush () = (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr)

  (* the status of a run of p *)
  fun interpret (opts : RhcOptions.options, p : Core.program) : int =
    let
      val out = fn s => TextIO.output (TextIO.stdOut, s)
      val err = fn s => (TextIO.flushOut TextIO.stdOut; TextIO.output (TextIO.stdErr, s))
      (* the program's name, command_name's: the file read last (ruling 33) *)
      val () = case #readCore opts of [] => () | files => CorePrimSys.program := {name = List.last files, args = !programArgs}
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
                   (fn p => CoreToMid.program ({fault = #fault opts}, p)) p
      (* Mid's text that Mid's reader refuses is a bug of Core to Mid *)
      fun parse text =
        MidText.parse text
        handle MidText.Syntax msg => raise Error.Bug ("Mid's reader refuses what Core to Mid wrote: " ^ msg)
      val mid = MidPipeline.midStage NONE parse text
      val low = MidPipeline.lowOfMid MidPipeline.standardPasses mid
      (* the register machine's names in a dump of its code, as rune's
         driver sets them; the stack machine's are Code's own *)
      val () = if !CompilerSettings.target = "registers" then Code.opcodeNames := RegCodes.names else ()
      val code = MidPipeline.targetStage low
    in Emit.writeFileAs (MidPipeline.fingerprint (), out, code); 0 end
    handle CoreToMid.Unsupported msg =>
      (eprint (String.concatWith ", " (#readCore opts) ^ ": error: rhc cannot compile this yet: " ^ msg ^ "\n"); 1)

  (* Each file a unit, after rhc's runtime's, each checked and compiled
     apart against the units before it, which it imports from, and the
     units linked (the haskell98 roadmap's M21c). A unit takes what it
     names and does not declare from the latest unit before it that
     declares it, the runtime's last, as that unit's interface gives it: a
     value an import, a type a copy (CoreUnits.interface). With --store, a
     unit is kept in the store, keyed by its name and its text, and taken
     from it where each name it took gives now what it gave its compile:
     the same unit, at the same fingerprint and making (RhcStore). *)
  fun compileUnits (opts : RhcOptions.options, out : string) : int =
    let
      val strings = #strings opts
      fun one file =
        let val text = readFile file
        in
          (text, CoreText.parse text)
          handle CoreText.Error (line, msg) => (eprint (file ^ ":" ^ Int.toString line ^ ": error: " ^ msg ^ "\n"); raise Failed)
        end
      fun declared d =
        case d of
          Core.Data (t, _, cons) => t :: List.map #1 cons
        | Core.Newtype (t, _, c, _) => [t, c]
        | Core.Val (x, _, _) => [x]
        | Core.Import (x, _) => [x]
      fun member (x, xs) = List.exists (fn y => y = x) xs
      fun distinct xs = List.rev (List.foldl (fn (x, acc) => if member (x, acc) then acc else x :: acc) [] xs)
      (* the names p names and does not declare, a constructor by its type *)
      fun needed (earlier : RhcUnits.compiled list, p : Core.program) : string list =
        let
          val own = List.concat (List.map declared p)
          val ifaces = List.concat (List.map #iface earlier)
          fun typeOf n =
            case List.find (fn Core.Data (_, _, cons) => List.exists (fn (c, _) => c = n) cons
                             | Core.Newtype (_, _, c, _) => c = n | _ => false) ifaces of
              SOME (Core.Data (t, _, _)) => t
            | SOME (Core.Newtype (t, _, _, _)) => t
            | _ => n
        in distinct (List.map typeOf (List.filter (fn n => not (member (n, own))) (List.concat (List.map CoreRuntime.mentions p)))) end
      (* the unit a name is taken from, the latest that declares it, and
         the declaration *)
      fun resolve (earlier : RhcUnits.compiled list, n : string) : (RhcUnits.compiled * Core.decl) option =
        let
          fun go [] = NONE
            | go ((u : RhcUnits.compiled) :: us) =
                case List.find (fn d => member (n, declared d)) (#iface u) of
                  SOME d => SOME (u, d)
                | NONE => go us
        in go (List.rev earlier) end
      (* what a name taken gives: its unit, its fingerprint there and its
         making; "-" where no unit declares it (H1) *)
      val prints : (string * (string * string) list) list ref = ref []
      fun printsOf (u : RhcUnits.compiled) =
        case List.find (fn (n, _) => n = #name u) (!prints) of
          SOME (_, fps) => fps
        | NONE => let val fps = CoreUnits.fingerprints Pickle.hash (#iface u)
                  in prints := (#name u, fps) :: !prints; fps end
      fun gives (earlier, n) =
        case resolve (earlier, n) of
          NONE => "-"
        | SOME (u, _) =>
            #name u ^ " " ^ (case List.find (fn (x, _) => x = n) (printsOf u) of SOME (_, f) => f | NONE => "?")
            ^ (case List.find (fn (x, _) => x = n) (#abi u) of SOME (_, a) => " " ^ RhcUnits.abiName a | NONE => "")
      (* what p takes of the units before it, the latest first *)
      fun taken (earlier : RhcUnits.compiled list, p : Core.program) : Core.program =
        let
          fun firsts ([], _, acc) = List.rev acc
            | firsts (d :: ds, seen, acc) =
                let val n = hd (declared d)
                in if member (n, seen) then firsts (ds, seen, acc) else firsts (ds, n :: seen, d :: acc) end
          val ifaces = firsts (List.concat (List.map #iface (List.rev earlier)), [], [])
        in CoreUnits.interface (ifaces, needed (earlier, p)) end
      fun check (name, p) =
        if not (Pass.linting' 0) then ()
        else CoreLint.check p handle CoreLint.Error msg => (eprint (name ^ ": error: " ^ msg ^ "\n"); raise Failed)
      val extra = [("strings", case strings of CoreRuntime.Lazy => "lazy" | CoreRuntime.Whole => "whole")]
      val config = RhcStoreConfig.configuration extra
      fun say (name, what) = if #showUnits opts then eprint ("rhc: unit " ^ name ^ ": " ^ what ^ "\n") else ()
      (* the unit name of text and program p, against the units before it *)
      fun build ((name, text, p), done) =
        let
          val usages = List.map (fn n => ("n " ^ n, gives (done, n))) (needed (done, p))
          val key = RhcStore.key (name, [(name, Pickle.hash text)])
          fun current k = if String.isPrefix "n " k then gives (done, String.extract (k, 2, NONE)) else "?"
          val holds = RhcStore.holds {level = RhcStoreConfig.level (), current = current}
          val found =
            case #store opts of
              SOME dir => SOME (RhcStore.find {overlay = dir, layers = #layers opts, config = config, key = key, holds = holds})
            | NONE =>
                if null (#layers opts) then NONE
                else SOME (RhcStore.find {overlay = hd (#layers opts), layers = tl (#layers opts), config = config, key = key,
                                          holds = holds})
          fun compile why =
            let
              val p' = taken (done, p) @ p
              val () = check (name, p')
              val c = RhcUnits.compile {name = name, earlier = done, fault = #fault opts} p'
              val () =
                case #store opts of
                  SOME dir =>
                    let val iface = RhcUnits.ifaceText c
                    in
                      ignore (RhcStore.store {dir = dir, settings = RhcStoreConfig.settings extra, config = config, key = key,
                                              entry = {head = {usages = usages, exports = Pickle.hash iface,
                                                               level = RhcStoreConfig.level ()},
                                                       sections = {iface = iface, code = RhcUnits.codeBytes c}}})
                    end
                | NONE => ()
            in say (name, "compiled" ^ why); c end
        in
          done @ [case found of
                    SOME (UnitStore.Found ({sections, ...}, _)) => (say (name, "taken"); RhcUnits.fromEntry (name, sections))
                  | SOME (UnitStore.FoundBehind ({sections, ...}, _)) => (say (name, "taken"); RhcUnits.fromEntry (name, sections))
                  | SOME (UnitStore.Missed why) => compile (" (" ^ why ^ ")")
                  | NONE => compile ""]
        end
      val runtime = CoreRuntime.program strings
      val units = ("rhc-runtime", CoreText.show runtime, runtime)
                  :: List.map (fn f => let val (text, p) = one f in (OS.Path.base (OS.Path.file f), text, p) end) (#readCore opts)
    in RhcUnits.link (List.foldl build [] units, out); 0 end
    handle RhcUnits.Error msg => (eprint ("rhc: error: " ^ msg ^ "\n"); 1)
         | CoreToMid.Unsupported msg =>
             (eprint (String.concatWith ", " (#readCore opts) ^ ": error: rhc cannot compile this yet: " ^ msg ^ "\n"); 1)

  (* a program of Haskell, checked (RhcSyntax), desugared to Core (M15)
     with what it reaches of rhc's runtime, checked by CoreLint, and run on
     the Core interpreter or, with -o, compiled; `args` are the options of
     the command line that are not the syntax's *)
  fun haskell (file : string) (args : string list, desugar : CoreRuntime.strings -> Core.program) : int =
    let
      (* --match=report|sestoft: the order of matching (D34) *)
      val (orders, args) = List.partition (String.isPrefix "--match=") args
      val () = List.app (fn "--match=report" => HsMatch.order := HsMatch.Report
                          | "--match=sestoft" => HsMatch.order := HsMatch.Sestoft
                          | a => raise RhcOptions.Usage ("--match takes report or sestoft: " ^ a)) orders
      (* --desugar-only: as far as Core and CoreLint, and run nothing *)
      val (only, args) = List.partition (fn a => a = "--desugar-only") args
      (* --desugar-units: the program desugared a unit at a time, each group
         of modules after the interfaces of those before, and the units
         joined (M21f) *)
      val (byUnits, args) = List.partition (fn a => a = "--desugar-units") args
      val () = RhcDesugar.byUnits := not (null byUnits)
      val opts = RhcOptions.parse args
      val () = List.app (fn s => if s = "all" orelse List.exists (fn t => t = s) stages then ()
                                 else raise RhcOptions.Usage ("--dump-after: no stage " ^ s ^ " (the stages: "
                                                              ^ String.concatWith ", " stages ^ ")"))
                        (!Pass.dumpAfter)
      val () = Pass.startup ()
      val p =
        Pass.stage {name = "desugar", showIn = NONE, show = CoreText.show,
                    check = Pass.checkAt ("desugar", 3) roundTrip, size = List.length} desugar (#strings opts)
        handle Fail msg => raise Error.Bug ("rhc's desugaring fails, a bug of rhc's: " ^ msg)
      val () = lint ([file], p)
      (* HsLint's target check at level 2: the Core at the translation of
         its source types (RhcLint.target, D54) *)
      val () = RhcLint.target p
      val status =
        if not (null only) then 0
        else
          case #output opts of
            SOME out => compile (opts, p, out)
          | NONE =>
              (* the program's name, command_name's: the .hs file (ruling 33),
                 as the VM's is its bytecode's *)
              (CorePrimSys.program := {name = file, args = !programArgs}; interpret (opts, p))
    in
      Pass.finish (); status
    end
    handle RhcOptions.Usage msg => (eprint ("rhc: " ^ msg ^ "\n" ^ "rhc --help says what rhc takes\n"); 1)
         | Failed => 1

  (* --share DIR, where rhc's library is, which the wrapper bin/rhc gives *)
  fun share args =
    case args of
      "--share" :: d :: rest => (RhcLibrary.share := SOME d; share rest)
    | ["--share"] => raise RhcOptions.Usage "--share takes a directory"
    | a :: rest => a :: share rest
    | [] => []

  (* --whole, a program read and checked whole without the saved world;
     --world, what of it there is (RhcWorld); --identity, rhc's own
     (Config), which the Makefile writes to bin/rhc.identity *)
  fun world args =
    case args of
      "--whole" :: rest => (RhcWorld.whole := true; world rest)
    | a :: rest => a :: world rest
    | [] => []

  (* the library replayed by HsLint, at level 2, when its world is made;
     what the check keeps for the target check is a program's, not the
     library's, so the saved image holds none *)
  val () = RhcWorld.checkLibrary := (fn (g, r) => (RhcLint.check (g, r, false); RhcLint.kept := NONE))

  fun run (args : string list) : int =
    let
      val (args, ownArgs) = splitArgs args
      val () = programArgs := ownArgs
      val args = world (share args)
    in
    case args of
      ["--make-world", image] =>
        (* the saved world, made: the world that saves it stops here, and
           one bin/rhc restores goes on with its own command line *)
        (case RhcWorld.make image of
           Runtime.Saved => 0
         | Runtime.Restored => run (CommandLine.arguments ()))
    | ["--world"] => (print (RhcWorld.describe () ^ "\n"); 0)
    | ["--identity"] => (print (Config.identity ^ "\n"); 0)
    | _ =>
    case RhcSyntax.command args of
      SOME syntax =>
        let
          (* the status of a program run, which a status of success or
             failure would lose *)
          val code = ref NONE
          val file = getOpt (List.find RhcSyntax.isSource args, "")
          val () = RhcSyntax.compile := (fn x => let val n = haskell file x
                                                 in code := SOME n; if n = 0 then OS.Process.success else OS.Process.failure end)
          val ok = OS.Process.isSuccess (syntax ())
        in
          case !code of SOME n => n | NONE => if ok then 0 else 1
        end
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
              if #units opts then
                case #output opts of
                  SOME out => (Pass.startup (); compileUnits (opts, out) before Pass.finish ())
                | NONE => raise RhcOptions.Usage "--units compiles: give -o FILE"
              else
              let
                val () = Pass.startup ()
                val p = readCore (#strings opts, #readCore opts, not (#typecheckOnly opts))
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
