(* Reproducible frontend measurements and edit traces for runelsp.
   Timed phases contain their work only; hashes and verdicts are checked
   outside them. Failed or misclassified fixtures never become samples. *)
structure LspBench =
struct
  exception Failed of string
  fun need (b, message) = if b then () else raise Failed message
  fun hash text = Hex.fromBytes (Sha256.digest text)
  fun field (v, key) = case Json.member (key, v) of SOME x => x | NONE => raise Failed ("missing " ^ key)
  fun text v = case v of Json.String s => s | _ => raise Failed "expected a string"
  fun number v = case Json.toInt v of SOME n => n | NONE => raise Failed "expected an integer"
  fun array v = case v of Json.Array xs => xs | _ => raise Failed "expected an array"
  fun boolean v = case v of Json.Bool b => b | _ => raise Failed "expected a boolean"
  fun str s = Json.String s
  fun num n = Json.int n
  fun large n = Json.Number (LargeInt.toString n)
  fun micros t = large (Time.toMicroseconds t)
  fun mode s = case Source.modeNamed s of SOME m => m | NONE => raise Failed ("unknown source mode " ^ s)
  fun read path = let val input = TextIO.openIn path
                 in TextIO.inputAll input before TextIO.closeIn input end
  fun write (path, contents) = let val output = TextIO.openOut path
                             in TextIO.output (output, contents) before TextIO.closeOut output end
  fun jsonLine (output, v) = TextIO.output (output, Json.encode v ^ "\n")
  fun join xs = String.concatWith "\n" xs
  fun sortStrings xs =
    let fun add (x, []) = [x]
          | add (x, y :: ys) = if String.compare (x, y) = LESS then x :: y :: ys else y :: add (x, ys)
    in List.foldl add [] xs end
  fun mkdirs path =
    if path = "" orelse path = "." orelse OS.FileSys.access (path, []) then ()
    else (mkdirs (OS.Path.dir path); OS.FileSys.mkDir path)
  fun tokenDigest tokens =
    hash (join (Vector.foldr (fn ((t, sp : Source.span), acc) =>
      (Int.toString (#start sp) ^ ":" ^ Int.toString (#stop sp) ^ ":" ^ Token.toString t) :: acc) [] tokens))

  type sample = {fixture : string, source : string, revision : int, repetition : int, phase : string,
                 wall : Time.time, cpu : Time.time, bytes : int, objects : int}
  val samples : sample list ref = ref []
  fun timed label source revision repetition phase action =
    let
      val stats = Runtime.stats ()
      val cpu = Timer.startCPUTimer ()
      val start = Runtime.clock ()
      val result = action ()
      val wall = Time.- (Runtime.clock (), start)
      val used = Timer.checkCPUTimer cpu
      val afterStats = Runtime.stats ()
      val entry = {fixture = label, source = source, revision = revision, repetition = repetition, phase = phase,
                   wall = wall, cpu = Time.+ (#usr used, #sys used),
                   bytes = #bytes afterStats - #bytes stats,
                   objects = #objects afterStats - #objects stats}
    in (result, entry) end
  fun sampleJson (s : sample) = Json.Object
    [("fixture", str (#fixture s)), ("source", str (#source s)), ("revision", num (#revision s)),
     ("repetition", num (#repetition s)), ("phase", str (#phase s)),
     ("wall_us", micros (#wall s)), ("cpu_us", micros (#cpu s)),
     ("allocated_bytes", num (#bytes s)), ("allocated_objects", num (#objects s))]

  type parsed = {accepted : bool, tokens : string, declarations : int,
                 debugTree : string, fixity : Fixity.env, error : string option}
  (* The debug-tree hash is an additional change detector, not a complete
     AST equivalence oracle. M4 adds structural AST comparison. *)
  fun parse label revision repetition incoming (file : Source.file) =
    let
      val (lexed, lexTime) = timed label (#name file) revision repetition "lex"
        (fn () => SOME (Lexer.tokenize file) handle Error.CompileError (_, msg) => NONE)
    in
      case lexed of
        NONE => ({accepted = false, tokens = "", declarations = 0,
                  debugTree = "", fixity = incoming, error = SOME "lexical error"}, [lexTime])
      | SOME tokens =>
          let
            val (parsed, parseTime) = timed label (#name file) revision repetition "parse"
              (fn () => SOME (Parser.parseTokensWith (tokens, incoming))
                        handle Error.CompileError (_, msg) => NONE)
            val digest = tokenDigest tokens
          in
            case parsed of
              NONE => ({accepted = false, tokens = digest, declarations = 0,
                        debugTree = "", fixity = incoming, error = SOME "syntax error"}, [lexTime, parseTime])
            | SOME (tree, outgoing) =>
                ({accepted = true, tokens = digest, declarations = length tree,
                  debugTree = hash (join (List.map Ast.decToString tree)), fixity = outgoing,
                  error = NONE}, [lexTime, parseTime])
          end
    end
  fun insert (x : Time.time, []) = [x]
    | insert (x, y :: ys) = if Time.<= (x, y) then x :: y :: ys else y :: insert (x, ys)
  fun percentile sorted p =
    let val n = length sorted
        val rank = Int.max (1, (n * p + 99) div 100)
    in List.nth (sorted, rank - 1) end
  fun summarize entries =
    let
      fun key (s : sample) = #fixture s ^ "/" ^ #source s ^ "/" ^ #phase s
      val keys = sortStrings (List.foldl (fn (s, acc) =>
        if List.exists (fn k => k = key s) acc then acc else key s :: acc) [] entries)
      fun one k =
        let val selected = List.filter (fn s => key s = k) entries
            val sorted = List.foldl (fn (s, xs) => insert (#wall s, xs)) [] selected
        in Json.Object [("key", str k), ("samples", num (length sorted)),
             ("p50_us", micros (percentile sorted 50)),
             ("p95_us", micros (percentile sorted 95)),
             ("p99_us", micros (percentile sorted 99))] end
    in Json.Array (List.map one keys) end
  fun edited (source, edit) =
    let val start = number (field (edit, "start"))
        val stop = number (field (edit, "stop"))
        val added = text (field (edit, "text"))
        val () = need (0 <= start andalso start <= stop andalso stop <= size source,
                       "edit is outside its preceding revision")
    in String.substring (source, 0, start) ^ added ^ String.extract (source, stop, NONE) end
  fun generated n =
    let val () = need (n > 0 andalso n <= 100000, "generated fixture must contain 1..100000 declarations")
    in String.concat (List.tabulate (n, fn i => "val generated" ^ Int.toString i ^ " = " ^ Int.toString i ^ "\n")) end

  fun fixture manifestDirectory repetitions warmup spec output verdicts =
    let
      val label = text (field (spec, "name"))
      val sourceMode = mode (text (field (spec, "mode")))
      val expected = boolean (field (spec, "accepted"))
      val paths = case Json.member ("files", spec) of NONE => [] | SOME v => List.map text (array v)
      val inputs = case Json.member ("generate", spec) of
          SOME v => [("generated:" ^ label, generated (number v))]
        | NONE => List.map (fn p =>
            let val path = OS.Path.mkCanonical (if OS.Path.isAbsolute p then p else OS.Path.concat (manifestDirectory, p))
                val file = Source.readFile (sourceMode, path)
            in (path, #text file) end) paths
      val () = need (not (null inputs), "fixture has no sources: " ^ label)
      val edits = case Json.member ("edits", spec) of NONE => [] | SOME v => array v
      val () = need (null edits orelse length inputs = 1, "edit traces need one source")
      fun run repetition =
        let
          fun check (revision, name, contents, incoming, accepted, measured) =
            let val file = Source.fromStringIn (sourceMode, name, contents)
                val (result, phases) = parse label revision repetition incoming file
                val () = need (#accepted result = accepted,
                  label ^ " revision " ^ Int.toString revision ^ ": unexpected parser verdict")
                val () = if measured then samples := rev phases @ !samples else ()
                val () = if repetition = 0 then jsonLine (verdicts, Json.Object
                  [("fixture", str label), ("revision", num revision), ("source", str name),
                   ("mode", str (Source.modeName sourceMode)), ("source_sha256", str (hash contents)),
                   ("bytes", num (size contents)), ("accepted", Json.Bool (#accepted result)),
                   ("tokens_sha256", str (#tokens result)), ("declarations", num (#declarations result)),
                   ("debug_tree_sha256", str (#debugTree result))]) else ()
            in #fixity result end
          fun files ([], fixity) = fixity
            | files ((name, contents) :: rest, fixity) =
                files (rest, check (0, name, contents, fixity, expected, repetition >= 0))
          val _ = files (inputs, Fixity.initial)
          fun trace (_, _, []) = ()
            | trace (revision, contents, edit :: rest) =
                let val (updated, timing) = timed label (#1 (hd inputs)) revision repetition "edit" (fn () => edited (contents, edit))
                    val () = if repetition >= 0 then samples := timing :: !samples else ()
                    val _ = check (revision, #1 (hd inputs), updated, Fixity.initial,
                                   boolean (field (edit, "accepted")), repetition >= 0)
                in trace (revision + 1, updated, rest) end
        in if null edits then () else trace (1, #2 (hd inputs), edits) end
      val () = List.app run (List.tabulate (warmup, fn i => ~ (i + 1)))
      val () = List.app run (List.tabulate (repetitions, fn i => i))
    in () end

  (* Independent oracle for the fixity trace: interpret its arithmetic
     tree, rather than compare the parser's own debugging printer. *)
  fun arithmetic e =
    case e of
      Ast.EScon (Ast.SInt n, _, _, _) => IntInf.toInt n
    | Ast.EApp (Ast.EVar (([], "+"), _, _, _), Ast.ETuple ([a, b], _, _), _, _) => arithmetic a + arithmetic b
    | Ast.EApp (Ast.EVar (([], "*"), _, _, _), Ast.ETuple ([a, b], _, _), _, _) => arithmetic a * arithmetic b
    | Ast.EApp (Ast.EVar (([], "++"), _, _, _), Ast.ETuple ([a, b], _, _), _, _) => arithmetic a + arithmetic b
    | _ => raise Failed "unexpected arithmetic oracle tree"
  fun valueOf source fixity =
    let val (tree, outgoing) = Parser.parseFileWith (Source.fromString ("oracle.sml", source), fixity)
        val body = case rev tree of Ast.DVal (_, [(_, e)], _, _) :: _ => e
                                    | _ => raise Failed "oracle value declaration is absent"
    in (arithmetic body, outgoing) end
  fun selftest () =
    let
      val (low, lowOutgoing) = valueOf "infix 4 ++\nval result = 1 ++ 2 * 3\n" Fixity.initial
      val (high, outgoing) = valueOf "infix 8 ++\nval result = 1 ++ 2 * 3\n" Fixity.initial
      val (carried, _) = valueOf "val result = 1 ++ 2 * 3\n" outgoing
      val () = need (low = 7 andalso high = 9 andalso carried = 9, "fixity propagation oracle failed")
      val (stale, _) = valueOf "val result = 1 ++ 2 * 3\n" lowOutgoing
      val () = need (((need (stale = high, "planted stale fixity"); false)
                       handle Failed _ => true), "planted stale fixity was not detected by the arithmetic oracle")
      val () = need (edited ("abc", Json.Object [("start", num 1), ("stop", num 2), ("text", str "XYZ")]) = "aXYZc",
                     "edit replay failed")
      val () = need ((ignore (edited ("abc", Json.Object [("start", num 2), ("stop", num 1), ("text", str "")])); false)
                       handle Failed _ => true, "reversed edit range was accepted")
      val xs = List.tabulate (100, fn i => Time.fromMicroseconds (LargeInt.fromInt (i + 1)))
      val () = need (Time.toMicroseconds (percentile xs 95) = 95 andalso
                     Time.toMicroseconds (percentile xs 99) = 99, "percentile rank is wrong")
    in print "PASS lsp-bench: fixity, stale-state faults, edit bounds and percentile oracles\n" end

  fun main args =
    let
      val manifest = ref "tests/lsp/fixtures/manifest.json"
      val output = ref ""
      val repetitions = ref 20
      val warmup = ref 3
      val retentionCycles = ref 3
      val service = ref NONE : string option ref
      fun options [] = ()
        | options ("--manifest" :: s :: rest) = (manifest := s; options rest)
        | options ("--out" :: s :: rest) = (output := s; options rest)
        | options ("--repetitions" :: s :: rest) = (repetitions := number (Json.Number s); options rest)
        | options ("--warmup" :: s :: rest) = (warmup := number (Json.Number s); options rest)
        | options ("--retention-cycles" :: s :: rest) = (retentionCycles := number (Json.Number s); options rest)
        | options ("--service" :: s :: rest) = (service := SOME s; options rest)
        | options _ = raise Failed "usage: rune-lsp-bench --manifest FILE --out NEW-DIR [--repetitions N] [--warmup N]"
      val () = options args
      val () = need (!output <> "" andalso !repetitions >= 1 andalso !warmup >= 0 andalso !retentionCycles >= 0,
                     "output and valid repetition counts are required")
      val contents = read (!manifest)
      val spec = Json.decode contents
      val () = need (number (field (spec, "version")) = 1, "unsupported fixture schema")
      val directory = OS.Path.dir (!manifest)
      val () = mkdirs (OS.Path.dir (!output))
      val () = OS.FileSys.mkDir (!output)
      val _ = samples := []
      val verdicts = TextIO.openOut (!output ^ "/fixtures.jsonl")
      val () = List.app (fn f => fixture directory (!repetitions) (!warmup) f (!output) verdicts)
                       (array (field (spec, "fixtures")))
               handle e => (TextIO.closeOut verdicts; raise e)
      val () = TextIO.closeOut verdicts
      val entries = rev (!samples)
      val retention = TextIO.openOut (!output ^ "/retention.jsonl")
      fun retentionCycle i =
        let val () = Runtime.collect ()
            val beforeStats = Runtime.stats ()
            val () = List.app (fn f => fixture directory 0 1 f (!output) retention)
                             (array (field (spec, "fixtures")))
            val () = Runtime.collect ()
            val afterStats = Runtime.stats ()
        in jsonLine (retention, Json.Object [("cycle", num i),
             ("live_before_bytes", num (#live beforeStats)), ("live_after_bytes", num (#live afterStats)),
             ("heap_after_bytes", num (#heapSize afterStats))]) end
      val () = List.app retentionCycle (List.tabulate (!retentionCycles, fn i => i))
               handle e => (TextIO.closeOut retention; raise e)
      val () = TextIO.closeOut retention
      val () = case !service of
          NONE => ()
        | SOME compiler =>
            let fun process i =
                  let val directory = !output ^ "/prototype-" ^ Int.toString i
                      val () = OS.FileSys.mkDir directory
                      val rows = LspServiceBaseline.run {compiler = compiler, output = directory,
                                     repetitions = 1, warmup = !warmup}
                  in List.map (fn Json.Object fields => Json.Object (("process_repetition", num i) :: fields)
                                | _ => raise Failed "invalid prototype sample") rows end
                val rows = List.concat (List.tabulate (!repetitions, process))
                val stream = TextIO.openOut (!output ^ "/prototype-service.jsonl")
            in List.app (fn row => jsonLine (stream, row)) rows; TextIO.closeOut stream end
      val raw = TextIO.openOut (!output ^ "/samples.jsonl")
      val () = List.app (fn s => jsonLine (raw, sampleJson s)) entries
      val () = TextIO.closeOut raw
      val () = write (!output ^ "/summary.json", Json.encodeIndented 2 (summarize entries) ^ "\n")
      val uname = List.filter (fn (key, _) => List.exists (fn k => k = key) ["sysname", "release", "machine"])
                             (Posix.ProcEnv.uname ())
      val stats = Runtime.stats ()
      val metadata = Json.Object [("schema", num 1), ("compiler_version", str Config.version),
        ("compiler_identity", str Config.identity), ("harness_sha256", str (hash (read "bin/rune-lsp-bench.rbc"))),
        ("vm_sha256", str (hash (read "bin/runevm"))), ("processors", num (Runtime.processors ())),
        ("manifest_sha256", str (hash contents)), ("repetitions", num (!repetitions)), ("warmup", num (!warmup)),
        ("retention_cycles", num (!retentionCycles)),
        ("runtime_options", str (case OS.Process.getEnv "RUNEVM_OPTIONS" of SOME s => s | NONE => "")),
        ("platform", Json.Object (List.map (fn (k, v) => (k, str v)) uname)),
        ("service_compiler", case !service of NONE => Json.Null | SOME s => str s),
        ("heap_bytes_before_collection", num (#heapSize stats)), ("live_bytes_before_collection", num (#live stats)),
        ("oracle", str "fresh batch parser; debug hash is not structural AST equivalence")]
      val () = write (!output ^ "/metadata.json", Json.encodeIndented 2 metadata ^ "\n")
    in print ("LSP BASELINE " ^ !output ^ "\n"); OS.Process.success end
  fun entry args =
    (case args of ["--self-test"] => (selftest (); OS.Process.success)
                | ["--probe"] => (print "READY\n"; OS.Process.success)
                | _ => main args)
    handle e => (TextIO.output (TextIO.stdErr, "lsp-bench: " ^ (case e of Failed s => s
                 | LspServiceBaseline.Failed s => s | _ => General.exnMessage e) ^ "\n");
                 OS.Process.failure)
end
