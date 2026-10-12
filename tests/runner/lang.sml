(* The programs of tests/lang and tests/errors on the runner
   (docs/plans/unit-testing.md, M4; docs/testing.md, The three oracles):
   what tests/run-tests.sh did, in every way make check ran it, with each
   program compiled once by each compiler.

   A program of tests/lang is compiled by a compiler (`compile/COMPILER/NAME`)
   and run in each way that compiler serves (`lang/WAY/NAME`): a VM and its
   options. The run's standard output must be the `.expected` sibling, and
   the other siblings fix the rest, as run-tests.sh's header says: `.cargs`,
   `.args`, `.vmargs`, `.stdin`, `.exitcode`, `.stderr`, `.stderr-head`,
   `.cwarn`, and `.restore` with `.restoreargs` and `.restorevmargs`. A
   program of tests/errors must fail to compile, with the `.expected` text
   in the first line of what the compiler says (`errors/COMPILER/NAME`).

   Each run has a directory of its own, with `tests/out` in it for the
   images and files the programs write at fixed paths, and `tests/lang`
   for the one they read, so that the ways run at once. The stack
   compiler's bytecode goes to tests/out/NAME.rbc, where test-opt and
   test-native read it (`compile/stack-done` waits for all of it); the
   others' to the run's directory. The six host compilers make the stack
   compiler's bytes (make check-cross holds them to it): a run of their
   bytecode that is those bytes is the stack way's run, and passes with it.

   Each way carries the tag of the make target it came from, so that
   `bin/rune-test run --tier test-gc` is what make test-gc ran. *)
structure Lang =
struct
  fun env (name, default) = case OS.Process.getEnv name of SOME v => if v = "" then default else v | NONE => default
  fun exists f = OS.FileSys.access (f, []) handle OS.SysErr _ => false
  fun read f = (let val s = TextIO.openIn f in TextIO.inputAll s before TextIO.closeIn s end) handle IO.Io _ => ""
  fun write (f, text) = let val s = TextIO.openOut f in TextIO.output (s, text); TextIO.closeOut s end
  (* with --accept, a golden file that differs is written, by one way only *)
  fun accept (writes, file, text) =
    if writes andalso !Run.accept then (write (file, text); SOME ("ACCEPTED", "wrote " ^ file)) else NONE
  fun firstLine s = case String.fields (fn c => c = #"\n") s of l :: _ => l | [] => ""
  (* the first line, with its end, as head -1 gives it *)
  fun headLine s = case CharVector.findi (fn (_, c) => c = #"\n") s of
                     SOME (i, _) => String.substring (s, 0, i + 1)
                   | NONE => s

  (* where two texts first differ, for a failure *)
  fun firstDifference (expected, actual) =
    let
      fun go (n, e :: es, a :: as') = if e = a then go (n + 1, es, as') else SOME (n, e, a)
        | go (n, e :: _, []) = SOME (n, e, "(nothing)")
        | go (n, [], a :: _) = SOME (n, "(nothing)", a)
        | go (_, [], []) = NONE
      fun lines s = String.fields (fn c => c = #"\n") s
    in
      case go (1, lines expected, lines actual) of
        SOME (n, e, a) => "\nfirst at line " ^ Int.toString n ^ ":\n  expected: " ^ e ^ "\n  actual:   " ^ a
      | NONE => ""
    end

  (* the programs of a directory, by name *)
  fun programs dir =
    let
      val d = OS.FileSys.openDir dir
      fun go acc = case OS.FileSys.readDir d of
                     NONE => acc
                   | SOME f => go (if String.isSuffix ".sml" f then String.substring (f, 0, size f - 4) :: acc else acc)
      val names = go [] before OS.FileSys.closeDir d
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if y < x then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (x :: y :: rest) = let val (a, b) = split rest in (x :: a, y :: b) end
        | split xs = (xs, [])
      fun sort [] = []
        | sort [x] = [x]
        | sort xs = let val (a, b) = split xs in merge (sort a, sort b) end
    in sort names end
    handle OS.SysErr _ => []


  (* ---- compilers and ways *)
  val stackCompiler = "stack"
  (* a compiler: its name, the command that compiles, from the root, and
     the tag of its programs of tests/errors *)
  val hosts = ["mlton", "smlnj-legacy", "smlnj32", "smlnj-dev", "polyml", "mlkit"]
  val compilers =
    [(stackCompiler, "bin/rune-stack", "test"), ("register", "bin/rune", "test-register")]
    @ List.map (fn h => (h, "bin/rune-" ^ h ^ " --target=stack", "test-all")) hosts

  (* a way: its name, its compiler, its VM with the options before the
     program's, the tag of the make target it comes from, and whether it is
     native code, whose expectations are tests/opt-skip.txt's *)
  type way = {name : string, compiler : string, vm : string, tag : string, skip : bool}

  val gcStress = env ("GC_STRESS", "101")
  val small = " --gc-verify --heap-size 65536 --nursery 8192 --nursery-max 0"
  fun way (name, compiler, vm, tag) = {name = name, compiler = compiler, vm = vm, tag = tag, skip = false} : way
  val native = case OS.Process.getEnv "NATIVE_HOST" of
                 SOME v => v = "yes"
               | NONE => exists "bin/runevm-native"
  val ways =
    [way ("test", stackCompiler, env ("RUNEVM", "bin/runevm-stack"), "test"),
     way ("register-gcbits", "register", "bin/runevm-gcbits", "test-heap"),
     way ("register-gcbits-stress", "register", "bin/runevm-gcbits --jit=all --gc-stress " ^ gcStress, "test-heap"),
     way ("register-cards", "register", "bin/runevm-cards", "test-heap"),
     way ("register-verify", "register", "bin/runevm" ^ small, "test-heap"),
     way ("register-gc-throughput", "register", "bin/runevm --gc throughput" ^ small, "test-gc"),
     way ("register-gc-low-pause", "register", "bin/runevm --gc low-pause" ^ small, "test-gc"),
     way ("gc-throughput", stackCompiler, "bin/runevm-stack --gc throughput" ^ small, "test-gc"),
     way ("gc-low-pause", stackCompiler, "bin/runevm-stack --gc low-pause" ^ small, "test-gc"),
     way ("register-gc-low-pause-stress", "register",
          "bin/runevm --gc low-pause --jit=all --nursery 4096 --nursery-max 0 --gc-stress " ^ gcStress, "test-gc"),
     way ("register-gc-low-pause-cycles", "register",
          "bin/runevm --gc low-pause --gc-verify --nursery 65536 --gc-stress " ^ gcStress ^ " --gc-stress-cycles", "test-gc"),
     way ("gc-low-pause-cycles", stackCompiler,
          "bin/runevm-stack --gc low-pause --gc-verify --nursery 65536 --gc-stress " ^ gcStress ^ " --gc-stress-cycles", "test-gc"),
     way ("register-gc-throughput-compact", "register", "bin/runevm --gc throughput --gc-compact" ^ small, "test-gc"),
     way ("register-gc-low-pause-compact", "register", "bin/runevm --gc low-pause --gc-compact" ^ small, "test-gc"),
     way ("register", "register", "bin/runevm", "test-register"),
     way ("register-jit", "register", "bin/runevm --jit=all", "test-register-jit"),
     way ("register-opt", "register", "bin/runevm --jit=all --jit-tier=2", "test-register-jit")]
    @ List.map (fn h => way ("host-" ^ h, h, "bin/runevm-stack", "test-all")) hosts
    @ (if native then
         [{name = "native", compiler = stackCompiler, vm = "bin/runevm-native", tag = "test-native", skip = true},
          {name = "native-cycles", compiler = stackCompiler,
           vm = "bin/runevm-native --gc low-pause --nursery 4096 --gc-stress " ^ gcStress ^ " --gc-stress-cycles",
           tag = "test-native", skip = true}]
       else [])

  (* ---- the commands *)
  val tz = "TZ='NST3:30NDT,M3.2.0,M11.1.0'; export TZ; "
  fun rbcDir compiler =
    if compiler = stackCompiler then "\"$RUNE_TEST_ROOT\"/tests/out" else "\"$RUNE_TEST_RUN\"/c/" ^ compiler
  fun rbc (compiler, name) = rbcDir compiler ^ "/" ^ name ^ ".rbc"
  (* a sibling's words, as $(cat FILE) gives them, or nothing *)
  fun words (base, ext) =
    if exists ("tests/" ^ base ^ ext) then " $(cat \"$RUNE_TEST_ROOT\"/tests/" ^ base ^ ext ^ ")" else ""

  fun shell (script, dir, timeout, memory, after, judge) =
    {program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = dir, stdin = NONE,
     timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = memory, pools = [], exclusive = false,
     after = after, judge = judge} : Run.command

  fun compileJudge (writes, name) (r : Supervisor.result, files as {stderr, ...}) =
    case #outcome r of
      Supervisor.Exited 0 =>
        let
          val cerr = read stderr
          val cwarn = "tests/lang/" ^ name ^ ".cwarn"
        in
          if exists cwarn then
            if cerr = read cwarn then NONE
            else case accept (writes, cwarn, cerr) of
                   SOME a => SOME a
                 | NONE => SOME ("FAIL", "compiler warnings differ from " ^ cwarn ^ firstDifference (read cwarn, cerr))
          else if cerr = "" then NONE
          else SOME ("FAIL", "unexpected compiler output: " ^ firstLine cerr)
        end
    | Supervisor.Exited _ => SOME ("FAIL", "compile error: " ^ firstLine (read stderr))
    | _ => Run.exitZero (r, files)

  fun compile (compiler, command) name =
    Test.it name
      (shell (tz ^ "mkdir -p " ^ rbcDir compiler ^ " && exec " ^ command ^ words ("lang/" ^ name, ".cargs")
              ^ " tests/lang/" ^ name ^ ".sml -o " ^ rbc (compiler, name),
              SOME ".", 600, 300, [], compileJudge (compiler = stackCompiler, name)))

  fun errorJudge (writes, name) (r : Supervisor.result, files as {stderr, ...}) =
    case #outcome r of
      Supervisor.Exited 0 => SOME ("FAIL", "expected a compile error but compilation succeeded")
    | Supervisor.Exited _ =>
        let
          val expected = "tests/errors/" ^ name ^ ".expected"
          (* as $(cat FILE) gives it: without the newlines at its end *)
          val text = let fun drop (#"\n" :: cs) = drop cs | drop cs = cs
                     in String.implode (rev (drop (rev (String.explode (read expected))))) end
          val line = firstLine (read stderr)
          (* what --accept writes: the line without its place and "error: " *)
          fun message l =
            case CharVector.findi (fn (_, c) => c = #" ") l of
              SOME (i, _) => if String.isPrefix " error: " (String.extract (l, i, NONE))
                             then String.extract (l, i + size " error: ", NONE) else l
            | NONE => l
        in
          if exists expected andalso String.isSubstring text line then NONE
          else case accept (writes, expected, message line ^ "\n") of
                 SOME a => SOME a
               | NONE => if not (exists expected) then SOME ("FAIL", "missing " ^ expected)
                         else SOME ("FAIL", "error message mismatch: " ^ line ^ "\n  expected it to contain: " ^ text)
        end
    | _ => Run.exitZero (r, files)

  fun error (compiler, command) name =
    Test.it name
      (shell (tz ^ "mkdir -p \"$RUNE_TEST_RUN\"/e/" ^ compiler ^ " && exec " ^ command ^ words ("errors/" ^ name, ".cargs")
              ^ " tests/errors/" ^ name ^ ".sml -o \"$RUNE_TEST_RUN\"/e/" ^ compiler ^ "/" ^ name ^ ".rbc",
              SOME ".", 600, 300, [], errorJudge (compiler = stackCompiler, name)))

  (* the expected exit status of a program *)
  fun expectedCode name =
    let val f = "tests/lang/" ^ name ^ ".exitcode"
    in if exists f then getOpt (Int.fromString (read f), ~1) else 0 end

  fun runJudge (writes, name) (r : Supervisor.result, files as {stdout, stderr}) =
    let
      val base = "tests/lang/" ^ name
      val dir = OS.Path.dir stdout
      (* the first of the checks that fails, in run-tests.sh's order *)
      fun first [] = NONE
        | first ((fails, why) :: rest) = if fails () then SOME ("FAIL", why ()) else first rest
    in
      case #outcome r of
        Supervisor.Exited code =>
          (* the same in a run of the host compilers' bytes: the stack way's run *)
          if exists (dir ^ "/same") then NONE
          else
            let
              val err = read stderr
              val out = read stdout
              val expected = read (base ^ ".expected")
              val restoring = exists (base ^ ".restore")
              val img = dir ^ "/tests/out/" ^ name ^ ".img"
              fun rcode () = getOpt (Int.fromString (read (dir ^ "/restored.code")), ~1)
            in
              first
                [(fn () => code <> expectedCode name,
                  fn () => "exit code " ^ Int.toString code ^ ", expected " ^ Int.toString (expectedCode name) ^ ": "
                           ^ firstLine err),
                 (fn () => not (exists (base ^ ".expected")), fn () => "missing " ^ base ^ ".expected"),
                 (fn () => out <> expected andalso not (isSome (accept (writes, base ^ ".expected", out))),
                  fn () => "stdout differs from " ^ base ^ ".expected" ^ firstDifference (expected, out)),
                 (fn () => exists (base ^ ".stderr") andalso err <> read (base ^ ".stderr"),
                  fn () => "stderr differs from " ^ base ^ ".stderr" ^ firstDifference (read (base ^ ".stderr"), err)),
                 (fn () => exists (base ^ ".stderr-head") andalso headLine err <> read (base ^ ".stderr-head"),
                  fn () => "runtime error differs from " ^ base ^ ".stderr-head: " ^ firstLine err),
                 (fn () => restoring andalso not (exists img), fn () => "no tests/out/" ^ name ^ ".img to restore"),
                 (fn () => restoring andalso rcode () <> 0,
                  fn () => "--restore exited " ^ Int.toString (rcode ()) ^ ": " ^ firstLine (read (dir ^ "/restored.err"))),
                 (fn () => restoring andalso read (dir ^ "/restored") <> read (base ^ ".restore"),
                  fn () => "restored stdout differs from " ^ base ^ ".restore"
                           ^ firstDifference (read (base ^ ".restore"), read (dir ^ "/restored")))]
            end
      | _ => Run.exitZero (r, files)
    end

  fun run (w : way) name =
    let
      val base = "lang/" ^ name
      val vm = "\"$RUNE_TEST_ROOT\"/" ^ #vm w
      val program = rbc (#compiler w, name)
      val runIt = vm ^ " --checked" ^ words (base, ".vmargs") ^ " " ^ program ^ words (base, ".args")
      val restore =
        if exists ("tests/" ^ base ^ ".restore") then
          "; code=$?; if [ -f tests/out/" ^ name ^ ".img ]; then " ^ vm ^ words (base, ".restorevmargs")
          ^ " --restore tests/out/" ^ name ^ ".img"
          ^ (if exists ("tests/" ^ base ^ ".restoreargs") then " --" ^ words (base, ".restoreargs") else "")
          ^ " < /dev/null > restored 2> restored.err; echo $? > restored.code; fi; exit $code"
        else ""
      val start = tz ^ "mkdir -p tests/out && ln -sfn \"$RUNE_TEST_ROOT\"/tests/lang tests/lang && "
      val isHost = List.exists (fn h => h = #compiler w) hosts
      (* the host compilers' bytes that are the stack compiler's: the stack
         way's run, which this one waits for *)
      val same =
        if isHost then "if cmp -s " ^ program ^ " " ^ rbc (stackCompiler, name) ^ "; then : > same; exit 0; fi; " else ""
      val script = start ^ same ^ (if restore = "" then "exec " ^ runIt else runIt ^ restore)
      val stdin = if exists ("tests/" ^ base ^ ".stdin") then SOME ("tests/" ^ base ^ ".stdin") else NONE
      val after = ("compile/" ^ #compiler w ^ "/" ^ name)
                  :: (if isHost then ["compile/" ^ stackCompiler ^ "/" ^ name, "lang/test/" ^ name] else [])
    in
      Test.it name
        ({program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = NONE, stdin = stdin,
          timeout = Time.fromSeconds 900, cap = 0, cpus = 1, memory = if #skip w then 300 else 100, pools = [],
          exclusive = false, after = after, judge = runJudge (#name w = "test", name)} : Run.command)
    end

  (* ---- the tree *)
  val langPrograms = programs "tests/lang"
  val errorPrograms = programs "tests/errors"
  (* the programs native code does not run (docs/testing.md, Expectations) *)
  val optSkip = Expectations.read "tests/opt-skip.txt"

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  (* what the programs cover, for --affected; the tier quick has the
     default way, and the profile layout test-heap's ways *)
  val covers = ["covers:tests/lang/*", "covers:tests/errors/*", "covers:tests/opt-skip.txt"]
  fun extraTags tag = (if tag = "test" then ["quick"] else []) @ (if tag = "test-heap" then ["layout"] else [])

  val tests =
    Test.describe ""
      [Test.describe "compile"
         (List.map (fn (c, command, _) => tagged ("check" :: covers) (Test.describe c (List.map (compile (c, command)) langPrograms)))
                   compilers
          @ [tagged ("check" :: covers)
               (Test.it "stack-done"
                  (shell ("true", SOME ".", 60, 10, List.map (fn n => "compile/" ^ stackCompiler ^ "/" ^ n) langPrograms,
                          Run.exitZero)))]),
       Test.describe "errors"
         (List.map (fn (c, command, tag) => tagged (["check", tag] @ extraTags tag @ covers)
                                              (Test.describe c (List.map (error (c, command)) errorPrograms)))
                   compilers),
       Test.describe "lang"
         (List.map (fn w => tagged (["check", #tag w] @ extraTags (#tag w) @ covers)
                              (Test.describe (#name w)
                                 (List.map (fn n =>
                                              case (#skip w, Expectations.skipped (optSkip, {way = #name w, path = n})) of
                                                (true, SOME l) => Test.pending (#category l ^ ": " ^ #reason l) (run w n)
                                              | _ => run w n)
                                           langPrograms)))
                   ways)]
end
