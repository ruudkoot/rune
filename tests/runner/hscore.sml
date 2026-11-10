(* The tests of rhc's Core (tests/hs/core; the haskell98 roadmap, M8), a
   family of its own until the hs family of M2 takes them: each a command of
   bin/rune-test that prints a line FAIL for what it finds.

   A test is a file of Core text whose first line says what to do, as a test
   of tests/ir does:
     ; run: FLAGS     bin/rhc --lint=3 FLAGS --read-core FILE runs it; what it
                      prints is NAME.expected, and the status NAME.exitcode, 0
                      where there is none. A run that prints nothing fails.
     ; dump: FLAGS    the same, for what is not a run: a dump of a stage
     ; fail: MESSAGE  bin/rhc refuses it, with MESSAGE on standard error.
     ; forces: N FLAGS  bin/rhc --lint=2 FLAGS --dump-after=coretomid compiles
                      it, and the dump of Core to Mid holds N thunk_force
                      nodes, one for each force of Core, which the file
                      counts (the roadmap's M10)
     ; refuse: FLAGS | MESSAGE
                      bin/rhc --lint=2 FLAGS --read-core FILE -o OUT refuses
                      it, with MESSAGE: a fault of Core to Mid made on
                      purpose (--fault) and what catches it.
   At level 3 every program is printed, read back and printed again, so
   print, read, print is the identity on every test. A run reads NAME.stdin
   where there is one, and one of a test with a line `; files: own`, which
   writes files, runs in a directory of its own. Besides the files:
   every rule of CoreLint has its fault, lint-RULE.core, refused with its
   message; programs from the generator of D55 pass CoreLint and run to an
   outcome, a value or a bottom; and a silent run is judged a failure.

   A run test is also compiled by rhc through Mid (the roadmap's M10) at
   -O0, -O1 and -O2 to both bytecodes, and run on the register VM
   interpreted and at tier 2 and on the stack VM (hs/core/vm/NAME), and
   one with a line `; ways: E1` nightly in E1's forty-five ways too, twelve
   modes of the register VM and three of the stack VM a level
   (hs/core/vm45/NAME, results/E1/run.sh): it
   prints what the interpreter printed, and ends as it did, every bottom
   one bottom, a status other than 0. A test whose answer is the
   interpreter's alone says so on a line `; vm: no: REASON`: one whose
   answer depends on a suspension that raised being forced again, which
   the interpreter puts back and form C leaves under evaluation (D12), or
   on a bound only the interpreter has, --steps or --depth, or on what a
   milestone is to give; a residency or budget test that says so is not
   run either.

   Two more kinds of test read a program at two sizes, files of
   tests/hs/core/lib that define `size`, after tests/hs/core/lib/base.core:
   a line `; residency: SIZE1 SIZE2` holds the most live, with a collection
   at every allocation (runevm --stats), to the same at both sizes, at -O0
   and -O2, interpreted and at tier 2 (E2's last and leak, D12); a line
   `; budget: SIZE1 SIZE2` holds the instructions --count gives at the
   second to at most 2.2 times those at the first, so that a lost share,
   which grows exponentially, is caught (D6; rhc's policy). *)
structure HsCore =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")
  fun contains (f, text) = String.isSubstring text (read f)
  val dir = "tests/hs/core"
  val rhc = "bin/rhc"

  fun nameOf src = let val f = OS.Path.file src in if String.isSuffix ".core" f then String.substring (f, 0, size f - 5) else f end

  (* what the first line of src asks: the marker and what follows it *)
  fun marker src =
    let
      val line1 = firstLine src
      fun after m = if String.isPrefix ("; " ^ m ^ ":") line1
                    then SOME (String.extract (line1, size m + 3, NONE)) else NONE
    in
      case (after "run", after "dump", after "fail", after "refuse") of
        (SOME flags, _, _, _) => SOME ("run", flags)
      | (_, SOME flags, _, _) => SOME ("dump", flags)
      | (_, _, SOME msg, _) => SOME ("fail", String.extract (msg, if String.isPrefix " " msg then 1 else 0, NONE))
      | (_, _, _, SOME both) => SOME ("refuse", both)
      | _ => Option.map (fn rest => ("forces", rest)) (after "forces")
    end

  (* the status a test wants: NAME.exitcode, or 0 *)
  fun wanted n =
    let val f = dir ^ "/" ^ n ^ ".exitcode"
    in if exists f then (case Int.fromString (firstLine f) of SOME k => k | NONE => ~1) else 0 end

  (* what is wrong with a run that printed `out`, where `expected` is wanted:
     NONE where nothing is; a run that printed nothing has failed, whatever
     is expected, as jitOne holds (tests/runner/oracles.sml) *)
  fun judgeRun (out : string, expected : string) : string option =
    if out = "" then SOME "the run printed nothing"
    else if out <> expected then SOME "what it printed differs from its .expected"
    else NONE

  (* the standard input of a run of test n: NAME.stdin, or none *)
  fun stdinOf n = let val f = dir ^ "/" ^ n ^ ".stdin" in if exists f then f else "" end

  (* where a run of src, its output named o', runs: for a test with a line
     `; files: own`, which writes files where it runs, a directory of its
     own, which no other run shares; for any other, here. With its
     arguments: in such a directory, a path that names a file of the tree
     taken from the root. *)
  fun whereRuns (src, o', args) =
    if List.exists (fn l => l = "; files: own") (lines (read src)) then
      let val d = fromRoot (o' ^ ".d")
      in mkdirs d; (SOME d, List.map (fn a => if not (String.isPrefix "-" a) andalso exists a then fromRoot a else a) args) end
    else (NONE, args)

  (* the reason a run test is the interpreter's alone, if it is *)
  fun interpreterOnly src =
    Option.map (fn l => String.extract (l, size "; vm: no:", NONE))
               (List.find (String.isPrefix "; vm: no:") (lines (read src)))

  (* the run test src compiled through Mid and run on the VMs, each way
     printing its .expected and ending as its .exitcode says *)
  (* the ways a run test runs on the VMs: by default the register VM
     interpreted and at tier 2, and the stack VM; for a line `; ways: E1`,
     E1's forty-five, twelve modes of the register VM and three of the stack
     VM at each level (results/E1/run.sh) *)
  val defaultWays = ([("interpreted", ["--jit=off"]), ("tier2", ["--jit=all", "--jit-tier=2"])], [("stack", [])])
  val e1Ways =
    ([("plain", []), ("interpreted", ["--jit=off"]), ("baseline", ["--jit=baseline", "--jit-calls=1", "--jit-work=1"]),
      ("all", ["--jit=all"]), ("tier2", ["--jit=all", "--jit-tier=2"]), ("tier2checked", ["--jit=all", "--jit-tier=2", "--checked"]),
      ("tier2odd", ["--jit=all", "--jit-only=odd", "--jit-tier=2"]),
      ("jitstress", ["--jit=baseline", "--jit-calls=1", "--jit-work=1", "--jit-stress=5"]),
      ("jitstress2", ["--jit=all", "--jit-tier=2", "--jit-stress=3"]), ("deopt1", ["--jit=all", "--jit-tier=2", "--deopt-stress=1"]),
      ("deopt7", ["--jit=all", "--jit-tier=2", "--deopt-stress=7"]),
      ("gcstress", ["--gc-stress", "3", "--gc-verify", "--jit=all", "--jit-tier=2"])],
     [("stack", []), ("stackchecked", ["--checked"]), ("stackgcstress", ["--gc-stress", "3", "--gc-verify"])])
  fun hasE1Ways src = List.exists (fn l => l = "; ways: E1") (lines (read src))

  fun vmOne (src, family, ways) = vmAt (src, family, ways, ["O0", "O1", "O2"], ["O0", "O1", "O2"])
  (* make check's runs (the roadmap's D56 and the lead's ruling 45): -O0
     and -O2 on the register engine; nightly's the rest, -O1 on it and every
     level on the stack's *)
  and vmCheck src = vmAt (src, "vm", defaultWays, ["O0", "O2"], [])
  and vmRest src = vmAt (src, "vm-rest", defaultWays, ["O1"], ["O0", "O1", "O2"])
  and vmAt (src, family, (regWays, stackWays), regLevels, stackLevels) =
    let
      val n = nameOf src
      (* each family its own directory: the three ways and the forty-five of
         one program run at once in a run, and share every name of a file *)
      val outDir = run ^ "/hs-core/" ^ family
      val () = mkdirs outDir
      fun f ext = outDir ^ "/" ^ n ^ ext
      val expected = read (dir ^ "/" ^ n ^ ".expected")
      val want = wanted n
      val flags = case marker src of SOME ("run", flags) => String.tokens Char.isSpace flags | _ => []
      fun one (level, target, runs) =
        let
          val rbc = f ("." ^ level ^ "." ^ target ^ ".rbc")
          val code = exec {cmd = [rhc, "--lint=3", "-" ^ level, "--target=" ^ target] @ flags @ ["--read-core", src, "-o", rbc],
                           dir = NONE, stdin = "", stdout = f ".compile", stderr = f ".compile", timeout = 600}
          fun runOn (vm, vmFlags, way) =
            let
              val o' = f ("." ^ level ^ "." ^ target ^ "." ^ way)
              val (here, args) = whereRuns (src, o', ["--stack-size", "268435456"] @ vmFlags @ [rbc])
              val status = exec {cmd = vm :: args, dir = here, stdin = stdinOf n,
                                 stdout = o' ^ ".out", stderr = o' ^ ".err", timeout = 120}
              val ends = if want = 1 then status <> 0 else status = want
            in
              case judgeRun (read (o' ^ ".out"), expected) of
                SOME why => fail ("hs.core.vm." ^ n ^ ": at -" ^ level ^ " on " ^ target ^ " (" ^ way ^ "): " ^ why ^ ": "
                                  ^ firstLine (o' ^ ".out") ^ " / " ^ firstLine (o' ^ ".err"))
              | NONE => if ends then ()
                        else fail ("hs.core.vm." ^ n ^ ": at -" ^ level ^ " on " ^ target ^ " (" ^ way ^ ") status "
                                   ^ Int.toString status ^ " where " ^ Int.toString want ^ " is wanted: " ^ firstLine (o' ^ ".err"))
            end
        in
          if code <> 0 then fail ("hs.core.vm." ^ n ^ ": -" ^ level ^ " to " ^ target ^ " did not compile: " ^ firstLine (f ".compile"))
          else List.app runOn runs
        end
    in
      List.app (fn level => one (level, "registers", List.map (fn (w, fl) => ("bin/runevm", fl, w)) regWays)) regLevels;
      List.app (fn level => one (level, "stack", List.map (fn (w, fl) => ("bin/runevm-stack", fl, w)) stackWays)) stackLevels
    end

  (* the two size files of a `; KEY: SIZE1 SIZE2` line of src *)
  fun sizes (key, src) =
    case List.find (String.isPrefix ("; " ^ key ^ ":")) (lines (read src)) of
      SOME l => (case String.tokens Char.isSpace (String.extract (l, size key + 3, NONE)) of
                   [a, b] => SOME (dir ^ "/" ^ a, dir ^ "/" ^ b)
                 | _ => NONE)
    | NONE => NONE

  (* src with the size file sz compiled to rbc at the flags *)
  fun compileAt (n, src, sz, flags, rbc, log) =
    exec {cmd = [rhc] @ flags @ ["--read-core", dir ^ "/lib/base.core", "--read-core", sz, "--read-core", src, "-o", rbc],
          dir = NONE, stdin = "", stdout = log, stderr = log, timeout = 600} = 0

  (* what the stderr of a VM's run says after key, a number *)
  fun after (key, f) =
    let val at = #2 (Substring.position key (Substring.full (read f)))
    in if Substring.isEmpty at then NONE
       else Int.fromString (Substring.string (Substring.takel Char.isDigit (Substring.triml (size key) at))) end

  fun residency src =
    let
      val n = nameOf src
      val outDir = run ^ "/hs-core/residency"
      val () = mkdirs outDir
      fun f ext = outDir ^ "/" ^ n ^ ext
      val stress = ["--nursery", "0", "--old-space", "copy", "--gc-stress", "1", "--stats"]
      fun live (rbc, way, vmFlags, tag) =
        let val o' = f ("." ^ tag ^ "." ^ way)
            val _ = exec {cmd = ["bin/runevm"] @ vmFlags @ stress @ [rbc], dir = NONE, stdin = "", stdout = o' ^ ".out",
                          stderr = o' ^ ".err", timeout = 600}
        in after ("max live ", o' ^ ".err") end
    in
      case sizes ("residency", src) of
        NONE => fail ("hs.core.residency." ^ n ^ ": no line ; residency: SIZE1 SIZE2")
      | SOME (a, b) =>
          List.app (fn level =>
                      let
                        val ra = f ("." ^ level ^ ".a.rbc")
                        val rb = f ("." ^ level ^ ".b.rbc")
                      in
                        if not (compileAt (n, src, a, ["-" ^ level], ra, f ".compile")
                                andalso compileAt (n, src, b, ["-" ^ level], rb, f ".compile"))
                        then fail ("hs.core.residency." ^ n ^ ": -" ^ level ^ " did not compile: " ^ firstLine (f ".compile"))
                        else
                          List.app (fn (way, vmFlags) =>
                                      case (live (ra, way, vmFlags, level ^ ".a"), live (rb, way, vmFlags, level ^ ".b")) of
                                        (SOME x, SOME y) =>
                                          if x = y then ()
                                          else fail ("hs.core.residency." ^ n ^ ": at -" ^ level ^ " (" ^ way ^ ") the most live is "
                                                     ^ Int.toString x ^ " at the first size and " ^ Int.toString y ^ " at the second")
                                      | _ => fail ("hs.core.residency." ^ n ^ ": at -" ^ level ^ " (" ^ way ^ ") no most live in --stats"))
                                   [("interpreted", ["--jit=off"]), ("tier2", ["--jit=all", "--jit-tier=2"])]
                      end)
                   ["O0", "O2"]
    end

  fun budget src =
    let
      val n = nameOf src
      val outDir = run ^ "/hs-core/budget"
      val () = mkdirs outDir
      fun f ext = outDir ^ "/" ^ n ^ ext
      fun count (rbc, tag) =
        let val o' = f ("." ^ tag)
            val _ = exec {cmd = ["bin/runevm", "--count", rbc], dir = NONE, stdin = "", stdout = o' ^ ".out", stderr = o' ^ ".err",
                          timeout = 600}
        in after ("count: ", o' ^ ".err") end
    in
      case sizes ("budget", src) of
        NONE => fail ("hs.core.budget." ^ n ^ ": no line ; budget: SIZE1 SIZE2")
      | SOME (a, b) =>
          List.app (fn level =>
                      let
                        val ra = f ("." ^ level ^ ".a.rbc")
                        val rb = f ("." ^ level ^ ".b.rbc")
                      in
                        if not (compileAt (n, src, a, ["-" ^ level], ra, f ".compile")
                                andalso compileAt (n, src, b, ["-" ^ level], rb, f ".compile"))
                        then fail ("hs.core.budget." ^ n ^ ": -" ^ level ^ " did not compile: " ^ firstLine (f ".compile"))
                        else
                          case (count (ra, level ^ ".a"), count (rb, level ^ ".b")) of
                            (SOME x, SOME y) =>
                              if 10 * y <= 22 * x then ()
                              else fail ("hs.core.budget." ^ n ^ ": at -" ^ level ^ " " ^ Int.toString y ^ " instructions at the second size, "
                                         ^ "more than 2.2 times the " ^ Int.toString x ^ " at the first: a lost share")
                          | _ => fail ("hs.core.budget." ^ n ^ ": at -" ^ level ^ " no count")
                      end)
                   ["O0", "O1", "O2"]
    end

  fun one src =
    let
      val n = nameOf src
      val outDir = run ^ "/hs-core"
      val () = mkdirs outDir
      fun f ext = outDir ^ "/" ^ n ^ ext
      val expected = dir ^ "/" ^ n ^ ".expected"
      fun rhcRun flags =
        let val (here, args) = whereRuns (src, f "", ["--lint=3"] @ flags @ ["--read-core", src])
        in exec {cmd = rhc :: args, dir = here, stdin = stdinOf n, stdout = f ".out", stderr = f ".err", timeout = 600} end
    in
      case marker src of
        SOME ("refuse", both) =>
          let
            val (flags, msg) = case String.fields (fn c => c = #"|") both of
                                 [fl, m] => (String.tokens Char.isSpace fl, String.extract (m, if String.isPrefix " " m then 1 else 0, NONE))
                               | _ => ([], both)
            val status = exec {cmd = [rhc, "--lint=2"] @ flags @ ["--read-core", src, "-o", f ".rbc"], dir = NONE, stdin = "",
                               stdout = f ".out", stderr = f ".err", timeout = 600}
          in
            if status = 0 then fail ("hs.core." ^ n ^ ": compiled, where it should stop with: " ^ msg)
            else if contains (f ".err", msg) then ()
            else fail ("hs.core." ^ n ^ ": stopped with: " ^ firstLine (f ".err"))
          end
      | SOME ("forces", rest) =>
          (* the dump of Core to Mid, its thunk_force nodes counted *)
          (case String.tokens Char.isSpace rest of
             want :: flags =>
               let
                 val status = exec {cmd = [rhc, "--lint=2"] @ flags @ ["--dump-after=coretomid", "--read-core", src, "-o", f ".rbc"],
                                    dir = NONE, stdin = "", stdout = f ".out", stderr = f ".err", timeout = 600}
                 fun count (text, k) =
                   let val (_, rest) = Substring.position "(prim thunk_force " text
                   in if Substring.isEmpty rest then k else count (Substring.triml 1 rest, k + 1) end
                 val found = count (Substring.full (read (f ".out")), 0)
               in
                 if status <> 0 then fail ("hs.core." ^ n ^ ": did not compile: " ^ firstLine (f ".err"))
                 else if SOME found = Int.fromString want then ()
                 else fail ("hs.core." ^ n ^ ": " ^ Int.toString found ^ " thunk_force in Mid, where Core has " ^ want ^ " forces")
               end
           | [] => fail ("hs.core." ^ n ^ ": ; forces: says no number"))
      | SOME ("fail", msg) =>
          if rhcRun [] = 0 then fail ("hs.core." ^ n ^ ": accepted, where it should stop with: " ^ msg)
          else if contains (f ".err", msg) then ()
          else fail ("hs.core." ^ n ^ ": stopped with: " ^ firstLine (f ".err"))
      | SOME (kind, flags) =>
          let
            val status = rhcRun (String.tokens Char.isSpace flags)
            val want = wanted n
          in
            if status <> want then
              fail ("hs.core." ^ n ^ ": status " ^ Int.toString status ^ " where " ^ Int.toString want ^ " is wanted: "
                    ^ firstLine (f ".err"))
            else if accepting andalso not (same (f ".out", expected)) then
              (write (expected, read (f ".out")); say ("ACCEPTED " ^ expected ^ "\n"))
            else if kind = "run" then
              (case judgeRun (read (f ".out"), read expected) of
                 NONE => ()
               | SOME why => fail ("hs.core." ^ n ^ ": " ^ why ^ ": " ^ difference (expected, f ".out")))
            else if same (f ".out", expected) then ()
            else fail ("hs.core." ^ n ^ ": the dump differs from " ^ expected ^ ": " ^ difference (expected, f ".out"))
          end
      | NONE => fail ("hs.core." ^ n ^ ": its first line is no ; run:, ; dump:, ; forces:, ; fail: or ; refuse:")
    end

  (* every rule of CoreLint has its fault, lint-RULE.core, which names it;
     every lint- file is a rule's *)
  fun rules () =
    let
      val outDir = run ^ "/hs-core"
      val () = mkdirs outDir
      val listed = outDir ^ "/rules.out"
      val status = exec {cmd = [rhc, "--lint-rules"], dir = NONE, stdin = "", stdout = listed, stderr = listed, timeout = 60}
      val names = lines (read listed)
      val faults = List.filter (String.isPrefix "lint-") (List.map nameOf (glob (dir, ".core")))
      fun named r = "lint-" ^ r
    in
      if status <> 0 orelse null names then fail ("hs.core.@rules: rhc --lint-rules: " ^ firstLine listed)
      else
        (List.app (fn r =>
                     if not (List.exists (fn x => x = named r) faults) then fail ("hs.core.@rules: the rule " ^ r ^ " has no fault, " ^ dir ^ "/lint-" ^ r ^ ".core")
                     else case marker (dir ^ "/" ^ named r ^ ".core") of
                            SOME ("fail", msg) =>
                              if String.isPrefix ("[" ^ r ^ "]") msg then ()
                              else fail ("hs.core.@rules: " ^ named r ^ ".core is not refused by [" ^ r ^ "]")
                          | _ => fail ("hs.core.@rules: " ^ named r ^ ".core is no ; fail: test"))
                  names;
         List.app (fn x => if List.exists (fn r => named r = x orelse String.isPrefix (named r ^ "-") x) names then ()
                           else fail ("hs.core.@rules: " ^ x ^ ".core is the fault of no rule"))
                  faults)
    end

  (* programs of the generator, seeds 1 to n: each passes CoreLint at level
     3 and runs to a value or to the bottom it may hold, never further *)
  fun generated n =
    let
      val outDir = run ^ "/hs-core/generated"
      val () = mkdirs outDir
      fun seed s =
        let
          val src = outDir ^ "/" ^ Int.toString s ^ ".core"
          fun f ext = outDir ^ "/" ^ Int.toString s ^ ext
        in
          if exec {cmd = [rhc, "--generate-core=" ^ Int.toString s], dir = NONE, stdin = "", stdout = src, stderr = f ".gerr",
                   timeout = 60} <> 0
          then fail ("hs.core.@generated: seed " ^ Int.toString s ^ ": no program: " ^ firstLine (f ".gerr"))
          else
            let val status = exec {cmd = [rhc, "--lint=3", "--steps=5000000", "--read-core", src], dir = NONE, stdin = "",
                                   stdout = f ".out", stderr = f ".err", timeout = 120}
            in
              if not (status = 0 andalso read (f ".err") = "" orelse
                      status = 1 andalso read (f ".err") = "rhc: bottom: ErrorCall: bottom\n")
              then fail ("hs.core.@generated: seed " ^ Int.toString s ^ ": status " ^ Int.toString status ^ ": "
                         ^ firstLine (f ".err") ^ " (" ^ src ^ ")")
              (* the same program through Mid on the VM: what the interpreter
                 printed, and a bottom where it ended in one *)
              else if exec {cmd = [rhc, "--lint=2", "--read-core", src, "-o", f ".rbc"], dir = NONE, stdin = "",
                            stdout = f ".compile", stderr = f ".compile", timeout = 300} <> 0
              then fail ("hs.core.@generated: seed " ^ Int.toString s ^ ": no bytecode: " ^ firstLine (f ".compile"))
              else
                let val vm = exec {cmd = ["bin/runevm", f ".rbc"], dir = NONE, stdin = "", stdout = f ".vm.out",
                                   stderr = f ".vm.err", timeout = 120}
                in
                  if read (f ".vm.out") <> read (f ".out") then
                    fail ("hs.core.@generated: seed " ^ Int.toString s ^ ": the VM printed " ^ firstLine (f ".vm.out")
                          ^ " where the interpreter printed " ^ firstLine (f ".out") ^ " (" ^ src ^ ")")
                  else if (vm = 0) <> (status = 0) then
                    fail ("hs.core.@generated: seed " ^ Int.toString s ^ ": status " ^ Int.toString vm ^ " on the VM, "
                          ^ Int.toString status ^ " on the interpreter (" ^ src ^ ")")
                  else ()
                end
            end
        end
      fun go s = if s > n then () else (seed s; go (s + 1))
    in go 1 end

  (* the judge of a run holds a silent one a failure, and a right one not *)
  fun silent () =
    (case judgeRun ("", "") of
       SOME _ => ()
     | NONE => fail "hs.core.@silent: a run that printed nothing passed";
     case judgeRun ("1\n", "1\n") of
       NONE => ()
     | SOME why => fail ("hs.core.@silent: a right run failed: " ^ why))

  fun command args =
    case args of
      ["hs-core-one", src] => SOME (fn () => one src)
    | ["hs-core-vm", src] => SOME (fn () => vmCheck src)
    | ["hs-core-vm-rest", src] => SOME (fn () => vmRest src)
    | ["hs-core-vm45", src] => SOME (fn () => vmOne (src, "vm45", e1Ways))
    | ["hs-core-residency", src] => SOME (fn () => residency src)
    | ["hs-core-budget", src] => SOME (fn () => budget src)
    | ["hs-core-rules"] => SOME rules
    | ["hs-core-generated", n] => SOME (fn () => generated (getOpt (Int.fromString n, 16)))
    | ["hs-core-silent"] => SOME silent
    | _ => NONE

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:rhc.build", "covers:tests/hs/core/*",
                "covers:tests/runner/hscore.sml"]
  (* E1's forty-five ways of E1's programs, nightly (D56: three ways of the
     run set in make check, the rest nightly) *)
  fun nightly () =
    tagged (["nightly", "test-rhc"] @ covers)
      (Test.describe "hs/core"
         (List.mapPartial (fn s => if hasE1Ways s andalso not (isSome (interpreterOnly s))
                                   then SOME (Tools.job ("vm45/" ^ nameOf s, ["hs-core-vm45", s], [], 500, 3600)) else NONE)
                          (glob (dir, ".core"))
          @ List.mapPartial (fn s => case (marker s, interpreterOnly s) of
                                       (SOME ("run", _), NONE) => SOME (Tools.job ("vm-rest/" ^ nameOf s, ["hs-core-vm-rest", s], [], 500, 1800))
                                     | _ => NONE)
                            (glob (dir, ".core"))))
  fun tree () =
    Test.describe "" [nightly (), tagged (["check", "test-rhc"] @ covers)
      (Test.describe "hs/core"
         (List.map (fn s => Tools.job (nameOf s, ["hs-core-one", s], [], 300, 600)) (glob (dir, ".core"))
          @ List.mapPartial (fn s => case (marker s, interpreterOnly s) of
                                       (SOME ("run", _), NONE) => SOME (Tools.job ("vm/" ^ nameOf s, ["hs-core-vm", s], [], 500, 1800))
                                     | _ => NONE)
                            (glob (dir, ".core"))
          @ List.mapPartial (fn s => case (sizes ("residency", s), interpreterOnly s) of
                                       (SOME _, NONE) => SOME (Tools.job ("residency/" ^ nameOf s, ["hs-core-residency", s], [], 500, 1800))
                                     | _ => NONE)
                            (glob (dir, ".core"))
          @ List.mapPartial (fn s => case (sizes ("budget", s), interpreterOnly s) of
                                       (SOME _, NONE) => SOME (Tools.job ("budget/" ^ nameOf s, ["hs-core-budget", s], [], 500, 1800))
                                     | _ => NONE)
                            (glob (dir, ".core"))
          @ [Tools.job ("@rules", ["hs-core-rules"], [], 100, 120),
             Tools.job ("@generated", ["hs-core-generated", "32"], [], 300, 1200),
             Tools.job ("@silent", ["hs-core-silent"], [], 100, 60)]))]
end
