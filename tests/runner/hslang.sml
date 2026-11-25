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
  fun late name = List.exists (fn n => n = name) listedNightly

  (* The sample (the lead's ruling 47): a family that repeats a program of
     tests/hs (desugar's orders, meta's relations, the round trip's printers,
     interp-vm, the world's and HsLint's shards) runs in make check one
     program in sampleOneIn, the same every run, those whose name's FNV-1a
     hash is 0 modulo it, and none that lang-nightly.txt names; and nightly
     every program. `sampleTags name` are the tiers of such a job *)
  val sampleOneIn = 16
  fun fnv1a name =
    CharVector.foldl (fn (c, h) => Word32.* (Word32.xorb (h, Word32.fromInt (ord c)), 0w16777619)) 0w2166136261 name
  fun sampled name = not (late name) andalso Word32.mod (fnv1a name, Word32.fromInt sampleOneIn) = 0w0
  fun sampleTags name = if sampled name then ["check", "nightly"] else ["nightly"]
  fun tagAll tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  fun tiers kind (p : Lang.program) =
    case kind of
      "errors/typecheck" => ["nightly"]
    | "accept" => ["check"]
    | _ =>
        if String.isPrefix "errors/" kind then ["check", "quick"]
        else if late (#name p) then ["nightly"]
        else ["check"] @ (if kind = "lang/register" then ["quick"] else [])

  (* RUNE_HS_RHC_FLAGS: options every compile of the suite takes, before
     its own, none where it is unset: `-O2` runs the suite at the level of
     the Core simplifier and Sestoft's trees (D34) on both bytecodes *)
  val rhcFlags = case OS.Process.getEnv "RUNE_HS_RHC_FLAGS" of SOME f => if f = "" then "" else " " ^ f | NONE => ""

  val rhc : Lang.suite =
    {group = "hs", lang = "tests/hs/lang", errors = "tests/hs/errors", accept = SOME "tests/hs/accept",
     suffixes = suffixes, mains = mains,
     compilers = [("stack", "bin/rhc" ^ rhcFlags ^ " --target=stack", "hs"), ("register", "bin/rhc" ^ rhcFlags, "hs")],
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

  (* ---- the 2010 suites (the haskell2010 roadmap's M1, D38 and D41): the
     programs of tests/hs2010, group hs2010, and those of tests/hs that the
     2010 table shares by clause id (HsConformance.shared2010), group
     hs2010/shared, each compiled, checked and run by rhc with
     --language=haskell2010 to the same siblings. Every job is listed and
     pending until bin/rhc takes the flag (M6), and then while the rows it
     tests are Planned in tests/hs2010/conformance.tsv
     (HsConformance.pending2010). tests/hs2010's programs take the tiers of
     98's; a shared program is checked (--typecheck-only) in make check and
     compiled and run nightly, since make check runs it in 98 mode (D41) *)
  val rhc2010 = "bin/rhc --language=haskell2010"
  val covers2010 = ["covers:tests/hs2010/*", "covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*",
                    "covers:rhc.build", "covers:rhc.plan"]
  fun sharedTiers kind (_ : Lang.program) =
    if kind = "accept" orelse String.isSuffix "/typecheck" kind then ["check"] else ["nightly"]
  fun suite2010 (group, base, covers, selected, programTags) : Lang.suite =
    {group = group, lang = base ^ "/lang", errors = base ^ "/errors", accept = SOME (base ^ "/accept"),
     suffixes = suffixes, mains = mains,
     compilers = [("stack", rhc2010 ^ rhcFlags ^ " --target=stack", "hs"), ("register", rhc2010 ^ rhcFlags, "hs")],
     errorCompilers = [("register", rhc2010, "hs")],
     ways = rhcWays,
     out = fn compiler => "\"$RUNE_TEST_RUN\"/" ^ group ^ "/c/" ^ compiler,
     binary = fn name => name ^ "/prog.rbc", scratch = group ^ "/",
     writer = "register", writerWay = "register",
     typecheck = SOME (rhc2010 ^ " --typecheck-only"), stackDone = false, covers = covers,
     compileTags = ["hs"], errorTags = fn _ => ["hs"], typecheckTags = ["hs"],
     wayTags = fn (w : Lang.way) => ["hs"],
     needs = fn (n : string) => Test.requires (["rhc"] @ (if String.isSubstring ".err.perm" n then ["unprivileged"] else [])),
     wayNeeds = fn _ => fn t => t,
     selected = selected, pending = HsConformance.pending2010, programTags = programTags}
  val rhcOwn2010 = suite2010 ("hs2010", "tests/hs2010", covers2010, fn _ => fn _ => true, tiers)
  val rhcShared2010 =
    suite2010 ("hs2010/shared", "tests/hs", covers @ covers2010,
               fn kind => fn name =>
                 case List.find (fn (p : Lang.program) => #name p = name) (HsConformance.programsIn ("tests/hs/" ^ kind)) of
                   SOME p => HsConformance.shared2010 kind p
                 | NONE => false,
               sharedTiers)

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

  (* D17's count (runtime/heap.c, vm_selected): a program of selectors,
     interpreted at nurseries of 64 KiB, 256 KiB, 1 MiB and 4 MiB and with
     none (the copier), counts the same instructions and prints what it is
     to print, wherever its collections fall *)
  val nurseries = ["65536", "262144", "1048576", "4194304", "0"]
  fun selectorsNursery b =
    let
      val n = OS.Path.file b
      val dir = run ^ "/hs-selectors/" ^ n
      val () = mkdirs dir
      fun f x = dir ^ "/" ^ x
    in
      if exec {cmd = [fromRoot "bin/rhc", fromRoot (b ^ ".hs"), "-o", f "prog.rbc"], dir = NONE, stdin = "", stdout = "",
               stderr = f "cerr", timeout = 600} <> 0
      then say ("FAIL hs-selectors." ^ n ^ ": " ^ firstNonEmpty (f "cerr") ^ "\n")
      else
        let
          fun runAt k =
            (ignore (exec {cmd = [fromRoot "bin/runevm", "--count", "--jit=off", "--nursery", k, f "prog.rbc"], dir = NONE,
                           stdin = "", stdout = f ("out." ^ k), stderr = f ("err." ^ k), timeout = 600});
             (k, countOf (f ("err." ^ k))))
          val counts = List.map runAt nurseries
          val (k0, c0) = hd counts
        in
          List.app (fn (k, _) => if same (f ("out." ^ k), fromRoot (b ^ ".expected")) then ()
                                 else say ("FAIL hs-selectors." ^ n ^ ": --nursery " ^ k ^ " prints otherwise: "
                                           ^ firstNonEmpty (f ("err." ^ k)) ^ "\n")) counts;
          if c0 = "" then say ("FAIL hs-selectors." ^ n ^ ": no count with --nursery " ^ k0 ^ "\n") else ();
          List.app (fn (k, c) => if c = c0 then ()
                                 else say ("FAIL hs-selectors." ^ n ^ ": counts " ^ c0 ^ " with --nursery " ^ k0 ^ ", " ^ c
                                           ^ " with --nursery " ^ k ^ "\n")) (tl counts)
        end
    end

  (* D17's C for a generalised binding behind rhc's --selectors=generalised
     (off by default): the option changes the program's desugaring -- its
     Core marks more selectors -- and the bytecode; without it the bytecode
     is --selectors=monomorphic's, the default's; and the program prints
     what it is to print each way *)
  fun selectorsGeneralised b =
    let
      val n = OS.Path.file b
      val dir = run ^ "/hs-selectors/" ^ n
      val () = mkdirs dir
      fun f x = dir ^ "/" ^ x
      fun fail why = say ("FAIL hs-selectors." ^ n ^ ": " ^ why ^ "\n")
      fun rhc (flags, out, tag) =
        exec {cmd = [fromRoot "bin/rhc"] @ flags @ [fromRoot (b ^ ".hs")] @ out, dir = NONE, stdin = "",
              stdout = f (tag ^ ".out"), stderr = f (tag ^ ".err"), timeout = 600}
      fun core (flags, tag) = (ignore (rhc (["--desugar-only", "--dump-after=desugar", "--canonical-core"] @ flags, [], tag));
                               read (f (tag ^ ".out")) ^ read (f (tag ^ ".err")))
      fun marks text = length (List.filter (fn l => String.isSubstring "sel_mark" l) (String.fields (fn c => c = #"\n") text))
      val off = core ([], "core-off")
      val on = core (["--selectors=generalised"], "core-on")
      fun compile (flags, tag) =
        if rhc (flags, ["-o", f (tag ^ ".rbc")], tag) <> 0 then (fail (tag ^ ": " ^ firstNonEmpty (f (tag ^ ".err"))); false)
        else true
      fun runs tag =
        (ignore (exec {cmd = [fromRoot "bin/runevm", "--count", f (tag ^ ".rbc")], dir = NONE, stdin = "",
                       stdout = f (tag ^ ".run"), stderr = f (tag ^ ".runerr"), timeout = 600});
         if same (f (tag ^ ".run"), fromRoot (b ^ ".expected")) then ()
         else fail (tag ^ " prints otherwise: " ^ firstNonEmpty (f (tag ^ ".runerr"))))
    in
      if marks off = 0 andalso marks on = 0 then fail ("no Core dumped (" ^ dir ^ ")") else ();
      if marks on <= marks off then fail ("--selectors=generalised marks " ^ Int.toString (marks on) ^ " selectors, without it "
                                          ^ Int.toString (marks off) ^ ": the desugaring does not change")
      else ();
      if compile ([], "off") andalso compile (["--selectors=monomorphic"], "mono") andalso compile (["--selectors=generalised"], "on")
      then
        (if same (f "off.rbc", f "mono.rbc") then () else fail "the bytecode without the option is not --selectors=monomorphic's";
         if same (f "off.rbc", f "on.rbc") then fail "--selectors=generalised leaves the bytecode as it is" else ();
         List.app runs ["off", "mono", "on"])
      else ()
    end

  (* D17's C by shape (gap 4) behind rhc's --selector-shapes, on by default:
     off, Core to Mid marks fewer selectors and the bytecode changes; the
     default's bytecode is --selector-shapes=on's; each prints what it is to
     print; and linked through one store, on, off and on again, each is its
     own bytecode, the link's entry kept apart by the option (its memo hands
     neither the other's program) *)
  fun selectorsShapes b =
    let
      val n = OS.Path.file b
      val dir = run ^ "/hs-selectors/shapes-" ^ n
      val () = (rmTree dir; mkdirs dir)
      fun f x = dir ^ "/" ^ x
      fun fail why = say ("FAIL hs-selectors.shapes: " ^ why ^ " (" ^ dir ^ ")\n")
      fun rhc (flags, tag) =
        exec {cmd = [fromRoot "bin/rhc"] @ flags @ [fromRoot (b ^ ".hs"), "-o", f (tag ^ ".rbc")], dir = NONE, stdin = "",
              stdout = f (tag ^ ".out"), stderr = f (tag ^ ".err"), timeout = 600} = 0
        orelse (fail (tag ^ ": " ^ firstNonEmpty (f (tag ^ ".err"))); false)
      (* the marks of Core to Mid's dump: each a `prim thunk_selector`, many to a line *)
      fun marks tag =
        let
          val text = read (f (tag ^ ".out")) ^ read (f (tag ^ ".err"))
          val pat = "prim thunk_selector"
          fun go (i, n) = if i + size pat > size text then n
                          else if String.substring (text, i, size pat) = pat then go (i + size pat, n + 1) else go (i + 1, n)
        in go (0, 0) end
      fun runs tag =
        (ignore (exec {cmd = [fromRoot "bin/runevm", f (tag ^ ".rbc")], dir = NONE, stdin = "",
                       stdout = f (tag ^ ".run"), stderr = f (tag ^ ".runerr"), timeout = 600});
         if same (f (tag ^ ".run"), fromRoot (b ^ ".expected")) then ()
         else fail (tag ^ " prints otherwise: " ^ firstNonEmpty (f (tag ^ ".runerr"))))
      val store = f "store"
      val ok = rhc (["--no-store"], "default") andalso rhc (["--no-store", "--selector-shapes=on"], "on")
               andalso rhc (["--no-store", "--selector-shapes=off"], "off")
               andalso rhc (["--no-store", "--dump-after=coretomid"], "mid-on")
               andalso rhc (["--no-store", "--dump-after=coretomid", "--selector-shapes=off"], "mid-off")
               andalso rhc (["--store", store], "store-on") andalso rhc (["--store", store, "--selector-shapes=off"], "store-off")
               andalso rhc (["--store", store], "store-on-again")
    in
      if not ok then ()
      else
        (if same (f "default.rbc", f "on.rbc") then () else fail "the default's bytecode is not --selector-shapes=on's";
         if same (f "on.rbc", f "off.rbc") then fail "--selector-shapes=off leaves the bytecode as it is" else ();
         if marks "mid-off" < marks "mid-on" then ()
         else fail ("Core to Mid marks " ^ Int.toString (marks "mid-on") ^ " selectors with shapes, "
                    ^ Int.toString (marks "mid-off") ^ " without");
         if same (f "store-on.rbc", f "on.rbc") then () else fail "linked through the store, on is not on's bytecode";
         if same (f "store-off.rbc", f "off.rbc") then () else fail "linked through the store after on, off is not off's bytecode";
         if same (f "store-on-again.rbc", f "on.rbc") then ()
         else fail "linked through the store after off, on is not on's bytecode";
         List.app runs ["default", "off"])
    end

  fun command args =
    case args of
      "hs-stub-compile" :: rest => SOME (fn () => stubCompile rest)
    | ["hs-selectors-nursery", b] => SOME (fn () => selectorsNursery b)
    | ["hs-selectors-generalised", b] => SOME (fn () => selectorsGeneralised b)
    | ["hs-selectors-shapes", b] => SOME (fn () => selectorsShapes b)
    | "hs-stub-run" :: rest => SOME (fn () => stubRun rest)
    | ["hs-programs"] => SOME programs
    | _ => NONE

  (* ---- the tree *)
  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  (* the oracle jit of Rune's programs (Oracles.jitOneWith) on rhc's:
     interpreted and in each mode of the JIT, the same output, counts and
     errors; nightly, with the ways beyond D56's three *)
  (* a program whose path depends on its run says so on a line `-- jit:
     output only: REASON`, and its modes' outputs alone are compared *)
  fun outputOnly (p : Lang.program) =
    List.exists (String.isPrefix "-- jit: output only: ") (String.fields (fn c => c = #"\n") (read (fromRoot (#src p))))
    handle _ => false
  fun jit (p : Lang.program) =
    let val t = Oracles.jobIn ("", #name p, [if outputOnly p then "jit-one-output" else "jit-one-with", "bin/rhc", #base p, #src p],
                               [], 1, 600, 3600)
    in case HsConformance.pending p of SOME why => Test.pending why t | NONE => t end
  (* D17's count (runtime/heap.c, vm_selected): programs of selectors --
     tests/hs/selectors/count, and the two of tests/hs/lang whose counts
     differed (hs/jit, nightly, which D17's gate did not run) -- each
     counting the same instructions interpreted, at tier 1, at tier 2, under
     --deopt-stress and in the oracle's other modes, at the default nursery,
     whatever the collector reduced (hs/selectors/NAME, in a directory of
     their own, apart from hs/jit's of the same programs); and count the
     same at every nursery (hs/selectors/nursery). In make check *)
  val selectors = ["tests/hs/selectors/count", "tests/hs/lang/lib.complex.realpart_literal",
                   "tests/hs/lang/lib.numeric.showsigned_literal"]
  fun tree () =
    Test.describe ""
      [Lang.tree rhc,
       Lang.tree rhcOwn2010,
       Lang.tree rhcShared2010,
       Test.requires ["rhc"] (tagged (["nightly", "hs"] @ covers)
                                (Test.describe "hs/jit" (List.map jit (Lang.programsOf (#lang rhc, suffixes, mains))))),
       Test.requires ["rhc", "jit"]
         (tagged (["check", "hs"] @ covers @ ["covers:tests/hs/selectors/*", "covers:runtime/heap.c", "covers:runtime/gc/*",
                                              "covers:runtime/register/*", "covers:runtime/stack/*"])
            (Test.describe "hs/selectors"
               (List.map (fn b => Oracles.jobIn ("RUNE_TEST_RUN=\"$RUNE_TEST_RUN\"/hs-selectors ", OS.Path.file b,
                                                 ["jit-one-with", "bin/rhc", b, b ^ ".hs"], [], 1, 600, 3600))
                         selectors
                @ [Oracles.jobIn ("", "nursery", ["hs-selectors-nursery", "tests/hs/selectors/count"], [], 1, 600, 3600),
                   Oracles.jobIn ("", "generalised", ["hs-selectors-generalised", "tests/hs/selectors/generalised"], [], 1, 600,
                                  3600),
                   Oracles.jobIn ("", "shapes", ["hs-selectors-shapes", "tests/hs/selectors/count"], [], 1, 600, 3600)]))),
       tagged (runnerTags @ runnerCovers)
         (Test.describe "hs/runner"
            [Test.describe "silent" (List.map silent (Lang.programsOf (#lang stub, suffixes, mains))),
             Test.it "programs"
               {program = "/bin/sh", args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test hs-programs"],
                env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 60, cap = 0, cpus = 1, memory = 100,
                pools = [], exclusive = false, after = [], judge = failLines}]),
       Lang.tree stub]
end
