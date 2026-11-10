(* rhc's programs on the runner (docs/plans/language/haskell98.md, M2;
   docs/testing.md, rhc's tests): the suite of Lang (tests/runner/lang.sml)
   over tests/hs, compiled by bin/rhc and run in the three ways of D56.

   A program of rhc's is a file `NAME.hs` or `NAME.lhs`, or a directory
   `NAME` with a `Main.hs` or `Main.lhs` in it, whose other modules rhc
   finds beside it; its siblings are named from `tests/hs/lang/NAME` in both
   cases, as Rune's are (`.expected`, `.cargs`, `.args`, `.stdin`,
   `.exitcode`, `.cwarn`, ...). tests/hs/lang holds the programs compiled
   and run, tests/hs/errors those refused, with the text of their
   `.expected` in the first line of what rhc says, and tests/hs/accept those
   that are only checked, which `--typecheck-only` must accept as it says
   nothing (or what their `.cwarn` says). Their jobs are `hs/compile/...`,
   `hs/errors/...`, `hs/lang/WAY/NAME`, `hs/lang/typecheck/NAME`,
   `hs/errors/typecheck/NAME` and `hs/accept/NAME`, which need the
   capability `rhc` (bin/rhc). Where no program is there, there is no job,
   and a program's jobs are pending while every row it tests is Planned in
   tests/hs/conformance.tsv (HsConformance.pending).

   The runner's own check of that machinery, which needs no rhc, is a
   second suite of the same kind over tests/hs/runner: a stub compiler and a
   stub VM, commands of bin/rune-test written here, compile and run a `.hs`
   program, a `.lhs` program, a program of two modules in a directory, one
   that exits with a status and one that warns, refuse a program and check
   one (`hs/runner/...`). The stub compiler's bytecode is the text that
   the program's `putStrLn`s print, in the order of its modules; the stub VM
   prints it. A stub VM that prints nothing must fail each program
   (`hs/runner/silent/NAME`, whose judge is the run's turned round), as the
   oracle jit fails a program that prints nothing where it should print
   (Oracles.jitOne), which also runs rhc's programs nightly (`hs/jit/NAME`). *)
structure HsLang =
struct
  open Sh

  (* ---- rhc's suite *)
  (* what rhc's programs cover, for --affected: a change to rhc, its
     library or its Prelude selects them, and not Rune's *)
  val covers = ["covers:tests/hs/lang/*", "covers:tests/hs/errors/*", "covers:tests/hs/accept/*",
                "covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*",
                "covers:rhc.build", "covers:rhc.plan"]
  val suffixes = [".hs", ".lhs"]
  val mains = ["Main.hs", "Main.lhs"]

  (* the ways of D56: the stack VM, bin/runevm at its default tier, and
     tier 2 *)
  fun way (name, compiler, vm) = {name = name, compiler = compiler, vm = vm, tag = "hs", skip = NONE} : Lang.way
  val rhcWays =
    [way ("test", "stack", "bin/runevm-stack"),
     way ("register", "register", "bin/runevm"),
     way ("register-opt", "register", "bin/runevm --jit=all --jit-tier=2")]

  (* The tiers (the roadmap's D56, B; the lead's ruling 45): a program of
     tests/hs/lang runs in make check in D56's three ways, with its two
     compiles and its check, unless tests/hs/lang-nightly.txt names it (a
     program over D56's second, by its measured time), when all its jobs are
     nightly; tests/hs/errors refused by the register compile in check, and
     by --typecheck-only nightly; tests/hs/accept checked in check. The
     register way and the refusals are also quick. *)
  fun nightlyPrograms () =
    List.mapPartial (fn l => case String.tokens Char.isSpace l of
                               n :: _ => if String.isPrefix "#" n then NONE else SOME n
                             | [] => NONE)
                    (lines (read (fromRoot "tests/hs/lang-nightly.txt")))
    handle _ => []
  val listedNightly = nightlyPrograms ()
  fun tiers kind (p : Lang.program) =
    case kind of
      "errors/typecheck" => ["nightly"]
    | "accept" => ["check"]
    | _ =>
        if String.isPrefix "errors/" kind then ["check", "quick"]
        else if List.exists (fn n => n = #name p) listedNightly then ["nightly"]
        else ["check"] @ (if kind = "lang/register" then ["quick"] else [])

  val rhc : Lang.suite =
    {group = "hs", lang = "tests/hs/lang", errors = "tests/hs/errors", accept = SOME "tests/hs/accept",
     suffixes = suffixes, mains = mains,
     compilers = [("stack", "bin/rhc --target=stack", "hs"), ("register", "bin/rhc", "hs")],
     (* a program is refused before any code is made, so one compiler
        judges it *)
     errorCompilers = [("register", "bin/rhc", "hs")],
     ways = rhcWays,
     out = fn compiler => "\"$RUNE_TEST_RUN\"/hs/c/" ^ compiler,
     (* each program in a directory of its own as prog.rbc, so that
        getProgName, the file's base name (the lead's ruling 33), is prog *)
     binary = fn name => name ^ "/prog.rbc", scratch = "hs/",
     writer = "register", writerWay = "register",
     typecheck = SOME "bin/rhc --typecheck-only", stackDone = false, covers = covers,
     compileTags = ["hs"], errorTags = fn _ => ["hs"], typecheckTags = ["hs"],
     wayTags = fn (w : Lang.way) => ["hs"],
     (* a permission refusal (NAME.err.perm) cannot be seen by root: skipped
        there, with that reason (the lead's ruling 32) *)
     needs = fn (n : string) => Test.requires (["rhc"] @ (if String.isSubstring ".err.perm" n then ["unprivileged"] else [])),
     wayNeeds = fn _ => fn t => t,
     selected = fn _ => fn _ => true, pending = HsConformance.pending, programTags = tiers}

  val capabilities =
    [{name = "rhc", probe = "test -x bin/rhc", hint = "run: make bin/rhc (rhc.build; docs/testing.md, rhc's tests)"},
     {name = "unprivileged", probe = "test \"$(id -u)\" -ne 0",
      hint = "a permission refusal cannot be seen as root: run the tests as another user"}]

  (* ---- the runner's own suite *)
  val stubCompile = "bin/rune-test hs-stub-compile"
  val stubWay = {name = "stub", compiler = "stub", vm = "bin/rune-test hs-stub-run", tag = "hs", skip = NONE} : Lang.way
  val silentWay = {name = "silent", compiler = "stub", vm = "bin/rune-test hs-stub-run --silent", tag = "hs", skip = NONE}
                  : Lang.way
  (* not tests/runner/lang.sml: a change there selects every test, Rune's
     programs among them *)
  val runnerCovers = ["covers:tests/hs/runner/*", "covers:tests/runner/hslang.sml"]
  val runnerTags = ["check", "hs", "quick"]

  val stub : Lang.suite =
    {group = "hs/runner", lang = "tests/hs/runner/lang", errors = "tests/hs/runner/errors",
     accept = SOME "tests/hs/runner/accept", suffixes = suffixes, mains = mains,
     compilers = [("stub", stubCompile, "hs")], errorCompilers = [("stub", stubCompile, "hs")], ways = [stubWay],
     out = fn compiler => "\"$RUNE_TEST_RUN\"/hs-runner/c/" ^ compiler, binary = fn name => name ^ ".rbc",
     scratch = "hs-runner/",
     (* --accept writes none of the fixtures *)
     writer = "", writerWay = "",
     typecheck = SOME (stubCompile ^ " --typecheck-only"), stackDone = false, covers = runnerCovers,
     compileTags = runnerTags, errorTags = fn _ => runnerTags, typecheckTags = runnerTags,
     wayTags = fn _ => runnerTags, needs = fn _ => fn t => t, wayNeeds = fn _ => fn t => t,
     selected = fn _ => fn _ => true, pending = fn _ => NONE, programTags = fn _ => fn _ => []}

  (* a run of the silent VM: it passes only where the run's judge fails it
     for its output, and says so *)
  fun silent (p : Lang.program) =
    let
      val c : Run.command = case Test.leaves (Lang.run stub silentWay p) of
                              [{leaf, ...}] => leaf
                            | _ => raise Fail "HsLang.silent: one run"
      fun judge result =
        case #judge c result of
          SOME ("FAIL", why) =>
            if String.isPrefix "stdout differs" why then NONE
            else SOME ("FAIL", "a stub VM that prints nothing fails for another reason: " ^ why)
        | SOME (verdict, why) => SOME (verdict, why)
        | NONE => SOME ("FAIL", "a stub VM that prints nothing passes " ^ #base p)
    in
      Test.it (#name p)
        {program = #program c, args = #args c, env = #env c, dir = #dir c, stdin = #stdin c, timeout = #timeout c,
         cap = #cap c, cpus = #cpus c, memory = #memory c, pools = #pools c, exclusive = #exclusive c,
         after = #after c, judge = judge} : Run.command Test.tree
    end

  (* the names of a directory's programs that two of its entries give (a
     `.hs` beside a `.lhs`, or a file beside a directory), which would be
     two jobs of one name *)
  fun twice dir =
    let
      val names = List.map #name (Lang.programsOf (dir, suffixes, mains))
      fun go ([], _) = []
        | go (n :: rest, seen) = (if List.exists (fn m => m = n) seen then [n] else []) @ go (rest, n :: seen)
    in go (names, []) end
  val dirs = ["tests/hs/lang", "tests/hs/errors", "tests/hs/accept",
              "tests/hs/runner/lang", "tests/hs/runner/errors", "tests/hs/runner/accept"]
  fun programs () =
    List.app (fn dir => List.app (fn n => say ("FAIL " ^ dir ^ ": two programs named " ^ n ^ "\n")) (twice dir)) dirs

  (* ---- the stub compiler and VM *)
  (* a module's text: the lines after a bird track of a literate one *)
  fun code file =
    if String.isSuffix ".lhs" file then
      String.concat (List.mapPartial (fn l => if String.isPrefix "> " l then SOME (String.extract (l, 2, NONE) ^ "\n")
                                              else if l = ">" then SOME "\n" else NONE)
                                     (String.fields (fn c => c = #"\n") (read file)))
    else read file
  fun lineList text = String.fields (fn c => c = #"\n") text
  (* the modules a program is made of: its main, then each module it
     imports that is beside it, first found first *)
  fun modules main =
    let
      val dir = OS.Path.dir main
      fun imports text =
        List.mapPartial (fn l => case String.tokens Char.isSpace l of
                                   "import" :: m :: _ => SOME m
                                 | _ => NONE) (lineList text)
      fun find m = List.find exists [dir ^ "/" ^ m ^ ".hs", dir ^ "/" ^ m ^ ".lhs"]
      fun go ([], seen) = List.rev seen
        | go (f :: rest, seen) =
            if List.exists (fn (g, _) => g = f) seen then go (rest, seen)
            else
              let val text = code f
              in go (rest @ List.mapPartial find (imports text), (f, text) :: seen) end
    in go ([main], []) end
  (* the text after a marker in a line, to the end of the line *)
  fun after (marker, l) =
    let val (_, rest) = Substring.position marker (Substring.full l)
    in if Substring.isEmpty rest then NONE else SOME (Substring.string (Substring.triml (size marker) rest)) end
  (* the strings each `putStrLn "..."` prints, and the status of an
     `exitWith (ExitFailure N)` *)
  fun printed l = Option.map (fn s => hd (String.fields (fn c => c = #"\"") s)) (after ("putStrLn \"", l))
  fun status l = Option.mapPartial (fn s => Int.fromString s) (after ("ExitFailure ", l))

  fun err s = TextIO.output (TextIO.stdErr, s)
  fun stubCompile args =
    let
      val (check, rest) = case args of "--typecheck-only" :: rest => (true, rest) | _ => (false, args)
      val (src, out) = case rest of [src, "-o", out] => (src, SOME out) | [src] => (src, NONE)
                                  | _ => raise Fail "hs-stub-compile [--typecheck-only] SRC [-o OUT]"
      val ms = modules src
      val ls = List.concat (List.map (fn (f, text) => List.map (fn l => (f, l)) (lineList text)) ms)
      val refused = List.find (fn (_, l) => isSome (after ("-- error: ", l))) ls
      val () = List.app (fn (f, l) => case after ("-- warning: ", l) of
                                        SOME w => err (f ^ ": warning: " ^ w ^ "\n")
                                      | NONE => ()) ls
    in
      case refused of
        SOME (f, l) => (err (f ^ ": error: " ^ valOf (after ("-- error: ", l)) ^ "\n"); OS.Process.exit OS.Process.failure)
      | NONE =>
          case (check, out) of
            (false, SOME out) =>
              write (out, String.concat (List.mapPartial (fn (_, l) => Option.map (fn s => s ^ "\n") (printed l)) ls)
                          ^ String.concat (List.mapPartial (fn (_, l) => Option.map (fn n => "#exit " ^ Int.toString n ^ "\n")
                                                                                     (status l)) ls))
          | _ => ()
    end
  (* prints the stub bytecode's text, or nothing with --silent, and exits
     with its status *)
  fun stubRun args =
    let
      val quiet = List.exists (fn a => a = "--silent") args
      val file = case List.filter (fn a => not (String.isPrefix "--" a)) args of f :: _ => f
                                                                               | [] => raise Fail "hs-stub-run FILE"
      val ls = List.filter (fn l => l <> "") (lineList (read file))
      val code = List.foldl (fn (l, c) => case after ("#exit ", l) of SOME n => getOpt (Int.fromString n, c) | NONE => c) 0 ls
    in
      if quiet then () else List.app (fn l => if String.isPrefix "#exit " l then () else say (l ^ "\n")) ls;
      Posix.Process.exit (Word8.fromInt code)
    end

  fun command args =
    case args of
      "hs-stub-compile" :: rest => SOME (fn () => stubCompile rest)
    | "hs-stub-run" :: rest => SOME (fn () => stubRun rest)
    | ["hs-programs"] => SOME programs
    | _ => NONE

  (* ---- the tree *)
  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  (* the oracle jit of Rune's programs (Oracles.jitOneWith) on rhc's:
     interpreted and in each mode of the JIT, the same output, counts and
     errors; nightly, with the ways beyond D56's three *)
  fun jit (p : Lang.program) =
    let val t = Oracles.jobIn ("", #name p, ["jit-one-with", "bin/rhc", #base p, #src p], [], 1, 600, 3600)
    in case HsConformance.pending p of SOME why => Test.pending why t | NONE => t end
  fun tree () =
    Test.describe ""
      [Lang.tree rhc,
       Test.requires ["rhc"] (tagged (["nightly", "hs"] @ covers)
                                (Test.describe "hs/jit" (List.map jit (Lang.programsOf (#lang rhc, suffixes, mains))))),
       tagged (runnerTags @ runnerCovers)
         (Test.describe "hs/runner"
            [Test.describe "silent" (List.map silent (Lang.programsOf (#lang stub, suffixes, mains))),
             Test.it "programs"
               {program = "/bin/sh", args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test hs-programs"],
                env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 60, cap = 0, cpus = 1, memory = 100,
                pools = [], exclusive = false, after = [], judge = failLines}]),
       Lang.tree stub]
end
