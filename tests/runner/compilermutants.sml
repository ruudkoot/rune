(* Mutants of the compiler: which check catches which bug seeded in it
   (docs/testing.md, Mutants of the compiler; the linting roadmap's E3, kept
   by its M4). A mutant (tests/runner/compilermutantlist.sml) is one or
   more exact edits of the compiler's sources; it is built with bin/rune.rbc
   into a compiler of its own, which compiles a fixed corpus as the good
   compiler (bin/rune.rbc) did, at the default level of the checks (0). An
   item whose output differs exercises the mutant; up to `cap` of those, an
   even sample, are compiled again at level 2, where every pass is linted,
   and run in each of their ways, against the good compiler's runs (each
   run twice, so that an unstable one gives no verdict). What sees the
   mutant: the compiler stopping (an assertion that is always on), a lint
   (which, after which stage), a program of tests/errors accepted, the VM
   (its loader, its checks, --checked), the output, -O0 against -O2 (the
   rule of check-levels), and the bootstrap, whose stage two must compile
   the compiler as the good one does.

   The corpus: tests/lang and tests/perf at -O0 and -O2; 24 tests of the
   Basis; a sample of tests/lang on the stack target, and another built in
   units, each way and whole (--units --whole -O2); tests/errors, for the
   mutants of the elaborator and Translate; a dynamic module and the
   program that loads it, a functor of an earlier unit inlined, and a
   functor's function kept in its unit (tests/compiler/mutants,
   tests/units/functor-earlier, mod.functor.functions_capture in units),
   which E3's lacked; and the bootstrap at -O0 and -O2. Where no byte
   differs, a sample of the corpus and its extra items are linted still,
   for a mutant only a lint sees (E3's T09).

   Jobs (tier test-compiler-mutants, which make test-compiler-mutants runs
   and the nightly's job of its own: it takes hours): the good compiler's
   outputs, lints and runs in a job for each part of the corpus; a job for
   each mutant after them, which says what saw it; and a summary, in
   tests/out/compiler-mutants, which fails where a mutant in lintCaught is
   caught by no lint any more. COMPILER_MUTANTS=E01,M02 runs those alone;
   COMPILER_MUTANTS_QUICK=N keeps the first N items of each part, to try
   the harness. A broken controller is a FAIL, never a verdict.

   make check holds the mutants to the sources, as nothing else does between
   full runs: prepare, and a job for each mutant that builds it (built-ID).
   A mutant that no longer applies or compiles seeds nothing, and that is a
   FAIL in both tiers. *)
structure CompilerMutants =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  type mutant = CompilerMutantList.mutant

  (* ---- the corpus *)
  type item = {id : string, part : string, flags : string list, srcs : string list,
               module : string list,                 (* a dynamic module's sources, built first *)
               run : {args : string list, vmargs : string list, stdin : string} option,
               ways : string list, group : string, level : string}

  val cap = 160
  fun quick () = getOpt (Int.fromString (env ("COMPILER_MUTANTS_QUICK", "0")), 0)
  fun evenSample (xs, n) =
    if length xs <= n then xs else List.tabulate (n, fn i => List.nth (xs, (i * length xs) div n))
  fun programs dir = List.map basename (glob (dir, ".sml"))
  fun runOf base = {args = words (base ^ ".args"), vmargs = words (base ^ ".vmargs"),
                    stdin = if exists (base ^ ".stdin") then base ^ ".stdin" else ""}
  val basisTests = ["list", "listpair", "option", "bool", "char", "string", "substring", "stringcvt", "int", "intinf",
                    "word", "word8", "real", "math", "vector", "array", "arrayslice", "general", "ieeereal", "pack_real",
                    "intn_int64", "intn_word64", "textio", "vectorslice"]
  val runWays = ["interp", "t2c", "t2u"]
  fun plain (id, part, flags, srcs, run, ways, group, level) : item =
    {id = id, part = part, flags = flags, srcs = srcs, module = [], run = run, ways = ways, group = group, level = level}
  (* the compiler's own sources, as the bootstrap compiles them *)
  fun bootSources () = lines (read (run ^ "/compiler-mutants/bootsrcs.txt"))

  fun corpus () : item list =
    let
      fun levels (dir, kind) =
        List.concat (List.map (fn n =>
          let val b = dir ^ "/" ^ n
          in List.map (fn lv => plain (kind ^ "/" ^ n ^ "@" ^ lv, kind ^ "-" ^ lv, ("-" ^ lv) :: words (b ^ ".cargs"), [b ^ ".sml"],
                                       SOME (runOf b), runWays, kind ^ "/" ^ n, lv))
                      ["O0", "O2"]
          end) (programs dir))
      val lang = programs "tests/lang"
      fun basis t =
        plain ("basis/" ^ t, "basis", [],
               ["tests/basis/harness.sml"] @ List.map (fn u => "tests/basis/" ^ u) (Basis.uses t) @ ["tests/basis/" ^ t ^ ".sml", "tests/basis/finish.sml"],
               SOME {args = [], vmargs = [], stdin = ""}, ["interp", "t2c"], "", "")
      fun stack n =
        let val b = "tests/lang/" ^ n
        in List.map (fn lv => plain ("stack/" ^ n ^ "@" ^ lv, "stack", ["--target=stack", "-" ^ lv] @ words (b ^ ".cargs"), [b ^ ".sml"],
                                     SOME (runOf b), ["stack"], "stack/" ^ n, lv)) ["O0", "O2"] end
      fun units (n, srcs, cargs, base) =
        [plain ("units/" ^ n ^ "@U1", "units", ["--units", "--no-cache"] @ cargs, srcs, SOME (runOf base), ["interp", "t2c"], "", ""),
         plain ("units/" ^ n ^ "@UW2", "units", ["--units", "--whole", "--no-cache", "-O2"] @ cargs, srcs, SOME (runOf base),
                ["interp", "t2c"], "", "")]
      val dyn = "tests/compiler/mutants/"
      val extra =
        {id = "dynamic/shape@U1", part = "extra", flags = ["--units", "--no-cache"], srcs = [dyn ^ "shape.sml", dyn ^ "client.sml"],
         module = [dyn ^ "shape.sml", dyn ^ "impl.sml"], run = SOME {args = [], vmargs = [], stdin = ""},
         ways = ["interp", "t2c"], group = "", level = ""}
        :: List.map (fn (i : item) => {id = #id i, part = "extra", flags = #flags i, srcs = #srcs i, module = [], run = #run i,
                                       ways = #ways i, group = "", level = ""})
                    (units ("functor-earlier", [],
                            ["--build", "tests/units/functor-earlier/p.build"], "tests/units/functor-earlier/none")
                     (* a functor's function kept in its unit, whose closure
                        must not capture what a tuple Lower does not make
                        would hold (54a0d1928) *)
                     @ [plain ("units/mod.functor.functions_capture@U2", "extra", ["--units", "--no-cache", "-O2"],
                               ["tests/lang/mod.functor.functions_capture.sml"], SOME (runOf "tests/lang/mod.functor.functions_capture"),
                               ["interp", "t2c"], "", "")])
      val items =
        levels ("tests/lang", "lang") @ levels ("tests/perf", "perf") @ List.map basis basisTests
        @ List.concat (List.map stack (evenSample (lang, 60)))
        @ List.concat (List.map (fn n => units (n, ["tests/lang/" ^ n ^ ".sml"], words ("tests/lang/" ^ n ^ ".cargs"), "tests/lang/" ^ n))
                                (evenSample (lang, 24)))
        @ List.map (fn n => plain ("errors/" ^ n, "errors", words ("tests/errors/" ^ n ^ ".cargs"), ["tests/errors/" ^ n ^ ".sml"],
                                   NONE, [], "", ""))
                   (programs "tests/errors")
        @ extra
        @ List.map (fn lv => plain ("boot@" ^ lv, "boot", ["-" ^ lv], bootSources (), NONE, [], "", "")) ["O0", "O2"]
      val n = quick ()
      fun keep (seen, [] : item list) = []
        | keep (seen, it :: rest) =
            let val k = getOpt (Option.map #2 (List.find (fn (p, _) => p = #part it) seen), 0)
            in if k < n then it :: keep ((#part it, k + 1) :: seen, rest) else keep (seen, rest) end
    in if n > 0 then keep ([], items) else items end
  val parts = ["lang-O0", "lang-O2", "perf-O0", "perf-O2", "basis", "stack", "units", "errors", "extra", "boot"]

  (* ---- compiling and running *)
  val vm = fromRoot "bin/runevm"
  val good = fromRoot "bin/rune.rbc"
  fun dirOf name = run ^ "/compiler-mutants/" ^ name
  fun limits cpu = {addressSpace = SOME (6 * 1024 * 1024 * 1024), cpuTime = SOME cpu, fileSize = SOME (512 * 1024 * 1024), core = SOME 0}
  fun clean s = String.translate (fn #"\t" => " " | #"\n" => " " | c => str c) s
  fun hash file =
    let val s = BinIO.openIn file
        fun loop ctx = let val b = BinIO.inputN (s, 65536)
                       in if Word8Vector.length b = 0 then ctx else loop (Sha256.update (ctx, Byte.bytesToString b)) end
        val ctx = loop Sha256.empty before BinIO.closeIn s
    in String.substring (Hex.fromBytes (Sha256.finish ctx), 0, 16) end
    handle IO.Io _ => "-"
  (* the first line of a compile's or a run's standard error that says
     what went wrong *)
  fun errLine text =
    case List.filter (fn l => not (String.isSubstring "warning" l)) (lines text) of
      l :: _ => clean (if size l > 300 then String.substring (l, 0, 300) else l)
    | [] => ""
  val noLint = ["RUNE_LINT", "RUNEVM_JIT", "RUNEVM_JIT_TIER", "RUNE_VERIFY_CACHE", "RUNE_FAULT", "RUNE_REGVERIFY_INJECT"]
  fun environment e = setEnv ("TZ", "NST3:30NDT,M3.2.0,M11.1.0") (unsetEnv noLint e)
  fun execute (cpu, cmd, dir, stdin, out, err) =
    Children.exec (limits cpu) environment {cmd = cmd, dir = SOME dir, stdin = stdin, stdout = out, stderr = err, timeout = cpu * 3}
  fun compiler rbc = [vm, "--heap-size", "67108864", rbc, "--lib", fromRoot "lib"]

  (* a compile: SOME its output's hash, or NONE and what stopped it; at a
     level of the checks *)
  datatype compiled = Out of string | Stopped of string
  fun compile (rbc, it : item, out, level) =
    let
      val () = rmTree out
      val () = mkdirs out
      val err = out ^ "/err"
      val cpu = if #part it = "boot" then 300 else 120
      val lint = ["--lint=" ^ level]
      fun moduleFirst () =
        if null (#module it) then SOME ""
        else
          let
            val code = execute (cpu, compiler rbc @ lint @ ["--units", "--no-cache", "--emit-units", out ^ "/module.units"]
                                     @ List.map fromRoot (#module it) @ ["-o", out ^ "/module.rbc"], root, "", err, err)
            val listed = lines (read (out ^ "/module.units/units"))
            val suffix = "-" ^ OS.Path.base (OS.Path.file (List.last (#module it))) ^ ".rbu"
          in
            case (code, List.filter (String.isSuffix suffix) listed) of
              (0, [u]) =>
                let val u = if OS.Path.isAbsolute u then u
                            else if exists (out ^ "/module.units/" ^ u) then out ^ "/module.units/" ^ u else fromRoot u
                in ignore (exec {cmd = ["cp", u, out ^ "/impl.rbu"], dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 60});
                   SOME (hash (out ^ "/impl.rbu")) end
            | (0, _) => NONE
            | _ => NONE
          end
    in
      case moduleFirst () of
        NONE => Stopped ("the module: " ^ errLine (read err))
      | SOME h =>
          let val code = execute (cpu, compiler rbc @ lint @ #flags it @ List.map fromRoot (#srcs it) @ ["-o", out ^ "/prog.rbc"],
                                  root, "", err, err)
          in
            if code = 0 andalso exists (out ^ "/prog.rbc") then Out (hash (out ^ "/prog.rbc") ^ h)
            else Stopped ((if code = 124 then "timeout: " else "exit " ^ Int.toString code ^ ": ") ^ errLine (read err))
          end
    end
  fun showCompiled (Out h) = "out\t" ^ h
    | showCompiled (Stopped e) = "stopped\t" ^ e
  fun readCompiled ["out", h] = Out h
    | readCompiled ("stopped" :: e) = Stopped (String.concatWith "\t" e)
    | readCompiled _ = Stopped "?"

  (* a run of what a compile made, in a directory of its own where the
     programs of tests/lang find their files: its exit, its output's hash
     and its first line of standard error *)
  type ran = {code : int, out : string, err : string}
  fun runWay (out, it : item, way, k, timeout) : ran =
    let
      val r = valOf (#run it)
      val dir = out ^ "/run-" ^ way ^ "-" ^ Int.toString k
      val () = (rmTree dir; mkdirs (dir ^ "/tests/out"))
      val () = List.app (fn d => Posix.FileSys.symlink {old = fromRoot ("tests/" ^ d), new = dir ^ "/tests/" ^ d}) ["lang", "basis", "perf", "units"]
      val () = ignore (exec {cmd = ["cp", out ^ "/prog.rbc", dir ^ "/prog.rbc"], dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 60})
      val () = if exists (out ^ "/impl.rbu")
               then ignore (exec {cmd = ["cp", out ^ "/impl.rbu", dir ^ "/impl.rbu"], dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 60})
               else ()
      val opts = case way of
                   "interp" => [vm, "--jit=off", "--checked"]
                 | "t2c" => [vm, "--jit=all", "--jit-tier=2", "--checked"]
                 | "t2u" => [vm, "--jit=all", "--jit-tier=2"]
                 | _ => [fromRoot "bin/runevm-stack", "--checked"]
      val code = execute (timeout, opts @ #vmargs r @ ["prog.rbc"] @ #args r, dir, if #stdin r = "" then "" else fromRoot (#stdin r),
                          dir ^ "/stdout", dir ^ "/stderr")
      val result = {code = code, out = hash (dir ^ "/stdout"), err = errLine (read (dir ^ "/stderr"))}
    in rmTree dir; result end
  fun showRan ({code, out, err} : ran) = Int.toString code ^ "\t" ^ out ^ "\t" ^ err
  fun readRan (c :: o' :: e) = {code = getOpt (Int.fromString c, ~1), out = o', err = String.concatWith "\t" e}
    | readRan _ = {code = ~1, out = "", err = ""}
  fun sameRan (a : ran, b : ran) = #code a = #code b andalso #out a = #out b andalso #err a = #err b
  (* what a run that differs from the good compiler's shows *)
  fun classify (m : ran, g : ran) =
    let val e = #err m
    in
      if #code m = 124 then "timeout"
      else if #code m > 128 then "signal"
      else if String.isPrefix "runevm: prog.rbc: " e then "loader"
      else if String.isSubstring "of a constructor of tag" e then "checked"
      else if String.isSubstring "fatal error" e then "fatal"
      else if String.isSubstring "uncaught exception" e andalso e <> #err g then "exception"
      else if #out m <> #out g then "output"
      else if #code m <> #code g then "exit"
      else "stderr"
    end

  (* ---- the good compiler: a file of lines ID TAB ... for each part *)
  fun table file : (string * string list) list =
    List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of id :: rest => SOME (id, rest) | [] => NONE) (lines (read file))
  fun lookup (t, id) = Option.map #2 (List.find (fn (i, _) => i = id) t)
  fun goodTables () =
    let val d = dirOf "good"
        fun all kind = List.concat (List.map (fn p => table (d ^ "/" ^ p ^ "." ^ kind)) parts)
    in (all "compile", all "lint", all "runs") end

  (* where old occurs in text *)
  fun places (text, old) =
    let fun go (i, acc) =
          if i > size text - size old then List.rev acc
          else if String.substring (text, i, size old) = old then go (i + size old, i :: acc)
          else go (i + 1, acc)
    in if old = "" then [] else go (0, []) end

  fun prepare () =
    let
      val () = rmTree (dirOf "")
      val () = mkdirs (dirOf "good")
      val err = dirOf "bootsrcs.err"
      val code = Children.exec Subprocess.unlimited (fn e => e)
                   {cmd = ["sh", "scripts/build-files.sh", "rune.build"], dir = SOME root, stdin = "", stdout = dirOf "files.txt",
                    stderr = err, timeout = 60}
      val () = need (code = 0, "scripts/build-files.sh failed: " ^ firstNonEmpty err)
      val srcs = ["build/config.sml"] @ String.tokens Char.isSpace (read (dirOf "files.txt")) @ ["src/main/rune-main.sml"]
      val () = write (dirOf "bootsrcs.txt", String.concat (List.map (fn s => s ^ "\n") srcs))
      val () = need (exists good, "no bin/rune.rbc")
      (* each mutant applies to today's sources: its old text once *)
      val () = List.app (fn (m : mutant) =>
                 List.app (fn {file, old, ...} =>
                            need (length (places (read (fromRoot file), old)) = 1,
                                  #id m ^ ": its old text is not in " ^ file ^ " once"))
                          (#edits m))
               CompilerMutantList.mutants
    in say "PASS compiler-mutants: prepared\n" end

  fun goodPart part () =
    let
      val d = dirOf "good"
      val items = List.filter (fn (it : item) => #part it = part) (corpus ())
      val runs = ref []
      fun one (it : item) =
        let
          val out = d ^ "/out/" ^ String.translate (fn #"/" => "_" | c => str c) (#id it)
          val c = compile (good, it, out, "0")
          val l = compile (good, it, out ^ ".lint", "2")
          val () = rmTree (out ^ ".lint")
          val () =
            case (c, #run it) of
              (Out _, SOME _) =>
                List.app (fn w => runs := (#id it ^ "\t" ^ w ^ "\t" ^ showRan (runWay (out, it, w, 0, 60)) ^ "\t" ^ showRan (runWay (out, it, w, 1, 60)))
                                         :: !runs) (#ways it)
            | _ => ()
          val () = rmTree out
        in (#id it ^ "\t" ^ showCompiled c, #id it ^ "\t" ^ showCompiled l, case (c, l) of (Out _, Stopped _) => true | _ => false) end
      val results = List.map one items
      fun file (kind, ls) = write (d ^ "/" ^ part ^ "." ^ kind, String.concat (List.map (fn l => l ^ "\n") ls))
      val linted = List.filter #3 results
    in
      file ("compile", List.map #1 results);
      file ("lint", List.map #2 results);
      file ("runs", List.rev (!runs));
      (* the good compiler is lint-clean: else a lint's finding is not the mutant's *)
      List.app (fn (_, l, _) => say ("FAIL compiler-mutants.good: the lint refuses " ^ l ^ "\n")) linted;
      say ("PASS compiler-mutants: the good compiler on " ^ part ^ ": " ^ Int.toString (length items) ^ " items\n")
    end

  (* ---- a mutant *)
  fun build (m : mutant) : string option * string =
    let
      val d = dirOf (#id m)
      val () = (rmTree d; mkdirs (d ^ "/src"))
      val srcs = bootSources ()
      (* one edit of a file's text: its old text there once *)
      fun edit file ({old, new, ...} : CompilerMutantList.edit, text) =
        case places (text, old) of
          [i] => String.substring (text, 0, i) ^ new ^ String.extract (text, i + size old, NONE)
        | _ => raise Failed (#id m ^ ": its old text is not in " ^ file ^ " once")
      (* each file the mutant edits, with every edit of it, in a copy *)
      val files = List.foldl (fn ({file, ...} : CompilerMutantList.edit, fs) =>
                                if List.exists (fn f => f = file) fs then fs else fs @ [file]) [] (#edits m)
      fun apply (file, srcs) =
        let
          val text = List.foldl (edit file) (read (fromRoot file)) (List.filter (fn e => #file e = file) (#edits m))
          val dst = d ^ "/src/" ^ file
          val () = mkdirs (OS.Path.dir dst)
          val () = write (dst, text)
        in
          need (List.exists (fn s => s = file) srcs, #id m ^ ": " ^ file ^ " is no source of the compiler");
          List.map (fn s => if s = file then dst else s) srcs
        end
      val srcs = List.foldl apply srcs files
      val err = d ^ "/build.err"
      val code = execute (900, compiler good @ ["-o", d ^ "/rune.rbc"] @ List.map fromRoot srcs, root, "", err, err)
    in
      if code = 0 then (SOME (d ^ "/rune.rbc"), "built") else (NONE, "stillborn: " ^ errLine (read err))
    end

  (* what a refused compile says: the stage a lint names, or the first
     words of what stopped it *)
  fun stageOf e =
    case places (e, "lint after ") of
      i :: _ => "lint after " ^ hd (String.tokens (fn c => c = #":" orelse c = #" ") (String.extract (e, i + 11, NONE)) @ [""])
    | [] => "stopped: " ^ (if size e > 100 then String.substring (e, 0, 100) else e)

  (* E3's mutants that a lint caught then (E3's mutants.tsv) *)
  val lintCaughtInE3 = ["E07", "E12", "T01", "T02", "T03", "T05", "T06", "T08", "M01", "M02", "M07", "M08", "M09", "M10",
                        "M11", "M12", "M15", "M16", "M18", "M21", "L01", "L02", "L03", "L05", "L06", "L07", "L08"]

  (* the mutants a lint catches (the roadmap's M16): the summary fails where
     one of them no longer is, and one that a lint comes to catch is added *)
  val lintCaught = ["E01", "E02", "E03", "E04", "E05", "E06", "E07", "E10", "E12", "E13", "E14",
                    "T01", "T02", "T03", "T05", "T06", "T07", "T08", "T09", "T10", "M01", "M02",
                    "M05", "M07", "M08", "M09", "M10", "M11", "M12", "M15", "M16", "M18", "M19",
                    "M20", "M21", "L01", "L02", "L03", "L04", "L05", "L06", "L07", "L08", "L09",
                    "L10", "R01", "R02", "R03", "R06", "K01", "K02", "X01", "X02", "X03"]

  (* counts of keys, in the order first met *)
  fun tally keys =
    List.foldl (fn (k, acc) => case List.find (fn (k', _) => k' = k) acc of
                                 SOME _ => List.map (fn (k', n) => if k' = k then (k', n + 1) else (k', n)) acc
                               | NONE => acc @ [(k, 1)]) [] keys
  fun showTally t = String.concatWith ", " (List.map (fn (k, n) => k ^ " " ^ Int.toString n) t)

  fun named id = case List.find (fn (m : mutant) => #id m = id) CompilerMutantList.mutants of
                   SOME m => m
                 | NONE => raise Failed ("no mutant " ^ id)

  (* make check's: the mutant applies and builds *)
  fun builtJob id () =
    let val (rbc, status) = build (named id)
    in
      rmTree (dirOf id);
      need (isSome rbc, id ^ " no longer compiles: " ^ status);
      say ("PASS compiler-mutants: " ^ id ^ " builds\n")
    end

  fun mutantJob id () =
    let
      val m = named id
      val d = dirOf id
      val (gcomp, glint, gruns) = goodTables ()
      val (rbc, status) = build m
      fun verdict text = (mkdirs (dirOf "verdicts"); write (dirOf "verdicts/" ^ id, text ^ "\n"); say (text ^ "\n"))
    in
      case rbc of
        NONE => (verdict ("STILLBORN " ^ id ^ " (" ^ #pass m ^ "): " ^ status);
                 raise Failed (id ^ " no longer compiles: " ^ status))
      | SOME rbc =>
          let
            val elab = List.exists (fn p => p = #pass m) ["parse", "elaborate", "translate"]
            val items = List.filter (fn (it : item) => (elab orelse #part it <> "errors") andalso isSome (lookup (gcomp, #id it)))
                                    (corpus ())
            val hung = ref 0
            fun outOf (it : item) = d ^ "/out/" ^ String.translate (fn #"/" => "_" | c => str c) (#id it)
            fun goodOf (it : item) = readCompiled (valOf (lookup (gcomp, #id it)))
            fun differs (it, c) =
              case (goodOf it, c) of
                (Out a, Out b) => a <> b
              | (Stopped a, Stopped b) => a <> b
              | _ => true
            (* what does not differ is not kept *)
            fun compileOne (it : item) =
              if !hung >= 25 then (it, Stopped "skipped: the mutant compiler hung too often")
              else
                let val c = compile (rbc, it, outOf it, "0")
                in
                  (case c of Stopped e => if String.isPrefix "timeout" e then hung := !hung + 1 else () | _ => ());
                  if differs (it, c) then () else rmTree (outOf it);
                  (it, c)
                end
            val compiled = List.map compileOne items
            val diff = List.filter differs compiled
            val crashes = List.filter (fn (it, c) => case (goodOf it, c) of (Out _, Stopped _) => true | _ => false) diff
            val accepts = List.filter (fn (it, c) => case (goodOf it, c) of (Stopped _, Out _) => true | _ => false) diff
            (* the lint where the mutant is exercised, an even sample; where
               no byte differs, a sample of the corpus and its extra items,
               for a mutant only a lint sees (E3's T09) *)
            val toLint =
              if null diff then
                List.filter (fn (it : item, c) => #part it = "extra" orelse List.exists (fn (i : item, _) => #id i = #id it)
                                                                                      (evenSample (compiled, cap div 4)))
                            (List.filter (fn (_, c) => case c of Out _ => true | _ => false) compiled)
              else evenSample (List.filter (fn (it, c) => case (goodOf it, c) of (Stopped _, Stopped _) => false | _ => true) diff, cap)
            val linted =
              List.mapPartial (fn (it : item, _) =>
                                 let val r = compile (rbc, it, outOf it ^ ".lint", "2")
                                     val () = rmTree (outOf it ^ ".lint")
                                 in case (r, Option.map readCompiled (lookup (glint, #id it))) of
                                      (Stopped e, SOME (Out _)) => SOME (stageOf e)
                                    | (Stopped e, SOME (Stopped e')) => if e = e' then NONE else SOME (stageOf e)
                                    | _ => NONE
                                 end) toLint
            (* the runs of the differing programs, each way, against the good
               compiler's, where those were stable *)
            val toRun = evenSample (List.filter (fn (it : item, c) => isSome (#run it) andalso (case c of Out _ => true | _ => false)) diff, cap)
            fun goodRuns (id, way) =
              case List.find (fn (i, w :: _) => i = id andalso w = way | _ => false) gruns of
                SOME (_, _ :: rest) => if length rest >= 6 then SOME (readRan (List.take (rest, 3)), readRan (List.drop (rest, 3))) else NONE
              | _ => NONE
            val mine = ref []
            val oracle =
              List.concat (List.map (fn (it : item, _) =>
                List.mapPartial (fn way =>
                  case goodRuns (#id it, way) of
                    SOME (g0, g1) =>
                      if not (sameRan (g0, g1)) then NONE
                      else
                        let val r = runWay (outOf it, it, way, 0, 60)
                        in mine := ((#id it, way), r) :: !mine;
                           if sameRan (r, g0) then NONE else SOME (way ^ ":" ^ classify (r, g0)) end
                  | NONE => NONE) (#ways it)) toRun)
            (* -O0 against -O2, the first way, of the programs that differ,
               where the good compiler's two ran alike *)
            fun ranAt (group, lv, way) =
              let val id' = group ^ "@" ^ lv
              in case List.find (fn ((i, w), _) => i = id' andalso w = way) (!mine) of
                   SOME (_, r) => SOME r
                 | NONE =>
                     case List.find (fn (it : item, _) => #id it = id') diff of
                       SOME (it, Out _) => SOME (runWay (outOf it, it, way, 0, 60))
                     | SOME _ => NONE
                     | NONE => Option.map #1 (goodRuns (id', way))
              end
            val groups = List.foldl (fn ((it : item, _), acc) => if #group it = "" orelse List.exists (fn g => g = #group it) acc then acc
                                                                 else #group it :: acc) [] toRun
            val levels =
              List.filter (fn g =>
                let val way = case List.find (fn (it : item, _) => #group it = g) toRun of SOME (it, _) => hd (#ways it) | NONE => "interp"
                    fun good lv = Option.map #1 (goodRuns (g ^ "@" ^ lv, way))
                in
                  case (good "O0", good "O2", ranAt (g, "O0", way), ranAt (g, "O2", way)) of
                    (SOME a, SOME b, SOME x, SOME y) => sameRan (a, b) andalso not (sameRan (x, y))
                  | _ => false
                end) groups
            (* the bootstrap: stage two, made by the mutant, compiles the
               compiler as the good compiler does *)
            val boot =
              case List.find (fn (it : item, _) => #id it = "boot@O2") compiled of
                SOME (it, Out h) =>
                  if not (differs (it, Out h)) then "the same"
                  else
                    let val stage3 = compile (outOf it ^ "/prog.rbc", it, d ^ "/stage3", "0")
                    in case (stage3, goodOf it) of
                         (Out a, Out b) => if a = b then "differs; stage three the same" else "differs; stage three differs"
                       | (Stopped e, _) => "differs; stage two stops: " ^ e
                       | _ => "differs"
                    end
              | SOME (_, Stopped e) => "stops: " ^ e
              | NONE => "not compiled"
            val () = rmTree (d ^ "/out")
            val caught = not (null linted)
            val word =
              if caught then "LINT"
              else if null diff then "UNEXERCISED"
              else if not (null crashes) orelse not (null accepts) orelse not (null oracle) orelse not (null levels)
                      orelse String.isPrefix "differs; stage" boot andalso boot <> "differs; stage three the same"
              then "OTHER" else "UNCAUGHT"
            val was = if List.exists (fn i => i = id) lintCaughtInE3 then "; a lint caught it in E3" else ""
          in
            verdict (word ^ " " ^ id ^ " (" ^ #pass m ^ ", " ^ #class m ^ "): differs on " ^ Int.toString (length diff) ^ " of "
                     ^ Int.toString (length items) ^ "; stops the compiler on " ^ Int.toString (length crashes)
                     ^ "; accepts " ^ Int.toString (length accepts) ^ " of tests/errors; lint: "
                     ^ (if caught then showTally (tally linted) else "none") ^ " (of " ^ Int.toString (length toLint) ^ ")"
                     ^ "; runs: " ^ (if null oracle then "alike" else showTally (tally oracle)) ^ " (of " ^ Int.toString (length toRun) ^ ")"
                     ^ "; -O0 and -O2: " ^ Int.toString (length levels) ^ "; bootstrap: " ^ boot ^ was)
          end
    end

  fun final () =
    let
      val vs = List.map (fn (m : mutant) => read (dirOf "verdicts/" ^ #id m)) (selected ())
      val missing = List.filter (fn v => v = "") vs
      val () = need (null missing, Int.toString (length missing) ^ " mutants have no verdict")
      fun count w = length (List.filter (String.isPrefix (w ^ " ")) vs)
      val stillLint = List.filter (fn i => List.exists (fn v => String.isPrefix ("LINT " ^ i ^ " ") v) vs) lintCaughtInE3
      val inE3 = List.filter (fn i => List.exists (fn (m : mutant) => #id m = i) (selected ())) lintCaughtInE3
      val summary =
        Int.toString (length vs) ^ " mutants: " ^ Int.toString (count "LINT") ^ " caught by a lint, "
        ^ Int.toString (count "OTHER") ^ " by another check alone, " ^ Int.toString (count "UNCAUGHT") ^ " by nothing, "
        ^ Int.toString (count "UNEXERCISED") ^ " not exercised, " ^ Int.toString (count "STILLBORN") ^ " stillborn; "
        ^ Int.toString (length stillLint) ^ " of the " ^ Int.toString (length inE3) ^ " a lint caught in E3 still caught by one\n"
      val public = fromRoot "tests/out/compiler-mutants"
      (* a shortened corpus proves nothing about a mutant *)
      val lost = if quick () > 0 then []
                 else List.filter (fn i => List.exists (fn (m : mutant) => #id m = i) (selected ())
                                           andalso not (List.exists (String.isPrefix ("LINT " ^ i ^ " ")) vs)) lintCaught
    in
      rmTree public; mkdirs public;
      write (public ^ "/results.txt", String.concat vs);
      write (public ^ "/summary.txt", summary);
      say summary;
      need (null lost, "no lint catches " ^ String.concatWith ", " lost ^ " any more")
    end

  and selected () =
    case env ("COMPILER_MUTANTS", "") of
      "" => CompilerMutantList.mutants
    | s => let val ids = String.tokens (fn c => c = #",") s
           in List.filter (fn (m : mutant) => List.exists (fn i => i = #id m) ids) CompilerMutantList.mutants end

  fun protect f () = f () handle Failed why => say ("FAIL compiler-mutants: " ^ why ^ "\n")
  fun command args =
    case args of
      ["compiler-mutants-prepare"] => SOME (protect prepare)
    | ["compiler-mutants-good", part] => SOME (protect (goodPart part))
    | ["compiler-mutant", id] => SOME (protect (mutantJob id))
    | ["compiler-mutant-built", id] => SOME (protect (builtJob id))
    | ["compiler-mutants-final"] => SOME (protect final)
    | _ => NONE

  fun job (name, args, after, memory) =
    Test.it name
      {program = "/bin/sh",
       args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 21600, cap = 0, cpus = 1, memory = memory,
       pools = [], exclusive = false, after = after, judge = failLines} : Run.command Test.tree
  fun tree () =
    let
      val goods = List.map (fn p => "compiler-mutants/good-" ^ p) parts
      val ms = List.map #id (selected ())
    in
      Test.tag "covers:tests/runner/compilermutant*"
        (Test.describe "compiler-mutants"
           (Test.tag "check" (Test.tag "test-compiler-mutants" (job ("prepare", ["compiler-mutants-prepare"], [], 300)))
            :: List.map (fn i => Test.tag "check" (job ("built-" ^ i, ["compiler-mutant-built", i], ["compiler-mutants/prepare"], 1500))) ms
            @ List.map (Test.tag "test-compiler-mutants")
                (List.map (fn p => job ("good-" ^ p, ["compiler-mutants-good", p], ["compiler-mutants/prepare"], 2000)) parts
                 @ List.map (fn i => job (i, ["compiler-mutant", i], goods, 2500)) ms
                 @ [job ("final", ["compiler-mutants-final"], List.map (fn i => "compiler-mutants/" ^ i) ms, 300)])))
    end
end
