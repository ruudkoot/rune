(* Laws on native Basis implementations: source selection, alternatives,
   recovery and comparison are SML values, independent of host chatter. *)
structure HostLaws =
struct
  open Sh
  exception Failed of string
  type entry = {label : string, body : string}
  type program = {name : string, head : string, entries : entry list, tail : string}
  type deviation = {config : string, label : string, category : string, reason : string}
  fun need (ok, message) = if ok then () else raise Failed message
  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))
  fun rtrim s = Substring.string (Substring.dropr Char.isSpace (Substring.full s))
  fun unique xs = MatrixProbe.unique xs
  fun member (x, xs) = List.exists (fn y => x = y) xs
  fun minus (xs, ys) = List.filter (fn x => not (member (x, ys))) xs
  fun splitProgram name text : program =
    let
      val ls = Vector.fromList (String.fields (fn c => c = #"\n") text)
      val starts = List.filter (fn i => String.isPrefix "  (\"" (Vector.sub (ls, i)))
                    (List.tabulate (Vector.length ls, fn i => i))
      fun slice (lo, hi) = String.concatWith "\n" (List.tabulate (hi - lo, fn i => Vector.sub (ls, lo + i)))
      fun entry (lo, hi, last) =
        let val body = rtrim (slice (lo, hi))
            val () = need (size body > 0 andalso (not last orelse String.isSuffix "]" body), name ^ ": malformed law program tail")
            val body = if last orelse String.isSuffix "," body then String.substring (body, 0, size body - 1) else body
            val rest = String.extract (body, 4, NONE)
            val label = Substring.string (#1 (Substring.position "\"" (Substring.full rest)))
            val () = need (label <> "" andalso not (CharVector.exists Char.isSpace label), name ^ ": malformed law label")
        in {label = label, body = body} : entry end
      fun entries [] = []
        | entries [lo] = [entry (lo, Vector.length ls, true)]
        | entries (lo :: (rest as hi :: _)) = entry (lo, hi, false) :: entries rest
    in case starts of [] => {name = name, head = text, entries = [], tail = ""}
       | first :: _ => {name = name, head = slice (0, first), entries = entries starts, tail = "]\n"} end
  fun dependencies body = unique (SmlScan.qualified body @ SmlScan.opens body)
  fun opened body = List.concat (List.map (fn name => List.map (fn path => (name, path))
                              (List.filter (fn path => path <> name) (dependencies body))) (SmlScan.opens body))
  fun prefixes path =
    let val parts = String.fields (fn c => c = #".") path
    in List.tabulate (length parts, fn i => String.concatWith "." (List.take (parts, i + 1))) end
  fun libraryFiles () = Hosts.manifest "test/property" @ Hosts.manifest "test/property/basis"
  fun libraryNames files = unique (List.concat (List.map (fn r : Hosts.source => #provides r) files)
                                 @ List.concat (List.map #provides (Hosts.manifest "random")))
  fun libraryFor files present dropped =
    let val all = libraryNames files
        val initial = minus (all, List.concat (List.map (fn r : Hosts.source => #provides r) files))
        fun one (r : Hosts.source, (selected, provided)) =
          let val ready = List.all (fn name => member (name, if member (name, all) then provided else present)) (#requires r)
          in if (#host r orelse ready) andalso not (member (#path r, dropped))
             then (selected @ [#path r], unique (provided @ #provides r)) else (selected, provided) end
    in List.foldl one ([], initial) files end
  fun verdicts output =
    let
      fun label word = if String.isSuffix ":" word then String.substring (word, 0, size word - 1) else word
      fun one (line, got) =
        case String.tokens Char.isSpace line of status :: name :: _ =>
            if (status = "PASS" orelse status = "FAIL") andalso String.isPrefix (status ^ " ") line then
              (label name, (status, trim line)) :: List.filter (fn (name', _) => name' <> label name) got
            else got
          | _ => got
    in List.foldl one [] (lines output) end
  fun deviations file =
    let fun one line =
          let val fs = List.map trim (String.fields (fn c => c = #"|") line)
          in case fs of config :: label :: category :: reason =>
               (need (isSome (Expectations.meaning category), file ^ ": unknown category " ^ category);
                need (not (null reason) andalso trim (String.concatWith "|" reason) <> "", file ^ ": missing deviation reason");
                {config = config, label = label, category = category, reason = String.concatWith "|" reason} : deviation)
             | _ => raise Failed (file ^ ": malformed deviation") end
    in if not (exists file) then [] else List.map one
        (List.filter (fn line => trim line <> "" andalso not (String.isPrefix "#" (trim line))) (String.fields (fn c => c = #"\n") (read file))) end
  fun listed skips label =
    if not (exists skips) then false else
      List.exists (fn line => let val line = trim line in line <> "" andalso not (String.isPrefix "#" line)
                 andalso Expectations.glob (trim (hd (String.fields (fn c => c = #"|") line)), label) end)
                 (String.fields (fn c => c = #"\n") (read skips))
  fun runeVerdicts file =
    if file = "" then NONE else
      (need (exists file, "LAWS_RESULTS names no file: " ^ file); SOME (verdicts (read file)))
  fun runeVerdict skips reference label =
    case reference of SOME rows => Option.map #2 (List.find (fn (name, _) => name = label) rows)
    | NONE => SOME (if listed skips label then ("FAIL", "listed in " ^ skips)
                   else ("PASS", "not listed in " ^ skips ^ ", so make test-laws holds it"))
  fun compare host skips reference devs output =
    let
      fun one ((label, (status, line)), (explained, unexplained)) =
        case runeVerdict skips reference label of NONE => (explained, unexplained)
        | SOME (rune, theirs) =>
            if rune = status orelse (rune = "FAIL" andalso status = "PASS" andalso listed skips label)
            then (explained, unexplained)
            else
              let val why = List.find (fn r : deviation => Expectations.glob (#config r, "native:" ^ host)
                                                               andalso Expectations.glob (#label r, label)) devs
                  val text = host ^ " " ^ label ^ ": Rune " ^ rune ^ ", " ^ host ^ " " ^ status
                            ^ "\n    Rune: " ^ theirs ^ "\n    " ^ host ^ ": " ^ line
              in case why of NONE => (explained, unexplained @ [text])
                 | SOME r => (explained @ [text ^ "\n    explained: " ^ #category r ^ ": " ^ #reason r], unexplained) end
      val rows = verdicts output
      val rows = List.map (fn label => valOf (List.find (fn (name, _) => name = label) rows)) (sort (List.map #1 rows))
    in List.foldl one ([], []) rows end
  fun nonpassing output =
    List.mapPartial (fn line =>
      let val fs = String.tokens Char.isSpace line
          val name = case fs of "NOT" :: ("BUILT" :: name :: _) => SOME name
                       | "NOT" :: ("RUN" :: name :: _) => SOME name
                       | status :: name :: _ => if member (status, ["FAIL", "FLAKY", "STOPPED"]) then SOME name else NONE
                       | _ => NONE
      in Option.map (fn name => if String.isSuffix ":" name then String.substring (name, 0, size name - 1) else name) name end) (lines output)
  fun stale results devs =
    List.concat (List.map (fn r : deviation => if #category r = "HOST-FLAKY" then [] else
      List.concat (List.map (fn (host, output) =>
        if Expectations.glob (#config r, "native:" ^ host)
           andalso not (List.exists (fn label => Expectations.glob (#label r, label)) (nonpassing output))
        then ["stale deviation: " ^ #config r ^ " | " ^ #label r ^ " matches no law that " ^ host ^ " did not pass"] else []) results)) devs)
  fun firstError messages =
    let val ls = lines messages
        fun find [] = []
          | find (line :: rest) = if String.isSubstring "Error" line orelse String.isSubstring "error:" line
                                    orelse (String.isSubstring ", line " line andalso String.isSubstring ", column " line)
                                 then List.take (line :: rest, Int.min (4, length (line :: rest))) else find rest
        val error = find ls
        val text = if null error then (case List.rev ls of line :: _ => trim line | [] => "(no message)")
                   else String.concatWith " " (List.map trim error)
    in String.substring (text, 0, Int.min (240, size text)) end
  fun libraryOn host files present directory build =
    let
      val marker = directory ^ "/library.sml"
      val () = write (marker, "val () = print \"library built\\n\"\n")
      val random = ["lib/random/random_sig.sml", "lib/random/random.sml"]
      fun loop (attempt, dropped) =
        if attempt > length files then raise Failed (host ^ ": property library did not stabilize") else
          let val (chosen, provided) = libraryFor files present dropped
              val result : MatrixHost.result = build ("library", random @ chosen @ [marker])
          in
            if #built result then
              (need (#status result = 0 andalso String.isSubstring "library built\n" (#output result), host ^ ": property library initialization failed");
               (chosen, provided, dropped))
            else
              let val bad = List.filter (fn path =>
                       List.exists (fn r : Hosts.source => #path r = path andalso not (#host r)) files
                       andalso not (null (MatrixProbe.errorLines host (#messages result) path))) chosen
              in case bad of path :: _ => loop (attempt + 1, dropped @ [path])
                 | [] => raise Failed (host ^ ": property library does not build: " ^ firstError (#messages result)) end
          end
    in loop (0, []) end
  fun finishWith failure initial again =
    let
      fun hasVerdict label output = isSome (List.find (fn (name, _) => name = label) (verdicts output))
      fun ordinaryFailure status output = status = failure andalso
          List.exists (fn (_, (verdict, _)) => verdict = "FAIL") (verdicts output)
          andalso List.exists (fn line => case String.tokens Char.isSpace line of
              ["laws:", _, "pass,", failed, "fail"] => (case Int.fromString failed of SOME n => n > 0 | NONE => false)
            | _ => false) (lines output)
      fun loop (attempt, status, output, outputs, stopped) =
        if List.exists (String.isPrefix "laws: ") (lines output) then
          (need (status = 0 orelse ordinaryFailure status output, "law program failed after printing its final verdicts");
           (String.concatWith "\n" (List.rev (output :: outputs)), List.rev stopped))
        else if attempt >= 50 then (String.concatWith "\n" (List.rev (output :: outputs)), List.rev stopped)
        else
          case List.rev (List.filter (String.isPrefix "LAW ") (lines output)) of
            [] => (need (status = 0, "law program failed before its first law");
                   (String.concatWith "\n" (List.rev (output :: outputs)), List.rev stopped))
          | line :: _ =>
              let val label = case String.tokens Char.isSpace line of _ :: label :: _ => label | _ => raise Failed "malformed LAW marker"
              in
                if member (label, List.map #1 stopped) then (String.concatWith "\n" (List.rev (output :: outputs)), List.rev stopped)
                else if hasVerdict label output then
                  (* Preserve the old stop boundary, but reject an abnormal
                     process ending rather than accepting its printed PASS. *)
                  (need (status = 0, "law program failed after a printed verdict");
                   (String.concatWith "\n" (List.rev (output :: outputs)), List.rev stopped))
                else
                  let val last = case List.rev (lines output) of text :: _ => trim text | [] => "it stopped"
                      val why = if String.isPrefix "LAW " last then "it stopped" else String.substring (last, 0, Int.min (160, size last))
                      val (status, next) = again [("RUNE_PROPERTY_AFTER", label)]
                  in loop (attempt + 1, status, next, output :: outputs, (label, why) :: stopped) end
              end
    in loop (0, #1 initial, #2 initial, [], []) end
  fun finish initial again = finishWith 1 initial again
  type choice = {label : string, body : string, rest : string list}
  type context = {out : string, programs : program list, alternatives : (string * string list) list,
                  files : Hosts.source list, libraryNames : string list, basisNames : string list,
                  pairs : (string * string) list, skips : string, reference : (string * (string * string)) list option,
                  deviations : deviation list}
  fun structureOf label =
    (need (String.isSubstring "@" label, "law label has no structure");
     case List.rev (String.fields (fn c => c = #"@") label) of name :: _ =>
       (need (name <> "", "law label has an empty structure"); name) | [] => raise Failed "law label has no structure")
  fun generate out =
    let
      val programsDir = out ^ "/programs"
      val () = mkdirs programsDir
      val runedoc = MatrixModel.find (env ("RUNEDOC", fromRoot "bin/runedoc"))
      val status = Children.exec {addressSpace = NONE, cpuTime = SOME 600, fileSize = SOME (64 * 1024 * 1024), core = SOME 0} (fn e => e)
          {cmd = [runedoc, "--lib", "lib", "--library", "basis", "--laws", programsDir], dir = SOME root,
           stdin = "", stdout = out ^ "/runedoc.log", stderr = out ^ "/runedoc.log", timeout = 600}
      val () = need (status = 0, "runedoc --laws failed: " ^ firstError (read (out ^ "/runedoc.log")))
    in () end
  fun load out selected : context =
    let val programsDir = out ^ "/programs"
      val programs = List.map (fn file => splitProgram (OS.Path.base file) (read (programsDir ^ "/" ^ file)))
                     (List.filter (fn file => String.isSuffix ".sml" file andalso selected (OS.Path.base file)) (sort (entries programsDir)))
      val alternatives = List.map (fn file => splitProgram (OS.Path.base file) (read (programsDir ^ "/" ^ file)))
                     (List.filter (fn file => String.isSuffix ".alt" file andalso List.exists (fn p : program => #name p = OS.Path.base file) programs)
                                (sort (entries programsDir)))
      fun add ({label, body} : entry, table) =
        let val previous = case List.find (fn (name, _) => name = label) table of SOME (_, xs) => xs | NONE => []
        in (label, previous @ [body]) :: List.filter (fn (name, _) => name <> label) table end
      val alternatives = List.foldl add [] (List.concat (List.map #entries alternatives))
      val allEntries = List.concat (List.map #entries programs)
      fun bodies ({label, body} : entry) = body :: (case List.find (fn (name, _) => name = label) alternatives of SOME (_, xs) => xs | NONE => [])
      val files = libraryFiles ()
      val libraryNames = libraryNames files
      val wanted = unique (List.concat (List.map (fn e : entry => structureOf (#label e) :: List.concat (List.map dependencies (bodies e))) allEntries)
                          @ List.concat (List.map (fn r : Hosts.source => #requires r) files))
      val basisNames = unique (List.concat (List.map prefixes (List.filter (fn name => not (member (hd (String.fields (fn c => c = #".") name), libraryNames))) wanted)))
      val pairs = unique (List.concat (List.map (fn entry => List.concat (List.map opened (bodies entry))) allEntries))
    in {out = out, programs = programs, alternatives = alternatives, files = files, libraryNames = libraryNames,
        basisNames = basisNames, pairs = pairs, skips = env ("LAWS_SKIPS", "tests/basis/law-skips.txt"),
        reference = runeVerdicts (env ("LAWS_RESULTS", "")), deviations = deviations (env ("LAWS_DEVIATIONS", "tests/basis/law-deviations.txt"))} end
  fun prepare out selected = (generate out; load out selected)
  fun runProgram {host, program = p : program, alternatives, lacks, directory, library, build} =
    let
      val notbuilt = ref [] : (string * string) list ref
      val onAlternative = ref [] : string list ref
      fun choose ({label, body} : entry) =
        let val extra = case List.find (fn (name, _) => name = label) alternatives of SOME (_, bodies) => bodies | NONE => []
            val choices = List.filter (fn body => null (lacks (label, body))) (body :: extra)
        in case choices of first :: rest => SOME {label = label, body = first, rest = rest}
           | [] => (notbuilt := !notbuilt @ [(label, "the host lacks " ^ String.concatWith ", " (lacks (label, body)))]; NONE) end
      val initial = List.mapPartial choose (#entries p)
      val source = directory ^ "/" ^ #name p ^ ".sml"
      val head = #head p
      fun writeProgram keep = write (source, head ^ "\n" ^ String.concatWith ",\n" (List.map (fn c : choice => #body c) keep) ^ #tail p)
      fun entryLocations keep =
        let fun loop ([], _, acc) = List.rev acc
              | loop ((c : choice) :: rest, at, acc) =
                  let val count = length (String.fields (fn c => c = #"\n") (#body c))
                  in loop (rest, at + count, (at + 1, at + count, #label c) :: acc) end
        in loop (keep, length (String.fields (fn c => c = #"\n") head), []) end
      fun noBuild keep why =
        (notbuilt := !notbuilt @ List.map (fn c : choice => (#label c, why)) keep; ([], "", [], NONE))
      fun attempt ([], _, _) = ([], "", [], NONE)
        | attempt (keep, 12, why) = noBuild keep ("the program does not build after 12 attempts: " ^ why)
        | attempt (keep, count, _) =
          let
            val () = writeProgram keep
            val result : MatrixHost.result = build (#name p, library @ [source])
            val () = write (directory ^ "/" ^ #name p ^ ".build", #messages result)
          in
            if #built result then
              let val (output, stopped) = finishWith (if host = "mlkit" then 255 else 1) (#status result, #output result) (#again result)
              in (keep, output, stopped, SOME (#again result)) end
            else
              let
                val errors = MatrixProbe.errorLines host (#messages result) source
                val hit = List.mapPartial (fn (lo, hi, label) =>
                     if List.exists (fn line => lo <= line andalso line <= hi) errors then SOME label else NONE) (entryLocations keep)
                val why = firstError (#messages result)
                val () = need (MatrixProbe.staticError host (#messages result) orelse not (null errors),
                               host ^ ": compiler failed without a located static diagnostic: " ^ why)
                fun next (c : choice) =
                  if not (member (#label c, hit)) then SOME c else
                    case #rest c of body :: rest => SOME {label = #label c, body = body, rest = rest}
                    | [] => (notbuilt := !notbuilt @ [(#label c, why)]; NONE)
              in if null hit then noBuild keep ("the program does not build: " ^ why)
                 else attempt (List.mapPartial next keep, count + 1, why) end
          end
      val (keep, output, stopped, again) = attempt (initial, 0, "")
      val () = write (directory ^ "/" ^ #name p ^ ".out", output)
      val got = verdicts output
      fun primary label = #body (valOf (List.find (fn e : entry => #label e = label) (#entries p)))
      val () = onAlternative := List.map #label (List.filter (fn c : choice => #body c <> primary (#label c)) keep)
      fun result (c : choice) =
        let val label = #label c
        in case List.find (fn (name, _) => name = label) got of
            SOME (_, ("FAIL", line)) =>
              (case again of NONE => line | SOME run =>
                let fun retry 0 = NONE
                      | retry n =
                          let val (status, output) = run [("RUNE_PROPERTY_AFTER", ""), ("RUNE_PROPERTY_ONLY", label)]
                              val found = List.find (fn (name, _) => name = label) (verdicts output)
                          in case found of SOME (_, (verdict, line)) => (need (status = 0 orelse (status = (if host = "mlkit" then 255 else 1) andalso verdict = "FAIL"), "law rerun failed after a verdict"); SOME line)
                             | NONE => retry (n - 1) end
                in case retry 3 of NONE => line ^ "; again: the program stopped before a verdict, three times"
                   | SOME second => if second = line then line else "FLAKY " ^ label ^ ": " ^ line ^ "; again: " ^ second end)
          | SOME (_, (_, line)) => line
          | NONE => (case List.find (fn (name, _) => name = label) stopped of
                       SOME (_, why) => "STOPPED " ^ label ^ ": " ^ why
                     | NONE => "NOT RUN " ^ label ^ ": the program stopped before it") end
      val results = List.map result keep @ List.map (fn (label, why) => "NOT BUILT " ^ label ^ ": " ^ why) (!notbuilt)
      val () = need (null keep orelse not (null got) orelse not (null stopped), "law program exited without any law output")
    in {results = results, alternatives = !onAlternative} end
  fun oneHost (ctx : context) name =
    let
      val h = MatrixModel.host name
      val directory = #out ctx ^ "/" ^ name
      val () = mkdirs directory
      val () = rmTree (directory ^ "/unavailable.txt")
      fun setting (key, fallback) =
        case Int.fromString (env (key, Int.toString fallback)) of SOME n => if n > 0 then n else raise Failed (key ^ " must be positive")
        | NONE => raise Failed (key ^ " must be an integer")
      val timeout = setting ("LAWS_HOST_TIMEOUT", 600)
      val memory = setting ("LAWS_HOST_MEMORY", 8192)
      fun build (program, sources) = MatrixHost.laws {host = h, name = program, sources = sources,
                directory = directory, runDirectory = directory, input = "", timeout = timeout, memory = memory}
      val unavailable =
        if name <> "smlnj32" then NONE else
          let
            val version = MatrixModel.version (directory ^ "/support-version") h
            val source = directory ^ "/framework-word64.sml"
            val () = write (source, "val () = print (\"@@WORD64_MAX \" ^ Word64.toString (Word64.notb 0w0) ^ \"\\n\")\n")
            val probe = build ("framework-word64", [source])
            val () = need (#built probe andalso #status probe = 0, "native property framework preflight failed")
            val value = List.find (String.isPrefix "@@WORD64_MAX ") (lines (#output probe))
          in case value of SOME "@@WORD64_MAX FFFFFFFFFFFFFFFF" => NONE
             | SOME "@@WORD64_MAX FFFFFFFF3FFFFFFF" =>
                 if version = "110.99.9" then SOME ("HOST-BUG: official SML/NJ32 110.99.9 boot files corrupt Word64's low half; "
                    ^ "the property library cannot initialize (docs/bugreport/smlnj/Word64-low-half)")
                 else raise Failed "unclassified Word64 failure in the property framework preflight"
             | _ => raise Failed "invalid result from the property framework preflight" end
    in case unavailable of
      SOME reason =>
        let val output = String.concat (List.map (fn p : program => String.concat
                    (List.map (fn e : entry => "NOT BUILT " ^ #label e ^ ": " ^ reason ^ "\n") (#entries p))) (#programs ctx))
            val () = write (#out ctx ^ "/" ^ name ^ ".results", output)
            val () = write (directory ^ "/unavailable.txt", reason ^ "\n")
        in {output = output, explained = [], unexplained = [], alternatives = [], unavailable = SOME reason} end
    | NONE => let
      val missing = MatrixProbe.missingOn {host = h, names = #basisNames ctx, directory = directory ^ "/probe"}
      fun isLibrary path = member (hd (String.fields (fn c => c = #".") path), #libraryNames ctx)
      val under = unique (List.concat (List.map (fn (o', name) =>
                    if List.exists (fn prefix => member (prefix, missing)) (prefixes name)
                    then List.filter (fn path => not (isLibrary path)) (prefixes (o' ^ "." ^ name)) else []) (#pairs ctx)))
      val under = minus (under, #basisNames ctx)
      val missing = unique (missing @ MatrixProbe.missingOn {host = h, names = under, directory = directory ^ "/under-probe"})
      val () = write (#out ctx ^ "/" ^ name ^ ".structures", String.concat (List.map (fn path => path ^ "\n") (sort missing)))
      val (chosen, provided, dropped) = libraryOn name (#files ctx) (minus (#basisNames ctx, missing)) directory build
      val () = write (#out ctx ^ "/" ^ name ^ ".library", String.concat (List.map (fn path => path ^ "\n") chosen)
                            ^ String.concat (List.map (fn path => "left out: " ^ path ^ "\n") (sort dropped)))
      fun lacks path = List.filter (fn prefix => if isLibrary prefix then not (member (prefix, provided)) else member (prefix, missing)) (prefixes path)
      fun lackOf (label, body) = unique (List.concat (List.map
            (fn path => if List.exists (fn opened => opened <> path andalso null (lacks (opened ^ "." ^ path))) (SmlScan.opens body)
                        then [] else lacks path) (unique (structureOf label :: dependencies body))))
      val results = List.map (fn p => runProgram {host = name, program = p, alternatives = #alternatives ctx,
              lacks = lackOf, directory = directory, library = ["lib/random/random_sig.sml", "lib/random/random.sml"] @ chosen, build = build}) (#programs ctx)
      val output = String.concat (List.map (fn result => String.concat (List.map (fn line => line ^ "\n") (#results result))) results)
      val alternatives = List.concat (List.map #alternatives results)
      val () = write (#out ctx ^ "/" ^ name ^ ".results", output)
      val () = write (#out ctx ^ "/" ^ name ^ ".alternatives", String.concat (List.map (fn label => label ^ "\n") alternatives))
      val (explained, unexplained) = compare name (#skips ctx) (#reference ctx) (#deviations ctx) output
      val () = write (#out ctx ^ "/" ^ name ^ ".differences", String.concatWith "\n" (explained @ unexplained) ^ "\n")
    in {output = output, explained = explained, unexplained = unexplained, alternatives = alternatives, unavailable = NONE} end end
  fun outputDirectory () =
    case OS.Process.getEnv "RUNE_TEST_RUN" of SOME dir => dir ^ "/host-laws"
    | NONE => fromRoot "tests/out/laws-hosts"
  fun selectedHosts () =
    let val text = env ("LAWS_HOST_SELECTED", "")
        val names = if text = "" then Hosts.names else String.tokens (fn c => c = #"," orelse Char.isSpace c) text
        val () = need (List.all (fn name => member (name, Hosts.names)) names andalso length (unique names) = length names,
                       "invalid or duplicate native law host selection")
    in names end
  fun prepareAction () =
    let val out = outputDirectory ()
        val () = generate out
        val names = List.map (OS.Path.base o OS.Path.file) (glob (out ^ "/programs", ".sml"))
        val selected = ProgramSelect.filter {pattern = env ("LAWS_PROGRAMS", ""), names = names, directory = out ^ "/selection"}
        val () = write (out ^ "/selected.pending", String.concat (List.map (fn name => name ^ "\n") selected))
    in OS.FileSys.rename {old = out ^ "/selected.pending", new = out ^ "/selected.txt"} end
  fun context () =
    let val out = outputDirectory ()
        val () = need (exists (out ^ "/selected.txt"), "native law producer did not publish a selected-program list")
        val selected = lines (read (out ^ "/selected.txt"))
    in load out (fn name => member (name, selected)) end
  fun collectAction host () =
    let val ctx = context ()
        val result = oneHost ctx host
        val output = #output result
        fun count prefix = length (List.filter (String.isPrefix prefix) (lines output))
    in case #unavailable result of SOME reason => say (host ^ ": framework unavailable: " ^ reason ^ "\n")
       | NONE => say (host ^ ": " ^ Int.toString (count "PASS ") ^ " laws pass, " ^ Int.toString (count "FAIL ")
              ^ " fail, " ^ Int.toString (count "FLAKY ") ^ " flaky, " ^ Int.toString (count "STOPPED ") ^ " stopped, "
              ^ Int.toString (count "NOT BUILT ") ^ " not built, " ^ Int.toString (count "NOT RUN ") ^ " not run\n") end
  fun compareAction host () =
    let val ctx = context ()
        val out = #out ctx
        val unavailable = out ^ "/" ^ host ^ "/unavailable.txt"
    in if exists unavailable then say ("UNAVAILABLE " ^ read unavailable) else
      let val file = out ^ "/" ^ host ^ ".results"
          val () = need (exists file, "native law collector published no results for " ^ host)
          val (explained, unexplained) = compare host (#skips ctx) (#reference ctx) (#deviations ctx) (read file)
          val () = List.app (fn text => say (text ^ "\n")) unexplained
      in need (null unexplained, host ^ ": " ^ Int.toString (length unexplained) ^ " unexplained differences from Rune");
         say (host ^ ": " ^ Int.toString (length explained) ^ " differences from Rune explained, 0 not\n") end end
  fun compareFiles out hosts =
    let
      val skips = env ("LAWS_SKIPS", "tests/basis/law-skips.txt")
      val reference = runeVerdicts (env ("LAWS_RESULTS", ""))
      val devs = deviations (env ("LAWS_DEVIATIONS", "tests/basis/law-deviations.txt"))
      val results = List.mapPartial (fn host =>
        if exists (out ^ "/" ^ host ^ "/unavailable.txt") then NONE else
        let val file = out ^ "/" ^ host ^ ".results"
        in if exists file then SOME (host, read file) else NONE end) hosts
      val differences = List.concat (List.map (fn (host, output) =>
        let val (explained, unexplained) = compare host skips reference devs output
            val () = write (out ^ "/" ^ host ^ ".differences", String.concatWith "\n" (explained @ unexplained) ^ "\n")
        in unexplained end) results)
      val old = stale results devs
      val () = write (out ^ "/differences.txt", String.concat (List.map (fn text => text ^ "\n") (differences @ old)))
      val () = List.app (fn text => say (text ^ "\n")) (differences @ old)
    in need (null differences andalso null old, Int.toString (length differences) ^ " unexplained differences, " ^ Int.toString (length old) ^ " stale deviations") end
  fun finalAction () =
    let val out = outputDirectory ()
        val hosts = selectedHosts ()
        (* Keep --compare's historical entrypoint usable after a runner run.
           Copy small result records, not the large compiler workspaces. *)
        val public = fromRoot "tests/out/laws-hosts"
        val () = mkdirs public
        val () = List.app (fn host =>
            List.app (fn suffix => if exists (out ^ "/" ^ host ^ suffix) then
              write (public ^ "/" ^ host ^ suffix, read (out ^ "/" ^ host ^ suffix)) else ())
                       [".results", ".differences", ".structures", ".library", ".alternatives"]) hosts
        val () = List.app (fn host =>
          let val file = public ^ "/" ^ host ^ "/unavailable.txt"
              val () = mkdirs (OS.Path.dir file)
              val () = rmTree file
          in if exists (out ^ "/" ^ host ^ "/unavailable.txt") then
               write (file, read (out ^ "/" ^ host ^ "/unavailable.txt")) else () end) hosts
        val () = compareFiles out hosts
    in say "test-laws-hosts: no unexplained differences or stale deviations\n" end
  fun protect label f () = f () handle Failed message => say ("FAIL native laws " ^ label ^ ": " ^ message ^ "\n")
    | MatrixProbe.Failed message => say ("FAIL native laws " ^ label ^ ": " ^ message ^ "\n")
    | MatrixModel.Invalid message => say ("FAIL native laws " ^ label ^ ": " ^ message ^ "\n")
    | ProgramSelect.Invalid message => say ("FAIL native laws " ^ label ^ ": " ^ message ^ "\n")
  fun command ["host-laws-prepare"] = SOME (protect "prepare" prepareAction)
    | command ["host-laws-collect", host] = SOME (protect host (collectAction host))
    | command ["host-laws-compare", host] = SOME (protect host (compareAction host))
    | command ["host-laws-final"] = SOME (protect "compare" finalAction)
    | command _ = NONE
  fun main args =
    let
      val () = OS.FileSys.chDir root
      val compareOnly = case args of "--compare" :: _ => true | _ => false
      val names = case args of "--compare" :: rest => rest | rest => rest
      val names = if null names then Hosts.names else names
      val () = need (List.all (fn name => member (name, Hosts.names)) names andalso length (unique names) = length names,
                     "usage: rune-laws-hosts [--compare] [HOST...]")
    in if compareOnly then
         (compareFiles (fromRoot "tests/out/laws-hosts") names; say "test-laws-hosts: no unexplained differences or stale deviations\n")
       else
         let val vm = fromRoot "bin/runevm"
             val e = setEnv ("LAWS_HOST_SELECTED", String.concatWith "," names) (Posix.ProcEnv.environ ())
         in Posix.Process.exece (vm, [vm, fromRoot "bin/rune-test.rbc", "run", "--tier", "test-laws-hosts"], e) end end
  fun job (name, args, after, memory, pools, judge) =
    Test.it name {program = "/bin/sh", args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-laws-hosts "
          ^ String.concatWith " " (List.map quote args)], env = NONE, dir = SOME ".", stdin = NONE,
      timeout = Time.fromSeconds 43200, cap = 0, cpus = 1, memory = memory, pools = pools, exclusive = false,
      after = after, judge = judge} : Run.command Test.tree
  fun hostJudge host (result, files) =
    case failLines (result, files) of SOME why => SOME why | NONE =>
      if String.isSubstring "UNAVAILABLE " (read (#stdout files)) then
        SOME ("SKIP", "native property framework unavailable: see its recorded host preflight") else NONE
  fun tree () =
    let val hosts = selectedHosts ()
        val slots = Int.max (1, getOpt (Int.fromString (env ("LAWS_HOST_JOBS", "3")), 3))
        val memory = Int.max (1, getOpt (Int.fromString (env ("LAWS_HOST_MEMORY", "8192")), 8192))
        val regex = if env ("LAWS_PROGRAMS", "") = "" then [] else ["grep-pcre"]
        fun host (i, name) = Test.requires ["host:" ^ name] (Test.describe name
          [job ("collect", ["host-laws-collect", name], ["host-laws/prepare"], memory,
                ("host-law-slot-" ^ Int.toString (i mod slots)) :: (if name = "mlkit" then ["matrix"] else []), failLines),
           job ("compare", ["host-laws-compare", name], ["host-laws/" ^ name ^ "/collect"], 200, [], hostJudge name)])
    in Test.tag "test-laws-hosts" (Test.tag "covers:tests/basis/law-*" (Test.tag "covers:lib/test/property/*"
      (Test.describe "host-laws"
        (Test.requires regex (job ("prepare", ["host-laws-prepare"], [], 2000, [], failLines))
         :: List.map host (ListPair.zip (List.tabulate (length hosts, fn i => i), hosts))
         @ [job ("final", ["host-laws-final"], List.map (fn name => "host-laws/" ^ name ^ "/collect") hosts, 200, [], failLines)])))) end
end
