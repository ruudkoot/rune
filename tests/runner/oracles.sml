(* The differential checks as oracles (docs/plans/unit-testing.md, M9;
   docs/testing.md, The three oracles): "counts equal" and "bytes equal",
   compared across ways, levels, builds and hosts. Each was a script of
   scripts/ that ran a check on every program N at a time and then a few
   checks of its own; each program is now a job of the runner, which runs
   a command of bin/rune-test (`bin/rune-test levels-one PROGRAM`, ...) that
   prints a line FAIL for what it finds, and each check of its own a job.

   - levels: every program of tests/lang and tests/perf compiled to both
     bytecodes at -O0 and -O2, whole and of its units' Mid, and to the
     register bytecode in units linked by Link, with the lint, must print,
     err and exit the same, the register bytecode's at tier 2 of the JIT
     too, and the register bytecode's at -O2 and in units must be the same
     bytes as at level 0, its unit files and their bases too
     (check-levels.sh);
   - register: compiled to both bytecodes, runevm-stack and runtime/register
     must allocate the same; the compiler on runtime/register must make the
     bytes it makes on runevm-stack; the primitives must print the same; and
     the dead registers must go at every tier (check-register.sh);
   - jit: every program, interpreted and under seven modes of the JIT, must
     print, count and err the same, as must every instruction, the fatal
     errors and the compiler compiling itself; and every instruction must
     occur in some program; a run that did not start, or a program that
     prints nothing where it is expected to print, fails, and so does a
     probe that does not print what it should (check-jit.sh);
   - units: whole, of units at -O0, -O1 and -O2, through the cache, from
     it, relinked and loaded, the same bytes and the same runs, each
     compiled with the program's .cargs after the level (check-units.sh);
   - positions: every instruction's position names a line that exists
     (check-positions.sh);
   - cross: every program, the compiler, runedoc and runeopt compiled by
     every host's build to the same bytes; runedoc's and runeopt's builds
     printing the same (check-cross.sh, check-doc-cross.sh,
     check-opt-cross.sh);
   - reproducible: the compiler built in units and whole, without the
     cache, through it cold and warm, by one process and with -j, and from
     a copy of its sources, the same bytes (check-reproducible.sh);
   - bootstrap: the compiler compiled by itself, the bytes of bin/rune.rbc
     and bin/rune.stack.rbc (make bootstrap).

   A program of tests/lang runs in a directory of its own, with tests/out
   and tests/lang in it, so that two checks that run one program at once do
   not write one image. *)
structure Oracles =
struct
  open Sh

  (* Count comparisons use one arithmetic backend across every engine.
     tests/intinf checks GMP and forced SML separately. *)
  fun exec args = execEnv (setEnv ("RUNEVM_INTINF", "sml")) args

  val langPerf = glob ("tests/lang", ".sml") @ glob ("tests/perf", ".sml")
  fun base src = String.substring (src, 0, size src - 4)
  fun name src = if String.isPrefix "examples/" src then ExampleProjects.name src else basename src
  (* run-tests.sh's siblings: the words of .cargs, .args, .vmargs, and the
     file of .stdin *)
  fun sib (b, ext) = words (b ^ ext)
  fun stdinOf b = if exists (b ^ ".stdin") then fromRoot (b ^ ".stdin") else ""
  fun sourceArguments source=case ExampleProjects.find source of
      SOME project=>ExampleProjects.arguments project
    | NONE=>
      let val first=case String.fields(fn c=>c= #"\n")(read source) of line::_=>line | []=>""
          val libraries=if String.isPrefix "(* libraries: " first andalso String.isSuffix " *)" first then
            List.concat(List.map(fn library=>["--library",library])
              (String.tokens Char.isSpace(String.substring(first,14,size first-17)))) else []
      in libraries @ sib(base source,".cargs") @ [source] end
  (* the files of a tool's build, as scripts/build-files.sh lists them *)
  fun buildFiles tool =
    let val f = OS.FileSys.tmpName ()
    in
      ignore (exec {cmd = ["/bin/sh", "scripts/build-files.sh", tool ^ ".build"], dir = NONE, stdin = "", stdout = f, stderr = "",
                    timeout = 0});
      lines (read f) before OS.FileSys.remove f
    end
  fun toolSrcs tool =
    "build/config.sml" :: buildFiles tool
    @ [case tool of "rune" => "src/main/rune-main.sml" | "runedoc" => "src/main/runedoc-rune-main.sml" | _ => "src/main/runeopt-rune-main.sml"]
  fun bootSrcs () = toolSrcs "rune"
  (* the VM of the JIT's checks: bin/runevm, or another (portability's) *)
  fun jitVm () = env ("JIT_VM", "bin/runevm")
  (* the directory of the JIT's checks on a VM: jit for bin/runevm, and one
     of each other's name, so that two VMs' checks run at once *)
  fun jitDir () = run ^ (if jitVm () = "bin/runevm" then "/jit" else "/jit-" ^ OS.Path.file (jitVm ()))

  (* ---- levels *)
  (* each target: its compiler, its checks, its builds, those compiled again
     at level 0 to compare the bytes, its VM, and the ways each build is
     run. The stack bytecode's builds check Mid's text against itself too;
     the register bytecode's, the default, are built in units linked by
     Link as well, and at -O2 and in units compared with the compile at
     level 0 (what more costs: linting roadmap, M1 and M3). The compiler by
     its absolute path, as bin/rune-stack runs bin/rune: the library's
     files are named so in positions, which traces print *)
  val levelTargets =
    [("stack", "bin/rune-stack", ["--lint", "--mid-roundtrip"], ["O0", "O2", "U0", "U2"], [], "bin/runevm-stack",
      [("run", ["--checked"])]),
     ("registers", fromRoot "bin/rune", ["--lint"], ["O0", "O2", "U0", "U2", "UL"], ["O2", "UL"], "bin/runevm",
      [("run", ["--checked"]), ("tier2", ["--jit=all", "--jit-tier=2", "--checked"])])]
  fun levelsOne src =
    let
      val b = base src and n = name src
      val out = run ^ "/levels"
      val () = mkdirs out
      val cargs = sib (b, ".cargs")
      fun file (t, k, ext) = out ^ "/" ^ n ^ "." ^ t ^ "." ^ k ^ ext
      (* whole at -O0 and -O2, whole of its units' Mid, and in units linked
         by Link (UL), whose unit files, bases too, are kept to compare *)
      fun flags (t, k, lint) =
        case k of
          "O0" => ["-O0"]
        | "O2" => ["-O2"]
        | "U0" => ["--units", "--whole", "--no-cache", "-O0"]
        | "U2" => ["--units", "--whole", "--no-cache", "-O2"]
        | _ => ["--units", "-O1", "--cache-dir", file (t, k, if lint then ".cache" else ".plain.cache"),
                "--emit-units", file (t, k, if lint then ".units" else ".plain.units")]
      fun clear (t, k) =
        List.app (fn ext => rmTree (file (t, k, ext))) [".cache", ".plain.cache", ".units", ".plain.units"]
      (* the unit files a build in units wrote, but the list of their paths *)
      fun unitFiles d = sort (List.filter (fn f => f <> "units") (if isDir d then entries d else []))
      fun sameUnits (a, c) =
        let val fs = unitFiles a
        in fs = unitFiles c andalso List.all (fn f => same (a ^ "/" ^ f, c ^ "/" ^ f)) fs end
      (* each build with the target's checks, and where it says so again
         at level 0 (RUNE_LINT empty), which must be the same bytes: no check
         changes what the compiler makes *)
      fun compile (t, rune, checks, compares) [] = true
        | compile (t, rune, checks, compares) (k :: rest) =
            let
              val compared = List.exists (fn c => c = k) compares
              val () = clear (t, k)
              val linted =
                exec {cmd = [rune] @ flags (t, k, true) @ cargs @ checks @ [src, "-o", file (t, k, ".rbc")],
                      dir = NONE, stdin = "", stdout = "", stderr = file (t, k, ".cerr"), timeout = 0} = 0
              val plain =
                linted andalso
                (not compared orelse
                 execEnv (setEnv ("RUNE_LINT", "") o setEnv ("RUNEVM_INTINF", "sml"))
                         {cmd = [rune] @ flags (t, k, false) @ cargs @ [src, "-o", file (t, k, ".plain.rbc")],
                          dir = NONE, stdin = "", stdout = "", stderr = file (t, k, ".plain.cerr"), timeout = 0} = 0)
              val what = t ^ " " ^ String.concatWith " " (List.filter (fn w => not (String.isPrefix out w)) (flags (t, k, true) @ cargs))
              val ok =
                if not linted then (say ("FAIL levels." ^ n ^ ": " ^ what ^ ": " ^ firstLine (file (t, k, ".cerr")) ^ "\n"); false)
                else if not plain then
                  (say ("FAIL levels." ^ n ^ ": " ^ what ^ ", without the lint: " ^ firstLine (file (t, k, ".plain.cerr")) ^ "\n"); false)
                else if compared andalso not (same (file (t, k, ".rbc"), file (t, k, ".plain.rbc"))) then
                  (say ("FAIL levels." ^ n ^ ": " ^ what ^ ": the lint changes the bytes\n"); false)
                else if compared andalso k = "UL" andalso not (sameUnits (file (t, k, ".units"), file (t, k, ".plain.units"))) then
                  (say ("FAIL levels." ^ n ^ ": " ^ what ^ ": the lint changes a unit's file or its basis\n"); false)
                else true
            in
              clear (t, k);
              (OS.FileSys.remove (file (t, k, ".plain.rbc")) handle OS.SysErr _ => ());
              ok andalso compile (t, rune, checks, compares) rest
            end
    in
      if not (List.all (fn (t, rune, checks, builds, compares, _, _) => compile (t, rune, checks, compares) builds) levelTargets)
      then ()
      else
        let
          val dir = run ^ "/levels-run/" ^ n
          val () = scratch dir
          (* every build of each target run each of its ways, each compared
             with the stack's at -O0; but a build the same bytes as one
             before it of its target, whole of its units' Mid as whole most
             often, which would run as that one did *)
          fun earlier (k, x :: xs) = if x = k then [] else x :: earlier (k, xs)
            | earlier (_, []) = []
          fun distinct (t, builds, k) =
            not (List.exists (fn k' => same (file (t, k', ".rbc"), file (t, k, ".rbc"))) (earlier (k, builds)))
          val runs =
            List.concat (List.map (fn (t, _, _, builds, _, vm, ways) =>
                                     List.concat (List.map (fn k => if distinct (t, builds, k)
                                                                    then List.map (fn (w, vmflags) => (t, k, w, vm, vmflags)) ways
                                                                    else [])
                                                           builds))
                                  levelTargets)
          fun ran (t, k, w) = t ^ "." ^ k ^ "." ^ w
          val () = List.app (fn (t, k, w, vm, vmflags) =>
                               write (file (t, k, "." ^ w ^ ".code"),
                                      Int.toString (exec {cmd = [vm] @ vmflags @ sib (b, ".vmargs") @ [file (t, k, ".rbc")] @ sib (b, ".args"),
                                                          dir = SOME dir, stdin = stdinOf b, stdout = file (t, k, "." ^ w ^ ".out"),
                                                          stderr = file (t, k, "." ^ w ^ ".err"), timeout = 0}) ^ "\n"))
                            runs
          fun check [] = ()
            | check ((t, k, w, _, _) :: rest) =
                case List.find (fn part => not (same (file ("stack", "O0", ".run" ^ part), file (t, k, "." ^ w ^ part))))
                               [".out", ".err", ".code"] of
                  NONE => check rest
                | SOME part =>
                    say ("FAIL levels." ^ n ^ ": stack.O0.run and " ^ ran (t, k, w) ^ " differ (" ^ String.extract (part, 1, NONE) ^ ": "
                         ^ difference (file ("stack", "O0", ".run" ^ part), file (t, k, "." ^ w ^ part)) ^ ")\n")
        in
          check (List.tl runs)
        end
    end

  (* ---- register *)
  fun registerOne src =
    let
      val b = base src and n = name src
      (* the two directories' names have one length: CommandLine.name
         allocates as long a string *)
      val sides = [("stack", "--target=stack", "bin/runevm-stack"), ("regvm", "--target=registers", "bin/runevm")]
      fun file (side, ext) = run ^ "/register/" ^ side ^ "/" ^ n ^ ext
      fun compile [] = true
        | compile ((side, target, _) :: rest) =
            (mkdirs (run ^ "/register/" ^ side);
             if exec {cmd = ["bin/rune", target] @ sib (b, ".cargs") @ [src, "-o", file (side, ".rbc")], dir = NONE,
                      stdin = "", stdout = "", stderr = file (side, ".cerr"), timeout = 0} = 0
             then compile rest
             else (say ("FAIL new." ^ n ^ ": " ^ side ^ ": " ^ firstLine (file (side, ".cerr")) ^ "\n"); false))
    in
      if not (compile sides) then ()
      else
        let
          val dir = run ^ "/register-run/" ^ n
          val () = scratch dir
          fun alloc (side, _, vm) =
            (ignore (exec {cmd = [vm, "--count"] @ sib (b, ".vmargs") @ [file (side, ".rbc")] @ sib (b, ".args"),
                           dir = SOME dir, stdin = stdinOf b, stdout = "", stderr = file (side, ".err"), timeout = 0});
             (* the allocation: what the count says after its instructions *)
             case String.fields (fn c => c = #",") (countOf (file (side, ".err"))) of
               _ :: rest => String.concatWith "," rest
             | [] => "")
          val a = alloc (List.nth (sides, 0)) and b' = alloc (List.nth (sides, 1))
        in
          if a = b' then ()
          else say ("FAIL new." ^ n ^ ": runevm-stack and runtime/register allocate differently (" ^ a ^ " / " ^ b' ^ ")\n")
        end
    end

  (* the compiler on runtime/register makes the bytes it makes on runevm-stack *)
  fun registerBootstrap () =
    let
      val out = run ^ "/register"
      val () = mkdirs out
    in
      if exec {cmd = ["bin/rune", "--target=registers", "-o", out ^ "/rune.new.rbc"] @ bootSrcs (), dir = NONE, stdin = "",
               stdout = out ^ "/boot.err", stderr = out ^ "/boot.err", timeout = 0} <> 0
      then say ("FAIL new.bootstrap: rune --target=registers: " ^ firstLine (out ^ "/boot.err") ^ "\n")
      else if exec {cmd = ["bin/runevm-stack", "--heap-size", "67108864", "bin/rune.stack.rbc", "--lib", "lib", "-o",
                           out ^ "/by-stack.rbc"] @ bootSrcs (), dir = NONE, stdin = "", stdout = out ^ "/boot.err",
                    stderr = out ^ "/boot.err", timeout = 0} <> 0
              orelse exec {cmd = ["bin/runevm", "--heap-size", "67108864", out ^ "/rune.new.rbc", "--lib", "lib", "-o",
                                  out ^ "/by-new.rbc"] @ bootSrcs (), dir = NONE, stdin = "", stdout = out ^ "/boot.err",
                           stderr = out ^ "/boot.err", timeout = 0} <> 0
      then say ("FAIL new.bootstrap: the compiler did not compile itself: " ^ firstLine (out ^ "/boot.err") ^ "\n")
      else if same (out ^ "/by-stack.rbc", out ^ "/by-new.rbc") then ()
      else say "FAIL new.bootstrap: the compiler makes other bytes on runtime/register than on runevm-stack\n"
    end

  (* the primitives print the same on both *)
  fun registerPrims () =
    let
      val out = run ^ "/register"
      val () = mkdirs out
      fun c (target, rbc) = exec {cmd = ["bin/rune", target, "tests/opt/prims.sml", "-o", rbc], dir = NONE, stdin = "",
                                  stdout = out ^ "/prims.cerr", stderr = out ^ "/prims.cerr", timeout = 0} = 0
    in
      if not (c ("--target=stack", out ^ "/prims.rbc") andalso c ("--target=registers", out ^ "/prims.new.rbc"))
      then say ("FAIL new.prims: does not compile: " ^ firstLine (out ^ "/prims.cerr") ^ "\n")
      else
        (ignore (exec {cmd = ["bin/runevm-stack", out ^ "/prims.rbc"], dir = NONE, stdin = "", stdout = out ^ "/prims.stack.out",
                       stderr = out ^ "/prims.stack.out", timeout = 0});
         ignore (exec {cmd = ["bin/runevm", out ^ "/prims.new.rbc"], dir = NONE, stdin = "", stdout = out ^ "/prims.new.out",
                       stderr = out ^ "/prims.new.out", timeout = 0});
         if same (out ^ "/prims.stack.out", out ^ "/prims.new.out") then ()
         else say ("FAIL new.prims: the primitives print differently: "
                   ^ difference (out ^ "/prims.stack.out", out ^ "/prims.new.out") ^ "\n"))
    end

  (* a waiting frame's dead registers go, at every tier *)
  fun registerDeadRoots () =
    let
      val out = run ^ "/register"
      val () = mkdirs out
    in
      if exec {cmd = ["bin/rune", "--target=registers", "tests/register/dead-roots.sml", "-o", out ^ "/dead-roots.rbc"],
               dir = NONE, stdin = "", stdout = out ^ "/dead-roots.cerr", stderr = out ^ "/dead-roots.cerr", timeout = 0} <> 0
      then say ("FAIL new.dead-roots: does not compile: " ^ firstLine (out ^ "/dead-roots.cerr") ^ "\n")
      else
        List.app (fn mode =>
                    let val f = out ^ "/dead-roots." ^ mode ^ ".out"
                    in
                      ignore (exec {cmd = ["bin/runevm", "--jit=" ^ mode, out ^ "/dead-roots.rbc"], dir = NONE, stdin = "",
                                    stdout = f, stderr = f, timeout = 0});
                      if same (f, "tests/register/dead-roots.expected") then ()
                      else say ("FAIL new.dead-roots: --jit=" ^ mode ^ ": " ^ difference ("tests/register/dead-roots.expected", f) ^ "\n")
                    end)
                 ["off", "baseline", "opt", "all"]
    end

  (* the check of the register code (RegVerify; docs/plans/correctness/linting.md,
     M8) on tests/register/regverify.sml: clean as it is, and each of the
     eleven corruptions its switch makes (RUNE_REGVERIFY_INJECT) refused
     with a message of its own, which the VM's loader lets through all but
     the first of (docs/plans/correctness/vm-verifier.md) *)
  val regverifyKinds =
    [("rep-write", "CON0 writes con0 into register"),
     ("rep-read", "argument 0 of int_add: register"),
     ("unset", "which is not set on every way here"),
     ("noresult", "RESULT is due after CALLK"),
     ("arity", "arguments, whose arity is"),
     ("catch", "a handler's block that does not begin with CATCH"),
     ("switch", "where a test says"),
     ("env", "of a function whose closures capture"),
     ("pop", "is reached with"),
     ("image", "the image primitive posix_fork in PRIM"),
     ("closure", ", of arity 2")]
  fun regverifyOne kind =
    let
      val out = run ^ "/regverify"
      val () = mkdirs out
      val err = out ^ "/" ^ kind ^ ".err"
      val inject = if kind = "clean" then (fn e => e) else setEnv ("RUNE_REGVERIFY_INJECT", kind)
      val status = execEnv (inject o setEnv ("RUNE_REGVERIFY", "1"))
                           {cmd = ["bin/rune", "tests/register/regverify.sml", "-o", out ^ "/" ^ kind ^ ".rbc"], dir = NONE,
                            stdin = "", stdout = err, stderr = err, timeout = 0}
      val text = read err
    in
      if kind = "clean" then (if status = 0 then () else say ("FAIL regverify.clean: does not compile: " ^ firstLine err ^ "\n"))
      else
        case List.find (fn (k, _) => k = kind) regverifyKinds of
          NONE => say ("FAIL regverify." ^ kind ^ ": no such corruption\n")
        | SOME (_, why) =>
            if String.isSubstring "no place found" text then say ("FAIL regverify." ^ kind ^ ": no place to corrupt\n")
            else if status = 0 then say ("FAIL regverify." ^ kind ^ ": not refused\n")
            else if String.isSubstring "regverify" text andalso String.isSubstring why text then ()
            else say ("FAIL regverify." ^ kind ^ ": refused for another reason: " ^ firstNonEmpty err ^ "\n")
    end

  (* the check of the stack code (StackCheck: the loader's checks and
     runeopt's RbcCheck, at level 2; docs/plans/correctness/linting.md,
     M10) on tests/opt/rbccheck.sml with the lint, whole and linked from
     units: clean as it is, and each corruption its switch makes
     (RUNE_RBCCHECK_INJECT) refused with a message of its own *)
  val rbccheckKinds =
    [("underflow", ("underflow", [], "the stack underflows at")),
     ("height", ("height", [], "the stack or the handlers differ on the paths into")),
     ("handler", ("handler", [], "POPHANDLER without a handler of the function")),
     ("jump-out", ("jump-out", [], "a jump leaves its function")),
     ("ret-handler", ("ret-handler", [], "a handler of the function is still installed")),
     ("local", ("local", [], "the loader refuses the stack code: bad operand for LOCAL")),
     ("link", ("jump-out", ["--units", "--no-cache"], "a jump leaves its function"))]
  fun rbccheckOne kind =
    let
      val out = run ^ "/rbccheck"
      val () = mkdirs out
      val err = out ^ "/" ^ kind ^ ".err"
      val (inject, flags, why) =
        case List.find (fn (k, _) => k = kind) rbccheckKinds of
          SOME (_, (k, flags, why)) => (setEnv ("RUNE_RBCCHECK_INJECT", k), flags, SOME why)
        | NONE => (fn e => e, if kind = "clean-units" then ["--units", "--no-cache"] else [], NONE)
      val status = execEnv (inject o setEnv ("RUNE_LINT", "2"))
                           {cmd = ["bin/rune", "--target=stack"] @ flags @ ["tests/opt/rbccheck.sml", "-o", out ^ "/" ^ kind ^ ".rbc"],
                            dir = NONE, stdin = "", stdout = err, stderr = err, timeout = 0}
      val text = read err
    in
      case why of
        NONE =>
          if kind <> "clean" andalso kind <> "clean-units" then say ("FAIL rbccheck." ^ kind ^ ": no such corruption\n")
          else if status = 0 then () else say ("FAIL rbccheck." ^ kind ^ ": does not compile: " ^ firstNonEmpty err ^ "\n")
      | SOME why =>
          if String.isSubstring "no place found" text then say ("FAIL rbccheck." ^ kind ^ ": no place to corrupt\n")
          else if status = 0 then say ("FAIL rbccheck." ^ kind ^ ": not refused\n")
          else if String.isSubstring "lint after rbccheck" text andalso String.isSubstring why text then ()
          else say ("FAIL rbccheck." ^ kind ^ ": refused for another reason: " ^ firstNonEmpty err ^ "\n")
    end

  (* ---- jit *)
  val jitModes =
    [("off", ["--jit=off"], ""), ("all", ["--jit=all"], "--jit=all"),
     ("odd", ["--jit=all", "--jit-only=odd"], "every other function compiled"),
     ("stress", ["--jit=baseline", "--jit-calls=1", "--jit-work=1", "--jit-stress=5"], "tiering up and invalidating (--jit-stress)"),
     ("opt", ["--jit=all", "--jit-tier=2"], "every function at tier 2 (--jit-tier=2)"),
     ("optodd", ["--jit=all", "--jit-only=odd", "--jit-tier=2"], "every other function at tier 2"),
     ("deopt", ["--jit=all", "--jit-tier=2", "--deopt-stress=1"],
      "leaving for the interpreter after every instruction (--deopt-stress=1)"),
     ("profile", ["--jit=all", "--jit-tier=2", "--jit-profile"], "tier 2 counting its calls and branches (--jit-profile)")]

  fun jitName src = String.translate (fn #"/" => "_" | c => str c) (base src)

  fun jitOne src =
    let
      val b = base src and n = jitName src
      val dir = jitDir () ^ "/" ^ n
      val () = mkdirs dir
      fun f x = dir ^ "/" ^ x
    in
      if exec {cmd = ["bin/rune"] @ sib (b, ".cargs") @ [src, "-o", f "prog.rbc"], dir = NONE, stdin = "", stdout = "",
               stderr = f "cerr", timeout = 0} <> 0
      then say ("FAIL jit." ^ n ^ ": " ^ firstNonEmpty (f "cerr") ^ "\n")
      else
        let
          val _ = exec {cmd = [jitVm (), "--disasm", f "prog.rbc"], dir = NONE, stdin = "", stdout = f "disasm", stderr = "",
                        timeout = 0}
          val () =
            List.app (fn (mode, jit, _) =>
                        let
                          val code = exec {cmd = [jitVm (), "--count"] @ jit @ sib (b, ".vmargs") @ ["prog.rbc"] @ sib (b, ".args"),
                                           dir = SOME dir, stdin = stdinOf b, stdout = f ("stdout." ^ mode),
                                           stderr = f ("stderr." ^ mode), timeout = 600}
                        in
                          append (f ("stderr." ^ mode), "exit " ^ Int.toString code ^ "\n");
                          write (f ("count." ^ mode), countOf (f ("stderr." ^ mode)))
                        end)
                     jitModes
          (* nothing ran is no pass: a run that could not start, or nothing
             printed by a run that ends well where the program has an
             expected output (but one whose output is the restored image's,
             .restore; a program that writes files where it runs here stops,
             the same in every mode) *)
          fun exited (mode, k) = List.exists (fn l => l = "exit " ^ k) (lines (read (f ("stderr." ^ mode))))
          val unstarted = List.find (fn (mode, _, _) => exited (mode, "126") orelse exited (mode, "127")) jitModes
          val silent = size (read (b ^ ".expected")) > 0 andalso not (exists (b ^ ".restore"))
                       andalso size (read (f "stdout.off")) = 0 andalso exited ("off", "0")
        in
          case unstarted of
            SOME (mode, _, _) =>
              say ("FAIL jit." ^ n ^ ": the VM did not run with --jit=" ^ mode ^ ": " ^ firstLine (f ("stderr." ^ mode)) ^ "\n")
          | NONE =>
              if silent then say ("FAIL jit." ^ n ^ ": prints nothing interpreted, where " ^ b ^ ".expected is not empty\n")
              else
                List.app (fn (mode, _, what) =>
                            if mode = "off" then ()
                            else if not (same (f "stdout.off", f ("stdout." ^ mode))) then
                              say ("FAIL jit." ^ n ^ ": prints differently with " ^ what ^ ": " ^ difference (f "stdout.off", f ("stdout." ^ mode)) ^ "\n")
                            else if not (same (f "count.off", f ("count." ^ mode))) then
                              say ("FAIL jit." ^ n ^ ": counts " ^ read (f "count.off") ^ " interpreted, " ^ read (f ("count." ^ mode))
                                   ^ " with " ^ what ^ "\n")
                            else if not (same (f "stderr.off", f ("stderr." ^ mode))) then
                              say ("FAIL jit." ^ n ^ ": standard error differs with " ^ what ^ ": "
                                   ^ difference (f "stderr.off", f ("stderr." ^ mode)) ^ "\n")
                            else ())
                         jitModes
        end
    end

  (* the probe: one program, run as each of the others is, interpreted and
     at tier 2, prints what it is expected to, and the VM is one that can be
     run, so that runs that compare equal because nothing ran pass nothing
     (until performance M6 check-jit.sh took an absolute VM as relative, and
     its runs started nothing and compared equal) *)
  fun jitProbe () =
    let
      val probe = "tests/lang/basis.bool_ops"
      val dir = jitDir () ^ "/@probe"
      val () = mkdirs dir
      fun f x = dir ^ "/" ^ x
      val runnable = OS.FileSys.access (fromRoot (jitVm ()), [OS.FileSys.A_EXEC]) handle OS.SysErr _ => false
    in
      if not runnable then say ("FAIL jit.@probe: " ^ jitVm () ^ " is no VM that can be run\n")
      else if exec {cmd = ["bin/rune", probe ^ ".sml", "-o", f "prog.rbc"], dir = NONE, stdin = "", stdout = "",
                    stderr = f "cerr", timeout = 0} <> 0
      then say ("FAIL jit.@probe: " ^ probe ^ ".sml does not compile: " ^ firstNonEmpty (f "cerr") ^ "\n")
      else
        List.app (fn (mode, jit) =>
                    (ignore (exec {cmd = [jitVm ()] @ jit @ ["prog.rbc"], dir = SOME dir, stdin = "", stdout = f ("stdout." ^ mode),
                                   stderr = f ("stderr." ^ mode), timeout = 600});
                     if same (f ("stdout." ^ mode), probe ^ ".expected") then ()
                     else say ("FAIL jit.@probe: " ^ probe ^ ".sml does not print " ^ probe ^ ".expected with "
                               ^ String.concatWith " " jit ^ " under " ^ jitVm () ^ ": " ^ firstLine (f ("stderr." ^ mode)) ^ "\n")))
                 [("off", ["--jit=off"]), ("opt", ["--jit=all", "--jit-tier=2"])]
    end

  (* A register program in the independent fixture assembler's text. *)
  fun assemble (rasm, rbc) =
    ((write (rbc, BytecodeFixture.assemble {opdefs = "runtime/register/regs.def", primdefs = "runtime/prims.def", listing = rasm}); true)
     handle BytecodeFixture.Bad message => (say ("FAIL assembler: " ^ message ^ "\n"); false))

  fun jitEveryOpcode () =
    let
      val dir = jitDir () ^ "/every-opcode"
      val () = mkdirs dir
      fun f x = dir ^ "/" ^ x
      val modes = List.filter (fn (m, _, _) => List.exists (fn x => x = m) ["off", "all", "odd", "stress", "opt", "deopt"]) jitModes
    in
      if not (assemble ("tests/register/every-opcode.rasm", f "prog.rbc")) then say "FAIL jit.every-opcode: does not assemble\n"
      else
        (ignore (exec {cmd = [jitVm (), "--disasm", f "prog.rbc"], dir = NONE, stdin = "", stdout = f "disasm", stderr = "",
                       timeout = 0});
         List.app (fn (mode, jit, _) =>
                     append (f ("stderr." ^ mode),
                             "exit " ^ Int.toString (exec {cmd = [jitVm (), "--count"] @ jit @ [f "prog.rbc"], dir = NONE,
                                                           stdin = "", stdout = f ("stdout." ^ mode),
                                                           stderr = f ("stderr." ^ mode), timeout = 0}) ^ "\n"))
                  modes;
         case List.find (fn (mode, _, _) => mode <> "off" andalso not (same (f "stdout.off", f ("stdout." ^ mode))
                                                                      andalso same (f "stderr.off", f ("stderr." ^ mode)))) modes of
           SOME (mode, _, _) => say ("FAIL jit.every-opcode: differs with " ^ mode ^ "\n")
         | NONE => if List.exists (fn l => String.isPrefix "exit 0" l) (lines (read (f "stderr.off"))) then ()
                   else say "FAIL jit.every-opcode: does not exit with 0\n")
    end

  fun jitFatal which =
    let
      val dir = jitDir () ^ "/fatal-" ^ which
      val () = mkdirs dir
      fun f x = dir ^ "/" ^ x
      val modes = [("off", ["--jit=off"]), ("all", ["--jit=all"]), ("opt", ["--jit=all", "--jit-tier=2"])]
    in
      if not (assemble ("tests/register/fatal-" ^ which ^ ".rasm", f "prog.rbc")) then say ("FAIL jit.fatal-" ^ which ^ ": does not assemble\n")
      else
        (List.app (fn (mode, jit) =>
                     append (f ("stderr." ^ mode),
                             "exit " ^ Int.toString (exec {cmd = [jitVm (), "--checked"] @ jit @ [f "prog.rbc"], dir = NONE,
                                                           stdin = "", stdout = f ("stdout." ^ mode),
                                                           stderr = f ("stderr." ^ mode), timeout = 0}) ^ "\n"))
                  modes;
         if not (String.isSubstring "fatal error at pc" (read (f "stderr.off"))) then
           say ("FAIL jit.fatal-" ^ which ^ ": the interpreter does not stop with a fatal error\n")
         else ();
         List.app (fn (mode, _) =>
                     if mode = "off" orelse (same (f "stdout.off", f ("stdout." ^ mode)) andalso same (f "stderr.off", f ("stderr." ^ mode)))
                     then ()
                     else say ("FAIL jit.fatal-" ^ which ^ ": differs with " ^ mode ^ ": " ^ difference (f "stderr.off", f ("stderr." ^ mode)) ^ "\n"))
                  modes)
    end

  (* every instruction of the register set occurs in some program, so that
     every emitter runs: the disassemblies of this run's jit-one jobs and of
     every-opcode's *)
  fun jitEveryInstruction () =
    let
      val ops = List.mapPartial (fn l => if String.isPrefix "#" l then NONE
                                         else case String.tokens Char.isSpace l of x :: _ => SOME x | [] => NONE)
                                (lines (read "runtime/register/regs.def"))
      (* the instruction of a line `  N  OP ...` *)
      fun opOf l =
        let
          val s = Substring.dropl (fn c => c = #" ") (Substring.full l)
          val s = Substring.dropl Char.isDigit s
        in
          if Substring.isPrefix "  " s
          then SOME (Substring.string (Substring.takel (fn c => Char.isAlphaNum c orelse c = #"_") (Substring.triml 2 s)))
          else NONE
        end
      val seen = List.concat (List.map (fn d => List.mapPartial opOf (lines (read (jitDir () ^ "/" ^ d ^ "/disasm"))))
                                       (entries (jitDir ())))
      val missing = List.filter (fn x => not (List.exists (fn y => y = x) seen)) ops
    in
      if null missing then ()
      else say ("FAIL jit.every-instruction: no program of tests/lang or tests/perf has " ^ String.concatWith " " missing ^ "\n")
    end

  (* the compiler as register bytecode compiling itself in a mode: each in a
     directory of a name of one length, with the same arguments, since
     they reach its counts *)
  val bootModes =
    [("1", "off", ["--jit=off"]), ("2", "all", ["--jit=all"]), ("3", "odd", ["--jit=all", "--jit-only=odd"]),
     ("4", "baseline", ["--jit=baseline"]), ("5", "opt", ["--jit=all", "--jit-tier=2"]),
     ("6", "deopt", ["--jit=all", "--jit-tier=2", "--deopt-stress=7"])]

  fun jitBootCompile () =
    let val out = jitDir () ^ "-boot"
    in
      mkdirs out;
      if exec {cmd = ["bin/rune", "-o", out ^ "/rune.rbc"] @ bootSrcs (), dir = NONE, stdin = "", stdout = out ^ "/cerr",
               stderr = out ^ "/cerr", timeout = 0} = 0 then ()
      else say ("FAIL jit.bootstrap: does not compile: " ^ firstLine (out ^ "/cerr") ^ "\n")
    end

  fun jitBootMode mode =
    case List.find (fn (_, m, _) => m = mode) bootModes of
      NONE => say ("FAIL jit.bootstrap: no mode " ^ mode ^ "\n")
    | SOME (d, _, jit) =>
        let
          val dir = jitDir () ^ "-boot/" ^ d
          val () = mkdirs dir
          val code = exec {cmd = [jitVm (), "--count"] @ jit @ ["--heap-size", "67108864", jitDir () ^ "-boot/rune.rbc", "--lib",
                                                                  root ^ "/lib", "-o", "compiled.rbc"] @ List.map fromRoot (bootSrcs ()),
                           dir = SOME dir, stdin = "", stdout = "", stderr = dir ^ "/stderr", timeout = 0}
        in append (dir ^ "/stderr", "exit " ^ Int.toString code ^ "\n") end

  fun jitBootCompare () =
    let
      fun f (d, x) = jitDir () ^ "-boot/" ^ d ^ "/" ^ x
    in
      List.app (fn (d, mode, _) =>
                  if d = "1" then ()
                  else if not (same (f ("1", "compiled.rbc"), f (d, "compiled.rbc"))) then
                    say ("FAIL jit.bootstrap: the compiler makes other bytes with --jit=" ^ mode ^ "\n")
                  else if not (same (f ("1", "stderr"), f (d, "stderr"))) then
                    say ("FAIL jit.bootstrap: counts or errs differently with " ^ mode ^ ": " ^ difference (f ("1", "stderr"), f (d, "stderr")) ^ "\n")
                  else ())
               bootModes
    end

  (* ---- units *)
  (* the programs whose units are not loaded: their traces and images name
     the program, and loading has no arguments *)
  val noLoad = ["tests/lang/rt.trace_frames", "tests/lang/rt.trace_inlined", "tests/lang/rt.save_restore_cross",
                "tests/lang/mod.functor.functions_trace"]

  fun unitsSetup (variant, rune) =
    let val out = run ^ "/" ^ variant
    in
      rmTree (out ^ "/cache"); mkdirs out;
      if exec {cmd = [rune, "tests/units/load.sml", "-o", out ^ "/load.rbc"], dir = NONE, stdin = "", stdout = out ^ "/load.cerr",
               stderr = out ^ "/load.cerr", timeout = 0} = 0 then ()
      else say "FAIL units: tests/units/load.sml does not compile\n"
    end

  fun unitsOne (variant, rune, vm, src) =
    let
      val b = base src and n = name src
      val out = run ^ "/" ^ variant
      fun f x = out ^ "/" ^ n ^ "." ^ x
      (* its .cargs for the compiler, after the level, as levels gives them *)
      val cargs = sib (b, ".cargs")
      fun c (k, flags) = exec {cmd = [rune] @ flags @ cargs @ ["--lint", src, "-o", f (k ^ ".rbc")], dir = NONE, stdin = "",
                               stdout = "", stderr = f (k ^ ".cerr"), timeout = 0} = 0
      fun failed (flags, k) = (say ("FAIL units." ^ n ^ ": " ^ String.concatWith " " flags ^ ": " ^ firstLine (f (k ^ ".cerr")) ^ "\n"); false)
      val cache = out ^ "/cache"
      val builds =
        [("units.O0", ["--units", "-O0", "--no-cache"]),
         ("units.O1", ["--units", "-O1", "--no-cache", "--emit-units", out ^ "/" ^ n ^ ".files"]),
         ("units.O2", ["--units", "-O2", "--cache-dir", cache]),
         ("cached.O1", ["--units", "-O1", "--cache-dir", cache, "--explain-rebuild"]),
         ("warm.O1", ["--units", "-O1", "--cache-dir", cache, "--explain-rebuild"])]
      fun all [] = true
        | all ((k, flags) :: rest) =
            ((if k = "units.O1" then rmTree (out ^ "/" ^ n ^ ".files") else ()); if c (k, flags) then all rest else failed (flags, k))
      fun compiledAgain k = List.exists (fn l => String.isPrefix "rune: compiled" l) (lines (read (f (k ^ ".cerr"))))
      fun runs () =
        let
          val dir = run ^ "/" ^ variant ^ "-run/" ^ n
          val () = scratch dir
          fun go k = write (f (k ^ ".code"),
                            Int.toString (exec {cmd = [vm, "--checked"] @ sib (b, ".vmargs") @ [f (k ^ ".rbc")] @ sib (b, ".args"),
                                                dir = SOME dir, stdin = stdinOf b, stdout = f (k ^ ".out"), stderr = f (k ^ ".err"),
                                                timeout = 0}) ^ "\n")
        in List.app go ["whole", "units.O0", "units.O1", "units.O2"]; dir end
    in
      (* a program that does not compile whole is tests/errors' *)
      if not (c ("whole", [])) then ()
      else if not (all builds) then ()
      else if not (same (f "units.O1.rbc", f "cached.O1.rbc")) then say ("FAIL units." ^ n ^ ": built through the cache, it differs\n")
      else if not (same (f "units.O1.rbc", f "warm.O1.rbc")) then say ("FAIL units." ^ n ^ ": built from the cache, it differs\n")
      else if compiledAgain "warm.O1" then say ("FAIL units." ^ n ^ ": built from the cache, it compiled a unit again\n")
      else if not (c ("mid.cold", ["--units", "--whole", "--cache-dir", cache, "--explain-rebuild"])) then
        ignore (failed (["--units", "--whole"], "mid.cold"))
      else if not (same (f "whole.rbc", f "mid.cold.rbc")) then say ("FAIL units." ^ n ^ ": whole of its units' Mid, it differs\n")
      else if not (c ("mid.warm", ["--units", "--whole", "--cache-dir", cache, "--explain-rebuild"])) then
        ignore (failed (["--units", "--whole"], "mid.warm"))
      else if compiledAgain "mid.warm" then say ("FAIL units." ^ n ^ ": whole from the cache, it compiled a unit again\n")
      else if exec {cmd = [rune, "-o", f "relinked.rbc"] @ words (out ^ "/" ^ n ^ ".files/units"), dir = NONE, stdin = "",
                    stdout = "", stderr = f "relinked.cerr", timeout = 0} <> 0 then
        say ("FAIL units." ^ n ^ ": its unit files do not link: " ^ firstLine (f "relinked.cerr") ^ "\n")
      else if not (same (f "relinked.rbc", f "units.O1.rbc")) then say ("FAIL units." ^ n ^ ": its unit files linked, it differs\n")
      else
        let
          val dir = runs ()
          val bad = List.find (fn (k, p) => not (same (f ("whole" ^ p), f (k ^ p))))
                              (List.concat (List.map (fn k => List.map (fn p => (k, p)) [".out", ".err", ".code"])
                                                     ["units.O0", "units.O1", "units.O2"]))
        in
          case bad of
            SOME (k, p) => say ("FAIL units." ^ n ^ ": whole and " ^ k ^ " differ (" ^ String.extract (p, 1, NONE) ^ ": "
                                ^ difference (f ("whole" ^ p), f (k ^ p)) ^ ")\n")
          | NONE =>
              if List.exists (fn x => x = b) noLoad orelse exists (b ^ ".args") orelse exists (b ^ ".vmargs") then ()
              else
                (write (f "loaded.code",
                        Int.toString (exec {cmd = [vm, "--checked", out ^ "/load.rbc"] @ words (out ^ "/" ^ n ^ ".files/units"),
                                            dir = SOME dir, stdin = stdinOf b, stdout = f "loaded.out", stderr = f "loaded.err",
                                            timeout = 0}) ^ "\n");
                 if same (f "loaded.out", f "units.O1.out") andalso same (f "loaded.code", f "units.O1.code") then ()
                 else say ("FAIL units." ^ n ^ ": its units loaded differ: " ^ difference (f "units.O1.out", f "loaded.out") ^ "\n"))
        end
    end

  (* ---- positions *)
  fun positionsOne src =
    let
      val n = name src
      val out = run ^ "/positions"
      val () = mkdirs (OS.Path.dir(out ^ "/" ^ n ^ ".rbc"))
    in
      (* a program that does not compile is tests/errors' *)
      if exec {cmd = ["bin/rune-stack", "--lib", "lib"] @ sourceArguments src @ ["-o", out ^ "/" ^ n ^ ".rbc"], dir = NONE,
               stdin = "", stdout = out ^ "/" ^ n ^ ".log", stderr = out ^ "/" ^ n ^ ".log", timeout = 0} <> 0 then
        (case ExampleProjects.find src of NONE=>() | SOME _=>say("FAIL " ^ n ^ ": example project did not compile\n"))
      else
        let
          val dis = out ^ "/" ^ n ^ ".disasm"
          val disassembled = exec {cmd = ["bin/runevm-stack", "--disasm", out ^ "/" ^ n ^ ".rbc"], dir = NONE, stdin = "", stdout = dis,
                                   stderr = "", timeout = 0}
          val ()=if disassembled=0 andalso size(read dis)>0 then () else say("FAIL " ^ n ^ ": no disassembly for position checks\n")
          (* the position of a line `...\t; FILE:LINE:COL` *)
          fun pos l =
            case List.rev (String.fields (fn c => c = #"\t") l) of
              last :: _ :: _ => if String.isPrefix "; " last then SOME (String.extract (last, 2, NONE)) else NONE
            | _ => NONE
          val ps = List.mapPartial (fn p => case String.fields (fn c => c = #":") p of
                                              file :: line :: _ => SOME (file, getOpt (Int.fromString line, 0))
                                            | _ => NONE)
                                   (List.mapPartial pos (lines (read dis)))
          val files = List.foldl (fn ((file, _), acc) => if List.exists (fn x => x = file) acc then acc else acc @ [file]) [] ps
        in
          List.app (fn file =>
                      let
                        val ls = List.map #2 (List.filter (fn (x, _) => x = file) ps)
                        val top = List.foldl Int.max 0 ls
                      in
                        if not (exists file) orelse isDir file then say ("FAIL " ^ n ^ ": a position names " ^ file ^ ", which is not a file\n")
                        else if List.exists (fn x => x < 1) ls then say ("FAIL " ^ n ^ ": a position in " ^ file ^ " is before its first line\n")
                        else if top > length (String.fields (fn c => c = #"\n") (read file)) - 1 then
                          say ("FAIL " ^ n ^ ": " ^ file ^ " has no line " ^ Int.toString top ^ "\n")
                        else ()
                      end)
                   files
        end
    end

  (* ---- cross: every host's build makes the same bytes *)
  val hostBuilds = ["mlton", "smlnj-legacy", "smlnj32", "smlnj-dev", "polyml", "mlkit"]
  fun builds tool = hostBuilds @ (if exists ("bin/" ^ tool ^ "-boot") then ["boot"] else [])

  (* A host's build that may fail a check now and then, where the fault is
     the host's and Rune's sources are not changed for one host
     (docs/building.md): tests/cross/deviations.txt, in the form of
     tests/lib/deviations.txt -- HOST | CHECK | HOST-FLAKY | reason, HOST a
     build of hostBuilds (or boot) and CHECK the name of a check of
     cross/*, each a glob. A build with a line may fail the check, which
     then says so on a line that is not a FAIL; where it succeeds its bytes
     are compared as any build's. *)
  val crossDeviationsFile = "tests/cross/deviations.txt"
  fun crossFlaky (ls : Expectations.line list, c, n) =
    List.find (fn l => #category l = "HOST-FLAKY") (List.filter (fn l => isSome (Expectations.find ([l], {way = c, path = n, label = NONE}))) ls)

  (* What a check says of its builds' results: each build, whether it
     compiled, and whether its bytes are the reference's -- the mlton
     build's, or the first build's that compiled where mlton's did not --
     with the deviations; the lines it prints, FAIL ones for what fails.
     mayFail: a program that every build refuses is refused alike, by the
     reference's message (refusedAlike) *)
  fun crossVerdict {n, results : (string * bool) list, sameBytes : string -> bool, refusedAlike : string -> bool,
                    why : string -> string, mayFail, deviations} : string list =
    let
      val failed = List.filter (not o #2) results
      fun tolerated (c, _) = isSome (crossFlaky (deviations, c, n))
      val (flaky, hard) = List.partition tolerated failed
      fun flakyLine (c, _) =
        case crossFlaky (deviations, c, n) of
          SOME l => "HOST-FLAKY " ^ n ^ ": rune-" ^ c ^ " failed (" ^ why c ^ "), which " ^ #file l ^ ":"
                    ^ Int.toString (#number l) ^ " tolerates"
        | NONE => ""
    in
      if mayFail andalso not (null failed) andalso length failed = length results then
        List.mapPartial (fn (c, _) => if refusedAlike c then NONE
                                      else SOME ("FAIL " ^ n ^ ": the mlton and " ^ c ^ " builds reject the program differently"))
                        hard
      else if not (null hard) then List.map (fn (c, _) => "FAIL " ^ n ^ ": rune-" ^ c ^ " failed: " ^ why c) hard @ List.map flakyLine flaky
      else
        List.map flakyLine flaky
        @ List.mapPartial (fn (c, ok) => if ok andalso not (sameBytes c)
                                         then SOME ("FAIL " ^ n ^ ": bytecode differs between the mlton and " ^ c ^ " builds") else NONE)
                          results
    end

  (* check NAME ARGS: compiled by every build; when MAY_FAIL, a program that
     every build refuses is refused alike *)
  fun crossCheck (n, target, args, mayFail) =
    let
      val out = run ^ "/cross"
      val () = mkdirs (OS.Path.dir(out ^ "/" ^ n ^ ".rbc"))
      fun f (c, ext) = out ^ "/" ^ n ^ "." ^ c ^ ext
      (* a compile in units (a build file's) but by smlnj32, whose Word64 is
         wrong and so its hash (Pickle.hash, D11 of
         docs/plans/functors-units.md): a program that keeps its units'
         identities carries them, which smlnj32 works out otherwise, as
         rune-units below *)
      val inUnits = List.exists (fn a => a = "--build" orelse a = "--units") args
      val results = List.map (fn c => (c, exec {cmd = ["bin/rune-" ^ c] @ target @ args @ ["-o", f (c, ".rbc")], dir = NONE,
                                                stdin = "", stdout = "", stderr = f (c, ".err"), timeout = 0} = 0))
                             (List.filter (fn c => not inUnits orelse c <> "smlnj32") (builds "rune"))
      (* the reference: mlton's, or the first build's that compiled *)
      val reference = case List.find (fn (c, ok) => ok andalso c = "mlton") results of
                        SOME (c, _) => c
                      | NONE => (case List.find #2 results of SOME (c, _) => c | NONE => "mlton")
      fun why c = case firstLine (f (c, ".err")) of "" => "it says nothing (is bin/rune-" ^ c ^ " there?)" | l => l
      val said = crossVerdict {n = n, results = results, sameBytes = fn c => same (f (reference, ".rbc"), f (c, ".rbc")),
                               refusedAlike = fn c => same (f ("mlton", ".err"), f (c, ".err")), why = why, mayFail = mayFail,
                               deviations = Expectations.read crossDeviationsFile}
    in
      List.app (fn l => say (l ^ "\n")) said
    end

  (* The checks of cross/* by name, and the deviations' lines that name no
     build or no check, or are of another category: what is wrong with the
     file, which fails `expectations/cross-deviations` *)
  fun crossCheckNames () =
    ["rune", "rune-stack", "rune-units", "runedoc", "runedoc-stack", "runeopt", "runeopt-stack", "basis-all"]
    @ List.map name (glob ("tests/lang", ".sml") @ ExampleProjects.programs ())
    @ List.map (fn t => "basis-" ^ t) (List.filter (fn t => t <> "harness" andalso t <> "finish") (List.map basename (glob ("tests/basis", ".sml"))))
  fun crossDeviationErrors (ls : Expectations.line list, hosts : string list, checks : string list) : string list =
    List.mapPartial (fn l =>
                       if #category l <> "HOST-FLAKY" then SOME (Expectations.describe l ^ ": only HOST-FLAKY is a deviation of check-cross")
                       else if not (List.exists (fn h => Expectations.glob (#way l, h)) hosts) then
                         SOME (Expectations.describe l ^ ": no build " ^ #way l ^ " (" ^ String.concatWith ", " hosts ^ ")")
                       else if not (List.exists (fn c => Expectations.glob (#path l, c)) checks) then
                         SOME (Expectations.describe l ^ ": no check " ^ #path l ^ " of cross/*")
                       else if isSome (#label l) then SOME (Expectations.describe l ^ ": a check of cross/* has no labels")
                       else NONE)
                    ls

  fun crossOne x =
    case x of
      "rune" => crossCheck ("rune", [], toolSrcs "rune", false)
    | "runedoc" => crossCheck ("runedoc", [], toolSrcs "runedoc", false)
    | "runeopt" => crossCheck ("runeopt", [], toolSrcs "runeopt", false)
    | "rune-stack" => crossCheck ("rune-stack", ["--target=stack"], toolSrcs "rune", false)
    | "runedoc-stack" => crossCheck ("runedoc-stack", ["--target=stack"], toolSrcs "runedoc", false)
    | "runeopt-stack" => crossCheck ("runeopt-stack", ["--target=stack"], toolSrcs "runeopt", false)
    | "basis-all" => crossCheck ("basis-all", [], ["--basis", "all", "examples/hello.sml"], false)
    | "rune-units" =>
        let
          val out = run ^ "/cross"
          val cache = out ^ "/units-cache"
          val () = (mkdirs out; rmTree cache)
          val srcs = toolSrcs "rune"
          fun f c = out ^ "/rune-units." ^ c ^ ".rbc"
          val ok = exec {cmd = ["bin/rune-mlton", "--units", "--no-cache"] @ srcs @ ["-o", f "nocache"], dir = NONE, stdin = "",
                         stdout = "", stderr = "", timeout = 0} = 0
          (* one after another, through one cache; but smlnj32, whose Word64
             is wrong, and so its hash (Pickle.hash, D11 of
             docs/plans/functors-units.md): the compiler built in units keeps
             its units' identities, which smlnj32 works out otherwise, with a
             probe of its own that keeps its entries apart. Its whole
             programs are compared above *)
          val bad = List.mapPartial (fn c => if exec {cmd = ["bin/rune-" ^ c, "--units", "--cache-dir", cache] @ srcs @ ["-o", f c],
                                                      dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 0} <> 0 then SOME c
                                             else if same (f "nocache", f c) then NONE else SOME (c ^ "(differs)"))
                                    (List.filter (fn c => c <> "smlnj32") (builds "rune"))
        in
          if ok andalso null bad then ()
          else say ("FAIL rune-units: through one cache: " ^ String.concatWith " " ((if ok then [] else ["nocache"]) @ bad) ^ "\n")
        end
    | _ =>
        if String.isPrefix "basis:" x then
          let
            val t = String.extract (x, 6, NONE)
            val uses = List.concat (List.map (fn l => if String.isPrefix "(* uses: " l andalso String.isSuffix " *)" l
                                                      then String.tokens Char.isSpace (String.substring (l, 9, size l - 12)) else [])
                                             (lines (read ("tests/basis/" ^ t ^ ".sml"))))
          in
            crossCheck ("basis-" ^ t, [], ["tests/basis/harness.sml"] @ List.map (fn u => "tests/basis/" ^ u) uses
                                          @ ["tests/basis/" ^ t ^ ".sml", "tests/basis/finish.sml"], true)
          end
        else crossCheck (name x, [], sourceArguments x, false)

  (* runedoc's builds print the same: the IR of the library and of
     tests/doc, and the site *)
  fun docCross () =
    let
      val out = run ^ "/doc-cross"
      val () = mkdirs out
      fun f (n, c, ext) = out ^ "/" ^ n ^ "." ^ c ^ ext
      fun runAll (n, args) =
        (List.app (fn c => append (f (n, c, ".err"),
                                   "exit status " ^ Int.toString (exec {cmd = ["bin/runedoc-" ^ c] @ args, dir = NONE, stdin = "",
                                                                         stdout = f (n, c, ".out"), stderr = f (n, c, ".err"),
                                                                         timeout = 0}) ^ "\n"))
                  (builds "runedoc");
         if size (read (f (n, "mlton", ".out"))) = 0 then say ("FAIL doc-cross " ^ n ^ ": runedoc-mlton printed nothing\n")
         else List.app (fn c => if same (f (n, "mlton", ".out"), f (n, c, ".out")) andalso same (f (n, "mlton", ".err"), f (n, c, ".err"))
                                then ()
                                else say ("FAIL doc-cross " ^ n ^ ": runedoc-" ^ c ^ " differs from runedoc-mlton\n"))
                       (builds "runedoc"))
      val signatures = List.filter (fn p => List.exists (fn l => String.isPrefix "signature " l) (lines (read p)))
                                   (glob ("lib/basis", ".sml"))
      val () = runAll ("ir-basis", "--dump-ir" :: signatures)
      (* --unicode: a test's names may be Unicode (anchors-unicode.sml) *)
      val () = runAll ("ir-tests", "--unicode" :: "--dump-ir" :: glob ("tests/doc", ".sml"))
      fun site c = out ^ "/site." ^ c
      val () = List.app (fn c => (rmTree (site c);
                                  if exec {cmd = ["bin/runedoc-" ^ c, "--lib", "lib", "--library", "basis", "--tests", "tests/basis",
                                                  "--annotations", "tests/basis/annotations.txt", "--out", site c],
                                           dir = NONE, stdin = "", stdout = "", stderr = site c ^ ".err", timeout = 0} <> 0
                                  then say ("FAIL doc-cross site: runedoc-" ^ c ^ " failed: " ^ firstLine (site c ^ ".err") ^ "\n")
                                  else ()))
                         (builds "runedoc")
      (* diff -r: every file of each tree, the same *)
      fun tree dir = List.concat (List.map (fn e => let val p = dir ^ "/" ^ e
                                                    in if isDir p then List.map (fn x => e ^ "/" ^ x) (tree p) else [e] end)
                                           (sort (entries dir)))
      val reference = tree (site "mlton")
    in
      List.app (fn c => if tree (site c) = reference andalso List.all (fn p => same (site "mlton" ^ "/" ^ p, site c ^ "/" ^ p)) reference
                           andalso same (site "mlton" ^ ".err", site c ^ ".err")
                        then ()
                        else say ("FAIL doc-cross site: runedoc-" ^ c ^ " writes another site than runedoc-mlton\n"))
               (builds "runedoc")
    end

  (* runeopt's builds print and translate the same *)
  fun optCross () =
    let
      val out = run ^ "/opt-cross"
      val () = mkdirs out
      fun f (n, c, ext) = out ^ "/" ^ n ^ "." ^ c ^ ext
      fun runAll (n, args) =
        (List.app (fn c => append (f (n, c, ".err"),
                                   "exit status " ^ Int.toString (exec {cmd = ["bin/runeopt-" ^ c] @ args, dir = NONE, stdin = "",
                                                                         stdout = f (n, c, ".out"), stderr = f (n, c, ".err"),
                                                                         timeout = 0}) ^ "\n"))
                  (builds "runeopt");
         List.app (fn c => if same (f (n, "mlton", ".out"), f (n, c, ".out")) andalso same (f (n, "mlton", ".err"), f (n, c, ".err"))
                           then ()
                           else say ("FAIL opt-cross " ^ n ^ ": runeopt-" ^ c ^ " differs from runeopt-mlton\n"))
                  (builds "runeopt"))
      val () = runAll ("facts", ["--facts", "bin/rune.stack.rbc", "bin/runedoc.stack.rbc"])
      val () = runAll ("disasm-rune", ["--disasm", "bin/rune.stack.rbc"])
      val () = write (out ^ "/bad.rbc", BytecodeFixture.header "runtime/stack/opcodes.def"
                         ^ BytecodeFixture.u32 1 ^ String.implode (List.map Char.chr [3, 240, 255, 255, 255]))
      val () = runAll ("refused", ["--check", out ^ "/bad.rbc"])
      val () = write (out ^ "/every-opcode.rbc", BytecodeFixture.assemble
                     {opdefs = "runtime/stack/opcodes.def", primdefs = "runtime/prims.def", listing = "tests/opt/every-opcode.rasm"})
      fun translate (n, prog) =
        (List.app (fn c => if exec {cmd = ["bin/runeopt-" ^ c, "-S", prog, "-o", f (n, c, ".s")], dir = NONE, stdin = "",
                                    stdout = f (n, c, ".log"), stderr = f (n, c, ".log"), timeout = 0} <> 0
                           then say ("FAIL opt-cross " ^ n ^ ": runeopt-" ^ c ^ " failed: " ^ firstLine (f (n, c, ".log")) ^ "\n")
                           else ())
                  (builds "runeopt");
         List.app (fn c => if same (f (n, "mlton", ".s"), f (n, c, ".s")) then ()
                           else say ("FAIL opt-cross " ^ n ^ ": runeopt-" ^ c ^ " translates differently\n"))
                  (builds "runeopt"))
      val () = translate ("runeopt", "bin/runeopt.stack.rbc")
      val () = translate ("every-opcode", out ^ "/every-opcode.rbc")
      (* an image, in a directory of its own, carried on by every build *)
      val dir = out ^ "/image"
      val () = scratch dir
    in
      if exec {cmd = ["bin/rune", "--target=stack", "tests/lang/rt.save_first.sml", "-o", out ^ "/first.rbc"], dir = NONE,
               stdin = "", stdout = "", stderr = "", timeout = 0} <> 0
         orelse exec {cmd = ["bin/runevm-stack", out ^ "/first.rbc"], dir = SOME dir, stdin = "", stdout = "", stderr = "",
                      timeout = 0} <> 0
      then say "FAIL opt-cross image: no image of tests/lang/rt.save_first\n"
      else
        let
          val img = dir ^ "/tests/out/rt.save_first.img"
          fun one c =
            if exec {cmd = ["bin/runeopt-" ^ c, "--from-image", img, "-S", "-o", out ^ "/image.s"], dir = NONE, stdin = "",
                     stdout = f ("image", c, ".err"), stderr = f ("image", c, ".err"), timeout = 0} <> 0
            then say ("FAIL opt-cross image: runeopt-" ^ c ^ " failed: " ^ firstLine (f ("image", c, ".err")) ^ "\n")
            else (OS.FileSys.rename {old = out ^ "/image.s", new = f ("image", c, ".s")};
                  (OS.FileSys.rename {old = out ^ "/image.rbc", new = f ("image", c, ".rbc")} handle OS.SysErr _ => ()))
        in
          List.app one (builds "runeopt");
          List.app (fn c => if same (f ("image", "mlton", ".s"), f ("image", c, ".s")) andalso same (f ("image", "mlton", ".rbc"), f ("image", c, ".rbc"))
                            then ()
                            else say ("FAIL opt-cross image: runeopt-" ^ c ^ " carries the image on differently\n"))
                   (builds "runeopt")
        end
    end

  (* ---- reproducible: the compiler's builds, the same bytes *)
  val reproBuilds =
    (* name, directory (the copy or the tree), flags, the builds before it *)
    [("units-nocache", false, ["--no-cache"], []),
     ("units-cold", false, ["--cache-dir", "c1"], []),
     ("units-warm", false, ["--cache-dir", "c1"], ["units-cold"]),
     ("units-cold-j", false, ["--cache-dir", "c2", "-j", "J"], []),
     ("units-warm-j", false, ["--cache-dir", "c2", "-j", "J"], ["units-cold-j"]),
     ("units-copy", true, ["--cache-dir", "c3", "-j", "J"], ["copy"]),
     ("whole-nocache", false, ["--no-cache", "--whole"], []),
     ("whole-cold", false, ["--cache-dir", "c4", "--whole"], []),
     ("whole-warm", false, ["--cache-dir", "c4", "--whole"], ["whole-cold"]),
     ("whole-warm-j", false, ["--cache-dir", "c2", "--whole", "-j", "J"], ["units-warm-j"]),
     ("whole-copy", true, ["--cache-dir", "c3", "--whole"], ["units-copy"])]

  fun reproCopy () =
    let
      val out = run ^ "/reproducible"
      val copy = out ^ "/copy"
      val () = (rmTree copy; mkdirs copy)
      val () = Posix.FileSys.symlink {old = root ^ "/bin", new = copy ^ "/bin"}
      val list = out ^ "/build-list"
      val _ = exec {cmd = ["bin/rune", "--build-list", "rune.build"], dir = NONE, stdin = "", stdout = list, stderr = "", timeout = 0}
    in
      List.app (fn p => (mkdirs (OS.Path.dir (copy ^ "/" ^ p)); write (copy ^ "/" ^ p, read p)))
        (["rune.build", "lib/compiler/internal.build", "lib/compiler/frontend.build", "lib/compiler/util.build"] @ lines (read list))
    end

  fun reproBuild nm =
    case List.find (fn (n, _, _, _) => n = nm) reproBuilds of
      NONE => say ("FAIL reproducible: no build " ^ nm ^ "\n")
    | SOME (_, inCopy, flags, _) =>
        let
          val out = run ^ "/reproducible"
          val () = mkdirs out
          val j = env ("RUNE_TEST_CPUS", "8")
          val flags = List.map (fn "J" => j | x => if String.isPrefix "c" x andalso size x = 2 then out ^ "/" ^ x else x) flags
          val args = ["--build", "rune.build"] @ flags @ ["-o", out ^ "/" ^ nm ^ ".rbc"]
          (* the compiler is bin/rune by that name in the copy too, in the
             directory of the sources: the library's paths it writes come
             from the name *)
          val code = exec {cmd = if inCopy then ["/bin/sh", "-c", "cd " ^ quote (out ^ "/copy") ^ " && exec bin/rune \"$@\"", "sh"] @ args
                                 else "bin/rune" :: args,
                           dir = NONE, stdin = "", stdout = out ^ "/" ^ nm ^ ".out", stderr = out ^ "/" ^ nm ^ ".out", timeout = 0}
        in
          if code = 0 then () else say ("FAIL reproducible: " ^ nm ^ " failed: " ^ firstLine (out ^ "/" ^ nm ^ ".out") ^ "\n")
        end

  fun reproCompare () =
    let
      fun f n = run ^ "/reproducible/" ^ n ^ ".rbc"
      fun group (first, members) =
        List.app (fn n => if same (f first, f n) then ()
                          else say ("FAIL reproducible: the " ^ hd (String.fields (fn c => c = #"-") first) ^ " build " ^ n
                                    ^ " differs from " ^ first ^ "\n"))
                 members
    in
      group ("units-nocache", ["units-cold", "units-warm", "units-cold-j", "units-warm-j", "units-copy"]);
      group ("whole-nocache", ["whole-cold", "whole-warm", "whole-warm-j", "whole-copy"]);
      if exists "bin/rune.rbc" andalso not (same (f "whole-nocache", "bin/rune.rbc")) then
        say "FAIL reproducible: the whole build differs from bin/rune.rbc\n"
      else ()
    end

  (* ---- bootstrap: the compiler compiled by itself *)
  fun bootstrapOne target =
    let
      val out = run ^ "/bootstrap"
      val () = mkdirs out
      val (flags, made, reference) =
        if target = "stack" then (["--target=stack"], out ^ "/rune.stage2.stack.rbc", "bin/rune.stack.rbc")
        else ([], out ^ "/rune.stage2.rbc", "bin/rune.rbc")
    in
      if exec {cmd = ["bin/rune-boot"] @ flags @ ["-o", made] @ bootSrcs (), dir = NONE, stdin = "", stdout = out ^ "/" ^ target ^ ".err",
               stderr = out ^ "/" ^ target ^ ".err", timeout = 0} <> 0
      then say ("FAIL bootstrap: the compiler did not compile itself: " ^ firstLine (out ^ "/" ^ target ^ ".err") ^ "\n")
      else if same (reference, made) then ()
      else say ("FAIL bootstrap: " ^ reference ^ " does not reproduce itself\n")
    end

  (* Former Make test recipes: private outputs, finite commands, ordinary
     producer edges and the same independently reviewed expected bytes. *)
  fun unitsBootstrap () =
    let val out=run ^ "/bootstrap/units"
        val ()=mkdirs out
        val stage1=out ^ "/rune.units.rbc"
        val stage2=out ^ "/rune.stage2.units.rbc"
        fun command label args=exec {cmd=args,dir=NONE,stdin="",stdout=out ^ "/" ^ label ^ ".out",
                                    stderr=out ^ "/" ^ label ^ ".err",timeout=1800}
    in if command "stage1" (["bin/rune-boot","--units","-o",stage1] @ bootSrcs ())<>0
       then say "FAIL units bootstrap: stage 1 failed\n"
       else if command "stage2" (["bin/runevm","--heap-size",env ("RUNE_HEAP","67108864"),stage1,
                                 "--lib","bin/../lib","-o",stage2] @ bootSrcs ())<>0
       then say "FAIL units bootstrap: stage 2 failed\n"
       else if same ("bin/rune.rbc",stage2) then ()
       else say "FAIL units bootstrap: compiler bytecode differs\n" end
  (* the programs of make test-int64, each compiled at --int-bits=64: a
     word past 63 bits in a home, and the division by a constant
     (functors-units M1) of tests/lang, on 64-bit dividends *)
  val int64Programs = [("box-home", "tests/register/int64-box-home.sml", "tests/register/int64-box-home.expected"),
                       ("div-constant", "tests/lang/rt.div_constant.sml", "tests/register/int64-div-constant.expected")]
  fun int64Compile () =
    let val out=run ^ "/int64" val ()=mkdirs out
    in List.app (fn (name, src, _) =>
         if exec {cmd=["bin/rune","--int-bits=64",src,"-o",out ^ "/" ^ name ^ ".rbc"],
                  dir=NONE,stdin="",stdout=out ^ "/" ^ name ^ ".compile.out",stderr=out ^ "/" ^ name ^ ".compile.err",timeout=600}=0
         then () else say ("FAIL int64 " ^ name ^ ": compilation failed\n")) int64Programs end
  fun int64Home vm mode =
    let val out=run ^ "/int64"
    in List.app (fn (name, _, expected) =>
         let val file=out ^ "/" ^ name ^ "." ^ vm ^ "." ^ mode ^ ".out"
             val status=exec {cmd=["bin/" ^ vm,"--jit=" ^ mode,out ^ "/" ^ name ^ ".rbc"],dir=NONE,stdin="",
                              stdout=file,stderr=file,timeout=120}
         in if status=0 andalso same (file,expected) then ()
            else say ("FAIL int64 " ^ name ^ ": " ^ vm ^ "/" ^ mode ^ " differs or exits unsuccessfully\n") end) int64Programs end

  (* the deviations' rules on planted lines (the runner's own check,
     runner/cross-deviations): a build's failure that no line names fails;
     a flaky build that fails is told, not failed, and every other build is
     still compared; a flaky build that compiles is compared as any; and a
     line that names no build or no check, or of another category, is an
     error *)
  fun crossDeviationChecks () =
    let
      val planted = Expectations.parse ("planted", "smlnj32 | basis-word | HOST-FLAKY | planted\n")
      val builds = ["mlton", "smlnj-legacy", "smlnj32", "polyml"]
      fun verdict (n, results, sameBytes, refusedAlike, mayFail) =
        crossVerdict {n = n, results = results, sameBytes = sameBytes, refusedAlike = refusedAlike, why = fn _ => "planted",
                      mayFail = mayFail, deviations = planted}
      fun fails ls = List.exists (String.isPrefix "FAIL ") ls
      fun told ls = List.exists (String.isPrefix "HOST-FLAKY ") ls
      fun check (what, ok) = say ((if ok then "PASS" else "FAIL") ^ " cross deviations: " ^ what ^ "\n")
      fun all f = List.map (fn c => (c, f c)) builds
      val yes = fn _ => true
    in
      check ("a flaky build that fails is told, not failed",
             let val v = verdict ("basis-word", all (fn c => c <> "smlnj32"), yes, yes, false) in not (fails v) andalso told v end);
      check ("a failure that no line names fails", fails (verdict ("basis-word", all (fn c => c <> "polyml"), yes, yes, false)));
      check ("a flaky build's failure beside another's fails",
             fails (verdict ("basis-word", all (fn c => c <> "polyml" andalso c <> "smlnj32"), yes, yes, false)));
      check ("another check's failure of the flaky build fails",
             fails (verdict ("basis-int", all (fn c => c <> "smlnj32"), yes, yes, false)));
      check ("a flaky build that compiles other bytes fails",
             fails (verdict ("basis-word", all yes, fn c => c <> "smlnj32", yes, false)));
      check ("another build's other bytes fail beside a flaky failure",
             fails (verdict ("basis-word", all (fn c => c <> "smlnj32"), fn c => c <> "polyml", yes, false)));
      check ("a flaky build that compiles the same passes", null (verdict ("basis-word", all yes, yes, yes, false)));
      check ("a program every build refuses alike passes", null (verdict ("basis-word", all (fn _ => false), yes, yes, true)));
      check ("a program refused otherwise by one build fails",
             fails (verdict ("basis-word", all (fn _ => false), yes, fn c => c <> "polyml", true)));
      check ("lines that name no build, no check, a label or another category are errors",
             length (crossDeviationErrors
                       (Expectations.parse ("planted", "nohost | basis-word | HOST-FLAKY | x\nsmlnj32 | nocheck | HOST-FLAKY | x\n"
                                                       ^ "smlnj32 | basis-word | HOST-BUG | x\nsmlnj32 | basis-word::l | HOST-FLAKY | x\n"
                                                       ^ "smlnj* | basis-w* | HOST-FLAKY | x\n"),
                        hostBuilds @ ["boot"], ["basis-word", "rune"])) = 4)
    end

  (* tests/cross/deviations.txt parses, and names builds and checks that
     exist (expectations/cross-deviations) *)
  fun crossDeviations () =
    List.app (fn e => say ("FAIL " ^ e ^ "\n"))
             (crossDeviationErrors (Expectations.read crossDeviationsFile, hostBuilds @ ["boot"], crossCheckNames ()))
    handle Expectations.Parse m => say ("FAIL " ^ m ^ "\n")

  (* the commands of bin/rune-test that are these checks *)
  fun command args =
    case args of
      ["levels-one", src] => SOME (fn () => levelsOne src)
    | ["units-bootstrap"] => SOME unitsBootstrap
    | ["int64-compile"] => SOME int64Compile
    | ["int64-home",vm,mode] => SOME (fn () => int64Home vm mode)
    | ["register-one", src] => SOME (fn () => registerOne src)
    | ["register-bootstrap"] => SOME registerBootstrap
    | ["register-prims"] => SOME registerPrims
    | ["register-dead-roots"] => SOME registerDeadRoots
    | ["regverify-one", kind] => SOME (fn () => regverifyOne kind)
    | ["rbccheck-one", kind] => SOME (fn () => rbccheckOne kind)
    | ["jit-one", src] => SOME (fn () => jitOne src)
    | ["jit-probe"] => SOME jitProbe
    | ["jit-every-opcode"] => SOME jitEveryOpcode
    | ["jit-fatal", which] => SOME (fn () => jitFatal which)
    | ["jit-every-instruction"] => SOME jitEveryInstruction
    | ["jit-boot-compile"] => SOME jitBootCompile
    | ["jit-boot", mode] => SOME (fn () => jitBootMode mode)
    | ["jit-boot-compare"] => SOME jitBootCompare
    | ["units-setup", variant, rune] => SOME (fn () => unitsSetup (variant, rune))
    | ["units-one", variant, rune, vm, src] => SOME (fn () => unitsOne (variant, rune, vm, src))
    | ["positions-one", src] => SOME (fn () => positionsOne src)
    | ["cross-one", x] => SOME (fn () => crossOne x)
    | ["cross-deviation-checks"] => SOME crossDeviationChecks
    | ["cross-deviations"] => SOME crossDeviations
    | ["example-project-inventory"] => SOME ExampleProjects.audit
    | ["doc-cross"] => SOME docCross
    | ["opt-cross"] => SOME optCross
    | ["repro-copy"] => SOME reproCopy
    | ["repro-build", n] => SOME (fn () => reproBuild n)
    | ["repro-compare"] => SOME reproCompare
    | ["bootstrap", target] => SOME (fn () => bootstrapOne target)
    | _ => NONE

  (* ---- the tree *)
  fun jobIn (prefix, path, args, after, cpus, memory, timeout) =
    Test.it path
      {program = "/bin/sh",
       args = ["sh", "-c", prefix ^ "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = cpus, memory = memory,
       pools = [], exclusive = false, after = after, judge = failLines} : Run.command Test.tree
  fun job (path, args, after, cpus, memory, timeout) = jobIn ("", path, args, after, cpus, memory, timeout)

  (* the JIT's checks on a VM, under NAME: every program in every mode, every
     opcode, the fatal errors, every instruction and the bootstrap *)
  fun jitTree (vm, nm) =
    let
      val prefix = if vm = "bin/runevm" then "" else "JIT_VM=" ^ vm ^ " "
      fun j (path, args, after, memory, timeout) = jobIn (prefix, path, args, after, 1, memory, timeout)
    in
      Test.describe nm
        (List.map (fn src => j (jitName src, ["jit-one", src], [], 600, 3600)) (langPerf @ ["tests/opt/prims.sml"])
         @ [j ("@probe", ["jit-probe"], [], 200, 600), j ("@every-opcode", ["jit-every-opcode"], [], 500, 600)]
         @ List.map (fn w => j ("@fatal-" ^ w, ["jit-fatal", w], [], 200, 600)) ["call", "decon", "global"]
         @ [j ("@every-instruction", ["jit-every-instruction"],
               (nm ^ "/@every-opcode") :: List.map (fn s => nm ^ "/" ^ jitName s) (langPerf @ ["tests/opt/prims.sml"]), 200, 600),
            j ("@boot-compile", ["jit-boot-compile"], [], 1500, 3600)]
         @ List.map (fn (_, m, _) => j ("@boot-" ^ m, ["jit-boot", m], [nm ^ "/@boot-compile"], 1500, 3600)) bootModes
         @ [j ("@boot-compare", ["jit-boot-compare"], List.map (fn (_, m, _) => nm ^ "/@boot-" ^ m) bootModes, 100, 600)])
    end

  fun perProgram (cmd, srcs, after, name) = List.map (fn src => job (name src, [cmd, src], after, 1, 600, 3600)) srcs

  val positionsSrcs = glob ("tests/lang", ".sml") @ ExampleProjects.programs()
  val basisTests = List.filter (fn t => t <> "harness" andalso t <> "finish") (List.map basename (glob ("tests/basis", ".sml")))
  val crossSrcs = positionsSrcs @ List.map (fn t => "basis:" ^ t) basisTests

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  val langCovers = ["covers:tests/lang/*", "covers:tests/perf/*"]

  (* a command of bin/rune-functor-gen, which exits 0 when it passed; its
     output in the job's directory *)
  fun functorGen (path, args, out, timeout) =
    Test.it path
      {program = "/bin/sh",
       args = ["sh", "-c", "exec bin/rune-functor-gen " ^ String.concatWith " " (List.map quote args) ^ " --out \"$RUNE_TEST_RUN/" ^ out ^ "\""],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = 1500,
       pools = [], exclusive = false, after = [], judge = Run.exitZero} : Run.command Test.tree

  val tree =
    Test.describe ""
      [tagged (["check", "check-levels"] @ langCovers)
         (Test.describe "levels" (perProgram ("levels-one", langPerf, [], name))),
       tagged (["check", "test-register", "covers:tests/register/*", "covers:tests/opt/*"] @ langCovers)
         (Test.describe "register"
            (perProgram ("register-one", langPerf, [], name)
             @ [job ("@bootstrap", ["register-bootstrap"], [], 1, 1500, 3600),
                job ("@prims", ["register-prims"], [], 1, 500, 600),
                job ("@dead-roots", ["register-dead-roots"], [], 1, 500, 600)]
             @ List.map (fn k => job ("@regverify-" ^ k, ["regverify-one", k], [], 1, 500, 600))
                        ("clean" :: List.map #1 regverifyKinds))),
       tagged (["check", "test-register-jit", "covers:tests/register/*", "covers:tests/opt/*"] @ langCovers)
         (jitTree ("bin/runevm", "jit")),
       tagged ["check", "test-opt", "covers:tests/opt/*", "covers:src/opt/*", "covers:src/driver/stackcheck.sml"]
         (Test.describe "stack"
            (List.map (fn k => job ("@rbccheck-" ^ k, ["rbccheck-one", k], [], 1, 500, 600))
                      (["clean", "clean-units"] @ List.map #1 rbccheckKinds))),
       tagged (["check", "check-units", "covers:tests/units/*"] @ langCovers)
         (Test.describe ""
            (List.map (fn (variant, rune, vm) =>
                         Test.describe variant
                           (job ("@setup", ["units-setup", variant, rune], [], 1, 500, 600)
                            :: List.map (fn src => job (name src, ["units-one", variant, rune, vm, src], [variant ^ "/@setup"], 1, 600, 3600))
                                        langPerf))
                      [("units", "bin/rune", "bin/runevm"), ("units-stack", "bin/rune-stack", "bin/runevm-stack")])),
       tagged ["check", "check-positions", "covers:tests/lang/*", "covers:examples/*"]
         (Test.describe "positions" (perProgram ("positions-one", positionsSrcs, [], name))),
       Test.requires hostBuilds (tagged ["check", "check-cross", "covers:tests/lang/*", "covers:examples/*", "covers:tests/basis/*", "covers:tests/doc/*",
               "covers:tests/opt/*"]
         (Test.describe "cross"
            (job ("@examples", ["example-project-inventory"], [], 1, 100, 60) ::
             List.map (fn x => job (x, ["cross-one", x], [], 1, 1500, 3600))
                      ["rune", "rune-stack", "rune-units", "runedoc", "runedoc-stack", "runeopt", "runeopt-stack", "basis-all"]
             @ List.map (fn x => job (if String.isPrefix "basis:" x then "basis-" ^ String.extract (x, 6, NONE) else name x,
                                       ["cross-one", x], [], 1, 1000, 3600))
                        crossSrcs
             @ [job ("@doc", ["doc-cross"], [], 1, 2000, 3600), job ("@opt", ["opt-cross"], [], 1, 2000, 3600)]))),
       tagged ["check", "quick", "covers:tests/cross/*", "covers:tests/runner/oracles.sml"]
         (Test.describe "runner" [job ("cross-deviations", ["cross-deviation-checks"], [], 1, 256, 120)]),
       tagged ["check", "covers:tests/cross/*", "covers:tests/lang/*", "covers:tests/basis/*", "covers:examples/*"]
         (Test.describe "expectations" [job ("cross-deviations", ["cross-deviations"], [], 1, 256, 120)]),
       tagged ["check", "check-reproducible", "covers:examples/hello.sml"]
         (Test.describe "reproducible"
            (job ("copy", ["repro-copy"], [], 1, 100, 600)
             :: List.map (fn (n, _, flags, earlier) =>
                            job (n, ["repro-build", n], List.map (fn b => "reproducible/" ^ b) earlier,
                                 if List.exists (fn x => x = "J") flags then 4 else 1, 1500, 3600))
                         reproBuilds
             @ [job ("@compare", ["repro-compare"], List.map (fn (n, _, _, _) => "reproducible/" ^ n) reproBuilds, 1, 100, 600)])),
       tagged ["check", "check-units", "check-units-bootstrap", "covers:tests/units/*"]
         (Test.describe "bootstrap" [job ("units", ["units-bootstrap"], [], 1, 1500, 3600)]),
       (* generated programs of functors, compiled with functors as functions
          and as copies, whole and in units, from a fixed seed; and the
          programs of the failures it found (docs/testing.md, Generated
          functor programs) *)
       tagged ["check", "check-units", "covers:tests/functors/*", "covers:tests/runner/functorgen.sml",
               "covers:tests/runner/functorgen-main.sml"]
         (Test.describe "functors"
            [functorGen ("@generated", ["check", "--seed", "1", "--count", "16", "--shrinks", "100", "--known", "tests/functors/known.txt"],
                         "functors", 3600),
             functorGen ("@regressions", ["regressions", "--known", "tests/functors/known.txt", "tests/functors"], "functors-regressions",
                         1800)]),
       tagged ["test-int64", "covers:tests/register/int64-box-home.*", "covers:tests/register/int64-div-constant.*",
               "covers:tests/lang/rt.div_constant.*"]
         (Test.describe "int64"
           (job ("compile", ["int64-compile"], [], 1, 600, 900) ::
            List.concat (List.map (fn vm => List.map (fn mode =>
              job (vm ^ "/" ^ mode,["int64-home",vm,mode],["int64/compile"],1,300,180))
              ["off","baseline","opt","all"]) ["runevm-int64","runevm-rawhomes"]))),
       tagged ["check", "bootstrap"]
         (Test.describe "bootstrap" [job ("register", ["bootstrap", "register"], [], 1, 1500, 3600),
                                      job ("stack", ["bootstrap", "stack"], [], 1, 1500, 3600)])]
end
