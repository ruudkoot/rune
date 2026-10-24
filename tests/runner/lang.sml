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
   Each program is also checked with --typecheck-only, which must judge it
   as the compile does (`lang/typecheck/NAME`, `errors/typecheck/NAME`),
   but where its `.typecheck-error` (tests/lang) or `.typecheck-ok`
   (tests/errors) says otherwise: the corners where the check types a
   functor application by the Definition and the compile does not yet
   (docs/language.md, *Functors*; LangChecks.typecheckJudge).

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
  val selectedCompiler=env ("RUNE_SUITE_COMPILER","")
  val compilers =
    [(stackCompiler, "bin/rune-stack", "test"), ("register", "bin/rune", "test-register")]
    @ List.map (fn h => (h, "bin/rune-" ^ h ^ " --target=stack", "test-all")) hosts
    @ (if selectedCompiler="" then [] else [("suite","\"$RUNE_SUITE_COMPILER\"","suite-selected")])

  (* a way: its name, its compiler, its VM with the options before the
     program's, the tag of the make target it comes from, and the file of
     its expectations, if it has one (native code's tests/opt-skip.txt, the
     other machines' tests/portability-skip.txt) *)
  type way = {name : string, compiler : string, vm : string, tag : string, skip : string option}

  val gcStress = env ("GC_STRESS", "101")
  val small = " --gc-verify --heap-size 65536 --nursery 8192 --nursery-max 0"
  fun way (name, compiler, vm, tag) = {name = name, compiler = compiler, vm = vm, tag = tag, skip = NONE} : way
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
     way ("register-opt", "register", "bin/runevm --jit=all --jit-tier=2", "test-register-jit"),
     (* returning by ret (docs/plans/native-frames.md, M7) *)
     way ("register-callret", "register", "bin/runevm --jit=all --jit-tier=2 --jit-returns=call", "test-register-jit")]
    @ List.map (fn h => way ("host-" ^ h, h, "bin/runevm-stack", "test-all")) hosts
    @ (if native then
         [{name = "native", compiler = stackCompiler, vm = "bin/runevm-native", tag = "test-native", skip = SOME "tests/opt-skip.txt"},
          {name = "native-cycles", compiler = stackCompiler,
           vm = "bin/runevm-native --gc low-pause --nursery 4096 --gc-stress " ^ gcStress ^ " --gc-stress-cycles",
           tag = "test-native", skip = SOME "tests/opt-skip.txt"}]
       else [])
    @ [way ("stress-stack", stackCompiler, "bin/runevm-stack --nursery 0 --gc-stress " ^ gcStress, "test-stress"),
       way ("stress-register", "register", "bin/runevm --nursery 0 --gc-stress " ^ gcStress, "test-stress"),
       way ("stress-jit", "register", "bin/runevm --jit=all --nursery 4096 --nursery-max 0 --gc-stress " ^ gcStress, "test-stress"),
       way ("stress-opt", "register", "bin/runevm --jit=all --jit-tier=2 --nursery 4096 --nursery-max 0 --gc-stress " ^ gcStress, "test-stress"),
       way ("stress-jit-cycles", "register", "bin/runevm --gc low-pause --jit=all --nursery 4096 --gc-stress " ^ gcStress ^ " --gc-stress-cycles", "test-stress"),
       way ("stress-opt-cycles", "register", "bin/runevm --gc low-pause --jit=all --jit-tier=2 --nursery 4096 --gc-stress " ^ gcStress ^ " --gc-stress-cycles", "test-stress"),
       way ("register-asan", "register", "bin/runevm-asan", "test-register-asan"),
       way ("register-asan-jit", "register", "bin/runevm-asan --jit=all", "test-register-asan"),
       way ("register-asan-opt", "register", "bin/runevm-asan --jit=all --jit-tier=2", "test-register-asan"),
       way ("register-asan-deopt", "register", "bin/runevm-asan --jit=all --jit-tier=2 --deopt-stress=1", "test-register-asan")]
    @ (if native then
         [{name = "native-stress", compiler = stackCompiler, vm = "bin/runevm-native --gc-stress " ^ gcStress,
           tag = "test-native-stress", skip = SOME "tests/opt-skip.txt"},
          {name = "native-asan", compiler = stackCompiler, vm = "bin/runevm-native",
           tag = "test-native-asan", skip = SOME "tests/opt-skip.txt"}]
       else [])
    (* the VMs of other machines (make test-portability), which are not
       make check's: a 32-bit x86, a big-endian PowerPC and an aarch64 under
       qemu, each also with a cycle of incremental marking always under way *)
    @ List.concat (List.map (fn (name, compiler, vm) =>
                               let val cycles = " --gc low-pause --gc-stress " ^ gcStress ^ " --gc-stress-cycles"
                               in
                                 {name = "port-" ^ name, compiler = compiler, vm = vm, tag = "test-portability",
                                  skip = SOME "tests/portability-skip.txt"}
                                 :: (if String.isSuffix "aarch64" vm then []
                                     else [{name = "port-" ^ name ^ "-cycles", compiler = compiler, vm = vm ^ cycles,
                                            tag = "test-portability", skip = SOME "tests/portability-skip.txt"}])
                               end)
                            [("stack32", stackCompiler, "bin/runevm-stack32"), ("stack-ppc64", stackCompiler, "bin/runevm-stack-ppc64"),
                             ("32", "register", "bin/runevm32"), ("ppc64", "register", "bin/runevm-ppc64"),
                             ("aarch64", "register", "bin/runevm-aarch64")])
    @ (if selectedCompiler="" then [] else
         [{name="suite",compiler="suite",vm="",tag="suite-selected",
           skip=case OS.Process.getEnv "RUNE_SUITE_SKIP" of SOME path => if path="" then NONE else SOME path | NONE => NONE}])


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

  val compileJudge = LangChecks.compileJudge

  fun compile (compiler, command) name =
    Test.it name
      (shell (tz ^ "mkdir -p " ^ rbcDir compiler ^ " && exec " ^ command ^ words ("lang/" ^ name, ".cargs")
              ^ " tests/lang/" ^ name ^ ".sml -o " ^ rbc (compiler, name),
              SOME ".", 600, 300, [], compileJudge (compiler = stackCompiler orelse (compiler="suite" andalso env ("RUNE_SUITE_UPDATE","0")="1"), name)))

  val errorJudge = LangChecks.errorJudge

  fun error (compiler, command) name =
    Test.it name
      (shell (tz ^ "mkdir -p \"$RUNE_TEST_RUN\"/e/" ^ compiler ^ " && exec " ^ command ^ words ("errors/" ^ name, ".cargs")
              ^ " tests/errors/" ^ name ^ ".sml -o \"$RUNE_TEST_RUN\"/e/" ^ compiler ^ "/" ^ name ^ ".rbc",
              SOME ".", 600, 300, [], errorJudge (compiler = stackCompiler orelse (compiler="suite" andalso env ("RUNE_SUITE_UPDATE","0")="1"), name)))

  (* a program of tests/lang or tests/errors checked by bin/rune with
     --typecheck-only and its .cargs (`lang/typecheck/NAME`,
     `errors/typecheck/NAME`; LangChecks.typecheckJudge) *)
  fun typecheck dir name =
    Test.it name
      (shell (tz ^ "exec bin/rune --typecheck-only" ^ words (dir ^ "/" ^ name, ".cargs") ^ " tests/" ^ dir ^ "/" ^ name ^ ".sml",
              SOME ".", 600, 300, [], LangChecks.typecheckJudge (dir, name)))

  (* the expected exit status of a program *)
  val expectedCode = LangChecks.expectedCode
  val runJudge = LangChecks.runJudge

  fun run (w : way) name =
    let
      val base = "lang/" ^ name
      val vm = if #name w="suite" then "\"$RUNE_SUITE_VM\"" else "\"$RUNE_TEST_ROOT\"/" ^ #vm w
      val program = rbc (#compiler w, name)
      val runIt = vm ^ " --checked" ^ words (base, ".vmargs") ^ " " ^ program ^ words (base, ".args")
      val restore =
        if exists ("tests/" ^ base ^ ".restore") then
          "; code=$?; if [ -f tests/out/" ^ name ^ ".img ]; then " ^ vm ^ words (base, ".restorevmargs")
          ^ " --restore tests/out/" ^ name ^ ".img"
          ^ (if exists ("tests/" ^ base ^ ".restoreargs") then " --" ^ words (base, ".restoreargs") else "")
          ^ " < /dev/null > restored 2> restored.err; echo $? > restored.code; fi; exit $code"
        else ""
      val asanEnv = if #name w = "native-asan" then
        "RUNEOPT_RUNTIME=\"$RUNE_TEST_ROOT/build/asan\"; RUNEOPT_CC=\"$RUNE_TEST_ROOT/build/asan/cc\"; "
        ^ "RUNEOPT_CACHE=\"$RUNE_TEST_RUN/native-asan-cache\"; export RUNEOPT_RUNTIME RUNEOPT_CC RUNEOPT_CACHE; " else ""
      val start = tz ^ asanEnv ^ "mkdir -p tests/out && ln -sfn \"$RUNE_TEST_ROOT\"/tests/lang tests/lang && "
      val isHost = List.exists (fn h => h = #compiler w) hosts
      (* the host compilers' bytes that are the stack compiler's: the stack
         way's run, which this one waits for *)
      val same =
        if isHost then "if cmp -s " ^ program ^ " " ^ rbc (stackCompiler, name) ^ "; then : > same; exit 0; fi; " else ""
      val script = start ^ same ^ (if restore = "" then "exec " ^ runIt else runIt ^ restore)
      val stdin = if exists ("tests/" ^ base ^ ".stdin") then SOME ("tests/" ^ base ^ ".stdin") else NONE
      val after = ("compile/" ^ #compiler w ^ "/" ^ name)
                  :: (if isHost then ["compile/" ^ stackCompiler ^ "/" ^ name, "lang/test/" ^ name] else [])
                  @ (if #tag w = "test-register-asan" then ["native/prepare/asan"]
                     else if #tag w = "test-native-asan" then ["native/prepare/native-asan"] else [])
    in
      Test.it name
        ({program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = NONE, stdin = stdin,
          timeout = Time.fromSeconds 900, cap = 0, cpus = 1, memory = if isSome (#skip w) then 300 else 100, pools = [],
          exclusive = false, after = after, judge = runJudge (#name w = "test" orelse (#name w="suite" andalso env ("RUNE_SUITE_UPDATE","0")="1"), name)} : Run.command)
    end

  (* ---- the tree *)
  fun selectedName kind name = if selectedCompiler="" then true else
       let val one=env ("RUNE_SUITE_ONE","")
           val category=env ("RUNE_SUITE_KIND","")
       in String.isSubstring (env ("RUNE_SUITE_FILTER","")) name
            andalso (one="" orelse (one=name andalso (category="" orelse category=kind))) end
  val langPrograms = List.filter (selectedName "lang") (programs "tests/lang")
  val errorPrograms = List.filter (selectedName "errors") (programs "tests/errors")
  (* the programs native code does not run (docs/testing.md, Expectations) *)
  val optSkip = Expectations.read "tests/opt-skip.txt"
  val portabilitySkip = Expectations.read "tests/portability-skip.txt"
  fun expectationsOf file = if file = "tests/opt-skip.txt" then optSkip else if file="tests/portability-skip.txt" then portabilitySkip else Expectations.read file
  fun selectedSkip name = case OS.Process.getEnv "RUNE_SUITE_SKIP" of NONE => NONE | SOME file =>
        List.find (fn row : Expectations.line => List.exists (fn kind => kind= #category row)
                      ["HOST-ABSENT","XC1-NA","XC2-NA","UNTESTED","UNSUPPORTED"] andalso Expectations.glob (#path row,name)) (Expectations.read file)

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  (* what the programs cover, for --affected; the tier quick has the
     default way, and the profile layout test-heap's ways *)
  val covers = ["covers:tests/lang/*", "covers:tests/errors/*", "covers:tests/opt-skip.txt"]
  (* a host's compiler needs the host's build *)
  fun needs compiler t = if List.exists (fn h => h = compiler) hosts then Test.requires [compiler] t else t
  fun extraTags tag = (if tag = "test" then ["quick"] else []) @ (if tag = "test-heap" then ["layout"] else [])
                      @ (if tag = "test-portability" then ["portability", "vm", "nightly"]
                         else if tag = "test-stress" orelse tag = "test-register-asan" then ["vm", "nightly"]
                         else if tag = "test-native-stress" orelse tag = "test-native-asan" then ["nightly"] else [])
  (* a way of another machine is not make check's, and one under qemu needs qemu *)
  fun portable (w : way) = #tag w = "test-portability"
  fun wayTags (w : way) =
    (if List.exists (fn tag => tag = #tag w)
        ["test-portability", "test-stress", "test-register-asan", "test-native-stress", "test-native-asan"]
     then [] else ["check"]) @ [#tag w] @ extraTags (#tag w)
  fun wayNeeds (w : way) t =
    if portable w andalso (String.isSubstring "ppc64" (#vm w) orelse String.isSubstring "aarch64" (#vm w))
    then Test.requires ["qemu"] t else t

  (* the programs checked with --typecheck-only, by bin/rune; not for a
     compiler of bin/rune-suite's *)
  fun typecheckTests dir names =
    if selectedCompiler <> "" then []
    else [tagged (["check", "test"] @ covers) (Test.describe "typecheck" (List.map (typecheck dir) names))]

  val tests =
    Test.describe ""
      [Test.describe "compile"
         (List.map (fn (c, command, _) => needs c (tagged ("check" :: covers) (Test.describe c (List.map (compile (c, command)) langPrograms))))
                   compilers
          @ [tagged ("check" :: covers)
               (Test.it "stack-done"
                  (shell ("true", SOME ".", 60, 10, List.map (fn n => "compile/" ^ stackCompiler ^ "/" ^ n) langPrograms,
                          Run.exitZero)))]),
       Test.describe "errors"
         (List.map (fn (c, command, tag) => needs c (tagged (["check", tag]
                      @ (if c = stackCompiler then ["test-stress", "test-native-stress", "test-native-asan", "nightly", "vm"]
                         else if c = "register" then ["test-stress", "test-register-asan", "nightly", "vm"] else []) @ extraTags tag @ covers)
                                                       (Test.describe c (List.map (fn name => if c<>"suite" then error (c,command) name else
                       case selectedSkip name of SOME row => Test.pending (Expectations.describe row) (error (c,command) name)
                          | NONE => error (c,command) name) errorPrograms))))
                   compilers
          @ typecheckTests "errors" errorPrograms),
       Test.describe "lang"
         (List.map (fn w => wayNeeds w (needs (#compiler w) (tagged (wayTags w @ covers)
                              (Test.describe (#name w)
                                 (List.map (fn n =>
                                              case (if #name w="suite" then selectedSkip n else Option.mapPartial (fn f => Expectations.skipped (expectationsOf f, {way = #name w, path = n})) (#skip w)) of
                                                SOME l => Test.pending (#category l ^ ": " ^ #reason l) (run w n)
                                              | NONE => run w n)
                                           langPrograms)))))
                   ways
          @ typecheckTests "lang" langPrograms)]
end
