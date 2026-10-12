(* The differential checks as oracles (docs/plans/unit-testing.md, M9;
   docs/testing.md, The three oracles): "counts equal" and "bytes equal",
   compared across ways, levels, builds and hosts. Each was a script of
   scripts/ that ran a check on every program N at a time and then a few
   checks of its own; each program is now a job of the runner, which runs
   a command of bin/rune-test (`bin/rune-test levels-one PROGRAM`, ...) that
   prints a line FAIL for what it finds, and each check of its own a job.

   - levels: every program of tests/lang and tests/perf compiled at -O0 and
     -O2, whole and of its units' Mid, with the lint, must print, err and
     exit the same (check-levels.sh);
   - register: compiled to both bytecodes, runevm-stack and runtime/register
     must allocate the same; the compiler on runtime/register must make the
     bytes it makes on runevm-stack; the primitives must print the same; and
     the dead registers must go at every tier (check-register.sh);
   - jit: every program, interpreted and under seven modes of the JIT, must
     print, count and err the same, as must every instruction, the fatal
     errors and the compiler compiling itself; and every instruction must
     occur in some program (check-jit.sh);
   - units: whole, of units at -O0, -O1 and -O2, through the cache, from
     it, relinked and loaded, the same bytes and the same runs
     (check-units.sh);
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

  val langPerf = glob ("tests/lang", ".sml") @ glob ("tests/perf", ".sml")
  fun base src = String.substring (src, 0, size src - 4)
  fun name src = basename src
  (* run-tests.sh's siblings: the words of .cargs, .args, .vmargs, and the
     file of .stdin *)
  fun sib (b, ext) = words (b ^ ext)
  fun stdinOf b = if exists (b ^ ".stdin") then fromRoot (b ^ ".stdin") else ""
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
  fun levelsOne src =
    let
      val b = base src and n = name src
      val out = run ^ "/levels"
      val () = mkdirs out
      val cargs = sib (b, ".cargs")
      val builds = [("O0", ["-O0"] @ cargs), ("O2", ["-O2"] @ cargs),
                    ("U0", ["--units", "--whole", "--no-cache", "-O0"] @ cargs),
                    ("U2", ["--units", "--whole", "--no-cache", "-O2"] @ cargs)]
      fun file (k, ext) = out ^ "/" ^ n ^ "." ^ k ^ ext
      fun compile [] = true
        | compile ((k, flags) :: rest) =
            if exec {cmd = ["bin/rune-stack"] @ flags @ ["--lint", "--mid-roundtrip", src, "-o", file (k, ".rbc")],
                     dir = NONE, stdin = "", stdout = "", stderr = file (k, ".cerr"), timeout = 0} = 0
            then compile rest
            else (say ("FAIL levels." ^ n ^ ": " ^ String.concatWith " " flags ^ ": " ^ firstLine (file (k, ".cerr")) ^ "\n"); false)
    in
      if not (compile builds) then ()
      else
        let
          val dir = run ^ "/levels-run/" ^ n
          val () = scratch dir
          val () = List.app (fn (k, _) =>
                               write (file (k, ".code"),
                                      Int.toString (exec {cmd = ["bin/runevm-stack", "--checked"] @ sib (b, ".vmargs")
                                                                @ [file (k, ".rbc")] @ sib (b, ".args"),
                                                          dir = SOME dir, stdin = stdinOf b, stdout = file (k, ".out"),
                                                          stderr = file (k, ".err"), timeout = 0}) ^ "\n"))
                            builds
          fun check [] = ()
            | check ((k, part) :: rest) =
                if same (file ("O0", part), file (k, part)) then check rest
                else say ("FAIL levels." ^ n ^ ": -O0 and " ^ k ^ " differ (" ^ String.extract (part, 1, NONE) ^ ": "
                          ^ difference (file ("O0", part), file (k, part)) ^ ")\n")
        in
          check (List.concat (List.map (fn k => List.map (fn p => (k, p)) [".out", ".err", ".code"]) ["O2", "U0", "U2"]))
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
        in
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

  (* a program of tests/register or tests/opt in the assembler's text, as
     bytecode (tests/opt/rbcasm.awk) *)
  fun assemble (rasm, rbc) =
    exec {cmd = ["/bin/sh", "-c", "printf \"$(awk -v opdefs=runtime/register/regs.def -v primdefs=runtime/prims.def "
                                  ^ "-f tests/opt/rbcasm.awk " ^ rasm ^ ")\" > " ^ rbc],
          dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 0} = 0

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
  val noLoad = ["tests/lang/rt.trace_frames", "tests/lang/rt.trace_inlined", "tests/lang/rt.save_restore_cross"]

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
      fun c (k, flags) = exec {cmd = [rune] @ flags @ ["--lint", src, "-o", f (k ^ ".rbc")], dir = NONE, stdin = "", stdout = "",
                               stderr = f (k ^ ".cerr"), timeout = 0} = 0
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
      val () = mkdirs out
    in
      (* a program that does not compile is tests/errors' *)
      if exec {cmd = ["bin/rune-stack", "--lib", "lib"] @ sib (base src, ".cargs") @ [src, "-o", out ^ "/" ^ n ^ ".rbc"], dir = NONE,
               stdin = "", stdout = out ^ "/" ^ n ^ ".log", stderr = out ^ "/" ^ n ^ ".log", timeout = 0} <> 0 then ()
      else
        let
          val dis = out ^ "/" ^ n ^ ".disasm"
          val _ = exec {cmd = ["bin/runevm-stack", "--disasm", out ^ "/" ^ n ^ ".rbc"], dir = NONE, stdin = "", stdout = dis,
                        stderr = "", timeout = 0}
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

  (* check NAME ARGS: compiled by every build; when MAY_FAIL, a program that
     every build refuses is refused alike *)
  fun crossCheck (n, target, args, mayFail) =
    let
      val out = run ^ "/cross"
      val () = mkdirs out
      fun f (c, ext) = out ^ "/" ^ n ^ "." ^ c ^ ext
      val results = List.map (fn c => (c, exec {cmd = ["bin/rune-" ^ c] @ target @ args @ ["-o", f (c, ".rbc")], dir = NONE,
                                                stdin = "", stdout = "", stderr = f (c, ".err"), timeout = 0} = 0))
                             (builds "rune")
      val failed = List.filter (not o #2) results
    in
      if not (null failed) then
        if mayFail andalso length failed = length results then
          List.app (fn (c, _) => if same (f ("mlton", ".err"), f (c, ".err")) then ()
                                 else say ("FAIL " ^ n ^ ": the mlton and " ^ c ^ " builds reject the program differently\n"))
                   results
        else List.app (fn (c, _) => say ("FAIL " ^ n ^ ": rune-" ^ c ^ " failed: "
                                         ^ (case firstLine (f (c, ".err")) of
                                              "" => "it says nothing (is bin/rune-" ^ c ^ " there?)"
                                            | l => l) ^ "\n")) failed
      else
        case List.find (fn (c, _) => not (same (f ("mlton", ".rbc"), f (c, ".rbc")))) results of
          SOME (c, _) => say ("FAIL " ^ n ^ ": bytecode differs between the mlton and " ^ c ^ " builds\n")
        | NONE => ()
    end


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
          (* one after another, through one cache *)
          val bad = List.mapPartial (fn c => if exec {cmd = ["bin/rune-" ^ c, "--units", "--cache-dir", cache] @ srcs @ ["-o", f c],
                                                      dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 0} <> 0 then SOME c
                                             else if same (f "nocache", f c) then NONE else SOME (c ^ "(differs)"))
                                    (builds "rune")
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
        else
          let
            (* the first line's `(* libraries: a b *)` *)
            val first = case String.fields (fn c => c = #"\n") (read x) of l :: _ => l | [] => ""
            val libs = if String.isPrefix "(* libraries: " first andalso String.isSuffix " *)" first
                       then List.concat (List.map (fn l => ["--library", l])
                                                  (String.tokens Char.isSpace (String.substring (first, 14, size first - 17))))
                       else []
          in crossCheck (name x, [], libs @ sib (base x, ".cargs") @ [x], false) end

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
      val () = runAll ("ir-tests", "--dump-ir" :: glob ("tests/doc", ".sml"))
      fun site c = out ^ "/site." ^ c
      val () = List.app (fn c => (rmTree (site c);
                                  if exec {cmd = ["bin/runedoc-" ^ c, "--lib", "lib", "--library", "basis", "--tests", "tests/basis",
                                                  "--annotations", "tests/basis/annotations.txt", "--out", site c, "--title", "Basis"],
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
      val _ = exec {cmd = ["/bin/sh", "-c", "printf \"$(sed -n 's/^# rbc header //p' runtime/stack/opcodes.def)\\001\\000\\000\\000\\003\\360\\377\\377\\377\" > "
                                            ^ out ^ "/bad.rbc"], dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 0}
      val () = runAll ("refused", ["--check", out ^ "/bad.rbc"])
      val _ = exec {cmd = ["/bin/sh", "-c", "printf \"$(awk -v opdefs=runtime/stack/opcodes.def -v primdefs=runtime/prims.def "
                                            ^ "-f tests/opt/rbcasm.awk tests/opt/every-opcode.rasm)\" > " ^ out ^ "/every-opcode.rbc"],
                    dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 0}
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
      List.app (fn p => (mkdirs (OS.Path.dir (copy ^ "/" ^ p)); write (copy ^ "/" ^ p, read p))) ("rune.build" :: lines (read list))
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

  (* the commands of bin/rune-test that are these checks *)
  fun command args =
    case args of
      ["levels-one", src] => SOME (fn () => levelsOne src)
    | ["register-one", src] => SOME (fn () => registerOne src)
    | ["register-bootstrap"] => SOME registerBootstrap
    | ["register-prims"] => SOME registerPrims
    | ["register-dead-roots"] => SOME registerDeadRoots
    | ["jit-one", src] => SOME (fn () => jitOne src)
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
         @ [j ("@every-opcode", ["jit-every-opcode"], [], 500, 600)]
         @ List.map (fn w => j ("@fatal-" ^ w, ["jit-fatal", w], [], 200, 600)) ["call", "decon", "global"]
         @ [j ("@every-instruction", ["jit-every-instruction"],
               (nm ^ "/@every-opcode") :: List.map (fn s => nm ^ "/" ^ jitName s) (langPerf @ ["tests/opt/prims.sml"]), 200, 600),
            j ("@boot-compile", ["jit-boot-compile"], [], 1500, 3600)]
         @ List.map (fn (_, m, _) => j ("@boot-" ^ m, ["jit-boot", m], [nm ^ "/@boot-compile"], 1500, 3600)) bootModes
         @ [j ("@boot-compare", ["jit-boot-compare"], List.map (fn (_, m, _) => nm ^ "/@boot-" ^ m) bootModes, 100, 600)])
    end

  fun perProgram (cmd, srcs, after, name) = List.map (fn src => job (name src, [cmd, src], after, 1, 600, 3600)) srcs

  val positionsSrcs = glob ("tests/lang", ".sml") @ glob ("examples", ".sml")
                      @ List.concat (List.map (fn d => glob ("examples/" ^ d, ".sml"))
                                              (List.filter (fn d => isDir ("examples/" ^ d)) (sort (entries "examples"))))
  val basisTests = List.filter (fn t => t <> "harness" andalso t <> "finish") (List.map basename (glob ("tests/basis", ".sml")))
  val crossSrcs = positionsSrcs @ List.map (fn t => "basis:" ^ t) basisTests

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  val langCovers = ["covers:tests/lang/*", "covers:tests/perf/*"]

  val tree =
    Test.describe ""
      [tagged (["check", "check-levels"] @ langCovers)
         (Test.describe "levels" (perProgram ("levels-one", langPerf, [], name))),
       tagged (["check", "test-register", "covers:tests/register/*", "covers:tests/opt/*"] @ langCovers)
         (Test.describe "register"
            (perProgram ("register-one", langPerf, [], name)
             @ [job ("@bootstrap", ["register-bootstrap"], [], 1, 1500, 3600),
                job ("@prims", ["register-prims"], [], 1, 500, 600),
                job ("@dead-roots", ["register-dead-roots"], [], 1, 500, 600)])),
       tagged (["check", "test-register-jit", "covers:tests/register/*", "covers:tests/opt/*"] @ langCovers)
         (jitTree ("bin/runevm", "jit")),
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
            (List.map (fn x => job (x, ["cross-one", x], [], 1, 1500, 3600))
                      ["rune", "rune-stack", "rune-units", "runedoc", "runedoc-stack", "runeopt", "runeopt-stack", "basis-all"]
             @ List.map (fn x => job (if String.isPrefix "basis:" x then "basis-" ^ String.extract (x, 6, NONE) else name x,
                                       ["cross-one", x], [], 1, 1000, 3600))
                        crossSrcs
             @ [job ("@doc", ["doc-cross"], [], 1, 2000, 3600), job ("@opt", ["opt-cross"], [], 1, 2000, 3600)]))),
       tagged ["check", "check-reproducible", "covers:examples/hello.sml"]
         (Test.describe "reproducible"
            (job ("copy", ["repro-copy"], [], 1, 100, 600)
             :: List.map (fn (n, _, flags, earlier) =>
                            job (n, ["repro-build", n], List.map (fn b => "reproducible/" ^ b) earlier,
                                 if List.exists (fn x => x = "J") flags then 4 else 1, 1500, 3600))
                         reproBuilds
             @ [job ("@compare", ["repro-compare"], List.map (fn (n, _, _, _) => "reproducible/" ^ n) reproBuilds, 1, 100, 600)])),
       tagged ["check", "bootstrap"]
         (Test.describe "bootstrap" [job ("register", ["bootstrap", "register"], [], 1, 1500, 3600),
                                      job ("stack", ["bootstrap", "stack"], [], 1, 1500, 3600)])]
end
