(* Matrix ways in the existing inventory. Public CLI selection is carried in
   the environment; only producer jobs resolve tools and prepare libraries. *)
structure Matrix =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun integer key fallback = case Int.fromString (env (key, fallback)) of SOME n =>
                (need (n > 0, key ^ " must be positive"); n) | NONE => raise Failed (key ^ " must be an integer")
  fun timing () = env ("RUNE_MATRIX_TIMING", "0") = "1" orelse env ("RUNE_MATRIX_PERF", "0") = "1"
  fun selectedSpecs () = MatrixModel.expand (env ("RUNE_MATRIX_CONFIGS", "all"))
  fun selectedTests () =
    let val filter = env ("RUNE_MATRIX_FILTER", "")
        val names = if env ("RUNE_MATRIX_PROGRAM_LIST", "") <> "" then ["program"]
          else if env ("RUNE_MATRIX_PERF", "0") = "1" then List.map (OS.Path.base o OS.Path.file) (glob (fromRoot "tests/perf", ".expected"))
          else List.map basename (List.filter (fn path => not (List.exists (fn name => OS.Path.file path = name) ["harness.sml", "finish.sml"]))
                                    (glob (fromRoot "tests/basis", ".sml")))
    in List.filter (fn name => if env ("RUNE_MATRIX_ONE", "") <> "" then name = env ("RUNE_MATRIX_ONE", "") else String.isSubstring filter name) names end
  fun output () =
    case OS.Process.getEnv "RUNE_MATRIX_OUT" of SOME path => fromRoot path | NONE =>
      case OS.Process.getEnv "RUNE_MATRIX_RUN" of SOME path => fromRoot path ^ "/matrix" | NONE => fromRoot "tests/out/matrix"
  fun modelFile spec = run ^ "/matrix-model/" ^ MatrixSuite.path spec ^ ".tsv"
  fun config spec =
    let val file = modelFile spec
        val () = need (exists file, "matrix resolution producer did not complete: " ^ spec)
        val rows = lines (read file)
    in case rows of [row] => MatrixModel.parseRow (timing ()) row | _ => raise Failed "invalid matrix resolution record" end
  fun directory config = output () ^ "/" ^ MatrixSuite.path (#id (config : MatrixModel.config))
  fun prepare spec () =
    let val file = modelFile spec
        val () = mkdirs (OS.Path.dir file)
        val () = MatrixLoad.remove file
        val config = MatrixModel.resolve {timing = timing (), directory = run ^ "/matrix-resolution"} spec
        val dir = directory config
        val () = MatrixPrepare.prepare config dir
    in MatrixPrepare.atomic (file, MatrixModel.row config); say ("PREPARED " ^ #id config ^ "\n") end
  fun collect spec test () =
    let val c = config spec
        val dir = directory c
    in (if env ("RUNE_MATRIX_PERF", "0") = "1" then MatrixPerf.collect c dir test else MatrixSuite.collect c dir test);
       say ("COLLECTED " ^ #id c ^ " " ^ test ^ "\n") end
  fun compare spec test () =
    let val c = config spec
        val file = directory c ^ "/" ^ test ^ ".result"
        val deviations = Expectations.read (fromRoot "tests/basis/deviations.txt")
        val unexplained = MatrixSuite.compare deviations (#id c) test file
        val () = List.app (fn line => say (line ^ "\n")) unexplained
        val results = lines (read file)
        val () = if null unexplained andalso not (null results) andalso
                       List.all (fn line => String.isPrefix "ABSENT " line orelse String.isPrefix "NA " line) results
                 then say ("UNAVAILABLE " ^ String.concatWith ", " results ^ "\n") else ()
    in () end
  fun stale spec () =
    let val c = config spec
        val configs = if spec = "rune" orelse not (List.exists (fn s => s = "rune") (selectedSpecs ())) then [c] else [config "rune", c]
        val stale = MatrixSuite.stale (Expectations.read (fromRoot "tests/basis/deviations.txt")) configs
                           (selectedTests ()) directory (env ("RUNE_MATRIX_FILTER", "") <> "")
    in List.app (fn line => if String.isPrefix (#id c ^ " ") line then say ("FAIL matrix stale deviation: " ^ line ^ "\n") else ()) stale end
  fun program spec () =
    let val c = config spec
        val sources = List.map fromRoot (MatrixProgram.readList (fromRoot (env ("RUNE_MATRIX_PROGRAM_LIST", ""))))
        val input = fromRoot (env ("RUNE_MATRIX_PROGRAM_INPUT", "/dev/null"))
        val dataRoot = fromRoot (env ("RUNE_MATRIX_PROGRAM_DATA", ""))
        val list = env ("RUNE_MATRIX_PROGRAM_DATA_LIST", "")
        val data = if list = "" then [] else List.map (fn name =>
                 (need (MatrixLoad.dataPath name, "invalid program data path " ^ name); (dataRoot ^ "/" ^ name, name)))
                   (MatrixProgram.readList (fromRoot list))
    in MatrixProgram.run {config = c, directory = directory c, sources = sources, input = input, data = data,
            timeout = integer "RUNE_MATRIX_TIMEOUT" "120", memoryKiB = integer "RUNE_MATRIX_MEMORY" "4194304"} end
  fun supplements configs tests =
    let fun dropped (c : MatrixModel.config) = if MatrixLoad.kind c <> "xc1" then "" else
          String.concat (List.map (fn line => case String.fields (fn ch => ch = #"\t") line of
              [file,why] => "| " ^ #id c ^ " | " ^ file ^ " | " ^ why ^ " |\n"
             | _ => raise Failed "malformed dropped library record") (lines (read (directory c ^ "/basis.dropped"))))
        fun duration c test = case String.tokens Char.isSpace (read (directory c ^ "/" ^ test ^ ".time")) of
              [total,first,wait] => (case (Real.fromString total,Real.fromString first,Real.fromString wait) of
                 (SOME total,SOME first,SOME wait) => (total,Real.max (0.0,total-first-wait))
               | _ => raise Failed "invalid matrix timing record")
            | _ => raise Failed ("missing matrix timing record: " ^ #id c ^ " " ^ test)
        val timingRows = ref [] : string list ref
        fun timing (c : MatrixModel.config) =
          let val samples = List.map (fn test => (test,duration c test)) tests
              val total = List.foldl (fn ((_,(total,_)),acc) => total+acc) 0.0 samples
              val fallback = List.foldl (fn ((_,(_,fallback)),acc) => fallback+acc) 0.0 samples
              val () = timingRows := List.map (fn (test,(total,_)) => #id c ^ "\t" ^ test ^ "\t" ^ Real.fmt (StringCvt.FIX (SOME 3)) total) samples @ !timingRows
              val probe = case String.tokens Char.isSpace (read (directory c ^ "/basis.time")) of
                   [state,loads,seconds] =>
                     (if MatrixLoad.kind c="xc1" orelse MatrixLoad.kind c="xc2" then
                        timingRows := (#id c ^ "\t@probe\t" ^ seconds) :: !timingRows else ();
                      state ^ " " ^ loads ^ " loads, " ^ seconds ^ " s") | _ => ""
          in "| " ^ #id c ^ " | " ^ Real.fmt (StringCvt.FIX (SOME 1)) total ^ " | "
                  ^ Real.fmt (StringCvt.FIX (SOME 1)) fallback ^ " | " ^ probe ^ " |\n" end
        val timing = String.concat (List.map timing configs)
        val old = lines (read (output () ^ "/timings.tsv"))
        fun identity line = case String.fields (fn c => c = #"\t") line of config :: test :: _ => config ^ "\t" ^ test | _ => ""
        val fresh = !timingRows
        val kept = List.filter (fn old => not (List.exists (fn row => identity old = identity row) fresh)) old
        val () = MatrixPrepare.atomic (output () ^ "/timings.tsv",String.concat (List.map (fn row => row ^ "\n") (sort (fresh @ kept))))
    in "\n## Files of lib/basis that a host does not load (xc1)\n\n| Configuration | File | First error |\n|---|---|---|\n"
           ^ String.concat (List.map dropped configs)
           ^ "\n## Timing\n\n| Configuration | Work s | Fallback s | Preparation |\n|---|---:|---:|---|\n" ^ timing
           ^ "\nThe runner receipt records wall time, CPU use, job-slot utilization and slowest cases. Producer dependencies replace probe waiting.\n" end
  fun report () =
    let val configs = List.map config (selectedSpecs ())
        val tests = selectedTests ()
        val deviations = Expectations.read (fromRoot "tests/basis/deviations.txt")
        val rows = ref [] : string list ref
        val explained = ref [] : string list ref
        val unexplained = ref [] : string list ref
        fun one (c : MatrixModel.config) test =
          let val id = #id c
              val file = directory c ^ "/" ^ test ^ ".result"
              val () = need (exists file, "missing matrix result " ^ file)
              val results = lines (read file)
              val failures = MatrixSuite.failures id test results
              val checks = MatrixSuite.checks (String.concatWith "\n" results)
              val pass = length (List.filter (String.isPrefix "PASS ") checks)
              val skip = length (List.filter (String.isPrefix "SKIP ") checks)
              val bad = MatrixSuite.compare deviations id test file
              val good = List.filter (fn line => not (List.exists (fn b => b = line) bad)) failures
              fun explanation line = case MatrixSuite.explain deviations (id, MatrixSuite.label line) of SOME (r, _) =>
                      "| " ^ id ^ " | " ^ MatrixSuite.label line ^ " | " ^ #category r ^ " | " ^ #reason r ^ " |\n"
                   | _ => raise Failed "lost matrix failure explanation"
              val () = explained := List.map explanation good @ !explained
              val () = unexplained := List.map (fn line => id ^ " " ^ line) bad @ !unexplained
              val notRun = List.filter (fn line => String.isPrefix "ABSENT " line orelse String.isPrefix "NA " line) results
              val fields = [id, test, Int.toString (length checks), Int.toString pass, Int.toString (length good),
                            Int.toString (length bad), Int.toString skip, String.concatWith ", " notRun]
          in rows := ("| " ^ String.concatWith " | " fields ^ " |\n") :: !rows end
        val () = List.app (fn c => List.app (one c) tests) configs
        val stale = MatrixSuite.stale deviations configs tests directory (env ("RUNE_MATRIX_FILTER", "") <> "")
        val file = output () ^ "/report" ^ (if env ("RUNE_MATRIX_FILTER", "") = "" then "" else "-" ^ env ("RUNE_MATRIX_FILTER", "")) ^ ".md"
        val () = need (MatrixLoad.dataPath (OS.Path.file file), "invalid matrix report name")
        val text = "# Basis Library suite\n\n| Configuration | Test | Checks | Pass | Explained | Unexplained | Skipped | Not run |\n"
                   ^ "|---|---|---|---|---|---|---|---|\n" ^ String.concat (List.rev (!rows))
                   ^ "\n## Explained deviations\n\n| Configuration | Check | Category | Reason |\n|---|---|---|---|\n"
                   ^ String.concat (sort (!explained)) ^ "\n## Unexplained failures\n\n"
                   ^ String.concat (List.map (fn line => "    " ^ line ^ "\n") (List.rev (!unexplained)))
                   ^ "\n## Stale deviations\n\n" ^ String.concat (List.map (fn line => "    " ^ line ^ "\n") stale)
                   ^ supplements configs tests
        val () = MatrixPrepare.atomic (file, text)
        val () = List.app (fn line => say ("FAIL matrix stale deviation: " ^ line ^ "\n")) stale
        val () = List.app (fn line => say ("FAIL matrix unexplained: " ^ line ^ "\n")) (List.rev (!unexplained))
    in say ("report: " ^ file ^ "\n") end
  fun finalReport () = if env ("RUNE_MATRIX_PERF", "0") = "1" then
          MatrixPerf.report (List.map config (selectedSpecs ())) (selectedTests ()) directory else report ()
  fun error (MatrixLoad.Failed text)=text | error (MatrixPrepare.Failed text)=text
    | error (MatrixSuite.Failed text)=text | error (MatrixProgram.Failed text)=text
    | error (MatrixPerf.Failed text)=text | error (MatrixModel.Invalid text)=text
    | error (Failed text)=text | error e=General.exnMessage e
  fun protect f () = f () handle e => (say ("FAIL matrix controller: " ^ error e ^ "\n"); Posix.Process.exit 0w1)
  fun command ["matrix-cache-fixture", mode] = SOME (protect (MatrixCacheFaults.fixture mode))
    | command ["matrix-cache-faults"] = SOME (protect MatrixCacheFaults.one)
    | command ["matrix-prepare", spec] = SOME (protect (prepare spec))
    | command ["matrix-collect", spec, test] = SOME (protect (collect spec test))
    | command ["matrix-compare", spec, test] = SOME (protect (compare spec test))
    | command ["matrix-program", spec] = SOME (protect (program spec))
    | command ["matrix-stale", spec] = SOME (protect (stale spec))
    | command ["matrix-report"] = SOME (protect finalReport)
    | command ["matrix-recovery-fixture"] = SOME (protect MatrixExecutionFaults.fixture)
    | command ["matrix-execution-faults"] = SOME (protect MatrixExecutionFaults.one)
    | command _ = NONE
  fun job (name, args, after, memory, pools, seconds, judge) = Test.it name {program = "/bin/sh",
    args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-matrix " ^ String.concatWith " " (List.map quote args)],
    env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds seconds, cap = 0, cpus = 1,
    memory = memory, pools = pools, exclusive = env ("RUNE_MATRIX_PERF", "0") = "1", after = after, judge = judge} : Run.command Test.tree
  fun unavailable (result, files) = case failLines (result, files) of SOME why => SOME why | NONE =>
       if String.isPrefix "UNAVAILABLE " (read (#stdout files)) then SOME ("SKIP", firstNonEmpty (#stdout files)) else NONE
  fun tree () =
    let val specs = selectedSpecs ()
        val () = need (List.all MatrixModel.validSpec specs, "invalid matrix configuration")
        val () = need (length specs = length (MatrixProbe.unique specs), "duplicate matrix selection")
        val tests = selectedTests ()
        val programMode = env ("RUNE_MATRIX_PROGRAM_LIST", "") <> ""
        val perf = env ("RUNE_MATRIX_PERF", "0") = "1"
        val custom = isSome (OS.Process.getEnv "RUNE_MATRIX_CONFIGS")
        val () = need (not (null tests), "matrix selection has no matching programs")
        val memory = Int.max (500, integer "RUNE_MATRIX_MEMORY" "4194304" div 1024)
        fun host spec = case String.fields (fn c => c = #":") spec of [kind, name] => if kind = "native" orelse kind = "xc1" then SOME name else NONE | _ => NONE
        fun required spec = case host spec of NONE => [] | SOME name => ["host:" ^ name]
        fun pool spec = if host spec = SOME "mlkit" then ["matrix"] else []
        fun group spec =
          let val name = MatrixSuite.path spec
              val after = ["matrix/" ^ name ^ "/prepare"]
              val nodes = if programMode then [job ("program", ["matrix-program", spec], after, memory, pool spec, 7200, failLines)] else
                List.concat (List.map (fn test =>
                  job ("collect/" ^ test, ["matrix-collect", spec, test], after, memory, pool spec, 7200, failLines)
                    :: (if perf then [] else [job ("compare/" ^ test, ["matrix-compare", spec, test], ["matrix/" ^ name ^ "/collect/" ^ test], 200, [], 60, unavailable)])) tests)
              val nodes = nodes @ (if programMode orelse perf then [] else
                [job ("stale", ["matrix-stale", spec], List.map (fn test => "matrix/" ^ name ^ "/collect/" ^ test) tests
                    @ (if spec = "rune" orelse not (List.exists (fn s => s = "rune") specs) then [] else
                        List.map (fn test => "matrix/rune/collect/" ^ test) tests), 200, [], 120, failLines)])
              val tags = if custom then ["matrix-selected"] else ["nightly", "matrix"]
                         @ (if spec = "rune" orelse String.isPrefix "xc1:" spec then ["library", "matrix-quick"] else [])
          in List.foldl (fn (tag, tree) => Test.tag tag tree)
             (Test.requires (required spec) (Test.describe name
                (job ("prepare", ["matrix-prepare", spec], [], memory, pool spec, 14400, failLines) :: nodes))) tags end
        val dependencies = List.concat (List.map (fn spec => List.map (fn test => "matrix/" ^ MatrixSuite.path spec ^ "/collect/" ^ test) tests) specs)
        val final = if programMode then [] else [List.foldl (fn (tag, tree) => Test.tag tag tree)
            (job ("report", ["matrix-report"], dependencies, 500, [], 120, failLines))
            (if custom then ["matrix-selected"] else ["nightly", "matrix"])]
    in Test.tag "covers:tests/basis/*" (Test.tag "covers:lib/basis/*" (Test.tag "covers:tests/runner/matrix*.sml"
         (Test.describe "matrix" (List.map group specs @ final)))) end
  val faults = Test.tag "check" (Test.tag "quick" (Test.tag "covers:tests/runner/matrix*.sml"
       (Test.describe "runner" [job ("matrix-execution-faults", ["matrix-execution-faults"], [], 1500, [], 180, failLines),
        job ("matrix-cache-faults", ["matrix-cache-faults"], [], 1500, [], 180, failLines)])))
end
