(* The Basis Library suite on the runner (docs/plans/unit-testing.md, M7;
   tests/basis/README.md): what tests/basis/run-matrix.sh did in make check's
   four configurations of Rune, rune, rune:new, rune:jit and rune:opt, and
   tests/basis/run-examples.sh.

   A test of tests/basis is a program: harness.sml, the files its `uses`
   header names, the test and finish.sml, compiled once by each compiler
   (`basis-compile/COMPILER/TEST`; the stack compiler serves rune and
   rune:opt, and writes where test-opt reads, tests/out/matrix/rune; bin/rune
   serves rune:new and rune:jit) and run in each configuration
   (`basis/CONFIG/TEST`), in a directory of its own as prog.rbc, for at most
   RUNE_MATRIX_TIMEOUT seconds (120). It prints a line PASS, FAIL or SKIP
   for each check and a SUMMARY. Every failed check must be explained by a
   line of tests/basis/deviations.txt for the configuration (or by a
   RUNE-DEV or SPEC-AMBIGUOUS line of `rune`); the program also fails when
   it does not end with its SUMMARY, when the SUMMARY counts other checks
   than it printed, or when two checks share a label. After a
   configuration's programs, `basis/CONFIG/@stale` fails on a line that
   explained no failure there (but a HOST-FLAKY line, or one that matches a
   check that was skipped or did not run for a timeout).

   A program that does not compile fails at its compile: run-matrix.sh's
   cutting of a test into the sections that load is for the hosts, where
   Rune's library is meant to be complete.

   The examples of the Basis Library's documentation are programs that
   runedoc writes into build/basis-examples (make check-tools), each a job
   `basis-examples/NAME` that compiles and runs it with bin/rune and
   bin/runevm: every example must print PASS. *)
structure Basis =
struct
  fun env (name, default) = case OS.Process.getEnv name of SOME v => if v = "" then default else v | NONE => default
  fun exists f = OS.FileSys.access (f, []) handle OS.SysErr _ => false
  fun read f = (let val s = TextIO.openIn f in TextIO.inputAll s before TextIO.closeIn s end) handle IO.Io _ => ""
  fun lines s = List.filter (fn l => l <> "") (String.fields (fn c => c = #"\n") s)

  fun sort (xs : string list) =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if y < x then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (x :: y :: rest) = let val (a, b) = split rest in (x :: a, y :: b) end
        | split xs = (xs, [])
      fun go [] = []
        | go [x] = [x]
        | go xs = let val (a, b) = split xs in merge (go a, go b) end
    in go xs end

  fun files (dir, suffix) =
    let
      val d = OS.FileSys.openDir dir
      fun go acc = case OS.FileSys.readDir d of
                     NONE => acc
                   | SOME f => go (if String.isSuffix suffix f then String.substring (f, 0, size f - size suffix) :: acc
                                   else acc)
    in sort (go [] before OS.FileSys.closeDir d) end
    handle OS.SysErr _ => []

  (* ---- the tests and their configurations *)
  val tests = List.filter (fn t => t <> "harness" andalso t <> "finish") (files ("tests/basis", ".sml"))

  (* the words of a test's `(* uses: ... *)` lines, as run-matrix.sh's sed
     reads them: whole lines from the first column *)
  fun uses t =
    List.concat (List.map (fn l => if String.isPrefix "(* uses: " l andalso String.isSuffix " *)" l
                                   then String.tokens Char.isSpace (String.substring (l, 9, size l - 12)) else [])
                          (lines (read ("tests/basis/" ^ t ^ ".sml"))))

  val timeout = getOpt (Int.fromString (env ("RUNE_MATRIX_TIMEOUT", "120")), 120)
  val native = case OS.Process.getEnv "NATIVE_HOST" of SOME v => v = "yes" | NONE => exists "bin/runevm-native"
  (* a compiler: its name and command; a configuration: its id, its
     directory's name, its compiler, its VM and the make target's tag *)
  val compilers = [("stack", "bin/rune-stack"), ("register", "bin/rune")]
  val configs =
    [("rune", "rune", "stack", env ("RUNEVM", "bin/runevm-stack"), "test-basis"),
     ("rune:new", "rune-new", "register", "bin/runevm", "test-register"),
     ("rune:jit", "rune-jit", "register", "bin/runevm --jit=all --jit-tier=2", "test-register-jit")]
    @ (if native then [("rune:opt", "rune-opt", "stack", "bin/runevm-native", "test-native")] else [])

  val tz = "TZ='NST3:30NDT,M3.2.0,M11.1.0'; export TZ; "
  (* the stack compiler's bytecode where test-opt reads it, as run-matrix.sh
     left it; the other's in the run's directory *)
  fun rbcDir (compiler, t) =
    if compiler = "stack" then "\"$RUNE_TEST_ROOT\"/tests/out/matrix/rune/" ^ t ^ ".dir" else "\"$RUNE_TEST_RUN\"/b/" ^ compiler
  fun rbc (compiler, t) = rbcDir (compiler, t) ^ (if compiler = "stack" then "/prog.rbc" else "/" ^ t ^ ".rbc")

  fun shell (script, dir, timeout, memory, after, judge) =
    {program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = dir, stdin = NONE,
     timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = memory, pools = [], exclusive = false,
     after = after, judge = judge} : Run.command

  fun firstLine s = case lines s of l :: _ => l | [] => ""

  fun compile (compiler, command) t =
    let
      val root = "\"$RUNE_TEST_ROOT\"/tests/basis/"
      val sources = [root ^ "harness.sml"] @ List.map (fn u => root ^ u) (uses t) @ [root ^ t ^ ".sml", root ^ "finish.sml"]
    in
      Test.it t
        (shell (tz ^ "mkdir -p " ^ rbcDir (compiler, t) ^ " && exec " ^ command ^ " " ^ String.concatWith " " sources
                ^ " -o " ^ rbc (compiler, t),
                SOME ".", 600, 400, [],
                fn (r, files as {stdout, stderr}) =>
                  case #outcome r of
                    Supervisor.Exited 0 => NONE
                  | Supervisor.Exited _ =>
                      SOME ("FAIL", "@load/" ^ t ^ ": does not compile: " ^ firstLine (read stderr ^ read stdout))
                  | _ => Run.exitZero (r, files)))
    end

  (* ---- the deviations, and what a run used of them *)
  val deviations = Expectations.read "tests/basis/deviations.txt"
  (* by configuration: the lines that explained a failure, and the labels
     of the checks that did not run (skipped, or after a timeout) *)
  val used : (string * Expectations.line) list ref = ref []
  val unrun : (string * string) list ref = ref []

  (* the first line that explains a failure of LABEL in ID, and whether it
     is the configuration's own (else a line of rune that it inherits,
     which is not marked used) *)
  fun explain (id, label) =
    let
      fun candidate (l : Expectations.line) =
        Expectations.glob (#way l, id)
        orelse (String.isPrefix "rune:" id andalso #way l = "rune"
                andalso (#category l = "RUNE-DEV" orelse #category l = "SPEC-AMBIGUOUS"))
    in
      Option.map (fn l => (l, Expectations.glob (#way l, id)))
                 (List.find (fn l => candidate l andalso Expectations.glob (#path l, label)) deviations)
    end

  fun field2 l = case String.tokens (fn c => c = #" ") l of _ :: x :: _ => x | _ => ""

  fun runJudge (id, t) (r : Supervisor.result, files as {stdout, stderr}) =
    let
      val out = lines (read stdout)
      val checks = List.filter (fn l => String.isPrefix "PASS " l orelse String.isPrefix "FAIL " l
                                        orelse String.isPrefix "SKIP " l) out
      val () = List.app (fn l => if String.isPrefix "SKIP " l then unrun := (id, field2 l) :: !unrun else ()) checks
      val summary = List.find (fn l => String.isPrefix "SUMMARY " l) out
      val timedOut = #outcome r = Supervisor.TimedOut
      val load =
        if timedOut then
          (List.app (fn l => unrun := (id, field2 l) :: !unrun) checks;
           ["@load/" ^ t ^ " -- timed out after " ^ Int.toString timeout ^ " s"])
        else
          case summary of
            NONE =>
              let
                val why = List.find (fn l => let val x = String.map Char.toLower l
                                             in List.exists (fn w => String.isSubstring w x) ["error", "exception", "raised"] end)
                                    (lines (read stderr) @ List.filter (fn l => not (String.isPrefix "PASS " l)) out)
              in ["@load/" ^ t ^ " -- " ^ getOpt (why, "did not load")] end
          | SOME s =>
              let
                val claimed = case String.tokens Char.isSpace s of _ :: n :: _ => Int.fromString n | _ => NONE
                val labels = sort (List.map field2 checks)
                fun dups (a :: (rest as b :: _)) = if a = b then a :: dups (List.filter (fn x => x <> a) rest) else dups rest
                  | dups _ = []
                val twice = dups labels
              in
                (if claimed = SOME (length checks) then []
                 else ["@load/" ^ t ^ " -- SUMMARY reports " ^ (case claimed of SOME n => Int.toString n | NONE => "?")
                       ^ " checks but " ^ Int.toString (length checks) ^ " were printed"])
                @ (if null twice then []
                   else ["@load/" ^ t ^ " -- duplicate check labels: " ^ String.concatWith " " (List.take (twice, Int.min (3, length twice)))])
              end
      val failures = List.mapPartial (fn l => if String.isPrefix "FAIL " l then SOME (String.extract (l, 5, NONE)) else NONE) checks
                     @ load
      fun label f = case String.tokens (fn c => c = #" ") f of x :: _ => x | [] => f
      val unexplained =
        List.filter (fn f => case explain (id, label f) of
                               SOME (l, own) => (if own then used := (id, l) :: !used else (); false)
                             | NONE => true)
                    failures
    in
      case unexplained of
        [] => NONE
      | _ => SOME ("FAIL", Int.toString (length unexplained) ^ " unexplained (add a fix, or a line to tests/basis/deviations.txt):\n  "
                           ^ String.concatWith "\n  " (List.take (unexplained, Int.min (20, length unexplained))))
    end

  fun run (id, _, compiler, vm, _) t =
    Test.it t
      (shell (tz ^ "cp " ^ rbc (compiler, t) ^ " prog.rbc && exec \"$RUNE_TEST_ROOT\"/" ^ vm ^ " prog.rbc",
              NONE, LargeInt.fromInt timeout, 300, ["basis-compile/" ^ compiler ^ "/" ^ t], runJudge (id, t)))

  (* the stale lines of a configuration, once its programs ran *)
  fun stale (id, dir, _, _, _) =
    Test.it "@stale"
      (shell ("true", SOME ".", 60, 10, List.map (fn t => "basis/" ^ dir ^ "/" ^ t) tests,
              fn _ =>
                let
                  val mine = List.filter (fn l => Expectations.glob (#way l, id) andalso #category l <> "HOST-FLAKY") deviations
                  val notRun = List.mapPartial (fn (i, lab) => if i = id then SOME lab else NONE) (!unrun)
                  val st = List.filter (fn l => not (List.exists (fn (i, u) => i = id andalso #number u = #number l) (!used))
                                                andalso not (List.exists (fn lab => Expectations.glob (#path l, lab)) notRun))
                                       mine
                in
                  case st of
                    [] => NONE
                  | _ => SOME ("FAIL", "stale deviations: they match no failure of " ^ id ^ ":\n  "
                                       ^ String.concatWith "\n  " (List.map Expectations.describe st))
                end))

  (* ---- the examples of the documentation *)
  val examples = files ("build/basis-examples", ".sml")

  fun example name =
    Test.it name
      (shell ("\"$RUNE_TEST_ROOT\"/bin/rune -o example.rbc \"$RUNE_TEST_ROOT\"/build/basis-examples/" ^ name ^ ".sml > compile.log 2>&1"
              ^ " || { echo \"its examples do not compile: $(head -1 compile.log)\" >&2; exit 125; }; exec \"$RUNE_TEST_ROOT\"/bin/runevm example.rbc",
              NONE, 600, 300, [],
              fn (r, files as {stdout, stderr}) =>
                let val fails = List.filter (fn l => String.isPrefix "FAIL " l) (lines (read stdout))
                in
                  case (#outcome r, fails) of
                    (Supervisor.Exited 125, _) => SOME ("FAIL", firstLine (read stderr))
                  | (_, f :: _) => SOME ("FAIL", String.concatWith "\n" fails)
                  | (Supervisor.Exited 0, []) => NONE
                  | (Supervisor.Exited n, []) =>
                      SOME ("FAIL", "the program ended with status " ^ Int.toString n ^ ": "
                                    ^ (case rev (lines (read stdout ^ read stderr)) of l :: _ => l | [] => ""))
                  | _ => Run.exitZero (r, files)
                end))

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  val covers = ["covers:tests/basis/*"]

  val tree =
    Test.describe ""
      [Test.describe "basis-compile"
         (List.map (fn (c, command) => tagged ("check" :: covers) (Test.describe c (List.map (compile (c, command)) tests)))
                   compilers
          @ [tagged ("check" :: covers)
               (Test.it "stack-done"
                  (shell ("true", SOME ".", 60, 10, List.map (fn t => "basis-compile/stack/" ^ t) tests, Run.exitZero)))]),
       Test.describe "basis"
         (List.map (fn cfg as (_, dir, _, _, tag) =>
                      tagged (["check", tag] @ covers) (Test.describe dir (List.map (run cfg) tests @ [stale cfg])))
                   configs),
       tagged ["check", "test-basis", "covers:lib/basis/*"] (Test.describe "basis-examples" (List.map example examples))]
end
